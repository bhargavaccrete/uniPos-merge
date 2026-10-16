import 'dart:async';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/domain/store/retail/stock_alert_store.dart';
import 'package:billberrylite/core/routes/notification_routes.dart';
import 'package:billberrylite/data/models/common/notification_presenter.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/domain/services/common/local_notification_service.dart';
import 'package:billberrylite/domain/services/retail/expiry_alert_service.dart';
import 'package:billberrylite/domain/services/retail/expiry_status.dart';

/// Turns retail's derived alerts into persisted notification events.
///
/// The retail counterpart of `NotificationSyncService`, and deliberately the
/// same shape: raise-or-resolve on every run, `fireOs: false` on the individual
/// events, plus one scheduled reminder per alert type.
///
/// **Reconciling, not event-driven.** Restaurant raises `low_stock` from inside
/// `deductStockForOrder` — it knows exactly which item moved. Retail's
/// low-stock and expiry states are *derived* (`StockAlertService` and
/// `ExpiryAlertService` recompute from live variant data on every read), so
/// there is no single moment to hook. Instead this recomputes the whole
/// alerting set, raises one event per alerting variant, and resolves every
/// previously-raised event whose variant has dropped out. That is what makes
/// the three awkward cases correct for free: a restocked variant resolves, an
/// edited expiry date updates the same row in place, and a cleared expiry drops
/// out entirely.
///
/// It reads the existing services — it does not re-implement the reorder-point
/// or expiry maths, and it stores no alert state of its own.
class RetailNotificationSyncService {
  RetailNotificationSyncService._();

  static const String lowStockEvent = 'low_stock';
  static const String expiryEvent = 'expiry_alert';

  /// Both events are per-variant, so the identity triple is
  /// `(eventCode, 'variant', variantId)`. Restaurant's own low-stock events use
  /// `'item'`, so the two verticals can never collide inside the shared box.
  static const String subjectVariant = 'variant';

  static const String _lowStockSeed = 'low_stock:retail-summary';
  static const String _expirySeed = 'expiry_alert:retail-summary';

  static const int _morningHour = 9;

  static Timer? _debounce;

  /// Fire-and-forget reconcile after a stock write, coalesced over a short
  /// window — the retail twin of restaurant's `LowStockSyncService.scheduleSync`.
  ///
  /// Alerts used to refresh only at startup and on the notifications screen,
  /// so selling the last unit or receiving new stock left them stale all day.
  /// Called from `ProductStore`'s stock writers (the choke point every sale,
  /// receipt, return, adjustment and edit goes through). The debounce keeps a
  /// 50-line stock take to one run. A no-op until the alert store exists.
  static void scheduleSync() {
    if (!locator.isRegistered<StockAlertStore>()) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _debounce = null;
      // Unawaited on purpose: a notification refresh must never delay or
      // fail a stock write.
      runStartupChecks().catchError((_) {});
    });
  }

  /// [asOf] and [warningDays] exist for tests — production always uses now / 7.
  static Future<void> runStartupChecks({
    DateTime? asOf,
    int warningDays = kExpiryWarningDays,
  }) async {
    // The catalogue hydrates asynchronously from ProductStore's constructor;
    // without this a cold start concludes nothing is low or expiring.
    await productStore.ensureLoaded();
    await _syncLowStock();
    await _syncExpiry(asOf: asOf, warningDays: warningDays);
  }

  // ==================== LOW STOCK ====================

  static Future<void> _syncLowStock() async {
    await stockAlertStore.loadSettings();

    // `stock_alerts_enabled` has been collecting a preference and gating
    // nothing. A user who switched stock alerts off should not be notified.
    if (!stockAlertStore.isEnabled) {
      await _resolveMissing(lowStockEvent, const <String>{});
      await LocalNotificationService.instance.cancelBySeed(_lowStockSeed);
      return;
    }

    await stockAlertStore.loadLowStockItems();
    final rows = stockAlertStore.lowStockItems.toList();
    final byId = _variantsById();
    final alerting = <String>{};

    for (final row in rows) {
      final id = row['variantId'] as String?;
      if (id == null || id.isEmpty) continue;
      alerting.add(id);
      final variant = byId[id];
      await notificationStore.raiseEvent(
        eventCode: lowStockEvent,
        subjectType: subjectVariant,
        subjectId: id,
        data: {
          'name': _label(row),
          'remaining': row['currentStock'],
          // Restaurant always sends a unit (falling back to 'units') and the
          // presenter interpolates it unguarded, so match that contract.
          'unit': variant?.effectiveUnit ?? 'units',
        },
        fireOs: false,
      );
    }

    await _resolveMissing(lowStockEvent, alerting);
    await _scheduleSummary(
      seed: _lowStockSeed,
      count: rows.length,
      title: 'Low Stock',
      body: rows.length == 1
          ? '1 product is below its reorder point.'
          : '${rows.length} products are below their reorder point.',
      channelId: NotificationChannels.lowStock,
      route: NotificationRoutes.lowStock,
    );
  }

  // ==================== EXPIRY ====================

  static Future<void> _syncExpiry({
    DateTime? asOf,
    int warningDays = kExpiryWarningDays,
  }) async {
    final rows = ExpiryAlertService.getExpiryAlerts(
      asOf: asOf,
      warningDays: warningDays,
    );
    final alerting = <String>{};
    var expiredCount = 0;

    for (final row in rows) {
      final id = row['variantId'] as String?;
      if (id == null || id.isEmpty) continue;
      alerting.add(id);
      final status = row['status'] as RetailExpiryStatus;
      if (status == RetailExpiryStatus.expired) expiredCount++;
      await notificationStore.raiseEvent(
        eventCode: expiryEvent,
        subjectType: subjectVariant,
        subjectId: id,
        data: {
          'name': _label(row),
          // `raiseEvent` refreshes `data` even on a same-day repeat, so a row
          // that tips from expiringSoon to expired upgrades its own severity
          // instead of leaving a stale copy behind.
          'status': status.name,
          'expiryDate': row['expiryDate'],
          'daysUntil': row['daysUntil'],
        },
        fireOs: false,
      );
    }

    await _resolveMissing(expiryEvent, alerting);
    await _scheduleSummary(
      seed: _expirySeed,
      count: rows.length,
      title: expiredCount > 0 ? 'Products Expired' : 'Expiring Soon',
      body: expiredCount > 0
          ? '$expiredCount expired, ${rows.length - expiredCount} expiring soon.'
          : rows.length == 1
              ? '1 product is expiring soon.'
              : '${rows.length} products are expiring soon.',
      channelId: NotificationChannels.expiry,
      route: NotificationRoutes.expiry,
    );
  }

  // ==================== SHARED ====================

  /// Retires every active [eventCode] whose subject is no longer alerting.
  static Future<void> _resolveMissing(
    String eventCode,
    Set<String> stillAlerting,
  ) async {
    // Snapshot first — `resolve` writes back through the same observable list.
    final stale = notificationStore
        .activeOf(eventCode, subjectType: subjectVariant)
        .where((n) => !stillAlerting.contains(n.subjectId))
        .toList();
    for (final n in stale) {
      await notificationStore.resolve(eventCode, subjectVariant, n.subjectId);
    }
  }

  /// One tray reminder per alert type, not one per variant.
  ///
  /// The per-variant rows already drive the in-app list and the unread badge;
  /// firing an OS notification for each would mean dozens at once on a
  /// mid-sized catalogue. `schedule` also gives idempotence for free — the same
  /// seed replaces the pending alarm, so relaunching never double-notifies.
  static Future<void> _scheduleSummary({
    required String seed,
    required int count,
    required String title,
    required String body,
    required String channelId,
    String? route,
  }) async {
    if (count == 0) {
      await LocalNotificationService.instance.cancelBySeed(seed);
      return;
    }
    await LocalNotificationService.instance.schedule(
      idSeed: seed,
      when: _nextMorning(),
      title: title,
      body: body,
      channelId: channelId,
      payload: route,
    );
  }

  static Map<String, VarianteModel> _variantsById() => {
        for (final v in productStore.variants) v.varianteId: v,
      };

  /// "Amul Milk (1L)" — the variant label is empty for single-variant products.
  static String _label(Map<String, dynamic> row) {
    final name = (row['productName'] as String?) ?? 'A product';
    final label = ((row['variantLabel'] as String?) ?? '').trim();
    return label.isEmpty ? name : '$name ($label)';
  }

  static DateTime _nextMorning() {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, _morningHour);
    if (!target.isAfter(now)) target = target.add(const Duration(days: 1));
    return target;
  }
}
