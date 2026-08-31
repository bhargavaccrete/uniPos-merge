import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/routes/routes_name.dart';

/// Mode-aware destinations for notification taps.
///
/// `NotificationPresenter` is shared by both verticals, but a route name is
/// not: "low stock" lands on the restaurant inventory screen in one mode and
/// the retail Stock Alerts screen in the other. This is the [ModeKeys]
/// treatment applied to routes — one canonical resolution per destination, so
/// no call site ever inlines `AppConfig.isRetail ? … : …`.
///
/// `null` means "this event has no destination in this mode" — the screen
/// marks it read and stays put, which is already how routeless events
/// (`backup_due`, `announcement`) behave.
class NotificationRoutes {
  NotificationRoutes._();

  /// The notification feed itself (the AppBar bell's target).
  static String get self => AppConfig.isRetail
      ? RouteNames.notifications
      : RouteNames.restaurantNotifications;

  static String? get lowStock => AppConfig.isRetail
      ? RouteNames.stockAlerts
      : RouteNames.restaurantInventory;

  /// Retail-only: restaurant does not raise `expiry_alert`.
  static String? get expiry =>
      AppConfig.isRetail ? RouteNames.expiryAlerts : null;

  /// Restaurant-only: retail has no day-management/EOD session flow.
  static String? get endDay =>
      AppConfig.isRetail ? null : RouteNames.restaurantEndDay;

  /// Restaurant-only: retail has no licensing screen to land on.
  static String? get licensing =>
      AppConfig.isRetail ? null : RouteNames.restaurantLicensing;
}
