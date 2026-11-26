import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:billberrylite/data/models/common/staffModel_310.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';
import 'package:billberrylite/util/restaurant/restaurant_auth_helper.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';

/// Drawer "Change PIN": the current PIN is checked against the LOGGED-IN
/// staff member only, so a colleague's PIN can never be changed from here.
void main() {
  StaffModel member(String id, String role, String pin, {bool active = true}) =>
      StaffModel(
        id: id,
        userName: id,
        firstName: id,
        lastName: '',
        isCashier: role,
        mobileNo: '',
        emailId: '',
        pinNo: RestaurantAuthHelper.hashPassword(pin),
        createdAt: DateTime(2026, 1, 1),
        isActive: active,
      );

  final manager = member('mgr', 'Manager', '2222');
  final waiter = member('wtr', 'Waiter', '3333');
  final staff = [manager, waiter];

  /// Runs the dialog's rule, then applies the update the dialog would make.
  /// Returns the error shown, and the staff list after the attempt.
  ({String? error, List<StaffModel> after}) changePin(
      String? loggedInId, String currentPin, String newPin,
      [List<StaffModel>? list]) {
    final all = list ?? staff;
    final check = RestaurantAuthHelper.staffForOwnPinChange(
        staffId: loggedInId, staff: all, currentPin: currentPin);
    if (check.staff == null) return (error: check.error, after: all);
    final updated = check.staff!
        .copyWith(pinNo: RestaurantAuthHelper.hashPassword(newPin));
    return (
      error: null,
      after: [for (final s in all) s.id == updated.id ? updated : s],
    );
  }

  bool pinIs(List<StaffModel> list, String id, String pin) =>
      RestaurantAuthHelper.verifyPassword(
          pin, list.firstWhere((s) => s.id == id).pinNo);

  test("a Waiter cannot use the Manager's PIN as their current PIN", () {
    final r = changePin('wtr', '2222', '9999');
    expect(r.error, 'Current PIN is incorrect');
    expect(pinIs(r.after, 'mgr', '2222'), isTrue);
    expect(pinIs(r.after, 'wtr', '3333'), isTrue);
  });

  test('a staff member changes their own PIN; nobody else\'s changes', () {
    final r = changePin('wtr', '3333', '4444');
    expect(r.error, isNull);
    expect(pinIs(r.after, 'wtr', '4444'), isTrue);
    expect(pinIs(r.after, 'mgr', '2222'), isTrue,
        reason: 'the Manager is untouched');
  });

  for (final id in [null, '']) {
    test('no logged-in staff id ("$id") refuses and changes nothing', () {
      final r = changePin(id, '3333', '4444');
      expect(r.error, RestaurantAuthHelper.reloginToChangePinMessage);
      expect(pinIs(r.after, 'wtr', '3333'), isTrue);
      expect(pinIs(r.after, 'mgr', '2222'), isTrue);
    });
  }

  test('a staff id with no record refuses', () {
    final r = changePin('gone', '3333', '4444');
    expect(r.error, RestaurantAuthHelper.reloginToChangePinMessage);
    expect(pinIs(r.after, 'wtr', '3333'), isTrue);
  });

  test('an inactive staff member is refused, even with the right PIN', () {
    final list = [manager, member('wtr', 'Waiter', '3333', active: false)];
    final r = changePin('wtr', '3333', '4444', list);
    expect(r.error, RestaurantAuthHelper.reloginToChangePinMessage);
    expect(pinIs(r.after, 'wtr', '3333'), isTrue);
  });

  group('RestaurantSession staff id', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    tearDown(() async => RestaurantSession.clearSession());

    test('a staff login saves the id; logout clears it', () async {
      await RestaurantSession.saveStaffSession(waiter);
      final prefs = await SharedPreferences.getInstance();
      expect(RestaurantSession.staffId, 'wtr');
      expect(prefs.getString(RestaurantSession.staffIdKey), 'wtr');

      await RestaurantSession.clearSession();
      expect(RestaurantSession.staffId, isNull);
      expect(prefs.getString(RestaurantSession.staffIdKey), isNull);
    });

    test('an admin login clears a previous staff id', () async {
      await RestaurantSession.saveStaffSession(waiter);
      await RestaurantSession.saveAdminSession();
      final prefs = await SharedPreferences.getInstance();
      expect(RestaurantSession.staffId, isNull);
      expect(prefs.getString(RestaurantSession.staffIdKey), isNull);
    });

    test('a cold start reads the saved id back', () async {
      SharedPreferences.setMockInitialValues(
          {RestaurantSession.staffIdKey: 'wtr'});
      await RestaurantSession.load();
      expect(RestaurantSession.staffId, 'wtr');
    });

    test('the staff id is never carried by a backup', () {
      expect(
          UnifiedBackupService.prefTravelsWithBackup(
              RestaurantSession.staffIdKey),
          isFalse);
    });
  });
}
