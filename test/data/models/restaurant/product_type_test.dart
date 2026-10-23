import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';

void main() {
  group('ProductType.displayName', () {
    test('semiFinished matches the Add Item card label exactly', () {
      expect(ProductType.displayName(ProductType.semiFinished), 'Semi-Finished');
    });

    // Phase 1 renamed the types (approved): Finished Good → "Finished", and
    // legacy Recipe-Based now reads as Finished (made to order).
    test('other types unaffected', () {
      expect(ProductType.displayName(ProductType.rawMaterial), 'Raw Material');
      expect(ProductType.displayName(ProductType.recipeBased), 'Finished');
      expect(ProductType.displayName(ProductType.finishedGood), 'Finished');
      expect(ProductType.displayName(null), 'Finished');
      expect(ProductType.displayName(ProductType.tradeItem), 'Trade Item');
    });
  });

  group('ProductType.isMenuType', () {
    test('finishedGood and recipeBased are menu types', () {
      expect(ProductType.isMenuType(ProductType.finishedGood), isTrue);
      expect(ProductType.isMenuType(ProductType.recipeBased), isTrue);
    });

    test('rawMaterial, semiFinished, and null are not menu types', () {
      expect(ProductType.isMenuType(ProductType.rawMaterial), isFalse);
      expect(ProductType.isMenuType(ProductType.semiFinished), isFalse);
      expect(ProductType.isMenuType(null), isFalse);
    });
  });

  group('ProductType.isStockDerived', () {
    test('only recipeBased is stock-derived', () {
      expect(ProductType.isStockDerived(ProductType.recipeBased), isTrue);
      expect(ProductType.isStockDerived(ProductType.rawMaterial), isFalse);
      expect(ProductType.isStockDerived(ProductType.semiFinished), isFalse);
      expect(ProductType.isStockDerived(ProductType.finishedGood), isFalse);
      expect(ProductType.isStockDerived(null), isFalse);
    });
  });

  group('ProductType.resolvePhysicalStock', () {
    test('recipeBased always clears stock regardless of requested inputs', () {
      final result = ProductType.resolvePhysicalStock(
        ProductType.recipeBased,
        requestedTrackInventory: true,
        requestedStockQuantity: 250.0,
      );
      expect(result.trackInventory, isFalse);
      expect(result.stockQuantity, 0.0);
    });

    test('recipeBased clears stock even when requested inputs are already off', () {
      final result = ProductType.resolvePhysicalStock(
        ProductType.recipeBased,
        requestedTrackInventory: false,
        requestedStockQuantity: 0.0,
      );
      expect(result.trackInventory, isFalse);
      expect(result.stockQuantity, 0.0);
    });

    test('every other type passes requested values through unchanged', () {
      for (final type in [
        ProductType.rawMaterial,
        ProductType.semiFinished,
        ProductType.finishedGood,
        null,
      ]) {
        final result = ProductType.resolvePhysicalStock(
          type,
          requestedTrackInventory: true,
          requestedStockQuantity: 42.0,
        );
        expect(result.trackInventory, isTrue, reason: 'type: $type');
        expect(result.stockQuantity, 42.0, reason: 'type: $type');

        final resultOff = ProductType.resolvePhysicalStock(
          type,
          requestedTrackInventory: false,
          requestedStockQuantity: 0.0,
        );
        expect(resultOff.trackInventory, isFalse, reason: 'type: $type');
        expect(resultOff.stockQuantity, 0.0, reason: 'type: $type');
      }
    });
  });
}
