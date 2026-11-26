import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';

/// Phase 1.4 — the item editor's load/save mapping. Opening and saving an
/// item without touching its type must never change how it sells, and a
/// type change must keep its recipe.
void main() {
  /// Open the item in the editor, change nothing, save.
  Items openAndSave(Items stored) {
    final view = ProductType.editorView(
        stored.productType, stored.prepMode, stored.makeFreshWhenOut);
    final out = ProductType.storedFields(
        type: view.type, prepMode: view.prepMode, makeFresh: view.makeFresh);
    return stored.copyWith(productType: out.productType)
      ..prepMode = out.prepMode
      ..makeFreshWhenOut = out.makeFreshWhenOut;
  }

  group('open + save changes nothing', () {
    test("legacy 'recipeBased' stays made to order", () {
      final saved = openAndSave(Items(id: 'b', name: 'Burger',
          productType: ProductType.recipeBased));
      expect(saved.isMadeToOrder, isTrue,
          reason: 'must keep cascading into its recipe');
      expect(saved.productType, ProductType.finishedGood,
          reason: 'saved with the new value');
      expect(saved.prepMode, ProductType.madeToOrder);
      // The editor keeps (saves) the recipe whenever the opened type can
      // carry one — so an opened Recipe-Based item keeps its recipe.
      final view = ProductType.editorView('recipeBased', null, false);
      expect(ProductType.canHaveRecipe(view.type), isTrue);
    });

    test("legacy 'finishedGood' / null stays made in advance", () {
      for (final t in [ProductType.finishedGood, null]) {
        final saved = openAndSave(Items(id: 'c', name: 'Coke', productType: t));
        expect(saved.isMadeInAdvance, isTrue);
      }
    });

    test('a hybrid keeps "make fresh when out"', () {
      final saved = openAndSave(Items(id: 'h', name: 'Cake',
          productType: ProductType.finishedGood,
          prepMode: ProductType.madeInAdvance, makeFreshWhenOut: true));
      expect(saved.isMadeInAdvance, isTrue);
      expect(saved.makeFreshWhenOut, isTrue);
    });

    test('Raw / Semi / Trade carry no prep mode', () {
      for (final t in [ProductType.rawMaterial, ProductType.semiFinished,
          ProductType.tradeItem]) {
        final saved = openAndSave(Items(id: 'x', name: 'X', productType: t,
            prepMode: ProductType.madeToOrder, makeFreshWhenOut: true));
        expect(saved.productType, t);
        expect(saved.prepMode, isNull);
        expect(saved.makeFreshWhenOut, isFalse);
      }
    });
  });

  group('rules the editor and quick add share', () {
    test('Finished and Semi-Finished can have a recipe; Raw and Trade never',
        () {
      expect(ProductType.canHaveRecipe(ProductType.finishedGood), isTrue);
      expect(ProductType.canHaveRecipe(ProductType.semiFinished), isTrue);
      expect(ProductType.canHaveRecipe(ProductType.recipeBased), isTrue);
      expect(ProductType.canHaveRecipe(ProductType.rawMaterial), isFalse);
      expect(ProductType.canHaveRecipe(ProductType.tradeItem), isFalse);
    });

    test('made to order clears own stock; made in advance keeps it', () {
      final toOrder = ProductType.resolvePhysicalStock(ProductType.finishedGood,
          prepMode: ProductType.madeToOrder,
          requestedTrackInventory: true, requestedStockQuantity: 9);
      expect([toOrder.trackInventory, toOrder.stockQuantity], [false, 0.0]);

      final inAdvance = ProductType.resolvePhysicalStock(
          ProductType.finishedGood,
          prepMode: ProductType.madeInAdvance,
          requestedTrackInventory: true, requestedStockQuantity: 9);
      expect([inAdvance.trackInventory, inAdvance.stockQuantity], [true, 9.0]);
    });

    test('Trade Item is a menu type (needs price + category)', () {
      expect(ProductType.isMenuType(ProductType.tradeItem), isTrue);
    });
  });
}
