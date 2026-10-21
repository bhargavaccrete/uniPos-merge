import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/routes/routes_name.dart';
import 'package:billberrylite/data/models/common/dashboard_alert.dart';
import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/models/common/notification_presenter.dart';

/// NOTIFICATION PRESENTER — one event catalogue, two verticals.
///
/// The notification stack moved out of `restaurant/` into `common/` so retail
/// could reuse it. The only thing in it that genuinely differs per vertical is
/// where a tap LANDS: "low stock" means the restaurant Inventory screen in one
/// mode and retail's Stock Alerts screen in the other.
///
/// Group A is the regression pin for that move — it asserts restaurant's
/// existing routes and severities are exactly what they were before. Group B
/// covers the retail resolutions and the new `expiry_alert` event.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('notif_presenter_');
    Hive.init(tempDir.path);
    await AppConfig.init();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> useRestaurant() async =>
      AppConfig.box.put('businessMode', 'restaurant');
  Future<void> useRetail() async => AppConfig.box.put('businessMode', 'retail');

  AppNotificationModel event(String code, [Map<String, dynamic>? data]) =>
      AppNotificationModel(
        id: 'n-$code',
        eventCode: code,
        subjectType: 'variant',
        subjectId: 'v1',
        data: data == null ? null : jsonEncode(data),
        timestamp: DateTime.now(),
      );

  // ==================== A. RESTAURANT (regression pin) ====================

  group('A. restaurant routes and severities are unchanged', () {
    setUp(useRestaurant);

    // Was `restaurantInventory` (the hub). A low-stock tap now lands on the
    // Low Stock list itself, which is the screen that can restock — matching
    // how retail has always routed its own low-stock events.
    test('low_stock → restaurant low-stock list, warning', () {
      final v = NotificationPresenter.present(
        event('low_stock', {'name': 'Paneer', 'remaining': 2, 'unit': 'kg'}),
      );
      expect(v.route, RouteNames.restaurantLowStock);
      expect(v.severity, AlertSeverity.warning);
      expect(v.channelId, NotificationChannels.lowStock);
      expect(v.title, 'Low Stock');
      expect(v.body, 'Paneer: 2 kg left.');
    });

    test('pending_eod → end day, critical', () {
      final v = NotificationPresenter.present(event('pending_eod'));
      expect(v.route, RouteNames.restaurantEndDay);
      expect(v.severity, AlertSeverity.critical);
      expect(v.channelId, NotificationChannels.appAlerts);
    });

    test('license_expired → licensing, critical', () {
      final v = NotificationPresenter.present(event('license_expired'));
      expect(v.route, RouteNames.restaurantLicensing);
      expect(v.severity, AlertSeverity.critical);
    });

    test('license_expiring → licensing, warning, day count in the body', () {
      final v = NotificationPresenter.present(
        event('license_expiring', {'daysRemaining': 1}),
      );
      expect(v.route, RouteNames.restaurantLicensing);
      expect(v.severity, AlertSeverity.warning);
      expect(v.body, contains('in 1 day.'));
    });

    test('backup_due and announcement stay routeless', () {
      expect(NotificationPresenter.present(event('backup_due')).route, isNull);
      expect(
        NotificationPresenter.present(event('announcement')).route,
        isNull,
      );
    });

    test('expiry_alert has no destination in restaurant', () {
      // Restaurant never raises it, but the presenter must not hand back a
      // retail route if a stale record or an FCM push ever carries the code.
      final v = NotificationPresenter.present(
        event('expiry_alert', {'name': 'Curd', 'status': 'expired'}),
      );
      expect(v.route, isNull);
    });
  });

  // ==================== B. RETAIL ====================

  group('B. retail routes and the expiry event', () {
    setUp(useRetail);

    test('low_stock → retail stock alerts, same copy', () {
      final v = NotificationPresenter.present(
        event('low_stock', {'name': 'Amul Milk (1L)', 'remaining': 3, 'unit': 'piece'}),
      );
      expect(v.route, RouteNames.stockAlerts);
      expect(v.severity, AlertSeverity.warning);
      expect(v.body, 'Amul Milk (1L): 3 piece left.');
    });

    test('expiry_alert expired → critical', () {
      final v = NotificationPresenter.present(
        event('expiry_alert', {'name': 'Curd 500g', 'status': 'expired'}),
      );
      expect(v.route, RouteNames.expiryAlerts);
      expect(v.severity, AlertSeverity.critical);
      expect(v.title, 'Product Expired');
      expect(v.body, 'Curd 500g has expired.');
      expect(v.channelId, NotificationChannels.expiry);
    });

    test('expiry_alert expiring soon → warning, with the day count', () {
      final v = NotificationPresenter.present(
        event('expiry_alert', {
          'name': 'Curd 500g',
          'status': 'expiringSoon',
          'daysUntil': 3,
        }),
      );
      expect(v.severity, AlertSeverity.warning);
      expect(v.title, 'Expiring Soon');
      expect(v.body, 'Curd 500g expires in 3 days.');
    });

    test('expiry_alert expiring today reads as today, not "in 0 days"', () {
      final v = NotificationPresenter.present(
        event('expiry_alert', {
          'name': 'Curd 500g',
          'status': 'expiringToday',
          'daysUntil': 0,
        }),
      );
      expect(v.body, 'Curd 500g expires today.');
      expect(v.severity, AlertSeverity.warning);
    });

    test('restaurant-only events have no retail destination', () {
      expect(NotificationPresenter.present(event('pending_eod')).route, isNull);
      expect(
        NotificationPresenter.present(event('license_expired')).route,
        isNull,
      );
    });
  });
}
