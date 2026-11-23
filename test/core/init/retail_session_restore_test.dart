import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/core/init/mode_services.dart';
import 'package:billberrylite/data/models/common/shift_model.dart';
import 'package:billberrylite/data/repositories/common/shift_repository.dart';
import 'package:billberrylite/domain/services/retail/auth_service.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';

import '../../helpers/backup_box_registry.dart';

/// WF-3: a Retail restart restores the open shift and the auto-logout
/// timeout before the first sale, clears a shift ID whose shift is closed or
/// gone, and leaves Retail's automatic login exactly as it was.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  // The keys RestaurantSession persists (the previous process wrote them).
  const shiftKey = 'restaurant_current_shift_id';
  const timeoutKey = 'restaurant_inactivity_timeout_minutes';

  Box<ShiftModel> shifts() => Hive.box<ShiftModel>(HiveBoxNames.shift);

  ModeStartupSteps realSessionSteps() => ModeStartupSteps(
        loadRetailSettings: () async {},
        startLocalNotifications: () async {},
        startPushNotifications: () async {},
      );

  /// A new process: nothing in memory, only what the last one saved.
  Future<void> restart({String? savedShiftId, int? savedTimeout}) async {
    await RestaurantSession.clearShiftSession();
    RestaurantSession.timeoutMinutesNotifier.value = 15;
    final prefs = await SharedPreferences.getInstance();
    if (savedShiftId != null) await prefs.setString(shiftKey, savedShiftId);
    if (savedTimeout != null) await prefs.setInt(timeoutKey, savedTimeout);
    ModeServices.resetForTesting();
    ModeServices.steps = realSessionSteps();
    await ModeServices.start();
  }

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('retail_session_restore_');
    await initHiveForBackupTest(dir);
    await AppConfig.box.put('businessMode', 'retail');
    await HiveInit.openCommonBoxes();
    locator.registerLazySingleton<ShiftRepository>(() => ShiftRepository());
  });

  setUp(() async {
    await shifts().clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(shiftKey);
    await prefs.remove(timeoutKey);
  });

  tearDownAll(() async {
    ModeServices.resetForTesting();
    await locator.reset();
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  test('the open shift is restored at startup, before any sale', () async {
    await shifts().put(
        's1',
        ShiftModel(
            id: 's1',
            staffId: 'admin',
            staffName: 'Admin',
            startTime: DateTime(2026, 11, 16, 9)));
    await restart(savedShiftId: 's1');
    expect(RestaurantSession.currentShiftId, 's1',
        reason: 'what checkout, return and exchange stamp on the document');
  });

  test('the configured auto-logout timeout survives a restart', () async {
    await RestaurantSession.setTimeoutMinutes(5);
    await restart();
    expect(RestaurantSession.timeoutMinutes, 5);
  });

  test('a restored ID whose shift is closed is cleared (memory and storage)',
      () async {
    await shifts().put(
        's2',
        ShiftModel(
            id: 's2',
            staffId: 'admin',
            staffName: 'Admin',
            startTime: DateTime(2026, 11, 15, 9),
            endTime: DateTime(2026, 11, 15, 18),
            status: 'closed'));
    await restart(savedShiftId: 's2');
    expect(RestaurantSession.currentShiftId, isNull);
    expect((await SharedPreferences.getInstance()).getString(shiftKey), isNull);
  });

  test('a restored ID with no shift at all is cleared', () async {
    await restart(savedShiftId: 'ghost');
    expect(RestaurantSession.currentShiftId, isNull);
  });

  test('Retail automatic login after a restart is unchanged (no PIN)',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('admin_session', true);
    await prefs.setString('admin_username', 'Admin');
    await restart();
    // load() starts every cold start logged out (Restaurant's rule)…
    expect(RestaurantSession.isLoggedIn, isFalse);
    // …and the splash's authService.initialize() logs Retail back in, as
    // before WF-3.
    expect(await AuthService().initialize(), isTrue);
    expect(RestaurantSession.isLoggedIn, isTrue);
    expect(RestaurantSession.isAdmin, isTrue);
  });

  test('lifecycle handling is registered once, even if startup runs again',
      () async {
    var lifecycle = 0;
    ModeServices.resetForTesting();
    ModeServices.steps = ModeStartupSteps(
      loadRetailSettings: () async {},
      loadRetailSession: () async {},
      validateRestoredShift: () async {},
      initRetailLifecycle: () => lifecycle++,
      startLocalNotifications: () async {},
      startPushNotifications: () async {},
    );
    await ModeServices.start();
    await ModeServices.start();
    expect(lifecycle, 1);
  });
}
