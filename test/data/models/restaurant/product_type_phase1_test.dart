import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';

/// Phase 1.1 — the four target types and read-time normalisation of legacy
/// values. Legacy strings are written raw: they are what devices and backups
/// already hold.
void main() {
  group('ProductType.effective normalises legacy values', () {
    test("'recipeBased' reads as Finished", () {
      expect(ProductType.effective('recipeBased'), ProductType.finishedGood);
    });
    test('null reads as Finished', () {
      expect(ProductType.effective(null), ProductType.finishedGood);
    });
    test('current values pass through', () {
      expect(ProductType.effective('rawMaterial'), ProductType.rawMaterial);
      expect(ProductType.effective('semiFinished'), ProductType.semiFinished);
      expect(ProductType.effective('finishedGood'), ProductType.finishedGood);
    });
  });

  group('preparation mode', () {
    test("legacy 'recipeBased' with no prep mode is made to order", () {
      expect(ProductType.effectivePrepMode('recipeBased', null),
          ProductType.madeToOrder);
    });
    test('legacy Finished Good / null with no prep mode is made in advance',
        () {
      expect(ProductType.effectivePrepMode('finishedGood', null),
          ProductType.madeInAdvance);
      expect(ProductType.effectivePrepMode(null, null),
          ProductType.madeInAdvance);
    });
    test('a stored prep mode wins', () {
      expect(
          ProductType.effectivePrepMode('finishedGood', ProductType.madeToOrder),
          ProductType.madeToOrder);
    });
  });

  group('Items getters keep legacy behaviour', () {
    Items legacy(String? type) =>
        Items(id: 'x', name: 'X', productType: type);

    test("legacy 'recipeBased' = Finished · made to order", () {
      final i = legacy('recipeBased');
      expect(i.isFinished, isTrue);
      expect(i.isMadeToOrder, isTrue);
      expect(i.isRecipeBased, isTrue, reason: 'deprecated alias, same meaning');
      expect(i.isFinishedGood, isFalse);
      expect(i.hasRecipe, isTrue);
      expect(i.isStockDerivedFromRecipe, isTrue);
    });

    test("legacy 'finishedGood' / null = Finished · made in advance", () {
      for (final i in [legacy('finishedGood'), legacy(null)]) {
        expect(i.isFinished, isTrue);
        expect(i.isMadeInAdvance, isTrue);
        expect(i.isFinishedGood, isTrue);
        expect(i.isRecipeBased, isFalse);
        expect(i.hasRecipe, isFalse);
      }
    });

    test('new Finished items follow their prep mode', () {
      final toOrder = Items(id: 'a', name: 'A',
          productType: ProductType.finishedGood,
          prepMode: ProductType.madeToOrder);
      final inAdvance = Items(id: 'b', name: 'B',
          productType: ProductType.finishedGood,
          prepMode: ProductType.madeInAdvance, makeFreshWhenOut: true);
      expect(toOrder.isRecipeBased, isTrue);
      expect(inAdvance.isMadeInAdvance, isTrue);
      expect(inAdvance.makeFreshWhenOut, isTrue);
      expect(inAdvance.isRecipeBased, isFalse);
    });

    test('Trade Item: own stock, on the POS, never a recipe', () {
      final t = Items(id: 't', name: 'T', productType: ProductType.tradeItem);
      expect(t.isTradeItem, isTrue);
      expect(t.isFinished, isFalse);
      expect(t.isFinishedGood, isFalse);
      expect(t.isRecipeBased, isFalse);
      expect(t.hasRecipe, isFalse);
      expect(t.sellsAtPos, isTrue);
      expect(t.isMadeToOrder, isFalse);
    });

    test('makeFreshWhenOut defaults to false', () {
      expect(legacy('finishedGood').makeFreshWhenOut, isFalse);
    });
  });

  group('serialisation', () {
    test('toMap / fromMap carry the new fields', () {
      final i = Items(id: 'a', name: 'A',
          productType: ProductType.finishedGood,
          prepMode: ProductType.madeInAdvance, makeFreshWhenOut: true);
      final back = Items.fromMap(i.toMap());
      expect(back.prepMode, ProductType.madeInAdvance);
      expect(back.makeFreshWhenOut, isTrue);
    });

    test('an old backup map without the new keys reads as before', () {
      final map = Items(id: 'a', name: 'A', productType: 'recipeBased').toMap()
        ..remove('prepMode')
        ..remove('makeFreshWhenOut');
      final back = Items.fromMap(map);
      expect(back.prepMode, isNull);
      expect(back.makeFreshWhenOut, isFalse);
      expect(back.isRecipeBased, isTrue);
    });

    test('copyWith carries the new fields', () {
      final i = Items(id: 'a', name: 'A', prepMode: ProductType.madeToOrder)
          .copyWith(makeFreshWhenOut: true);
      expect(i.prepMode, ProductType.madeToOrder);
      expect(i.makeFreshWhenOut, isTrue);
    });
  });
}
