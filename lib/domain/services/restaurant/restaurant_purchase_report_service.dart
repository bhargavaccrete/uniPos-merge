import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/restaurant_grn_item_model.dart';
import '../../../data/models/restaurant/db/restaurant_grn_model.dart';
import '../../../data/models/restaurant/db/restaurant_purchase_order_model.dart';
import '../../../data/models/restaurant/db/restaurant_purchase_return_model.dart';
import '../../../data/models/restaurant/db/restaurant_supplier_claim_model.dart';
import '../../../data/models/restaurant/db/restaurant_supplier_ledger_entry_model.dart';
import '../../../data/models/restaurant/db/stock_movement_model.dart';
import '../../../data/repositories/restaurant/stock_movement_repository.dart';
import '../../../util/restaurant/report_history_window.dart';
import 'stock_adjust_service.dart';

/// Aggregation layer behind restaurant's purchase & inventory reports.
///
/// **The money vocabulary — five distinct figures, never conflated:**
///
/// | Term | Formula | Meaning |
/// |---|---|---|
/// | Billed Value | `receivedQty * costPrice` (= `grn.totalAmount`) | what the supplier invoices, **damaged units included**. The only figure that posts to the ledger as a `purchase` |
/// | Accepted Value | `acceptedQty * costPrice` | what entered inventory |
/// | Damaged Value | `damagedQty * costPrice` | Billed minus Accepted |
/// | Supplier Credit | return credit note, or settled claim | what was actually recovered; a write-off recovers nothing |
/// | Net Cost | Billed minus Supplier Credit | what the business actually bore |
///
/// so that `Billed - Credit = Net Cost` and `Net Cost - Accepted = Absorbed`.
/// **Damage is never netted out of the bill** — it is recovered afterwards by a
/// credit note or a settled claim, or absorbed. Reports read the stored
/// `totalAmount`; they never recompute it or compensate for a suspect one.
///
/// **Reads repositories, NOT stores — deliberately.**
/// `RestaurantPurchaseOrderStore` and `RestaurantDamagedGoodsStore` load from
/// their constructors and expose no `ensureLoaded()`, so a report opened on a
/// cold start can read an empty `ObservableList` and render "nothing here" over
/// real data. Repositories read the open Hive box directly and cannot be empty
/// for that reason. It also keeps reports out of MobX's reactive graph.
/// The one exception is the supplier statement, which goes through
/// `RestaurantSupplierStore.getLedger` because that owns ledger ordering and
/// the "Balance brought forward" synthesis for pre-journal suppliers.
///
/// **Instance, not static**, so [_historyCutoff] is captured once per report
/// run and every row is judged against the same instant.
class RestaurantPurchaseReportService {
  /// Plan history limit, resolved once. Unlike retail — whose entitlements are
  /// bypassed until a manifest arrives — restaurant enforcement is live, so
  /// this genuinely clamps.
  final DateTime? _historyCutoff = ReportHistoryWindow.cutoff;

  // ==================== SHARED RULES ====================

  /// The one date rule: plan cutoff, then **inclusive start / exclusive end**.
  ///
  /// Never use `PlanEnforce.windowCutoff` directly — it has no `days <= 0`
  /// guard, so a zero would pin the cutoff to *now* and blank every report
  /// while the period pills stayed unlocked.
  bool _inWindow(DateTime at, DateTime? start, DateTime? end) {
    final cutoff = _historyCutoff;
    if (cutoff != null && at.isBefore(cutoff)) return false;
    if (start != null && at.isBefore(start)) return false;
    if (end != null && !at.isBefore(end)) return false;
    return true;
  }

  /// Every restaurant date field is a stored ISO `String`. Parse FIRST — an
  /// unparseable value is out of range even for an all-time query, and a bare
  /// `DateTime.parse` here would throw and blank the whole report.
  bool _withinRange(String? iso, DateTime? start, DateTime? end) {
    final at = DateTime.tryParse(iso ?? '');
    if (at == null) return false;
    return _inWindow(at, start, end);
  }

  /// Confirmed receipts only — a draft moved no stock and owes no money.
  /// Sorted newest-first with an id tiebreak, because `List.sort` is not
  /// stable and many receipts share a date.
  List<RestaurantGRNModel> _confirmedGRNs({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final rows = restaurantGrnRepository
        .getAllGRNs()
        .where((g) =>
            g.statusEnum == RestaurantGRNStatus.confirmed &&
            _withinRange(g.receivedDate, startDate, endDate))
        .toList();
    rows.sort((a, b) {
      final c = b.receivedDate.compareTo(a.receivedDate);
      return c != 0 ? c : a.grnId.compareTo(b.grnId);
    });
    return rows;
  }

  /// A line that arrived with no usable cost — its value is unknown, not zero.
  static bool _lineUnpriced(RestaurantGRNItemModel i) =>
      i.receivedQty > 0 && (i.costPrice == null || i.costPrice! <= 0);

  static Set<String> _grnIdsWithUnpricedLines(
    List<RestaurantGRNItemModel> items,
  ) =>
      items.where(_lineUnpriced).map((i) => i.grnId).toSet();

  /// Legacy/restore guard. Unlike retail, `confirmGRN` always computes a header
  /// total, so this rarely fires on data this app wrote — the unpriced-line
  /// flag is the one that matters here.
  static bool _grnAmountMissing(RestaurantGRNModel g) => g.totalAmount == null;

  /// GRN lines grouped by their header id.
  Map<String, List<RestaurantGRNItemModel>> _itemsByGrn() {
    final byGrn = <String, List<RestaurantGRNItemModel>>{};
    for (final i in restaurantGrnItemRepository.getAllItems()) {
      (byGrn[i.grnId] ??= <RestaurantGRNItemModel>[]).add(i);
    }
    return byGrn;
  }

  /// Snapshot name first, live record second, placeholder last — so a rename
  /// never relabels history that was captured under the old name.
  String _supplierName(String? snapshot, String supplierId) {
    final snap = (snapshot ?? '').trim();
    if (snap.isNotEmpty) return snap;
    final live = restaurantSupplierRepository.getSupplierById(supplierId);
    final name = (live?.name ?? '').trim();
    return name.isEmpty ? 'Unknown Supplier' : name;
  }

  // ==================== DAMAGE RECOVERY ====================

  /// Expected / recovered / absorbed damage value per supplier.
  ///
  /// **Each document is dated by its OWN event**, so a receipt in January
  /// credited in March belongs to March and January never changes.
  Future<Map<String, _DamagedRecovery>> _damagedRecoveryInWindow(
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    final out = <String, _DamagedRecovery>{};
    _DamagedRecovery bucket(String supplierId, String? name) => out.putIfAbsent(
          supplierId,
          () => _DamagedRecovery(_supplierName(name, supplierId)),
        );

    for (final r in await restaurantPurchaseReturnRepository.getAll()) {
      switch (r.statusEnum) {
        case RestaurantPurchaseReturnStatus.pending:
          // Raised, not yet credited — still expected.
          if (_withinRange(r.returnDate, startDate, endDate)) {
            bucket(r.supplierId, r.supplierName).expected += r.totalAmount;
          }
        case RestaurantPurchaseReturnStatus.creditReceived:
          // The note's FACE value, which may be less than the return total.
          if (_withinRange(r.creditNoteDate, startDate, endDate)) {
            bucket(r.supplierId, r.supplierName).recovered +=
                r.creditNoteAmount ?? 0;
          }
        case RestaurantPurchaseReturnStatus.cancelled:
          // Excluded from all three buckets: the goods never went back, so
          // nothing was recovered and nothing was written off either.
          break;
      }
    }

    for (final c in await restaurantSupplierClaimRepository.getAll()) {
      switch (c.statusEnum) {
        case RestaurantSupplierClaimStatus.pending:
        case RestaurantSupplierClaimStatus.approved:
          // Approved is a promise, not money.
          if (_withinRange(c.claimDate, startDate, endDate)) {
            bucket(c.supplierId, c.supplierName).expected += c.totalAmount;
          }
        case RestaurantSupplierClaimStatus.settled:
          if (_withinRange(c.resolvedAt, startDate, endDate)) {
            bucket(c.supplierId, c.supplierName).recovered += c.totalAmount;
          }
        case RestaurantSupplierClaimStatus.rejected:
          // Only when it has NOT been written off — otherwise its loss row
          // below counts the same value a second time.
          if (!c.isLossRecorded &&
              _withinRange(c.resolvedAt, startDate, endDate)) {
            bucket(c.supplierId, c.supplierName).absorbed += c.totalAmount;
          }
      }
    }

    for (final l in await restaurantInventoryLossRepository.getAll()) {
      final supplierId = l.supplierId;
      // A stock-adjustment loss is an inventory event, not a purchasing one.
      if (l.grnId == null || supplierId == null) continue;
      if (!_withinRange(l.recordedAt, startDate, endDate)) continue;
      bucket(supplierId, l.supplierName).absorbed += l.lossValue;
    }

    return out;
  }

  // ==================== REPORTS ====================

  /// Every confirmed goods receipt, with ordered/received/accepted/damaged side
  /// by side and the **billed** value (damage included).
  Future<List<Map<String, dynamic>>> getGRNReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final grns = _confirmedGRNs(startDate: startDate, endDate: endDate);
    if (grns.isEmpty) return const [];

    final byGrn = _itemsByGrn();
    final unpriced = _grnIdsWithUnpricedLines(
      restaurantGrnItemRepository.getAllItems(),
    );

    final rows = <Map<String, dynamic>>[];
    for (final g in grns) {
      final lines = byGrn[g.grnId] ?? const <RestaurantGRNItemModel>[];
      var accepted = 0.0;
      var damaged = 0.0;
      var acceptedValue = 0.0;
      var damagedValue = 0.0;
      for (final i in lines) {
        accepted += i.acceptedQty;
        damaged += i.damagedQty ?? 0;
        acceptedValue += i.acceptedAmount;
        damagedValue += i.damagedAmount;
      }

      rows.add(<String, dynamic>{
        'grnId': g.grnId,
        'grnNumber': g.grnNumber,
        'poNumber': g.poNumber,
        'supplierId': g.supplierId,
        'supplierName': _supplierName(g.supplierName, g.supplierId),
        'receivedDate': g.receivedDate,
        'invoiceNumber': g.invoiceNumber,
        'orderedQty': g.totalOrderedQty.toDouble(),
        'receivedQty': g.totalReceivedQty.toDouble(),
        'acceptedQty': accepted.toDouble(),
        'damagedQty': damaged.toDouble(),
        // The STORED billed figure — never reconstructed from the lines.
        'billedValue': (g.totalAmount ?? 0).toDouble(),
        'acceptedValue': acceptedValue.toDouble(),
        'damagedValue': damagedValue.toDouble(),
        'hasUnpricedLine': unpriced.contains(g.grnId),
        'amountMissing': _grnAmountMissing(g),
      });
    }
    return rows;
  }

  /// Purchase orders in one status, with receiving progress folded from
  /// confirmed GRNs.
  Future<List<Map<String, dynamic>>> getPurchaseOrderStatusReport(
    RestaurantPOStatus status, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pos = restaurantPurchaseOrderRepository
        .getAllPurchaseOrders()
        .where((po) =>
            po.statusEnum == status &&
            _withinRange(po.createdAt, startDate, endDate))
        .toList();
    if (pos.isEmpty) return const [];

    pos.sort((a, b) {
      final c = b.createdAt.compareTo(a.createdAt);
      return c != 0 ? c : a.poId.compareTo(b.poId);
    });

    // Receipts are counted across ALL time, not the report window: a PO's
    // progress is a fact about the order, not about the period being viewed.
    final receiptsByPo = <String, List<double>>{};
    for (final g in restaurantGrnRepository.getAllGRNs()) {
      if (g.statusEnum != RestaurantGRNStatus.confirmed) continue;
      final prev = receiptsByPo[g.poId] ?? <double>[0, 0];
      receiptsByPo[g.poId] = <double>[
        prev[0] + g.totalReceivedQty,
        prev[1] + (g.totalAmount ?? 0),
      ];
    }

    final rows = <Map<String, dynamic>>[];
    for (final po in pos) {
      final got = receiptsByPo[po.poId] ?? <double>[0, 0];
      rows.add(<String, dynamic>{
        'poId': po.poId,
        'poNumber': po.poNumber,
        'supplierId': po.supplierId,
        'supplierName': _supplierName(po.supplierName, po.supplierId),
        'createdAt': po.createdAt,
        'expectedDeliveryDate': po.expectedDeliveryDate,
        'orderedQty': po.totalItems.toDouble(),
        'receivedQty': got[0].toDouble(),
        // Trailing toDouble is load-bearing: num.clamp returns whichever
        // operand it picked, so an int bound would yield an int here.
        'remainingQty':
            (po.totalItems - got[0]).clamp(0.0, po.totalItems).toDouble(),
        'estimatedTotal': po.estimatedTotal.toDouble(),
        'receivedValue': got[1].toDouble(),
        'status': po.status,
      });
    }
    return rows;
  }

  /// One summary map: ordered vs received vs outstanding, plus the full
  /// Billed -> Credit -> Net Cost reconciliation.
  Future<Map<String, dynamic>> getPurchaseSummaryReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pos = restaurantPurchaseOrderRepository
        .getAllPurchaseOrders()
        .where((po) => _withinRange(po.createdAt, startDate, endDate))
        .toList();

    final countByStatus = <String, int>{
      for (final s in RestaurantPOStatus.values) s.name: 0,
    };
    var orderedQty = 0.0;
    var orderedValue = 0.0;
    var outstandingValue = 0.0;
    for (final po in pos) {
      final name = po.statusEnum.name;
      countByStatus[name] = (countByStatus[name] ?? 0) + 1;
      // A draft was never placed and a cancelled order never will be.
      if (po.statusEnum == RestaurantPOStatus.draft ||
          po.statusEnum == RestaurantPOStatus.cancelled) {
        continue;
      }
      orderedQty += po.totalItems;
      orderedValue += po.estimatedTotal;
      // Restaurant's enum is partiallyReceived/completed — NOT retail's
      // partiallyCompleted/fullyCompleted.
      if (po.statusEnum == RestaurantPOStatus.sent ||
          po.statusEnum == RestaurantPOStatus.partiallyReceived) {
        outstandingValue += po.estimatedTotal;
      }
    }

    final grns = _confirmedGRNs(startDate: startDate, endDate: endDate);
    final byGrn = _itemsByGrn();
    var receivedQty = 0.0;
    var billedValue = 0.0;
    var acceptedValue = 0.0;
    var damagedValue = 0.0;
    final suppliers = <String>{};
    var amountMissing = 0;
    for (final g in grns) {
      receivedQty += g.totalReceivedQty;
      billedValue += g.totalAmount ?? 0;
      suppliers.add(g.supplierId);
      if (_grnAmountMissing(g)) amountMissing++;
      for (final i in byGrn[g.grnId] ?? const <RestaurantGRNItemModel>[]) {
        acceptedValue += i.acceptedAmount;
        damagedValue += i.damagedAmount;
      }
    }

    final recovery = await _damagedRecoveryInWindow(startDate, endDate);
    var expected = 0.0;
    var recovered = 0.0;
    var absorbed = 0.0;
    for (final r in recovery.values) {
      expected += r.expected;
      recovered += r.recovered;
      absorbed += r.absorbed;
    }

    final unpricedGrnIds = _grnIdsWithUnpricedLines(
      restaurantGrnItemRepository.getAllItems(),
    );
    final grnIdsInWindow = grns.map((g) => g.grnId).toSet();

    return <String, dynamic>{
      'orderCount': pos.length,
      'countByStatus': countByStatus,
      'orderedQty': orderedQty.toDouble(),
      'orderedValue': orderedValue.toDouble(),
      'outstandingValue': outstandingValue.toDouble(),
      'receiptCount': grns.length,
      'receivedQty': receivedQty.toDouble(),
      // The reconciliation identity, ready for the detail panel.
      'billedValue': billedValue.toDouble(),
      'acceptedValue': acceptedValue.toDouble(),
      'damagedValue': damagedValue.toDouble(),
      'damagedExpected': expected.toDouble(),
      'damagedRecovered': recovered.toDouble(),
      'damagedAbsorbed': absorbed.toDouble(),
      // Damage nobody recovered AND nobody wrote off — a return that was
      // cancelled, or one still sitting pending. Absorbed counts only
      // documented write-offs, so without this the reconciliation would not
      // balance for goods left in limbo, which is exactly the case worth
      // seeing. Damage is dated by receipt and recovery by its own event, so
      // this is only exact when both fall in the window being viewed.
      'damagedUnrecovered':
          (damagedValue - recovered).clamp(0.0, damagedValue).toDouble(),
      'netCost': (billedValue - recovered).toDouble(),
      'supplierCount': suppliers.length,
      'grnsMissingAmount': amountMissing,
      'grnsWithUnpricedLines':
          grnIdsInWindow.where(unpricedGrnIds.contains).length,
    };
  }

  /// Every damaged line from a confirmed receipt, with what was decided about
  /// it.
  ///
  /// Dated by the RECEIPT, not by any later recovery — this answers "what
  /// arrived broken this period", which is a fact about the delivery. What the
  /// supplier later credited is a separate question, answered by
  /// Supplier-wise and Purchase Summary.
  Future<List<Map<String, dynamic>>> getDamagedItemsReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final grns = {
      for (final g in _confirmedGRNs(startDate: startDate, endDate: endDate))
        g.grnId: g,
    };
    if (grns.isEmpty) return const [];

    final rows = <Map<String, dynamic>>[];
    for (final i in restaurantGrnItemRepository.getAllItems()) {
      if ((i.damagedQty ?? 0) <= 0) continue;
      final g = grns[i.grnId];
      if (g == null) continue; // draft, cancelled, or outside the window

      rows.add(<String, dynamic>{
        'grnItemId': i.grnItemId,
        'grnId': i.grnId,
        'grnNumber': g.grnNumber,
        'poNumber': g.poNumber,
        'supplierId': g.supplierId,
        'supplierName': _supplierName(g.supplierName, g.supplierId),
        'receivedDate': g.receivedDate,
        'itemName': i.itemName ?? i.itemId,
        'damagedQty': (i.damagedQty ?? 0).toDouble(),
        'costPrice': (i.costPrice ?? 0).toDouble(),
        'damagedValue': i.damagedAmount.toDouble(),
        // Its value is unknown, not zero — the row is shown but flagged.
        'costMissing': _lineUnpriced(i),
        'handling': i.damagedHandling,
        // One switch, shared with the Goods Receiving screen.
        'handlingDisplay': i.damagedHandlingDisplay,
      });
    }

    rows.sort((a, b) {
      final c = (b['receivedDate'] as String)
          .compareTo(a['receivedDate'] as String);
      if (c != 0) return c;
      // Many damaged lines share one receipt's date, so ties are the norm.
      return (a['grnItemId'] as String).compareTo(b['grnItemId'] as String);
    });
    return rows;
  }

  /// Goods sent back to suppliers, and where each credit note stands.
  ///
  /// Dated by `returnDate` — when the return was raised. A cancelled return is
  /// still listed (it happened) but contributes nothing to value totals, since
  /// the goods never went back.
  Future<List<Map<String, dynamic>>> getPurchaseReturnReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final all = await restaurantPurchaseReturnRepository.getAll();
    final rows = <Map<String, dynamic>>[];
    for (final r in all) {
      if (!_withinRange(r.returnDate, startDate, endDate)) continue;
      final cancelled =
          r.statusEnum == RestaurantPurchaseReturnStatus.cancelled;

      rows.add(<String, dynamic>{
        'returnId': r.returnId,
        'returnNumber': r.returnNumber,
        'grnNumber': r.grnNumber,
        'poNumber': r.poNumber,
        'supplierId': r.supplierId,
        'supplierName': _supplierName(r.supplierName, r.supplierId),
        'returnDate': r.returnDate,
        'totalQty': r.totalQty.toDouble(),
        'totalAmount': r.totalAmount.toDouble(),
        // Excluded from value totals — nothing went back, so nothing is owed
        // back. The row stays so the decision is visible.
        'countsTowardValue': !cancelled,
        'status': r.status,
        'statusDisplay': r.statusDisplay,
        'isOpen': r.isOpen,
        'creditNoteNumber': r.creditNoteNumber,
        'creditNoteDate': r.creditNoteDate,
        'creditNoteAmount': (r.creditNoteAmount ?? 0).toDouble(),
      });
    }

    rows.sort((a, b) {
      final c =
          (b['returnDate'] as String).compareTo(a['returnDate'] as String);
      return c != 0 ? c : (a['returnId'] as String).compareTo(b['returnId'] as String);
    });
    return rows;
  }

  // ==================== STOCK ADJUSTMENT ====================

  /// Reasons written BY CODE, never chosen by a human. Exact matches.
  static const Set<String> _systemReasons = {
    'Opening stock',
    'Sale',
    'Production batch',
    'Void / Refund return',
  };

  /// ...and the parameterised ones.
  ///
  /// The trailing `(` matters: the manual add reason `'Restock / Purchase'`
  /// must NOT be swallowed by the `'Purchase ('` prefix.
  static const List<String> _systemReasonPrefixes = [
    'Purchase (',
    'Sale (recipe: ',
    'Production (',
    'Void / Refund return (recipe: ',
  ];

  /// Was this movement a human decision rather than a side effect?
  ///
  /// **A deny-list, deliberately.** An allow-list over the dropdown vocabulary
  /// would silently drop the stock take's caller-supplied `shortageReason` and
  /// every future dropdown entry — an audit report going quietly incomplete is
  /// the worst failure it can have. The *system* vocabulary is closed and
  /// code-owned: it only changes when someone adds a `saveMovement` call.
  ///
  /// Public and static so a test can pin the vocabulary without Hive.
  static bool isManualAdjustment(StockMovementModel m) =>
      !_systemReasons.contains(m.reason) &&
      !_systemReasonPrefixes.any(m.reason.startsWith);

  /// Every manual stock correction — who, why, and the before/after.
  ///
  /// This is an accountability report, not a valuation one: the summary counts
  /// adjustments rather than summing quantities, because rows mix units and
  /// "5.5 units" across kg and pcs means nothing.
  Future<List<Map<String, dynamic>>> getStockAdjustmentReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final rows = <Map<String, dynamic>>[];
    for (final m in StockMovementRepository().allMovements()) {
      if (!isManualAdjustment(m)) continue;
      if (!_inWindow(m.timestamp, startDate, endDate)) continue;

      rows.add(<String, dynamic>{
        'id': m.id,
        'timestamp': m.timestamp.toIso8601String(),
        'itemId': m.itemId,
        'variantId': m.variantId,
        'itemName': m.itemName,
        'type': m.type,
        'isIn': m.isIn,
        'quantity': m.quantity.toDouble(),
        'signedQuantity': m.signedQuantity.toDouble(),
        'balanceAfter': m.balanceAfter.toDouble(),
        // Derived, because only the after-balance is stored. All three stay
        // doubles or a kg item's Before + Change stops equalling After.
        'balanceBefore': (m.balanceAfter - m.signedQuantity).toDouble(),
        'unit': m.unit,
        'reason': m.reason,
        'note': m.note,
        'staffName': m.staffName,
        'isLossReason': StockAdjustService.isLossReason(m.reason),
      });
    }

    rows.sort((a, b) {
      final c =
          (b['timestamp'] as String).compareTo(a['timestamp'] as String);
      return c != 0 ? c : (a['id'] as String).compareTo(b['id'] as String);
    });
    return rows;
  }

  // ==================== LOW STOCK ====================

  /// Items at or below their reorder point, right now.
  ///
  /// **No date dimension** — stock is a level, not an event, so the plan's
  /// history window deliberately does not apply here.
  ///
  /// Delegates to [StockAdjustService.lowStockEntries], which is already
  /// recipe-aware: a made-to-order item is measured on how many its
  /// ingredients can make, not on a `stockQuantity` it never populates.
  Future<List<Map<String, dynamic>>> getLowStockReport() async {
    // The one place this service touches a store — lowStockEntries reads
    // itemStore, which unlike the purchase stores DOES expose ensureLoaded.
    await itemStore.ensureLoaded();

    final rows = <Map<String, dynamic>>[];
    for (final e in StockAdjustService.lowStockEntries()) {
      rows.add(<String, dynamic>{
        'itemId': e.item.id,
        'itemName': e.item.name,
        'variantId': e.variant?.variantId,
        'variantName': e.variantName,
        'currentStock': e.stock.toDouble(),
        'reorderPoint': e.item.effectiveLowStockThreshold.toDouble(),
        'unit': e.item.unit ?? (e.item.isSoldByWeight ? 'kg' : 'pcs'),
        'costPrice': (e.item.lastPurchaseCost ?? 0).toDouble(),
        'isMadeToOrder': e.item.isMadeToOrder,
        'isOut': e.isOut,
      });
    }

    // lowStockEntries has no defined order, so give it a total one — otherwise
    // the table and its own export can disagree between loads.
    rows.sort((a, b) {
      final c = (a['currentStock'] as double)
          .compareTo(b['currentStock'] as double);
      if (c != 0) return c;
      final i = (a['itemId'] as String).compareTo(b['itemId'] as String);
      if (i != 0) return i;
      return ((a['variantId'] as String?) ?? '')
          .compareTo((b['variantId'] as String?) ?? '');
    });
    return rows;
  }

  // ==================== SUPPLIER STATEMENT ====================

  /// One supplier's ledger with a running balance.
  ///
  /// Row 0 is a synthetic **"Balance brought forward"** whenever the window
  /// starts after the account did — otherwise the running balance would begin
  /// mid-story and the closing figure would be wrong.
  ///
  /// > **This is the one deliberate relaxation of the history-window rule.**
  /// > The anchor is the `balanceAfter` of the last entry strictly before the
  /// > window, computed from EVERY entry, including ones the plan history
  /// > limit hides. The plan caps visible *history*; the brought-forward line
  /// > is a single aggregate of hidden rows, not a hidden row. Filter it out
  /// > and the statement simply does not add up. Do not "fix" this.
  ///
  /// Goes through `RestaurantSupplierStore.getLedger` rather than the
  /// repository — that is where ordering and the brought-forward synthesis for
  /// pre-journal suppliers already live.
  Future<List<Map<String, dynamic>>> getSupplierStatement({
    required String supplierId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final entries = await restaurantSupplierStore.getLedger(supplierId);
    if (entries.isEmpty) return const [];

    final rows = <Map<String, dynamic>>[];
    var broughtForward = 0.0;
    var sawEarlier = false;

    for (final e in entries) {
      final at = DateTime.tryParse(e.date);
      final before =
          at == null || (startDate != null && at.isBefore(startDate));
      if (before) {
        // Deliberately NOT routed through _inWindow — see the doc above.
        broughtForward = e.balanceAfter;
        sawEarlier = true;
        continue;
      }
      if (endDate != null && !at.isBefore(endDate)) continue;

      rows.add(<String, dynamic>{
        'entryId': e.entryId,
        'date': e.date,
        'type': e.type,
        'typeDisplay': e.typeDisplay,
        'description': e.description,
        'docNumber': e.docNumber,
        'docId': e.docId,
        'amount': e.amount.toDouble(),
        'balanceAfter': e.balanceAfter.toDouble(),
        'paymentMode': e.paymentMode,
        'referenceNo': e.referenceNo,
        'note': e.note,
        'seq': e.seq,
        'isBroughtForward': false,
      });
    }

    if (sawEarlier) {
      rows.insert(0, <String, dynamic>{
        'entryId': 'bf-$supplierId',
        'date': startDate?.toIso8601String() ?? entries.first.date,
        'type': 'opening',
        'typeDisplay': 'Brought Forward',
        'description': 'Balance brought forward',
        'amount': 0.0,
        'balanceAfter': broughtForward,
        'seq': 0,
        'isBroughtForward': true,
      });
    }
    return rows;
  }

  /// Outstanding per supplier, aged. **No period filter** — ageing is
  /// as-of-now by definition; a balance does not belong to a month.
  Future<List<Map<String, dynamic>>> getSupplierOutstandingAgeing({
    DateTime? asOf,
  }) async {
    final at = asOf ?? DateTime.now();
    final rows = <Map<String, dynamic>>[];

    for (final supplier in restaurantSupplierRepository.getAllSuppliers()) {
      if (supplier.currentBalance == 0) continue;
      final entries =
          await restaurantSupplierStore.getLedger(supplier.supplierId);
      final aged = ageRestaurantSupplierLedger(entries, at);

      rows.add(<String, dynamic>{
        'supplierId': supplier.supplierId,
        'supplierName': supplier.name,
        'closing': supplier.currentBalance.toDouble(),
        'b0_30': aged.b0_30,
        'b31_60': aged.b31_60,
        'b61_90': aged.b61_90,
        'b90plus': aged.b90plus,
        'unappliedCredit': aged.unappliedCredit,
        'oldestOpen': aged.oldestOpen?.toIso8601String(),
        'oldestDays': aged.oldestOpen == null
            ? 0
            : at.difference(aged.oldestOpen!).inDays,
      });
    }

    rows.sort((a, b) {
      final c = (b['b90plus'] as double).compareTo(a['b90plus'] as double);
      if (c != 0) return c;
      final d = (b['closing'] as double).compareTo(a['closing'] as double);
      if (d != 0) return d;
      return (a['supplierId'] as String).compareTo(b['supplierId'] as String);
    });
    return rows;
  }

  /// Spend per supplier, measured on confirmed receipts (billed value), merged
  /// with what damage cost or recovered for each.
  Future<List<Map<String, dynamic>>> getSupplierWisePurchaseReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final grns = _confirmedGRNs(startDate: startDate, endDate: endDate);
    final byGrn = _itemsByGrn();

    Map<String, dynamic> blank(String supplierId, String name) =>
        <String, dynamic>{
          'supplierId': supplierId,
          'supplierName': name,
          'receiptCount': 0,
          'receivedQty': 0.0,
          'billedValue': 0.0,
          'acceptedValue': 0.0,
          'damagedValue': 0.0,
          'damagedExpected': 0.0,
          'damagedRecovered': 0.0,
          'damagedAbsorbed': 0.0,
        };

    // Grouped by supplierId, never by name: two suppliers sharing a name must
    // not merge, and one supplier's history must not split on a rename.
    final acc = <String, Map<String, dynamic>>{};
    for (final g in grns) {
      final row = acc.putIfAbsent(
        g.supplierId,
        () => blank(g.supplierId, _supplierName(g.supplierName, g.supplierId)),
      );
      row['receiptCount'] = (row['receiptCount'] as int) + 1;
      row['receivedQty'] = (row['receivedQty'] as double) + g.totalReceivedQty;
      row['billedValue'] =
          (row['billedValue'] as double) + (g.totalAmount ?? 0);
      for (final i in byGrn[g.grnId] ?? const <RestaurantGRNItemModel>[]) {
        row['acceptedValue'] =
            (row['acceptedValue'] as double) + i.acceptedAmount;
        row['damagedValue'] = (row['damagedValue'] as double) + i.damagedAmount;
      }
    }

    final recovery = await _damagedRecoveryInWindow(startDate, endDate);
    recovery.forEach((supplierId, r) {
      // A supplier whose only activity this period was a credit note still
      // belongs in the report.
      final row =
          acc.putIfAbsent(supplierId, () => blank(supplierId, r.supplierName));
      row['damagedExpected'] = (row['damagedExpected'] as double) + r.expected;
      row['damagedRecovered'] =
          (row['damagedRecovered'] as double) + r.recovered;
      row['damagedAbsorbed'] = (row['damagedAbsorbed'] as double) + r.absorbed;
    });

    final rows = acc.values.toList();
    for (final row in rows) {
      final billed = row['billedValue'] as double;
      final damaged = row['damagedValue'] as double;
      final recovered = row['damagedRecovered'] as double;
      row['netCost'] = billed - recovered;
      // See the note on 'damagedUnrecovered' in getPurchaseSummaryReport.
      row['damagedUnrecovered'] = (damaged - recovered).clamp(0.0, damaged);
    }
    rows.sort((a, b) {
      final c =
          (b['billedValue'] as double).compareTo(a['billedValue'] as double);
      if (c != 0) return c;
      return (a['supplierId'] as String).compareTo(b['supplierId'] as String);
    });
    return rows;
  }
}

/// Per-supplier damage outcome within a window. Mutable on purpose — it is
/// accumulated across three document types before being read once.
class _DamagedRecovery {
  final String supplierName;

  /// Raised but not yet settled — a return awaiting its credit note, or an
  /// open/approved claim.
  double expected = 0;

  /// Actually credited back by the supplier.
  double recovered = 0;

  /// The business absorbed it — a write-off, or a rejected claim.
  double absorbed = 0;

  _DamagedRecovery(this.supplierName);

  double get total => expected + recovered + absorbed;
}

/// One unpaid invoice still open against a supplier.
class _OpenItem {
  final DateTime at;
  double amount;
  _OpenItem(this.at, this.amount);
}

/// **FIFO ageing of a running-balance ledger.**
///
/// The journal records movements, not open items — it can say a supplier is
/// owed 12,400 but not how overdue any of it is. This derives that: positive
/// rows (`opening`, `purchase`, a positive `adjustment`) are invoices dated by
/// their own `date`; negative rows (`payment`, `returnCredit`, `claimCredit`, a
/// negative `adjustment`) pay off the **oldest open invoice first**. What is
/// left is bucketed by age.
///
/// Credit beyond what is owed becomes `unappliedCredit` — an advance, which
/// `RestaurantSupplierAccountSummary.isAdvance` already names.
///
/// **Invariant:** `b0_30 + b31_60 + b61_90 + b90plus - unappliedCredit`
/// equals the supplier current balance. If it ever does not, the ledger and
/// the balance have diverged — which is what the Overview reconciliation
/// banner exists to surface, so surface it rather than plugging it.
///
/// Pure: no Hive, no locator, no clock of its own.
({
  double b0_30,
  double b31_60,
  double b61_90,
  double b90plus,
  DateTime? oldestOpen,
  double unappliedCredit,
}) ageRestaurantSupplierLedger(
  List<RestaurantSupplierLedgerEntryModel> entries,
  DateTime asOf,
) {
  // The ledger own total order: date, then seq. getAll() sorts by date alone,
  // so two movements in the same millisecond would otherwise age in arbitrary
  // order.
  final sorted = [...entries]..sort(compareRestaurantLedgerEntries);

  final open = <_OpenItem>[];
  var credit = 0.0;

  for (final e in sorted) {
    final at = DateTime.tryParse(e.date);
    if (at == null) continue; // undateable rows cannot be aged
    if (e.amount == 0) continue;

    if (e.amount > 0) {
      var amount = e.amount;
      // An advance already sitting on the account settles the new invoice
      // before any of it becomes outstanding.
      if (credit > 0) {
        final used = credit < amount ? credit : amount;
        credit -= used;
        amount -= used;
      }
      if (amount > 0) open.add(_OpenItem(at, amount));
      continue;
    }

    var toApply = -e.amount;
    while (toApply > 0 && open.isNotEmpty) {
      final head = open.first;
      final used = head.amount < toApply ? head.amount : toApply;
      head.amount -= used;
      toApply -= used;
      if (head.amount <= 0.0000001) open.removeAt(0);
    }
    // Paid more than was owed — the remainder sits as an advance.
    if (toApply > 0) credit += toApply;
  }

  var b0 = 0.0;
  var b31 = 0.0;
  var b61 = 0.0;
  var b90 = 0.0;
  DateTime? oldest;
  for (final item in open) {
    if (oldest == null || item.at.isBefore(oldest)) oldest = item.at;
    final days = asOf.difference(item.at).inDays;
    if (days <= 30) {
      b0 += item.amount;
    } else if (days <= 60) {
      b31 += item.amount;
    } else if (days <= 90) {
      b61 += item.amount;
    } else {
      b90 += item.amount;
    }
  }

  return (
    b0_30: b0,
    b31_60: b31,
    b61_90: b61,
    b90plus: b90,
    oldestOpen: oldest,
    unappliedCredit: credit,
  );
}
