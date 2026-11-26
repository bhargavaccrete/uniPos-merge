import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/domain/services/restaurant/trade_item_suggestion_rule.dart';

/// Phase 1.9 — read-only "Suggested Trade Items" (Q2). Candidates only:
/// nothing here changes an item.
void main() {
  Items legacy(String id,
          {String? type, String? prepMode, bool tracked = true}) =>
      Items(
        id: id,
        name: id,
        productType: type,
        prepMode: prepMode,
        trackInventory: tracked,
      );

  var n = 0;
  StockMovementModel mv(String itemId, String reason, {String type = 'in'}) =>
      StockMovementModel(
        id: 'm${n++}',
        timestamp: DateTime(2026, 10, 1),
        itemId: itemId,
        itemName: itemId,
        type: type,
        quantity: 12,
        balanceAfter: 12,
        reason: reason,
        unit: 'pcs',
        staffName: 'staff',
      );

  List<TradeItemSuggestion> suggest(
    List<Items> items,
    List<StockMovementModel> movements, {
    Set<String> withRecipe = const {},
  }) =>
      TradeItemSuggestionRule.suggest(
        items: items,
        hasRecipe: withRecipe.contains,
        movements: movements,
      );

  group('included', () {
    test('legacy Finished (no type stored), no recipe, received on a PO', () {
      final s = suggest([legacy('coke')], [mv('coke', 'Purchase (PO-0001)')]);
      expect(s.single.item.id, 'coke');
      expect(s.single.supplierReceipts, 1);
      expect(s.single.manualPurchases, 0);
    });

    test('stored as finishedGood without a prep mode, restocked as a purchase',
        () {
      final s = suggest([legacy('water', type: ProductType.finishedGood)],
          [mv('water', 'Restock / Purchase')]);
      expect(s.single.item.id, 'water');
      expect(s.single.manualPurchases, 1);
    });

    test('counts every purchase and explains why', () {
      final s = suggest([
        legacy('coke')
      ], [
        mv('coke', 'Purchase (PO-0001)'),
        mv('coke', 'Purchase (PO-0002)'),
        mv('coke', 'Restock / Purchase'),
        mv('coke', 'Sale', type: 'out'),
      ]);
      expect(s.single.supplierReceipts, 2);
      expect(s.single.manualPurchases, 1);
      expect(s.single.reasons, [
        'Received from a supplier 2 times',
        'Restocked as a purchase 1 time',
        'No recipe',
        'Never produced in-house',
      ]);
    });

    test('a variant item with purchase evidence is still a candidate', () {
      final cola = Items(
        id: 'cola',
        name: 'cola',
        trackInventory: true,
        variant: [ItemVariante(variantId: 'v', price: 40, stockQuantity: 4)],
      );
      expect(suggest([cola], [mv('cola', 'Purchase (PO-0003)')]), hasLength(1));
    });
  });

  group('excluded', () {
    test('Trade, Raw and Semi-Finished are never suggested', () {
      for (final t in [
        ProductType.tradeItem,
        ProductType.rawMaterial,
        ProductType.semiFinished,
      ]) {
        expect(
          suggest([legacy('x', type: t)], [mv('x', 'Purchase (PO-1)')]),
          isEmpty,
          reason: t,
        );
      }
    });

    test('legacy Recipe-Based (made to order) is never suggested', () {
      expect(
        suggest([legacy('x', type: ProductType.recipeBased)],
            [mv('x', 'Purchase (PO-1)')]),
        isEmpty,
      );
    });

    test('an item with a recipe is not suggested', () {
      expect(
        suggest([legacy('x')], [mv('x', 'Purchase (PO-1)')],
            withRecipe: {'x'}),
        isEmpty,
      );
    });

    test('an item produced in-house is not suggested, even if also bought',
        () {
      expect(
        suggest([legacy('x')], [
          mv('x', 'Purchase (PO-1)'),
          mv('x', 'Production batch'),
        ]),
        isEmpty,
      );
    });

    test('an item saved since the redesign (prep mode stored) is reviewed',
        () {
      for (final mode in [ProductType.madeInAdvance, ProductType.madeToOrder]) {
        expect(
          suggest([legacy('x', type: ProductType.finishedGood, prepMode: mode)],
              [mv('x', 'Purchase (PO-1)')]),
          isEmpty,
          reason: mode,
        );
      }
    });
  });

  group('ambiguous', () {
    test('holds stock but no purchase evidence: not suggested', () {
      expect(
        suggest([legacy('cake')], [
          mv('cake', 'Opening stock'),
          mv('cake', 'Stock correction'),
          mv('cake', 'Sale', type: 'out'),
        ]),
        isEmpty,
      );
    });

    test('no movements at all: not suggested', () {
      expect(suggest([legacy('tea', tracked: false)], []), isEmpty);
    });

    test('only purchase-looking OUT rows do not count', () {
      expect(
        suggest([legacy('x')], [mv('x', 'Purchase (PO-1)', type: 'out')]),
        isEmpty,
      );
    });

    test('another item\'s purchases do not count', () {
      expect(
        suggest([legacy('x'), legacy('y', type: ProductType.tradeItem)],
            [mv('y', 'Purchase (PO-1)')]),
        isEmpty,
      );
    });
  });

  test('strongest evidence first, then by name', () {
    final s = suggest([
      legacy('b'),
      legacy('a'),
      legacy('c'),
    ], [
      mv('a', 'Restock / Purchase'),
      mv('b', 'Purchase (PO-1)'),
      mv('c', 'Purchase (PO-1)'),
      mv('c', 'Purchase (PO-2)'),
    ]);
    expect(s.map((e) => e.item.id), ['c', 'a', 'b']);
  });
}
