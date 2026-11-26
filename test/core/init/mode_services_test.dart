import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/init/mode_services.dart';

import '../../helpers/backup_box_registry.dart';

/// WF-6: the per-mode startup steps run in the order startup always used,
/// once per process, and not at all while no business mode is set. No backup
/// runs at startup (the daily backup is asked for by the start-of-day prompt).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late List<String> ran;

  ModeStartupSteps recording({bool localFails = false}) => ModeStartupSteps(
        loadRestaurantSettings: () async => ran.add('restaurantSettings'),
        initRestaurantLifecycle: () => ran.add('lifecycle'),
        startLanServer: () => ran.add('lanServer'),
        loadRetailSettings: () async => ran.add('retailSettings'),
        loadRetailSession: () async => ran.add('retailSession'),
        validateRestoredShift: () async => ran.add('validateShift'),
        initRetailLifecycle: () => ran.add('retailLifecycle'),
        startLocalNotifications: () async {
          ran.add('localNotifications');
          if (localFails) throw StateError('exact alarms denied');
        },
        startPushNotifications: () async => ran.add('push'),
      );

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('mode_services_');
    await initHiveForBackupTest(dir);
  });

  setUp(() {
    ran = [];
    ModeServices.resetForTesting();
    ModeServices.steps = recording();
  });

  tearDownAll(() async {
    ModeServices.resetForTesting();
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  Future<void> mode(String m) => AppConfig.box.put('businessMode', m);

  test('Restaurant: settings, lifecycle, LAN server, then notifications — in '
      'that order', () async {
    await mode('restaurant');
    await ModeServices.start();
    expect(ran, [
      'restaurantSettings',
      'lifecycle',
      'lanServer',
      'localNotifications',
      'push',
    ]);
    expect(ModeServices.startedFor, BusinessMode.restaurant);
    expect(ran.where((s) => s.startsWith('retail') || s == 'validateShift'),
        isEmpty, reason: 'WF-3 changes nothing for Restaurant');
  });

  test('Retail: settings + session (WF-3), shift check, lifecycle, then '
      'notifications — no LAN server or Restaurant steps', () async {
    await mode('retail');
    await ModeServices.start();
    expect(ran, ['retailSettings', 'retailSession', 'validateShift', 'retailLifecycle', 'localNotifications', 'push']);
    expect(ModeServices.startedFor, BusinessMode.retail);
  });

  test('Retail starts its services once, however often startup runs',
      () async {
    await mode('retail');
    await ModeServices.start();
    await ModeServices.start();
    expect(ran.where((s) => s == 'retailLifecycle'), hasLength(1));
    expect(ran, isNot(contains('lanServer')));
  });

  test('once per process: a second start adds no server or observer',
      () async {
    await mode('restaurant');
    await ModeServices.start();
    await ModeServices.start();
    await ModeServices.start();
    expect(ran.where((s) => s == 'lanServer'), hasLength(1));
    expect(ran.where((s) => s == 'lifecycle'), hasLength(1));
    expect(ran, hasLength(5));
  });

  test('no business mode yet (fresh install): nothing starts; once the wizard '
      'sets one, the next start runs everything', () async {
    await mode('none');
    await ModeServices.start();
    expect(ran, isEmpty);
    expect(ModeServices.startedFor, isNull);

    await mode('restaurant');
    await ModeServices.start();
    expect(ran, contains('lanServer'));
  });

  test('AND-24: startup never waits for push setup (offline / slow Firebase)',
      () async {
    final never = Completer<void>();
    ModeServices.steps = ModeStartupSteps(
      loadRestaurantSettings: () async => ran.add('restaurantSettings'),
      initRestaurantLifecycle: () => ran.add('lifecycle'),
      startLanServer: () => ran.add('lanServer'),
      startLocalNotifications: () async => ran.add('localNotifications'),
      startPushNotifications: () {
        ran.add('push');
        return never.future;
      },
    );
    await mode('restaurant');
    await ModeServices.start().timeout(const Duration(seconds: 2));
    expect(ran, contains('push'), reason: 'started');
  });

  test('AND-24: a push setup failure never reaches startup', () async {
    ModeServices.steps = ModeStartupSteps(
      loadRetailSettings: () async {},
      loadRetailSession: () async {},
      validateRestoredShift: () async {},
      initRetailLifecycle: () {},
      startLocalNotifications: () async {},
      startPushNotifications: () async => throw StateError('no Firebase'),
    );
    await mode('retail');
    await ModeServices.start();
    await Future<void>.delayed(Duration.zero);
    expect(ModeServices.startedFor, BusinessMode.retail);
  });

  test('a notification failure never blocks the rest', () async {
    ModeServices.steps = recording(localFails: true);
    await mode('retail');
    await ModeServices.start();
    expect(ran, ['retailSettings', 'retailSession', 'validateShift', 'retailLifecycle', 'localNotifications', 'push']);
  });
}
