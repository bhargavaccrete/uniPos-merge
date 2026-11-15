import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/hive_box_names.dart';
import '../../../core/di/service_locator.dart';
import '../../../data/models/retail/hive_model/cart_model_202.dart';
import '../../../data/models/retail/hive_model/sale_item_model_204.dart';
import '../../../data/models/retail/hive_model/sale_model_203.dart';
import '../../../data/repositories/retail/sale_item_repository.dart';
import '../../../data/repositories/retail/sale_repository.dart';
import '../restaurant/day_management_service.dart';
import 'checkout_customer_posting.dart';
import 'inventory_service.dart';

/// One Retail sale between "about to be saved" and "finished": everything a
/// restart needs to finish it — the lines to deduct, the customer steps, the
/// tab to clear — and the progress of each. Persisted in
/// [HiveBoxNames.retailCheckoutJournal] as a plain map.
class RetailCheckoutEntry implements SaleStockIntents {
  static const int version = 1;

  final String saleId;
  final String invoiceNumber;
  final String? tabId;
  final String staffName;
  final String? sessionId;
  final DateTime createdAt;
  final List<CartItemModel> lines;
  final CheckoutCustomerPosting? posting;

  /// Stock row id → `{before, after}`, or `{conflict: true}`.
  final Map<String, Map<String, dynamic>> stock;
  bool cartCleared;
  bool noticeRaised;

  RetailCheckoutEntry({
    required this.saleId,
    required this.invoiceNumber,
    required this.tabId,
    required this.staffName,
    required this.sessionId,
    required this.createdAt,
    required this.lines,
    required this.posting,
    Map<String, Map<String, dynamic>>? stock,
    this.cartCleared = false,
    this.noticeRaised = false,
  }) : stock = stock ?? {} {
    posting?.persist = save;
    posting?.onReview = _customerConflict;
  }

  Future<void> save() => RetailCheckoutCommit._box.put(saleId, toMap());

  /// Something is waiting for a person: a customer step or a stock row that
  /// could not be resolved without guessing.
  bool get hasReview =>
      (posting?.hasReview ?? false) ||
      stock.values.any((s) => s['conflict'] == true);

  // ── SaleStockIntents ──────────────────────────────────────────────────────

  @override
  ({double before, double after})? intentFor(String rowId) {
    final s = stock[rowId];
    if (s == null || s['conflict'] == true) return null;
    return (
      before: (s['before'] as num).toDouble(),
      after: (s['after'] as num).toDouble(),
    );
  }

  @override
  bool isConflict(String rowId) => stock[rowId]?['conflict'] == true;

  @override
  Future<void> record(String rowId,
      {required double before, required double after}) async {
    stock[rowId] = {'before': before, 'after': after};
    await save();
  }

  @override
  Future<void> conflict(String rowId,
      {required String label, required double qty}) async {
    stock[rowId] = {'conflict': true};
    await save();
    await RetailCheckoutCommit._raise(
      eventCode: 'stock_check_needed',
      subjectType: 'retail_sale_stock',
      subjectId: rowId,
      data: {
        'name': label,
        'qty': qty,
        'unit': 'pcs',
        'reason': 'Sale $invoiceNumber',
        'context': 'sale',
      },
    );
  }

  Future<void> _customerConflict(PostingConflict c) =>
      RetailCheckoutCommit._raise(
        eventCode: RetailCheckoutCommit.customerCheckEvent,
        subjectType: 'retail_sale_customer',
        subjectId: '$saleId:${c.step}',
        data: {
          'invoice': invoiceNumber,
          'customerId': c.customerId,
          'step': c.step,
          'before': c.before,
          'expected': c.expectedAfter,
          'found': c.found,
        },
      );

  Map<String, dynamic> toMap() => {
        'v': version,
        'saleId': saleId,
        'invoiceNumber': invoiceNumber,
        'tabId': tabId,
        'staffName': staffName,
        'sessionId': sessionId,
        'createdAt': createdAt.toIso8601String(),
        'lines': [for (final l in lines) l.toMap()],
        'posting': posting?.toMap(),
        'stock': stock,
        'cartCleared': cartCleared,
        'noticeRaised': noticeRaised,
      };

  factory RetailCheckoutEntry.fromMap(Map<String, dynamic> m) =>
      RetailCheckoutEntry(
        saleId: m['saleId'] as String,
        invoiceNumber: m['invoiceNumber'] as String,
        tabId: m['tabId'] as String?,
        staffName: m['staffName'] as String,
        sessionId: m['sessionId'] as String?,
        createdAt: DateTime.parse(m['createdAt'] as String),
        lines: [
          for (final l in m['lines'] as List)
            CartItemModel.fromMap(Map<String, dynamic>.from(l as Map)),
        ],
        posting: m['posting'] == null
            ? null
            : CheckoutCustomerPosting.fromMap(
                Map<String, dynamic>.from(m['posting'] as Map)),
        stock: {
          for (final e in (m['stock'] as Map? ?? const {}).entries)
            e.key as String: Map<String, dynamic>.from(e.value as Map),
        },
        cartCleared: m['cartCleared'] as bool? ?? false,
        noticeRaised: m['noticeRaised'] as bool? ?? false,
      );
}

/// Exactly-once completion of a Retail sale (BLK-13B).
///
/// Checkout used to keep "this cart is already a saved sale" only in memory.
/// A crash after the save left the cart on disk, the stock undeducted and the
/// customer uncharged — and the same cart could be billed again. Now:
///
/// 1. [begin] persists an entry BEFORE the sale is written.
/// 2. [saveSale] writes it (lines, then the header — the commit point).
/// 3. [finish]: customer steps → stock → cart → entry deleted.
///
/// [recoverAll] (startup) finishes every entry whose sale exists and discards
/// one whose sale never landed (with its orphan lines) — the cart then stays
/// for the cashier and nothing was charged. Every step resolves from what is
/// on disk, so running recovery any number of times changes nothing more;
/// anything it cannot decide without guessing is reported, never applied.
class RetailCheckoutCommit {
  RetailCheckoutCommit._();

  /// Persisted alert raised when a customer step met changed data.
  static const String customerCheckEvent = 'retail_customer_check_needed';

  /// Persisted alert raised when recovery finished a sale.
  static const String recoveredEvent = 'retail_sale_recovered';

  static Box get _box => Hive.box(HiveBoxNames.retailCheckoutJournal);

  /// The entries still in the journal.
  static List<RetailCheckoutEntry> pending() {
    if (!Hive.isBoxOpen(HiveBoxNames.retailCheckoutJournal)) return const [];
    return [
      for (final key in _box.keys)
        RetailCheckoutEntry.fromMap(
            Map<String, dynamic>.from(_box.get(key) as Map)),
    ];
  }

  /// Restore replaces the sales, stock and customers entries refer to.
  static Future<void> clear() => _box.clear();

  /// Persists the work of sale [saleId] before anything is written.
  static Future<RetailCheckoutEntry> begin({
    required String saleId,
    required String invoiceNumber,
    required String? tabId,
    required List<CartItemModel> lines,
    required CheckoutCustomerPosting? posting,
  }) async {
    final entry = RetailCheckoutEntry(
      saleId: saleId,
      invoiceNumber: invoiceNumber,
      tabId: tabId,
      staffName: authService.currentUsername ?? 'Staff',
      sessionId: await DayManagementService.getCurrentSessionId(),
      createdAt: DateTime.now(),
      lines: [for (final l in lines) CartItemModel.fromMap(l.toMap())],
      posting: posting,
    );
    await entry.save();
    return entry;
  }

  /// Writes the sale. Returns normally once its header is on disk — also when
  /// a later part of the save (the in-memory stats) threw, which used to
  /// leave a saved sale looking unsaved and let a retry write it again.
  /// Rethrows when it is not saved; the entry and any orphan lines are then
  /// removed. When even that cannot be read, the entry stays for recovery.
  static Future<void> saveSale(
      RetailCheckoutEntry entry, SaleModel sale, List<SaleItemModel> items) async {
    try {
      await saleStore.addSaleWithItems(sale, items);
    } catch (_) {
      final saved = await SaleRepository().getSaleById(entry.saleId);
      if (saved != null) return;
      await _discard(entry);
      rethrow;
    }
  }

  /// Customer → stock → cart, each once; deletes the entry when nothing is
  /// left. Throws on a failure with the entry kept, so a retry (or the next
  /// start) carries on from where it stopped.
  static Future<void> finish(
    RetailCheckoutEntry entry, {
    required Future<void> Function() clearCart,
  }) async {
    await entry.posting?.apply();
    await RetailInventoryService.deductStockForSale(
      entry.lines,
      saleId: entry.saleId,
      intents: entry,
      attribution: (staffName: entry.staffName, sessionId: entry.sessionId),
    );
    if (!entry.cartCleared) {
      await clearCart();
      entry.cartCleared = true;
      await entry.save();
    }
    // An entry waiting for a person stays, as the record of what to check.
    if (!entry.hasReview) await _box.delete(entry.saleId);
  }

  /// Finishes or discards every entry. Never throws: an entry that fails
  /// stays for the next start, its error returned by sale id.
  static Future<Map<String, Object>> recoverAll() async {
    final failures = <String, Object>{};
    final List<RetailCheckoutEntry> entries;
    try {
      entries = pending();
    } catch (e) {
      return {'journal': e};
    }
    if (entries.isEmpty) return failures;
    try {
      // Bundles are recognised from the catalogue; an empty one would deduct
      // a bundle's own stock instead of its components.
      await productStore.ensureLoaded();
    } catch (e) {
      for (final entry in entries) {
        failures[entry.saleId] = e;
      }
      return failures;
    }
    for (final entry in entries) {
      try {
        final sale = await SaleRepository().getSaleById(entry.saleId);
        if (sale == null) {
          // The sale never landed: nothing was charged or deducted.
          await _discard(entry);
          continue;
        }
        if (!entry.noticeRaised) {
          await _raise(
            eventCode: recoveredEvent,
            subjectType: 'retail_sale',
            subjectId: entry.saleId,
            data: {'invoice': entry.invoiceNumber},
          );
          entry.noticeRaised = true;
          await entry.save();
        }
        final sold = {for (final l in entry.lines) l.cartItemId};
        await finish(entry,
            clearCart: () => retailCartStore.removeSoldLines(entry.tabId, sold));
      } catch (e) {
        failures[entry.saleId] = e;
        debugPrint('Retail sale ${entry.invoiceNumber} not finished: $e');
      }
    }
    return failures;
  }

  static Future<void> _discard(RetailCheckoutEntry entry) async {
    await SaleItemRepository().deleteItemsBySaleId(entry.saleId);
    await _box.delete(entry.saleId);
  }

  static Future<void> _raise({
    required String eventCode,
    required String subjectType,
    required String subjectId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await notificationStore.raiseEvent(
        eventCode: eventCode,
        subjectType: subjectType,
        subjectId: subjectId,
        data: data,
      );
    } catch (e) {
      // The journal keeps the facts either way.
      debugPrint('Retail checkout alert failed: $e');
    }
  }
}
