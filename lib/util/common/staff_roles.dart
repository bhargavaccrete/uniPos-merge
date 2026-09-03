import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';

/// The ONE source of the staff role vocabulary for both verticals.
///
/// `StaffModel.isCashier` is a String holding the role name (the field name is
/// historical — it is the role, not a bool). Before this helper the list was
/// retyped in three places (`manage_staff_screen.dart`, `staffSetupStep.dart`
/// and retail's since-deleted staff stub), and the three had drifted apart.
///
/// Retail deliberately omits `Waiter` — there are no tables to wait — and stops
/// at Manager/Cashier because those are the two roles
/// `RestaurantSession.canAccess` already has a permission matrix for.
class StaffRoles {
  StaffRoles._();

  static const String unselected = 'Select Role';

  static const List<String> restaurant = ['Manager', 'Cashier', 'Waiter'];
  static const List<String> retail = ['Manager', 'Cashier'];

  /// Roles offered by the business mode this device is running.
  static List<String> get forCurrentMode =>
      AppConfig.isRetail ? retail : restaurant;

  static const Map<String, IconData> icons = {
    'Manager': Icons.manage_accounts_rounded,
    'Cashier': Icons.point_of_sale_rounded,
    'Waiter': Icons.restaurant_rounded,
    'Chef': Icons.soup_kitchen_rounded,
  };

  static const Map<String, Color> colors = {
    'Manager': Color(0xFF7C3AED),
    'Cashier': Color(0xFF059669),
    'Waiter': Color(0xFFDB2777),
    'Chef': Color(0xFFDC2626),
  };

  static IconData iconFor(String role) =>
      icons[role] ?? Icons.badge_outlined;

  static Color colorFor(String role) =>
      colors[role] ?? const Color(0xFF64748B);
}
