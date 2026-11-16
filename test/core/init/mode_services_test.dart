import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/init/mode_services.dart';

import '../../helpers/backup_box_registry.dart';

/// WF-6: the per-mode startup steps run in the order startup always used,
/// once per process, and not at all while no business mode is set.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late List<String> ran;

  ModeStartupSteps recording({bool localFails = false}) => ModeStartupSteps(
        loadRestaurantSettings: () async => ran.add('restaurantSettings'),
        initRestaurantLifecycle: () => ran.add('lifecycle'),
        startAutoBackup: () => ran.add('autoBackup'),
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

  test('Restaurant: settings, lifecycle, auto-backup, LAN server, then '
      'notifications — in that order', () async {
    await mode('restaurant');
    await ModeServices.start();
    expect(ran, [
      'restaurantSettings',
      'lifecycle',
      'autoBackup',
      'lanServer',
      'localNotifications',
      'push',
    ]);
    expect(ModeServices.startedFor, BusinessMode.restaurant);
    expect(ran.where((s) => s.startsWith('retail') || s == 'validateShift'),
        isEmpty, reason: 'WF-3 changes nothing for Restaurant');
  });

  test('Retail: settings + session (WF-3), shift check, lifecycle, '
      'auto-backup (M6a), then notifications — no LAN server or Restaurant '
      'steps', () async {
    await mode('retail');
    await ModeServices.start();
    expect(ran, ['retailSettings', 'retailSession', 'validateShift', 'retailLifecycle', 'autoBackup', 'localNotifications', 'push']);
    expect(ModeServices.startedFor, BusinessMode.retail);
  });

  test('Retail starts automatic backup once, however often startup runs',
      () async {
    await mode('retail');
    await ModeServices.start();
    await ModeServices.start();
    expect(ran.where((s) => s == 'autoBackup'), hasLength(1));
    expect(ran, isNot(contains('lanServer')));
  });

  test('once per process: a second start adds no timer, server or observer',
      () async {
    await mode('restaurant');
    await ModeServices.start();
    await ModeServices.start();
    await ModeServices.start();
    expect(ran.where((s) => s == 'autoBackup'), hasLength(1));
    expect(ran.where((s) => s == 'lanServer'), hasLength(1));
    expect(ran.where((s) => s == 'lifecycle'), hasLength(1));
    expect(ran, hasLength(6));
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

  test('a notification failure never blocks the rest', () async {
    ModeServices.steps = recording(localFails: true);
    await mode('retail');
    await ModeServices.start();
    expect(ran, ['retailSettings', 'retailSession', 'validateShift', 'retailLifecycle', 'autoBackup', 'localNotifications', 'push']);
  });
}
