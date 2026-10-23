import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/models/common/attendance_model.dart';
import 'package:billberrylite/data/models/common/business_details.dart';
import 'package:billberrylite/data/models/common/business_type.dart';
import 'package:billberrylite/data/models/common/shift_model.dart';
import 'package:billberrylite/data/models/restaurant/db/saved_printer_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';
import 'package:billberrylite/models/legacy/legacy_tax_rate_item.dart';
import 'package:billberrylite/models/payment_method.dart' as pm;
import 'package:billberrylite/models/tax_details.dart';

/// D-A0: restaurant backups exported and restored stock movements only in the
/// retail branch, so a restored restaurant lost its whole stock audit trail.
/// Runs the real UnifiedBackupService export → JSON → restore path.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('restaurant_backup_mov_');
    Hive.init(tempDir.path);

    void reg<T>(TypeAdapter<T> a) {
      if (!Hive.isAdapterRegistered(a.typeId)) Hive.registerAdapter(a);
    }

    reg(TaxDetailsAdapter());
    reg(BusinessTypeAdapter());
    reg(BusinessDetailsAdapter());
    reg(LegacyTaxRateItemAdapter());
    reg(pm.PaymentMethodAdapter());
    reg(SavedPrinterModelAdapter());
    reg(AppNotificationModelAdapter());
    reg(ShiftModelAdapter());
    reg(AttendanceModelAdapter());
    await HiveInit.registerRestaurantAdapters();
    await HiveInit.registerRetailAdapters();

    await AppConfig.init();
    await HiveInit.openCommonBoxes();
    await HiveInit.openRestaurantBoxes();
    await HiveInit.openRetailBoxes();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Box<StockMovementModel> box() =>
      Hive.box<StockMovementModel>(HiveBoxNames.restaurantStockMovements);

  StockMovementModel movement(String id, {String reason = 'Sale'}) =>
      StockMovementModel(
        id: id,
        timestamp: DateTime(2026, 10, 22, 9, 30),
        itemId: 'cheese',
        variantId: 'v-large',
        itemName: 'Cheese (Large)',
        type: 'out',
        quantity: 0.25,
        balanceAfter: 4.75,
        reason: reason,
        note: 'n1',
        unit: 'kg',
        staffName: 'Asha',
        sessionId: 'sess-7',
        unitCost: 312.5,
      );

  Future<void> seedMovements() async {
    await box().clear();
    await box().put('m1', movement('m1'));
    await box().put('m2', movement('m2', reason: 'Sale (recipe: Burger)'));
    await box().put('m3', movement('m3', reason: 'Production (Sauce)'));
  }

  /// Export, then the JSON round trip the backup file goes through.
  Future<Map<String, dynamic>> exportedData() async {
    final exported = await UnifiedBackupService.collectAllDataForTesting();
    final decoded = jsonDecode(jsonEncode(exported)) as Map<String, dynamic>;
    return decoded['data'] as Map<String, dynamic>;
  }

  Map<String, dynamic> snapshot() => {
        for (final m in box().values) m.id: m.toMap(),
      };

  group('restaurant mode', () {
    setUp(() => AppConfig.box.put('businessMode', 'restaurant'));

    test('restaurant export includes every stock movement', () async {
      await seedMovements();

      final data = await exportedData();

      expect(data.containsKey('stockMovements'), isTrue);
      final ids = (data['stockMovements'] as List)
          .map((m) => (m as Map)['id'])
          .toList();
      expect(ids, unorderedEquals(['m1', 'm2', 'm3']));
    });

    test('restaurant restore brings back every field of every movement',
        () async {
      await seedMovements();
      final before = snapshot();
      final data = await exportedData();

      await box().clear();
      await UnifiedBackupService.restoreRestaurantDataForTesting(data);

      expect(snapshot(), before);
      final m = box().get('m2')!;
      expect(m.unitCost, 312.5);
      expect(m.variantId, 'v-large');
      expect(m.sessionId, 'sess-7');
      expect(m.reason, 'Sale (recipe: Burger)');
    });

    test('the pending stock journal is never exported, and a restore clears '
        'it (its entries refer to orders and stock the restore replaced)',
        () async {
      final journal = Hive.box(HiveBoxNames.restaurantStockJournal);
      await journal.put('settle:x', {'id': 'settle:x', 'units': []});

      final data = await exportedData();
      expect(data.keys.where((k) => k.toLowerCase().contains('journal')),
          isEmpty);

      await UnifiedBackupService.restoreRestaurantDataForTesting(data);
      expect(journal.isEmpty, isTrue);
    });

    test('restoring a backup without stockMovements leaves the box untouched',
        () async {
      await seedMovements();
      final before = snapshot();
      final data = await exportedData()
        ..remove('stockMovements');

      await UnifiedBackupService.restoreRestaurantDataForTesting(data);

      expect(snapshot(), before);
    });
  });

  group('retail mode (shared box regression)', () {
    setUp(() => AppConfig.box.put('businessMode', 'retail'));

    test('retail export and restore of stockMovements is unchanged', () async {
      await seedMovements();
      final before = snapshot();
      final data = await exportedData();
      expect((data['stockMovements'] as List).length, 3);

      await box().clear();
      await UnifiedBackupService.restoreRetailDataForTesting(data);

      expect(snapshot(), before);
    });
  });
}
