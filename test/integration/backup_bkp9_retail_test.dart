import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/common/business_details.dart';
import 'package:billberrylite/data/models/common/staffModel_310.dart';
import 'package:billberrylite/data/models/common/taxmodel_314.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/billing_tab_model_173.dart';
import 'package:billberrylite/data/models/retail/hive_model/hold_sale_item_model_210.dart';
import 'package:billberrylite/data/models/retail/hive_model/hold_sale_model_209.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/presentation/screens/common/backup/restore_skipped_notice.dart';

import '../helpers/backup_box_registry.dart';
import '../helpers/backup_restore_fixtures.dart';

/// The approved BKP-9 classification for Retail, written out here so that
/// dropping a section from the service's set fails.
const retailCritical = [
  'cashMovements',
  'paymentEntries',
  'creditPayments',
  'eodReports',
  'expenses',
  'restaurantSessions',
  'dayManagement',
  'shifts',
  'appCounters',
  'supplierLedger',
  'stockMovements',
  'kitAssemblies',
  'purchaseOrders',
  'purchaseOrderItems',
  'grns',
  'grnItems',
  'holdSales',
  'holdSaleItems',
  'taxes',
  'staffBox',
  'billingTabs',
];

/// Sections whose restore step was already strict before BKP-9.
const retailAlreadyStrict = [
  'products',
  'variants',
  'cartItems',
  'sales',
  'saleItems',
  'customers',
  'suppliers',
  'purchaseReturns',
  'purchaseReturnItems',
  'supplierClaims',
  'supplierClaimItems',
  'inventoryLosses',
  'stockTakes',
  'stockTakeItems',
];

const retailNonCritical = [
  'categories',
  'expenseCategories',
  'attributes',
  'attributeValues',
  'productAttributes',
  'bundles',
  'printers',
  'restaurantAttendance',
];

/// BKP-9 (Retail): an unreadable money, stock, ledger, staff or open-bill
/// section refuses the whole restore before anything is written; a
/// non-critical one is skipped and the result says "Import completed with
/// warnings".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Map<String, dynamic> backup;

  Box<RestaurantSessionModel> sessions() =>
      Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions);
  Box<StaffModel> staff() => Hive.box<StaffModel>(HiveBoxNames.staff);
  Box<Tax> taxes() => Hive.box<Tax>(HiveBoxNames.tax);
  Box<HoldSaleModel> holdSales() =>
      Hive.box<HoldSaleModel>(HiveBoxNames.holdSales);
  Box<HoldSaleItemModel> holdSaleItems() =>
      Hive.box<HoldSaleItemModel>(HiveBoxNames.holdSaleItems);
  Box<BillingTabModel> tabs() =>
      Hive.box<BillingTabModel>(HiveBoxNames.billingTabs);

  Map<String, dynamic> copy(Map<String, dynamic> m) =>
      jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

  Map<String, dynamic> withUnreadable(Iterable<String> keys) {
    final bad = copy(backup);
    for (final k in keys) {
      (bad['data'] as Map<String, dynamic>)[k] = ['not a record'];
    }
    return bad;
  }

  StaffModel staffer(String id, String pin) => StaffModel(
        id: id,
        userName: id,
        firstName: 'Old',
        lastName: 'Admin',
        isCashier: 'Admin',
        mobileNo: '9000000000',
        emailId: '$id@example.com',
        pinNo: pin,
        createdAt: DateTime(2026, 11, 1),
      );

  HoldSaleModel heldBill(String id) => HoldSaleModel(
        holdSaleId: id,
        totalItems: 2,
        subtotal: 240,
        createdAt: '2026-11-14T10:00:00.000',
        updatedAt: '2026-11-14T10:00:00.000',
      );

  HoldSaleItemModel heldLine(String id, String billId) => HoldSaleItemModel(
        holdSaleItemId: id,
        holdSaleId: billId,
        variantId: 'v1',
        productId: 'p1',
        productName: 'Tea',
        price: 120,
        qty: 2,
        total: 240,
        createdAt: '2026-11-14T10:00:00.000',
      );

  BillingTabModel tab(String id) => BillingTabModel(
        id: id,
        name: 'Tab $id',
        items: const [],
        createdAt: DateTime(2026, 11, 14, 11),
        updatedAt: DateTime(2026, 11, 14, 11),
      );

  /// This device after the backup was taken: different from it everywhere
  /// the tests look, so any write the restore makes would show.
  Future<void> seedDevice() async {
    await sessions().clear();
    await sessions().put(
        'sess-device',
        RestaurantSessionModel(
            sessionId: 'sess-device',
            startTime: DateTime(2026, 11, 14, 18),
            openingCash: 300));
    await staff().clear();
    await staff().put('st-device', staffer('st-device', '1111'));
    await taxes().clear();
    await taxes().put(
        'tax-device', Tax(id: 'tax-device', taxname: 'GST 12', taxperecentage: 12));
    await holdSales().clear();
    await holdSales().put('hold-device', heldBill('hold-device'));
    await holdSaleItems().clear();
    await holdSaleItems()
        .put('hl-device', heldLine('hl-device', 'hold-device'));
    await tabs().clear();
    await tabs().put('tab-device', tab('tab-device'));
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_bkp9_retail_');
    await openBoxesFor('retail', tempDir);
    await AppConfig.box.put('isSetupComplete', true);
    if (!locator.isRegistered<ProductStore>()) {
      locator.registerLazySingleton<ProductStore>(() => ProductStore());
    }

    await Hive.box<BusinessDetails>(HiveBoxNames.businessDetailsBox)
        .add(BusinessDetails(storeName: 'Corner Shop', phone: '9111111111'));
    await sessions().put(
        'sess-backup',
        RestaurantSessionModel(
            sessionId: 'sess-backup',
            startTime: DateTime(2026, 11, 13, 9),
            openingCash: 1000));
    await staff().put('st-backup', staffer('st-backup', '2222'));
    await taxes().put(
        'tax-backup', Tax(id: 'tax-backup', taxname: 'GST 5', taxperecentage: 5));
    await holdSales().put('hold-backup', heldBill('hold-backup'));
    await holdSaleItems()
        .put('hl-backup', heldLine('hl-backup', 'hold-backup'));
    await tabs().put('tab-backup', tab('tab-backup'));
    backup = copy(await UnifiedBackupService.collectAllDataForTesting());
  });

  setUp(() async {
    UnifiedBackupService.failWritingKeyForTesting = null;
    UnifiedBackupService.failRollbackWritingKeyForTesting = null;
    UnifiedBackupService.failPostRestoreStepForTesting = null;
    await seedDevice();
  });

  tearDownAll(() async {
    UnifiedBackupService.failWritingKeyForTesting = null;
    UnifiedBackupService.failPostRestoreStepForTesting = null;
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> restore(Map<String, dynamic> b) =>
      UnifiedBackupService.restoreDecodedBackupForTesting(b);

  Matcher refusedFor(List<String> sections) => throwsA(
        isA<RestoreRefusedException>()
            .having((e) => e.sections, 'sections', sections)
            .having((e) => e.message, 'message',
                allOf(contains(sections.join(', ')),
                    contains('Nothing on this device was changed'))),
      );

  ({String title, String message, bool hasWarnings}) lastResult() =>
      restoreResultContent(
        skipped: UnifiedBackupService.lastRestoreSkippedSections,
        postRestoreWarnings:
            UnifiedBackupService.lastRestorePostRestoreWarnings,
        web: false,
      );

  // ==========================================================================
  test('the service classifies exactly the approved Retail sections', () {
    expect(UnifiedBackupService.retailCriticalSections,
        unorderedEquals(retailCritical));
    final all = {...retailCritical, ...retailAlreadyStrict, ...retailNonCritical};
    expect(all, unorderedEquals(retailBackedUp.values),
        reason: 'every restored section is classified exactly once');
    expect(all.length,
        retailCritical.length +
            retailAlreadyStrict.length +
            retailNonCritical.length);
  });

  group('an unreadable critical section refuses the restore, device unchanged',
      () {
    for (final key in retailCritical) {
      test(key, () async {
        final before = await deviceState(tempDir);
        await expectLater(restore(withUnreadable([key])), refusedFor([key]));
        expect(await deviceState(tempDir), before);
        expect(UnifiedBackupService.lastRestoreSkippedSections, isEmpty);
      });
    }
  });

  group('an unreadable already-strict section still refuses, device unchanged',
      () {
    for (final key in retailAlreadyStrict) {
      test(key, () async {
        final before = await deviceState(tempDir);
        await expectLater(
          restore(withUnreadable([key])),
          throwsA(predicate((e) =>
              e.toString().contains('This backup file is damaged') &&
              e.toString().contains('Nothing on this device was changed'))),
        );
        expect(await deviceState(tempDir), before);
      });
    }
  });

  test('staffBox: the old staff and PINs stay exactly as they were',
      () async {
    await expectLater(
        restore(withUnreadable(['staffBox'])), refusedFor(['staffBox']));
    expect(staff().keys, ['st-device']);
    expect(staff().get('st-device')!.pinNo, '1111');
    expect(sessions().keys, ['sess-device'],
        reason: 'nothing else from the backup was written');
  });

  test('taxes: the device keeps its own tax rates', () async {
    await expectLater(restore(withUnreadable(['taxes'])), refusedFor(['taxes']));
    expect(taxes().keys, ['tax-device']);
    expect(sessions().keys, ['sess-device']);
  });

  test('billingTabs: the open tabs stay as they were', () async {
    await expectLater(
        restore(withUnreadable(['billingTabs'])), refusedFor(['billingTabs']));
    expect(tabs().keys, ['tab-device']);
    expect(sessions().keys, ['sess-device']);
  });

  group('held bills: either half unreadable keeps the bill and its lines', () {
    for (final key in ['holdSales', 'holdSaleItems']) {
      test(key, () async {
        await expectLater(restore(withUnreadable([key])), refusedFor([key]));
        expect(holdSales().keys, ['hold-device']);
        expect(holdSaleItems().keys, ['hl-device']);
        expect(holdSaleItems().get('hl-device')!.holdSaleId, 'hold-device');
      });
    }
  });

  // ==========================================================================
  group('an unreadable non-critical section is skipped and reported', () {
    for (final key in retailNonCritical) {
      test(key, () async {
        await restore(withUnreadable([key]));
        expect(UnifiedBackupService.lastRestoreSkippedSections, [key]);
        expect(sessions().keys, ['sess-backup'],
            reason: 'the rest of the backup was restored');
        expect(staff().keys, ['st-backup']);
        final result = lastResult();
        expect(result.title, 'Import completed with warnings');
        expect(result.hasWarnings, isTrue);
        expect(result.message, contains(key));
        expect(result.message, isNot(contains('successfully')));
      });
    }
  });

  test('a clean restore reports nothing and says "Data imported successfully"',
      () async {
    await restore(copy(backup));
    expect(UnifiedBackupService.lastRestoreSkippedSections, isEmpty);
    expect(UnifiedBackupService.lastRestorePostRestoreWarnings, isEmpty);
    expect(lastResult().title, 'Import Completed');
    expect(lastResult().message, startsWith('Data imported successfully!'));
    expect(holdSales().keys, ['hold-backup']);
    expect(tabs().keys, ['tab-backup']);
    expect((await SharedPreferences.getInstance()).getString('store_name'),
        'Corner Shop', reason: 'the store details step ran');
  });

  test('localPrefs and secureCreds that fail to restore are warnings',
      () async {
    final b = copy(backup);
    (b['data'] as Map<String, dynamic>)
      ..['localPrefs'] = [
        {'key': 'some_ratio', 'type': 'double', 'value': 'not a number'},
      ]
      ..['secureCreds'] = ['not a map'];
    await restore(b);
    expect(UnifiedBackupService.lastRestoreSkippedSections,
        ['localPrefs', 'secureCreds']);
    expect(lastResult().title, 'Import completed with warnings');
    expect(sessions().keys, ['sess-backup']);
  });

  group('a post-restore step that fails is a warning, not success', () {
    for (final step in [
      UnifiedBackupService.postStepProductList,
      UnifiedBackupService.postStepStoreDetails,
      // The checkout journal clear is part of the restore now and rolls back
      // on failure (backup_journal_tx_retail_test.dart).
    ]) {
      test(step, () async {
        UnifiedBackupService.failPostRestoreStepForTesting = step;
        await restore(copy(backup));
        expect(UnifiedBackupService.lastRestorePostRestoreWarnings, [step]);
        expect(UnifiedBackupService.lastRestoreSkippedSections, isEmpty);
        expect(sessions().keys, ['sess-backup'],
            reason: 'the restore itself completed');
        expect(lastResult().title, 'Import completed with warnings');
        expect(lastResult().message, contains(step));
        expect(lastResult().message, isNot(contains('successfully')));
      });
    }
  });

  // ==========================================================================
  test('rollback is unchanged: a write failure with a skipped section still '
      'rolls everything back, verified', () async {
    final before = await deviceState(tempDir);
    UnifiedBackupService.failWritingKeyForTesting = 'grns';

    await expectLater(
      restore(withUnreadable(['bundles'])),
      throwsA(isA<RestoreFailedException>()
          .having((e) => e.rolledBack, 'rolledBack', isTrue)),
    );
    expect(await deviceState(tempDir), before);
    expect(staff().keys, ['st-device']);
    expect(holdSales().keys, ['hold-device']);
  });
}
