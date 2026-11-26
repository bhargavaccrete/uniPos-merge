import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/core/init/mode_services.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/data/repositories/business_type_repository.dart';
import 'package:billberrylite/data/repositories/tax_details_repository.dart';
import 'package:billberrylite/stores/setup_wizard_store.dart';

import 'backup_box_registry.dart';

/// WF-6: a fresh install (no mode at start) finishes the real setup wizard;
/// the mode's services must start before the wizard navigates on.
void wizardCompletionSuite({required String mode}) {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  final ran = <String>[];

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('wizard_completion_$mode');
    FlutterSecureStorage.setMockInitialValues({});
    await initHiveForBackupTest(dir); // fresh install: mode still "none"
    await HiveInit.openCommonBoxes();
    await setupServiceLocator();
    ModeServices.resetForTesting();
    ModeServices.steps = ModeStartupSteps(
      loadRestaurantSettings: () async => ran.add('restaurantSettings'),
      initRestaurantLifecycle: () => ran.add('lifecycle'),
      startLanServer: () => ran.add('lanServer'),
      loadRetailSettings: () async => ran.add('retailSettings'),
      loadRetailSession: () async => ran.add('retailSession'),
      validateRestoredShift: () async => ran.add('validateShift'),
      initRetailLifecycle: () => ran.add('retailLifecycle'),
      startLocalNotifications: () async => ran.add('localNotifications'),
      startPushNotifications: () async => ran.add('push'),
    );
  });

  tearDownAll(() async {
    ModeServices.resetForTesting();
    await Hive.close();
    await locator.reset();
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {/* Windows handle release */}
  });

  test('$mode: finishing the wizard starts the mode services once, and only '
      'that mode\'s', () async {
    // Startup ran with no mode set: nothing started.
    await ModeServices.start();
    expect(ran, isEmpty);

    final store = SetupWizardStore(
      businessTypeRepo: BusinessTypeRepository(),
      businessDetailsRepo: BusinessDetailsRepository(),
      taxDetailsRepo: TaxDetailsRepository(),
    );
    await store.selectBusinessType(
        mode, mode == 'retail' ? 'Retail' : 'Restaurant');
    store.storeName = 'Berry Store';
    store.ownerName = 'A. Owner';
    store.phone = '9876543210';
    if (mode == 'retail') {
      store.selectRetailStoreType('garment');
    } else {
      store.selectRestaurantStoreType('cafe');
    }

    expect(ran, isEmpty, reason: 'nothing starts mid-wizard');
    await store.completeSetup();

    expect(AppConfig.isSetupComplete, isTrue);
    expect(ModeServices.startedFor?.name, mode);
    expect(
      ran,
      mode == 'retail'
          ? ['retailSettings', 'retailSession', 'validateShift', 'retailLifecycle', 'localNotifications', 'push']
          : [
              'restaurantSettings',
              'lifecycle',
              'lanServer',
              'localNotifications',
              'push',
            ],
    );

    // Anything that calls it again (e.g. a later startup path) adds nothing.
    await ModeServices.start();
    expect(ran, hasLength(mode == 'retail' ? 6 : 5));
  });
}
