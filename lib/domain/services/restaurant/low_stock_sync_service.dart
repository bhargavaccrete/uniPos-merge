import 'dart:async';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/routes/notification_routes.dart';
import 'package:billberrylite/data/models/common/notification_presenter.dart';
import 'package:billberrylite/domain/services/common/local_notification_service.dart';
import 'package:billberrylite/domain/services/restaurant/stock_adjust_service.dart';

/// Keeps restaurant `low_stock` notifications matching what is *actually* low.
///
/// **Reconciling, not event-driven** — the restaurant twin of
/// `RetailNotificationSyncService`, and deliberately the same shape.
///
/// This used to be event-driven: `InventoryService.deductStockForOrder` raised
/// the event because it knew exactly which item moved. That only ever covered
/// selling. Stock take, wastage, goods-receiving, opening stock and a manual
/// edit in Edit Item all change stock too, and none of them raised anything —
/// so the Inventory screen (which re-derives from live stock on every build)
/// listed items the bell had never heard of. Worse, restocking never
/// *resolved* an alert, so a refilled item stayed in the bell until a later
/// sale happened to re-evaluate it.
///
/// Rather than hook eight write paths and hope the ninth is never added, this
/// recomputes the whole alerting set and makes the stored events match it:
/// raise for everything currently low, resolve everything that no longer is.
/// A restock needs no code — the item simply stops appearing in [#_entries],
/// and [_resolveMissing] retires it.
///
/// It re-uses `StockAdjustService.lowStockEntries()` — the same derivation the
/// Inventory screen renders — so the two can never disagree, and there is no
/// second threshold calculation to keep in step.
class LowStockSyncService {
  LowStockSyncService._();

  static const String eventCode = 'low_stock';

  /// Restaurant alerts are per ITEM; retail's are per `variant`. Different
  /// subject types mean the two verticals can never collide in the shared box.
  static const String subjectItem = 'item';

  static const String _seed = 'low_stock:restaurant-summary';
  static const int _morningHour = 9;

  static Timer? _debounce;

  /// Fire-and-forget reconcile, coalesced over a short window.
  ///
  /// Called from every `ItemStore` mutator, which is the single choke point
  /// every stock write in the app passes through — `StockAdjustService`'s
  /// add/adjust, goods-receiving's `applyStockDelta`, the POS deduction and
  /// Edit Item all end up there. Hooking one place is the whole point: a new
  /// stock-writing feature is covered without anyone remembering to add a
  /// call.
  ///
  /// The debounce is what makes that affordable. Committing a 50-line stock
  /// take calls `updateItem` 50 times; without coalescing that is 50 full
  /// passes, each rewriting the same Hive rows. The trailing timer collapses
  /// the burst into one pass after the last write lands.
  static void scheduleSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _debounce = null;
      // Unawaited on purpose — callers are store mutators, and a notification
      // refresh must never delay or fail a stock write.
      sync().catchError((_) {});
    });
  }

  /// Identity of one alert. A variant-bearing item alerts per variant, so the
  /// id must carry both parts — this is the same `itemId[:variantId]` shape
  /// the old event-driven code wrote, so events raised by previous builds are
  /// still matched (and therefore still resolvable) rather than orphaned.
  static String subjectIdFor(String itemId, String? variantId) =>
      variantId != null ? '$itemId:$variantId' : itemId;

  /// Recompute and reconcile. Safe to call often — `raiseEvent` updates an
  /// existing row in place rather than duplicating it, and re-notifies at most
  /// once a day, so calling this after every stock write costs nothing visible.
  static Future<void> sync() async {
    await itemStore.ensureLoaded();

    // Already honours BOTH gates: `AppSettings.lowStockAlertsEnabled` and the
    // per-item `lowStockAlertEnabled`. With alerts switched off it returns
    // empty, which flows through as "resolve everything" — no special case.
    final entries = StockAdjustService.lowStockEntries();

    final alerting = <String>{};
    for (final e in entries) {
      final id = subjectIdFor(e.item.id, e.variant?.variantId);
      alerting.add(id);
      await notificationStore.raiseEvent(
        eventCode: eventCode,
        subjectType: subjectItem,
        subjectId: id,
        data: {
          'name': _label(e),
          'remaining': e.stock,
          // The presenter interpolates `unit` unguarded, so never send null.
          'unit': e.item.unit ?? 'units',
        },
        // One grouped tray notification instead of one per item — see
        // _syncSummary. The in-app toast after an order already gives the
        // cashier the immediate, per-item version.
        fireOs: false,
      );
    }

    await _resolveMissing(alerting);
    await _syncSummary(entries.length);
  }

  /// Retires every active low-stock event whose item is no longer low.
  ///
  /// This is the half that makes restock/stock-take/GRN self-correct.
  static Future<void> _resolveMissing(Set<String> stillAlerting) async {
    // Snapshot first — `resolve` writes back through the same observable list
    // that `activeOf` reads, so iterating it live would be a concurrent
    // modification.
    final stale = notificationStore
        .activeOf(eventCode, subjectType: subjectItem)
        .where((n) => !stillAlerting.contains(n.subjectId))
        .toList();
    for (final n in stale) {
      await notificationStore.resolve(eventCode, subjectItem, n.subjectId);
    }
  }

  /// One tray reminder for the whole set, not one per item.
  ///
  /// A stock take that drops twenty items below threshold would otherwise fire
  /// twenty OS notifications at once. `schedule` is idempotent per seed, so
  /// reconciling repeatedly just replaces the pending alarm.
  static Future<void> _syncSummary(int count) async {
    if (count == 0) {
      await LocalNotificationService.instance.cancelBySeed(_seed);
      return;
    }
    await LocalNotificationService.instance.schedule(
      idSeed: _seed,
      when: _nextMorning(),
      title: 'Low Stock',
      body: count == 1
          ? '1 item is at or below its low-stock level.'
          : '$count items are at or below their low-stock level.',
      channelId: NotificationChannels.lowStock,
      payload: NotificationRoutes.lowStock,
    );
  }

  /// "Paneer Tikka (Half)" — the variant part is dropped for simple items.
  static String _label(StockAlertEntry e) {
    final variant = (e.variantName ?? '').trim();
    return variant.isEmpty ? e.item.name : '${e.item.name} ($variant)';
  }

  static DateTime _nextMorning() {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, _morningHour);
    if (!target.isAfter(now)) target = target.add(const Duration(days: 1));
    return target;
  }
}
