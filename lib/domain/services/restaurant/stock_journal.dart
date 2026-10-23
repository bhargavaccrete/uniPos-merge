import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/hive_box_names.dart';
import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../data/models/restaurant/db/stock_movement_model.dart';
import '../../../data/repositories/restaurant/stock_movement_repository.dart';
import '../../../util/restaurant/restaurant_session.dart';
import '../common/notification_service.dart';
import 'day_management_service.dart';
import 'inventory_service.dart';

/// One stock change a journaled Settle must make: an item, a variant, or one
/// recipe-ingredient row. [uid] is also the id of its StockMovementModel.
class JournalUnit {
  final String uid;
  final String itemId;
  final String? variantId;

  /// Stock units to deduct (weight already converted).
  final double qty;
  final String reason;
  final String itemName;
  final String unit;
  final double? unitCost;

  /// planned → applying (before/after recorded) → written (stock write
  /// confirmed) → done; or review.
  String state;
  double? before;
  double? after;

  JournalUnit({
    required this.uid,
    required this.itemId,
    this.variantId,
    required this.qty,
    required this.reason,
    required this.itemName,
    required this.unit,
    this.unitCost,
    this.state = StockJournal.planned,
    this.before,
    this.after,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'itemId': itemId,
        'variantId': variantId,
        'qty': qty,
        'reason': reason,
        'itemName': itemName,
        'unit': unit,
        'unitCost': unitCost,
        'state': state,
        'before': before,
        'after': after,
      };

  factory JournalUnit.fromMap(Map<String, dynamic> m) => JournalUnit(
        uid: m['uid'] as String,
        itemId: m['itemId'] as String,
        variantId: m['variantId'] as String?,
        qty: (m['qty'] as num).toDouble(),
        reason: m['reason'] as String,
        itemName: m['itemName'] as String,
        unit: m['unit'] as String,
        unitCost: (m['unitCost'] as num?)?.toDouble(),
        state: m['state'] as String,
        before: (m['before'] as num?)?.toDouble(),
        after: (m['after'] as num?)?.toDouble(),
      );
}

/// Pending stock work for one Settle commit, persisted BEFORE the order lines.
class JournalEntry {
  static const int version = 1;

  final String id;
  final String orderId;
  final DateTime createdAt;

  /// lineId → quantity the commit saves on the order; proves, after a crash,
  /// whether the order write happened.
  final Map<String, int> target;
  final String staffName;
  final String? sessionId;

  /// Set right after the order lines are saved.
  bool orderSaved;
  final List<JournalUnit> units;

  JournalEntry({
    required this.id,
    required this.orderId,
    required this.createdAt,
    required this.target,
    required this.staffName,
    this.sessionId,
    this.orderSaved = false,
    required this.units,
  });

  /// Units still owed (review units are never auto-applied).
  bool get hasUnfinished => units.any((u) =>
      u.state == StockJournal.planned ||
      u.state == StockJournal.applying ||
      u.state == StockJournal.written);

  Map<String, dynamic> toMap() => {
        'v': version,
        'id': id,
        'orderId': orderId,
        'createdAt': createdAt.toIso8601String(),
        'target': target,
        'staffName': staffName,
        'sessionId': sessionId,
        'orderSaved': orderSaved,
        'units': [for (final u in units) u.toMap()],
      };

  factory JournalEntry.fromMap(Map<String, dynamic> m) => JournalEntry(
        id: m['id'] as String,
        orderId: m['orderId'] as String,
        createdAt: DateTime.parse(m['createdAt'] as String),
        target: {
          for (final e in (m['target'] as Map).entries)
            e.key as String: (e.value as num).toInt(),
        },
        staffName: m['staffName'] as String,
        sessionId: m['sessionId'] as String?,
        orderSaved: m['orderSaved'] as bool? ?? false,
        units: [
          for (final u in (m['units'] as List))
            JournalUnit.fromMap(Map<String, dynamic>.from(u as Map)),
        ],
      );
}

/// Persistent, resumable stock deduction for Settle (Phase 0.2).
///
/// Lifecycle (SettleLineCommit): [open] the entry with every unit `planned`
/// BEFORE the order lines are saved → save the order → [markOrderSaved] →
/// [complete]. Each unit: inside the item's stock queue record `applying`
/// with the balance before and after → write stock → write the movement row
/// (id = unit uid) → `done`. Between the stock write and the row the unit is
/// `written`, known in-process. A complete entry is deleted.
///
/// After a failure or crash, [recoverAll] (startup, and every Settle)
/// resolves each unit from what is on disk: movement row exists → done;
/// `planned` → apply; `written` → write the row only. `applying` (the process
/// died between the stock write and `written`) is resolved from balances:
/// stock == after → row only; stock == before → apply; anything else →
/// `review` (never guessed; a persisted alert asks for a manual check). An entry whose order write never happened (target
/// lines absent, nothing applied yet) is discarded — stock only moves after
/// the order save.
class StockJournal {
  static const String planned = 'planned';
  static const String applying = 'applying';

  /// Stock write confirmed in-process; the movement row may still be missing.
  static const String written = 'written';
  static const String done = 'done';
  static const String review = 'review';

  /// Persisted alert raised for a `review` unit (NotificationPresenter).
  static const String reviewEvent = 'stock_check_needed';

  static const double _eps = 1e-9;

  static Box get _box => Hive.box(HiveBoxNames.restaurantStockJournal);

  static Future<void> save(JournalEntry entry) =>
      _box.put(entry.id, entry.toMap());

  static JournalEntry? get(String id) {
    final raw = _box.get(id);
    return raw == null
        ? null
        : JournalEntry.fromMap(Map<String, dynamic>.from(raw as Map));
  }

  static List<JournalEntry> all() => [
        for (final raw in _box.values)
          JournalEntry.fromMap(Map<String, dynamic>.from(raw as Map)),
      ];

  static Future<void> delete(String id) => _box.delete(id);

  /// Restore replaces the orders and stock entries refer to; replaying one
  /// against restored data would corrupt it.
  static Future<void> clear() => _box.clear();

  /// Persists a new entry, every unit `planned`, before any write it covers.
  static Future<JournalEntry> open({
    required String orderId,
    required Map<String, int> target,
    required List<SaleStockUnit> units,
  }) async {
    final key = 'settle:${const Uuid().v4()}';
    final entry = JournalEntry(
      id: key,
      orderId: orderId,
      createdAt: DateTime.now(),
      target: target,
      staffName: RestaurantSession.staffName ?? RestaurantSession.effectiveRole,
      sessionId: await DayManagementService.getCurrentSessionId(),
      units: [
        for (final u in units)
          JournalUnit(
            uid: u.uidFor(key),
            itemId: u.item.id,
            variantId: u.variantId,
            qty: u.qty,
            reason: u.reason,
            itemName: u.label,
            unit: u.unit,
            unitCost: u.item.lastPurchaseCost,
          ),
      ],
    );
    await save(entry);
    return entry;
  }

  static Future<void> markOrderSaved(JournalEntry entry) async {
    entry.orderSaved = true;
    await save(entry);
  }

  /// Applies every owed unit of [entry]. Throws on the first failure with
  /// the entry still persisted, so a retry or the next startup resumes it.
  /// Deletes the entry once nothing is owed.
  static Future<void> complete(JournalEntry entry) async {
    await itemStore.ensureLoaded();
    final repo = StockMovementRepository();
    final toasts = <String>[];
    for (final unit in entry.units) {
      await _resolve(entry, unit, repo, toasts);
    }
    if (!entry.hasUnfinished && !entry.units.any((u) => u.state == review)) {
      await delete(entry.id);
    }
    if (toasts.isNotEmpty) {
      try {
        NotificationService.instance
            .showWarning("Low Stock - ${toasts.join(" | ")}");
      } catch (_) {
        // A toast must never decide whether stock work counts as done.
      }
    }
  }

  static Future<void> _resolve(
    JournalEntry entry,
    JournalUnit unit,
    StockMovementRepository repo,
    List<String> toasts,
  ) async {
    if (unit.state == done || unit.state == review) return;

    if (repo.contains(unit.uid)) {
      // Crash after the movement row, before `done`.
      unit.state = done;
      await save(entry);
      return;
    }

    final item = itemStore.getItemById(unit.itemId);
    if (unit.state == written) {
      // Stock write confirmed in-process; only the row is missing.
      if (item == null) {
        unit.state = done;
        await save(entry);
        return;
      }
      await _writeMovement(entry, unit, item, unit.after!, repo, toasts);
      return;
    }
    if (item == null) {
      // Item deleted since: a sale skips deleted items, so does this.
      unit.state = done;
      await save(entry);
      return;
    }

    if (unit.state == applying) {
      // Only reached when the process died between the stock write and
      // recording `written`; resolved from the balances, never guessed.
      final current = _stockOf(item, unit.variantId);
      if (current != null && (current - unit.after!).abs() < _eps) {
        // Crash after the stock write: only the row is missing.
        await _writeMovement(entry, unit, item, unit.after!, repo, toasts);
        return;
      }
      if (current == null || (current - unit.before!).abs() >= _eps) {
        // Neither: another write moved this item since. Never guess.
        unit.state = review;
        await save(entry);
        await _raiseReview(unit);
        return;
      }
      // Stock still == before: the write never happened. Apply below.
    }

    var hookRan = false;
    final double balance;
    try {
      balance = await itemStore.applyStockDelta(
        itemId: unit.itemId,
        variantId: unit.variantId,
        delta: -unit.qty,
        beforePersist: (before, after) async {
          hookRan = true;
          unit
            ..state = applying
            ..before = before
            ..after = after;
          await save(entry);
        },
      );
    } catch (_) {
      // The stock write threw, so it did not happen: back to `planned` so a
      // retry never has to infer it from balances. Best effort — if this
      // save fails too, `applying` + stock == before still resolves it.
      if (hookRan) {
        unit
          ..state = planned
          ..before = null
          ..after = null;
        try {
          await save(entry);
        } catch (_) {}
      }
      rethrow;
    }
    if (!hookRan) {
      // Variant gone since planning: nothing moved, nothing to log.
      unit.state = done;
      await save(entry);
      return;
    }
    // Known in-process: the stock write happened. From here a retry only
    // ever writes the movement row — never the stock again.
    unit.state = written;
    await save(entry);
    await _writeMovement(entry, unit, item, balance, repo, toasts);
  }

  static Future<void> _writeMovement(
    JournalEntry entry,
    JournalUnit unit,
    Items item,
    double balanceAfter,
    StockMovementRepository repo,
    List<String> toasts,
  ) async {
    await repo.saveMovement(StockMovementModel(
      id: unit.uid,
      timestamp: DateTime.now(),
      itemId: unit.itemId,
      variantId: unit.variantId,
      itemName: unit.itemName,
      type: 'out',
      quantity: unit.qty,
      balanceAfter: balanceAfter,
      reason: unit.reason,
      unit: unit.unit,
      staffName: entry.staffName,
      sessionId: entry.sessionId,
      unitCost: unit.unitCost,
    ));
    unit.state = done;
    await save(entry);
    final toast =
        InventoryService.lowStockToastFor(item, unit.itemName, balanceAfter);
    if (toast != null) toasts.add(toast);
  }

  static double? _stockOf(Items item, String? variantId) {
    if (variantId == null) return item.stockQuantity;
    final v = item.variant?.where((v) => v.variantId == variantId).firstOrNull;
    return v?.stockQuantity;
  }

  static Future<void> _raiseReview(JournalUnit unit) async {
    try {
      await notificationStore.raiseEvent(
        eventCode: reviewEvent,
        subjectType: 'stock_journal_unit',
        subjectId: unit.uid,
        data: {
          'name': unit.itemName,
          'qty': unit.qty,
          'unit': unit.unit,
          'reason': unit.reason,
        },
      );
    } catch (e) {
      // The unit stays `review` in the journal either way.
      debugPrint('Stock journal review alert failed: $e');
    }
  }

  /// Whether the order write the entry covers happened. Only consulted while
  /// nothing has been applied (`orderSaved` is set right after the save).
  static bool _orderWasSaved(JournalEntry entry) {
    if (entry.orderSaved) return true;
    if (entry.units.any((u) => u.state != planned)) return true;
    final saved = orderStore.getOrderById(entry.orderId);
    if (saved == null) return false;
    return entry.target.entries.every((t) => saved.items
        .any((line) => line.id == t.key && line.quantity == t.value));
  }

  /// Finishes every persisted entry. Never throws: an entry that fails stays
  /// for the next attempt and its error is returned by entry id.
  static Future<Map<String, Object>> recoverAll() async {
    final failures = <String, Object>{};
    final entries = all();
    if (entries.isEmpty) return failures;
    try {
      await itemStore.ensureLoaded();
      if (entries.any((e) => !e.orderSaved)) await orderStore.loadOrders();
    } catch (e) {
      for (final entry in entries) {
        failures[entry.id] = e;
      }
      return failures;
    }
    for (final entry in entries) {
      try {
        if (!_orderWasSaved(entry)) {
          await delete(entry.id);
          continue;
        }
        if (!entry.orderSaved) await markOrderSaved(entry);
        await complete(entry);
      } catch (e) {
        failures[entry.id] = e;
        debugPrint('Stock journal ${entry.id} not finished: $e');
      }
    }
    return failures;
  }
}
