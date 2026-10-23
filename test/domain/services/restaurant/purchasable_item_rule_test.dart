import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/domain/services/restaurant/purchasable_item_rule.dart';

/// Phase 1.7 — which items a PO can order (Q1, Q5).
void main() {
  Items item(String? type, {String? prepMode}) =>
      Items(id: 'i', name: 'I', productType: type, prepMode: prepMode);

  bool buyable(Items i, {bool hasRecipe = false}) =>
      PurchasableItemRule.isPurchasable(i, hasRecipe: hasRecipe);
  bool legacy(Items i, {bool hasRecipe = false}) =>
      PurchasableItemRule.isLegacyBoughtIn(i, hasRecipe: hasRecipe);

  test('Raw Material, Semi-Finished and Trade Item are orderable', () {
    for (final t in [
      ProductType.rawMaterial,
      ProductType.semiFinished,
      ProductType.tradeItem,
    ]) {
      expect(buyable(item(t)), isTrue, reason: t);
      expect(buyable(item(t), hasRecipe: true), isTrue, reason: t);
      expect(legacy(item(t)), isFalse, reason: t);
    }
  });

  test('made-to-order Finished is never orderable', () {
    final dish =
        item(ProductType.finishedGood, prepMode: ProductType.madeToOrder);
    expect(buyable(dish), isFalse);
    expect(buyable(dish, hasRecipe: true), isFalse);
    expect(buyable(item(ProductType.recipeBased)), isFalse);
    expect(buyable(item(ProductType.recipeBased), hasRecipe: true), isFalse);
  });

  test('made-in-advance Finished WITH a recipe is produced, not bought', () {
    expect(
        buyable(item(ProductType.finishedGood,
                prepMode: ProductType.madeInAdvance),
            hasRecipe: true),
        isFalse);
    expect(buyable(item(null), hasRecipe: true), isFalse);
  });

  test('Finished WITHOUT a recipe stays orderable, flagged legacy (Q1)', () {
    for (final i in [
      item(null),
      item(ProductType.finishedGood),
      item(ProductType.finishedGood, prepMode: ProductType.madeInAdvance),
    ]) {
      expect(buyable(i), isTrue);
      expect(legacy(i), isTrue);
    }
  });

  test('label', () {
    expect(PurchasableItemRule.legacyLabel, 'Legacy — set as Trade Item');
  });
}
