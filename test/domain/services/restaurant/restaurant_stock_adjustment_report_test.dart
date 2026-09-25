import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/core/plan/entitlements.dart';

import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/repositories/restaurant/stock_movement_repository.dart';

import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/restaurant/restaurant_purchase_report_service.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';

/// **WHAT COUNTS AS A MANUAL STOCK ADJUSTMENT.**
///
/// `StockMovementModel.reason` is free text, and the report has to separate
/// human decisions from side effects. It does that with a **deny-list**: a
/// movement is manual unless code wrote it.
///
/// The alternative — listing the dropdown's own reasons — silently drops the
/// stock take's caller-supplied `shortageReason` and every reason added to the
/// dialog later. An audit report going quietly incomplete is the worst way it
/// can fail, so the closed, code-owned vocabulary is the one enumerated.
///
/// The trap this file exists for: **`'Restock / Purchase'` is a manual reason
/// and must not be swallowed by the `'Purchase ('` prefix.** Drop the trailing
/// bracket and every restock silently vanishes from the audit trail.
void main() {
  StockMovementModel movement(String reason, {String type = 'out'}) =>
      StockMovementModel(
        id: 'M-$reason',
        timestamp: DateTime(2026, 3, 10),
        itemId: 'ITEM-1',
        itemName: 'Cheese',
        type: type,
        quantity: 2,
        balanceAfter: 8,
        reason: reason,
        unit: 'kg',
        staffName: 'Raju',
      );

  group('reason vocabulary (pure)', () {
    // Every string any code path in the app writes.
    const systemReasons = [
      'Opening stock',
      'Sale',
      'Sale (recipe: Burger)',
      'Production (Tomato Sauce)',
      'Production batch',
      'Void / Refund return',
      'Void / Refund return (recipe: Burger)',
      'Purchase (PO-20260101-001)',
    ];

    // The two manage-inventory dropdowns, in full.
    const manualReasons = [
      'Restock / Purchase',
      'Customer return',
      'Stock correction',
      'Transfer in',
      'Wastage / Spoilage',
      'Theft / Loss',
      'Transfer out',
      'Sample / Complimentary',
      'Other',
    ];

    for (final reason in systemReasons) {
      test('system reason is excluded: "$reason"', () {
        expect(
          RestaurantPurchaseReportService.isManualAdjustment(movement(reason)),
          isFalse,
        );
      });
    }

    for (final reason in manualReasons) {
      test('manual reason is included: "$reason"', () {
        expect(
          RestaurantPurchaseReportService.isManualAdjustment(movement(reason)),
          isTrue,
        );
      });
    }

    test('THE TRAP: "Restock / Purchase" survives the "Purchase (" prefix', () {
      expect(
        RestaurantPurchaseReportService.isManualAdjustment(
          movement('Restock / Purchase'),
        ),
        isTrue,
        reason: 'the trailing bracket in the prefix is load-bearing',
      );
      expect(
        RestaurantPurchaseReportService.isManualAdjustment(
          movement('Purchase (PO-1)'),
        ),
        isFalse,
      );
    });

    test("a stock take's own shortage reason is included", () {
      // commit() passes whatever the user picked straight through, including
      // values that are not in either dropdown.
      expect(
        RestaurantPurchaseReportService.isManualAdjustment(
          movement('Spoiled during the count'),
        ),
        isTrue,
        reason: 'an allow-list would have dropped this',
      );
    });
  });

  group('the report', () {
    late Directory tempDir;
    late RestaurantPurchaseReportService service;

    setUp(() async {
      await locator.reset();
      Entitlements.instance.clear();

      tempDir = await Directory.systemTemp.createTemp('restaurant_adj_');
      Hive.init(tempDir.path);
      await HiveInit.registerRestaurantAdapters();

      await AppConfig.init();
      await AppConfig.box.put('businessMode', 'restaurant');

      await Hive.openBox<StockMovementModel>(
          HiveBoxNames.restaurantStockMovements);

      locator.registerLazySingleton<LicenseStore>(
          () => LicenseStore(LicenseApiService()));

      service = RestaurantPurchaseReportService();
    });

    tearDown(() async {
      Entitlements.instance.clear();
      await locator.reset();
      await Hive.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    Future<void> save(
      String id,
      String reason, {
      required String type,
      required double qty,
      required double balanceAfter,
      DateTime? at,
    }) async {
      await StockMovementRepository().saveMovement(
        StockMovementModel(
          id: id,
          timestamp: at ?? DateTime(2026, 3, 10),
          itemId: 'ITEM-1',
          itemName: 'Cheese',
          type: type,
          quantity: qty,
          balanceAfter: balanceAfter,
          reason: reason,
          unit: 'kg',
          staffName: 'Raju',
        ),
      );
    }

    test('sales and receipts never appear, corrections do', () async {
      await save('a', 'Sale', type: 'out', qty: 1, balanceAfter: 9);
      await save('b', 'Purchase (PO-1)', type: 'in', qty: 5, balanceAfter: 14);
      await save('c', 'Wastage / Spoilage',
          type: 'out', qty: 2, balanceAfter: 12);
      await save('d', 'Restock / Purchase',
          type: 'in', qty: 3, balanceAfter: 15);

      final rows = await service.getStockAdjustmentReport();

      expect(rows.map((r) => r['id']), containsAll(['c', 'd']));
      expect(rows.map((r) => r['id']), isNot(contains('a')));
      expect(rows.map((r) => r['id']), isNot(contains('b')));
      expect(rows, hasLength(2));
    });

    test('balanceBefore is derived so Before + Change = After', () async {
      // 12 on the shelf, 2 removed, 10 left.
      await save('out', 'Wastage / Spoilage',
          type: 'out', qty: 2, balanceAfter: 10);
      await save('in', 'Customer return', type: 'in', qty: 3, balanceAfter: 13);

      final rows = await service.getStockAdjustmentReport();
      final removal = rows.firstWhere((r) => r['id'] == 'out');
      final addition = rows.firstWhere((r) => r['id'] == 'in');

      expect(removal['balanceBefore'], 12.0);
      expect(removal['signedQuantity'], -2.0);
      expect(
        (removal['balanceBefore'] as double) +
            (removal['signedQuantity'] as double),
        removal['balanceAfter'],
      );

      expect(addition['balanceBefore'], 10.0);
      expect(addition['signedQuantity'], 3.0);
    });

    test('loss-bearing reasons are flagged', () async {
      await save('loss', 'Theft / Loss', type: 'out', qty: 1, balanceAfter: 9);
      await save('fix', 'Stock correction',
          type: 'out', qty: 1, balanceAfter: 8);

      final rows = await service.getStockAdjustmentReport();
      expect(rows.firstWhere((r) => r['id'] == 'loss')['isLossReason'], isTrue);
      expect(rows.firstWhere((r) => r['id'] == 'fix')['isLossReason'], isFalse);
    });

    test('respects the window and sorts newest first', () async {
      await save('jan', 'Stock correction',
          type: 'out', qty: 1, balanceAfter: 9, at: DateTime(2026, 1, 5));
      await save('mar', 'Stock correction',
          type: 'out', qty: 1, balanceAfter: 8, at: DateTime(2026, 3, 5));

      final all = await service.getStockAdjustmentReport();
      expect(all.first['id'], 'mar');

      final march = await service.getStockAdjustmentReport(
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 4, 1),
      );
      expect(march, hasLength(1));
      expect(march.single['id'], 'mar');
    });
  });
}
