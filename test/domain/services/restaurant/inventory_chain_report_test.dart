import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/repositories/restaurant/stock_movement_repository.dart';
import 'package:billberrylite/domain/services/restaurant/stock_adjust_service.dart';
import 'package:billberrylite/domain/services/restaurant/recipe_report_service.dart';

/// Unit tests for the new restaurant purchase-order aftermarket chain's
/// business logic (this session): `StockAdjustService.isLossReason` (pure
/// function) and `RecipeReportService.ingredientUsageReport` /
/// `wastageReport`'s preference for `StockMovementModel.unitCost` (historical
/// price) over the item's live cost.
///
/// `StockAdjustService.recordLoss` / `.adjustTo` / `.addStock` etc. all call
/// `itemStore` (a GetIt/MobX-backed store) and are not unit-tested here —
/// same judgment call as `inventory_and_cart_test.dart`, which documents that
/// itemStore/variantStore-dependent code needs a full integration harness.
///
/// `ingredientUsageReport`/`wastageReport` only touch `itemStore` on the
/// *fallback* path (`m.unitCost == null`). By constructing every movement in
/// these tests with `unitCost` set, that branch is never taken, so the
/// service locator never needs to be initialised — letting us test the
/// historical-pricing behaviour as a focused Hive-only test.
void main() {
  group('StockAdjustService.isLossReason', () {
    test('true for each of the 3 declared loss reasons', () {
      expect(StockAdjustService.isLossReason('Wastage / Spoilage'), isTrue);
      expect(StockAdjustService.isLossReason('Theft / Loss'), isTrue);
      expect(
          StockAdjustService.isLossReason('Sample / Complimentary'), isTrue);
    });

    test('false for non-loss reasons', () {
      expect(StockAdjustService.isLossReason('Stock correction'), isFalse);
      expect(StockAdjustService.isLossReason('Opening stock'), isFalse);
      expect(StockAdjustService.isLossReason('Internal transfer'), isFalse);
      expect(StockAdjustService.isLossReason(''), isFalse);
    });

    test('is case-sensitive / exact-match (no partial match)', () {
      expect(StockAdjustService.isLossReason('wastage / spoilage'), isFalse);
      expect(StockAdjustService.isLossReason('Wastage'), isFalse);
    });

    test('lossReasons set exposes exactly the 3 documented reasons', () {
      expect(
        StockAdjustService.lossReasons,
        equals({
          'Wastage / Spoilage',
          'Theft / Loss',
          'Sample / Complimentary',
        }),
      );
    });
  });

  group('RecipeReportService historical pricing (StockMovementModel.unitCost)',
      () {
    late Directory tempDir;

    setUp(() async {
      tempDir =
          await Directory.systemTemp.createTemp('recipe_report_service_');
      Hive.init(tempDir.path);
      await HiveInit.registerRestaurantAdapters();
      await Hive.openBox<StockMovementModel>(
          HiveBoxNames.restaurantStockMovements);
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('ingredientUsageReport prices recipe-cascade usage from unitCost',
        () async {
      final repo = StockMovementRepository();
      await repo.saveMovement(StockMovementModel(
        id: 'mov-1',
        timestamp: DateTime(2026, 6, 1),
        itemId: 'flour',
        itemName: 'Flour',
        type: 'out',
        quantity: 2,
        balanceAfter: 8,
        reason: 'Sale (recipe: Cake)',
        unit: 'kg',
        staffName: 'Priya',
        // Historical cost in effect when this movement happened — must be
        // preferred over any "live" cost, which this test never provides
        // (itemStore is never touched because unitCost is non-null).
        unitCost: 25.0,
      ));

      final rows = RecipeReportService.ingredientUsageReport();

      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.itemId, equals('flour'));
      expect(row.consumedQty, equals(2));
      // 2 kg * 25.0 historical cost = 50, NOT priced off any live cost.
      expect(row.estimatedCost, equals(50.0));
      expect(row.movementCount, equals(1));
    });

    test('ingredientUsageReport aggregates multiple movements for the same '
        'item, each priced at its own unitCost', () async {
      final repo = StockMovementRepository();
      await repo.saveMovement(StockMovementModel(
        id: 'mov-1',
        timestamp: DateTime(2026, 6, 1),
        itemId: 'sugar',
        itemName: 'Sugar',
        type: 'out',
        quantity: 1,
        balanceAfter: 9,
        reason: 'Production (Cake Batch)',
        unit: 'kg',
        staffName: 'Priya',
        unitCost: 40.0, // price at the time of this movement
      ));
      await repo.saveMovement(StockMovementModel(
        id: 'mov-2',
        timestamp: DateTime(2026, 7, 1),
        itemId: 'sugar',
        itemName: 'Sugar',
        type: 'out',
        quantity: 1,
        balanceAfter: 8,
        reason: 'Sale (recipe: Cookies)',
        unit: 'kg',
        staffName: 'Priya',
        unitCost: 45.0, // price rose by the second movement — must NOT be
        // overwritten by re-pricing the first movement at this rate.
      ));

      final rows = RecipeReportService.ingredientUsageReport();

      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.consumedQty, equals(2));
      // 1*40 + 1*45 = 85, proves each movement keeps its own historical cost.
      expect(row.estimatedCost, equals(85.0));
      expect(row.movementCount, equals(2));
    });

    test('ingredientUsageReport ignores movements outside the date range, '
        'movements that are not recipe-cascade/production, and "in" movements',
        () async {
      final repo = StockMovementRepository();
      // Outside range.
      await repo.saveMovement(StockMovementModel(
        id: 'mov-old',
        timestamp: DateTime(2025, 1, 1),
        itemId: 'flour',
        itemName: 'Flour',
        type: 'out',
        quantity: 5,
        balanceAfter: 5,
        reason: 'Sale (recipe: Cake)',
        unit: 'kg',
        staffName: 'Priya',
        unitCost: 20.0,
      ));
      // Wrong reason (manual adjustment, not recipe/production).
      await repo.saveMovement(StockMovementModel(
        id: 'mov-manual',
        timestamp: DateTime(2026, 6, 15),
        itemId: 'flour',
        itemName: 'Flour',
        type: 'out',
        quantity: 3,
        balanceAfter: 5,
        reason: 'Stock correction',
        unit: 'kg',
        staffName: 'Priya',
        unitCost: 20.0,
      ));
      // Wrong direction ('in', not 'out').
      await repo.saveMovement(StockMovementModel(
        id: 'mov-in',
        timestamp: DateTime(2026, 6, 15),
        itemId: 'flour',
        itemName: 'Flour',
        type: 'in',
        quantity: 3,
        balanceAfter: 8,
        reason: 'Sale (recipe: Cake)',
        unit: 'kg',
        staffName: 'Priya',
        unitCost: 20.0,
      ));
      // In-range, recipe-cascade, out — this is the only row that qualifies.
      await repo.saveMovement(StockMovementModel(
        id: 'mov-valid',
        timestamp: DateTime(2026, 6, 20),
        itemId: 'flour',
        itemName: 'Flour',
        type: 'out',
        quantity: 1,
        balanceAfter: 4,
        reason: 'Sale (recipe: Cake)',
        unit: 'kg',
        staffName: 'Priya',
        unitCost: 22.0,
      ));

      final rows = RecipeReportService.ingredientUsageReport(
        from: DateTime(2026, 6, 1),
        to: DateTime(2026, 6, 30),
      );

      expect(rows, hasLength(1));
      expect(rows.single.consumedQty, equals(1));
      expect(rows.single.estimatedCost, equals(22.0));
    });

    test('wastageReport prices "Wastage / Spoilage" removals from unitCost',
        () async {
      final repo = StockMovementRepository();
      await repo.saveMovement(StockMovementModel(
        id: 'mov-waste-1',
        timestamp: DateTime(2026, 6, 5),
        itemId: 'tomatoes',
        itemName: 'Tomatoes',
        type: 'out',
        quantity: 3,
        balanceAfter: 7,
        reason: 'Wastage / Spoilage',
        unit: 'kg',
        staffName: 'Priya',
        unitCost: 18.0,
      ));
      // A loss reason but not wastage — must be excluded.
      await repo.saveMovement(StockMovementModel(
        id: 'mov-theft',
        timestamp: DateTime(2026, 6, 6),
        itemId: 'tomatoes',
        itemName: 'Tomatoes',
        type: 'out',
        quantity: 2,
        balanceAfter: 5,
        reason: 'Theft / Loss',
        unit: 'kg',
        staffName: 'Priya',
        unitCost: 18.0,
      ));

      final rows = RecipeReportService.wastageReport();

      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.itemId, equals('tomatoes'));
      expect(row.wastedQty, equals(3));
      expect(row.estimatedCost, equals(54.0)); // 3 * 18.0 historical cost
      expect(row.movementCount, equals(1));
    });

    test('reports return empty lists when the movements box is empty', () {
      expect(RecipeReportService.ingredientUsageReport(), isEmpty);
      expect(RecipeReportService.wastageReport(), isEmpty);
    });
  });
}
