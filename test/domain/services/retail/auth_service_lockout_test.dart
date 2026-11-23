import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/common/staffModel_310.dart';
import 'package:billberrylite/data/repositories/common/staff_repository.dart';
import 'package:billberrylite/domain/services/retail/auth_service.dart';
import 'package:billberrylite/domain/store/common/staff_store.dart';
import 'package:billberrylite/util/common/pin_attempt_guard.dart';
import 'package:billberrylite/util/restaurant/restaurant_auth_helper.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';

import '../../../helpers/backup_box_registry.dart';

/// AND-12: Retail PIN login goes through [PinAttemptGuard] — admin and staff
/// alike — without changing who a PIN logs in as.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late AuthService auth;

  const adminPin = '4826';
  const staffPin = '7391';

  StaffModel staff(String id, String pin, {bool active = true}) => StaffModel(
        id: id,
        userName: id,
        firstName: 'Asha',
        lastName: id,
        isCashier: 'Cashier',
        mobileNo: '',
        emailId: '',
        pinNo: RestaurantAuthHelper.hashPassword(pin),
        createdAt: DateTime(2026, 1, 1),
        isActive: active,
      );

  Future<void> wrong(int n) async {
    for (var i = 0; i < n; i++) {
      await auth.login('0000');
    }
  }

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('auth_lockout_');
    await initHiveForBackupTest(dir);
    await Hive.openBox<StaffModel>(HiveBoxNames.staff);
    locator.registerLazySingleton<StaffStore>(
        () => StaffStore(StaffRepository()));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      RestaurantAuthHelper.adminPinKey:
          RestaurantAuthHelper.hashPassword(adminPin),
    });
    final box = Hive.box<StaffModel>(HiveBoxNames.staff);
    await box.clear();
    await box.put('s1', staff('s1', staffPin));
    await box.put('s2', staff('s2', '5555', active: false));
    auth = AuthService();
  });

  tearDown(() async => RestaurantSession.clearSession());

  tearDownAll(() async {
    await locator.reset();
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  test('the 5th wrong PIN locks for 30 s', () async {
    for (var i = 0; i < 4; i++) {
      final r = await auth.login('0000');
      expect(r.errorMessage, 'Invalid PIN');
      expect(r.retryAfter, isNull);
    }
    final r = await auth.login('0000');
    expect(r.success, isFalse);
    expect(r.retryAfter, const Duration(seconds: 30));
  });

  test('the correct admin PIN is refused while locked', () async {
    await wrong(5);
    final r = await auth.login(adminPin);
    expect(r.success, isFalse);
    expect(r.retryAfter, isNotNull);
    expect(auth.isLoggedIn, isFalse);
    expect(await PinAttemptGuard.remainingLock(), isNotNull,
        reason: 'a refused attempt does not clear the lock');
  });

  test('a lock survives a new AuthService (app restart)', () async {
    await wrong(5);
    final r = await AuthService().login(staffPin);
    expect(r.success, isFalse);
    expect(r.retryAfter, isNotNull);
  });

  test('after the lock ends the admin PIN works and clears the state',
      () async {
    await wrong(5);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(PinAttemptGuard.untilKey,
        DateTime.now().subtract(const Duration(seconds: 1)).millisecondsSinceEpoch);
    final r = await auth.login(adminPin);
    expect(r.success, isTrue);
    expect(r.username, 'Admin');
    for (final k in [
      PinAttemptGuard.failuresKey,
      PinAttemptGuard.levelKey,
      PinAttemptGuard.untilKey,
    ]) {
      expect(prefs.get(k), isNull, reason: k);
    }
  });

  test('a staff login also resets the count', () async {
    await wrong(4);
    final ok = await auth.login(staffPin);
    expect(ok.success, isTrue);
    expect(ok.username, 'Asha s1');
    await wrong(4);
    expect(await PinAttemptGuard.remainingLock(), isNull,
        reason: '4 + 4 with a login between never reaches 5 in a row');
  });

  test('an empty PIN is not counted', () async {
    await wrong(4);
    final r = await auth.login('   ');
    expect(r.errorMessage, 'PIN is required');
    expect(await PinAttemptGuard.remainingLock(), isNull);
  });

  test('an inactive staff PIN is still a wrong PIN', () async {
    await wrong(4);
    final r = await auth.login('5555');
    expect(r.success, isFalse);
    expect(r.retryAfter, const Duration(seconds: 30));
  });
}
