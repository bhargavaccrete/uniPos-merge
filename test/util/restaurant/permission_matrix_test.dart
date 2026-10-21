import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:billberrylite/data/models/common/staffModel_310.dart';
import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/data/models/common/business_type.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';

/// ROLE PERMISSION MATRIX — `RestaurantSession.canAccess`.
///
/// One function serves both verticals, so these tests do two jobs: they pin
/// retail's new rules, and they lock restaurant's existing ones against
/// regression. The restaurant group is the one that matters most — retail's
/// blocked set was added to a function restaurant already depended on.
///
/// Sign-in goes through the real `saveAdminSession` / `saveStaffSession` rather
/// than poking the notifiers, so the tests exercise the same path the app does —
/// including `_isLoggedIn`, which `canAccess` now fails closed on.
void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('permission_matrix_');
    Hive.init(tempDir.path);
    await AppConfig.init();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> asRetail() =>
      AppConfig.forceSetBusinessMode(BusinessMode.retail);
  Future<void> asRestaurant() =>
      AppConfig.forceSetBusinessMode(BusinessMode.restaurant);

  /// [role] null signs in as the admin; otherwise as a staff member with that
  /// role string (`StaffModel.isCashier` holds the role — historical name).
  Future<void> signInAs(String? role) async {
    if (role == null) return RestaurantSession.saveAdminSession();
    return RestaurantSession.saveStaffSession(StaffModel(
      id: 'staff-1',
      userName: 'tester',
      firstName: 'Test',
      lastName: 'User',
      isCashier: role,
      mobileNo: '',
      emailId: '',
      pinNo: '',
      createdAt: DateTime(2026, 1, 1),
    ));
  }

  group('retail — Cashier', () {
    setUp(() async {
      await asRetail();
      await signInAs('Cashier');
    });

    test('is denied every blocked key', () {
      for (final key in const [
        'reports',
        'manageStaff',
        'settings',
        'taxSettings',
        'catalogEdit',
        'inventoryAdjust',
        'suppliers',
        'purchase',
        'dataBackup',
        'billingOverride',
        'billingDiscount',
        'billingExchange',
      ]) {
        expect(RestaurantSession.canAccess(key), isFalse,
            reason: 'retail Cashier must NOT have "$key"');
      }
    });

    test('keeps the counter surface', () {
      for (final key in const [
        'billing',
        'customers',
        'catalog', // view-only: browsing is allowed, catalogEdit is not
        'inventory', // ditto vs inventoryAdjust
        'cashDrawer',
        'endDay',
        'attendance',
      ]) {
        expect(RestaurantSession.canAccess(key), isTrue,
            reason: 'retail Cashier must keep "$key"');
      }
    });

    test('can view the catalogue but not change it', () {
      expect(RestaurantSession.canAccess('catalog'), isTrue);
      expect(RestaurantSession.canAccess('catalogEdit'), isFalse);
      expect(RestaurantSession.canAccess('inventory'), isTrue);
      expect(RestaurantSession.canAccess('inventoryAdjust'), isFalse);
    });

    test('keeps cashDrawer, unlike a restaurant Cashier', () async {
      expect(RestaurantSession.canAccess('cashDrawer'), isTrue);
      await asRestaurant();
      expect(RestaurantSession.canAccess('cashDrawer'), isFalse,
          reason: 'the two verticals deliberately differ here');
    });
  });

  group('retail — Manager and Admin', () {
    test('Manager gets everything a Cashier is denied', () async {
      await asRetail();
      await signInAs('Manager');
      for (final key in const [
        'reports',
        'manageStaff',
        'settings',
        'taxSettings',
        'catalogEdit',
        'inventoryAdjust',
        'suppliers',
        'purchase',
        'dataBackup',
        'billingOverride',
        'billingDiscount',
        'billingExchange',
      ]) {
        expect(RestaurantSession.canAccess(key), isTrue,
            reason: 'Manager is full access — "$key" must pass');
      }
    });

    test('Admin gets everything', () async {
      await asRetail();
      await signInAs(null); // loginType 'admin'
      expect(RestaurantSession.isAdmin, isTrue);
      for (final key in const ['catalogEdit', 'settings', 'dataBackup']) {
        expect(RestaurantSession.canAccess(key), isTrue);
      }
    });
  });

  group('signed out', () {
    test('every permission is denied once the session is cleared', () async {
      await asRetail();
      await signInAs('Manager');
      expect(RestaurantSession.canAccess('settings'), isTrue);

      await RestaurantSession.clearSession();

      // clearSession resets loginType to its 'admin' default, so isAdmin reads
      // TRUE here. canAccess must still deny — it checks isLoggedIn first.
      expect(RestaurantSession.isAdmin, isTrue,
          reason: 'guards the assumption this test exists to protect');
      for (final key in const ['settings', 'billing', 'customers', 'catalog']) {
        expect(RestaurantSession.canAccess(key), isFalse,
            reason: 'a signed-out session must fail CLOSED on "$key"');
      }
    });
  });

  group('restaurant — regression lock', () {
    setUp(() async {
      await asRestaurant();
      await signInAs('Cashier');
    });

    test('Cashier blocked set is unchanged', () {
      for (final key in const [
        'reports',
        'manageStaff',
        'cashDrawer',
        'settings',
        'taxSettings',
      ]) {
        expect(RestaurantSession.canAccess(key), isFalse,
            reason: 'restaurant Cashier must still be denied "$key"');
      }
    });

    test('Cashier keeps orders, menu, customers, inventory, expenses', () {
      for (final key in const [
        'startOrder',
        'manageMenu',
        'customers',
        'inventory',
        'expenses',
        'endDay',
      ]) {
        expect(RestaurantSession.canAccess(key), isTrue,
            reason: 'restaurant Cashier must still have "$key"');
      }
    });

    test("retail's extra keys do not leak into restaurant's Cashier rules", () {
      // These are meaningless in restaurant; the denylist must not block them
      // there, or a shared screen would behave differently by accident.
      for (final key in const ['catalogEdit', 'suppliers', 'purchase']) {
        expect(RestaurantSession.canAccess(key), isTrue,
            reason: '"$key" is retail-only and must stay open in restaurant');
      }
    });

    test('Waiter gets orders only', () async {
      await signInAs('Waiter');
      expect(RestaurantSession.canAccess('startOrder'), isTrue);
      for (final key in const ['manageMenu', 'customers', 'inventory']) {
        expect(RestaurantSession.canAccess(key), isFalse);
      }
    });
  });
}
