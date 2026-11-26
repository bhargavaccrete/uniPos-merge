import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/data/models/common/business_details.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';
import 'package:billberrylite/models/payment_method.dart' as pm;
import 'package:billberrylite/models/tax_details.dart';

import '../helpers/backup_box_registry.dart';

/// SB-1e E2: a restore on a fresh install (onboarding) that fails after the
/// settings step rolls back to the fresh state and is verified: settings the
/// device never had are emptied again, and the retail store-name/address
/// preferences the failed restore synced are removed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_sb1e_fresh_');
    await initHiveForBackupTest(tempDir);
  });

  tearDownAll(() async {
    UnifiedBackupService.failWritingKeyForTesting = null;
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// A retail backup carrying store details and payment methods.
  Map<String, dynamic> retailBackup() => {
        'version': '2.0.0',
        'exportDate': '2026-10-29T10:00:00.000',
        'appMode': 'retail',
        'data': <String, dynamic>{
          'appConfig': [
            {'businessMode': 'retail', 'isSetupComplete': true},
          ],
          'restaurantSessions': [
            RestaurantSessionModel(
              sessionId: 'sess-backup',
              startTime: DateTime(2026, 10, 28, 9),
              openingCash: 1000,
            ).toMap(),
          ],
          'businessDetails': [
            BusinessDetails(
              storeName: 'Berry Fashion',
              ownerName: 'A. Owner',
              address: '12 Market Road',
              city: 'Pune',
            ).toMap(),
          ],
          'paymentMethods': [
            pm.PaymentMethod(
              id: 'pm-upi',
              name: 'UPI',
              value: 'upi',
              iconName: 'qr',
            ).toMap(),
          ],
        },
      };

  test('a failure after the settings step rolls back to the fresh state',
      () async {
    expect(AppConfig.isBusinessModeSet, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('store_name'), isNull);

    // paymentMethods is written after businessDetails and the retail
    // store-info sync, so both already hold the backup's values.
    UnifiedBackupService.failWritingKeyForTesting = 'paymentMethods';

    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(retailBackup()),
      throwsA(isA<RestoreFailedException>()
          .having((e) => e.rolledBack, 'rolledBack', isTrue)),
    );

    expect(
        Hive.box<BusinessDetails>(HiveBoxNames.businessDetailsBox).isEmpty,
        isTrue,
        reason: 'the device had no business details before');
    expect(Hive.box<TaxDetails>(HiveBoxNames.taxBox).isEmpty, isTrue);
    expect(
        Hive.box<pm.PaymentMethod>(HiveBoxNames.paymentMethods)
            .values
            .any((m) => m.id == 'pm-upi'),
        isFalse);
    expect(
        Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions)
            .isEmpty,
        isTrue);
    final after = await SharedPreferences.getInstance();
    await after.reload();
    for (final key in ['store_name', 'store_owner_name', 'store_address', 'store_city']) {
      expect(after.getString(key), isNull,
          reason: '$key synced from the backup is removed again');
    }
    expect(AppConfig.isBusinessModeSet, isFalse,
        reason: 'still a fresh install');
  });
}
