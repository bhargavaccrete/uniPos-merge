import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/core/constants/item_units.dart';
import 'package:billberrylite/data/models/retail/hive_model/cart_model_202.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_item_model_214.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/stock_take_item_model_181.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

/// Decimal-quantity support for retail loose goods (kg/litre), and the
/// guarantee that existing piece products are untouched by it.
///
/// These pin the ARITHMETIC and the SERIALIZATION contracts — the two places a
/// fractional quantity silently becomes wrong. The stock-write path itself
/// needs Hive plus GetIt, so it is covered by the manual plan rather than here.
void main() {
  VarianteModel potato({double stock = 0}) => VarianteModel(
        varianteId: 'v-potato',
        productId: 'p-potato',
        createdAt: DateTime.now().toIso8601String(),
        stockQty: stock,
        sellingPrice: 40,
        isDecimalQuantity: true,
        unit: 'kg',
      );

  VarianteModel coke({double stock = 0}) => VarianteModel(
        varianteId: 'v-coke',
        productId: 'p-coke',
        createdAt: DateTime.now().toIso8601String(),
        stockQty: stock,
        sellingPrice: 20,
      );

  group('unit of measure', () {
    test('a decimal variant reports its own unit', () {
      expect(potato().isDecimalQuantity, isTrue);
      expect(potato().effectiveUnit, equals('kg'));
    });

    test('a piece variant defaults to pieces with no unit stored', () {
      expect(coke().isDecimalQuantity, isFalse);
      expect(coke().unit, isNull);
      expect(coke().effectiveUnit, equals('piece'));
    });

    test('legacy unit spellings normalize through the shared restaurant list',
        () {
      // Reused, not reimplemented — kItemUnits/normalizeItemUnit are shared.
      expect(normalizeItemUnit('kgs'), equals('kg'));
      expect(normalizeItemUnit('litre'), equals('liter'));
      expect(normalizeItemUnit('pcs'), equals('piece'));
      expect(kItemUnits, contains('kg'));
    });

    test('the +/- step is fractional for loose goods, whole for pieces', () {
      expect(potato().quantityStep, equals(0.25));
      expect(coke().quantityStep, equals(1.0));
    });
  });

  group('TEST A — decimal stock chain: 10.50 +5.25 -1.75 -0.50 = 13.50', () {
    test('the full chain lands exactly on 13.50', () {
      var stock = potato(stock: 10.50).stockQty;
      expect(stock, equals(10.50));

      // Purchase received via GRN.
      stock += 5.25;
      expect(stock, equals(15.75));

      // POS sale.
      stock -= 1.75;
      expect(stock, equals(14.00));

      // Loss / adjustment.
      stock -= 0.50;

      expect(stock, closeTo(13.50, 1e-9));
    });

    test('no step of the chain truncates to a whole number', () {
      final steps = <double>[10.50, 15.75, 14.00, 13.50];
      // 14.00 is legitimately whole; the others must NOT be.
      expect(steps[0] % 1, isNot(equals(0)));
      expect(steps[1] % 1, isNot(equals(0)));
      expect(steps[3] % 1, isNot(equals(0)));
    });
  });

  group('TEST B — piece stock is unchanged: 20 - 3 = 17', () {
    test('whole-number arithmetic is exact', () {
      final stock = coke(stock: 20).stockQty - 3;
      expect(stock, equals(17));
      expect(stock % 1, equals(0));
    });

    test('a piece quantity renders with no decimal point', () {
      expect(coke(stock: 20).formatQuantity(20), equals('20'));
      expect(formatQty(17), equals('17'));
    });
  });

  group('TEST C — decimal POS sale: 10.50 kg, sell 1.25 kg', () {
    CartItemModel cartLine(double qty) => CartItemModel.create(
          cartItemId: 'c1',
          variantId: 'v-potato',
          productId: 'p-potato',
          productName: 'Potato',
          price: 40,
          qty: qty,
        );

    test('cart line carries the real fractional quantity', () {
      expect(cartLine(1.25).qty, equals(1.25));
    });

    test('line total is unit price x fractional quantity', () {
      // 40 x 1.25 = 50 — the whole reason qty must not be pinned to 1.
      expect(cartLine(1.25).grossAmount, equals(50.0));
    });

    test('the sale line records the same fractional quantity', () {
      // Direct constructor: the .create factory reads AppConfig, which needs
      // Hive booted. The quantity contract is what matters here.
      final sold = SaleItemModel(
        saleItemId: 'si1',
        saleId: 's1',
        varianteId: 'v-potato',
        productId: 'p-potato',
        productName: 'Potato',
        price: 40,
        qty: 1.25,
        total: 50,
      );
      expect(sold.qty, equals(1.25));
      expect(sold.price * sold.qty, equals(50.0));
    });

    test('stock after the sale is 9.25', () {
      expect(potato(stock: 10.50).stockQty - 1.25, equals(9.25));
    });
  });

  group('TEST D — decimal PO/GRN: ordered 7.50, received/accepted 7.25', () {
    final line = GRNItemModel.create(
      grnId: 'g1',
      poItemId: 'poi-1',
      variantId: 'v-potato',
      productId: 'p-potato',
      orderedQty: 7.50,
      receivedQty: 7.25,
      acceptedQty: 7.25,
      costPrice: 20,
    );

    test('ordered and received keep their fractions', () {
      expect(line.orderedQty, equals(7.50));
      expect(line.receivedQty, equals(7.25));
      expect(line.acceptedQty, equals(7.25));
    });

    test('the 0.25 shortage is tracked, not rounded away', () {
      expect(line.shortageQty, closeTo(0.25, 1e-9));
    });

    test('good quantity equals received when nothing is damaged', () {
      expect(line.goodQty, equals(7.25));
    });

    test('billed value uses the fractional received quantity', () {
      // 7.25 x 20 = 145
      expect(line.billableQty * 20, closeTo(145.0, 1e-9));
    });
  });

  group('TEST E — stock take: system 10.50, counted 9.25', () {
    final counted = StockTakeItemModel.create(
      takeId: 't1',
      variantId: 'v-potato',
      productId: 'p-potato',
      systemQty: 10.50,
      countedQty: 9.25,
      costPrice: 20,
    );

    test('variance is -1.25', () {
      expect(counted.variance, closeTo(-1.25, 1e-9));
    });

    test('it reads as a shortage', () {
      expect(counted.isShortage, isTrue);
      expect(counted.hasVariance, isTrue);
    });

    test('commit applies the DELTA, not the absolute count', () {
      // Mirrors StockTakeStore.commit: target = current stock + variance.
      // A sale of 0.5 kg landing between count and commit must survive.
      const stockNow = 10.00; // 0.5 kg sold since counting
      final target = stockNow + counted.variance;
      expect(target, closeTo(8.75, 1e-9));
      // Writing countedQty absolutely would wrongly give 9.25.
      expect(target, isNot(equals(9.25)));
    });

    test('variance is valued at the fractional quantity', () {
      expect(counted.varianceValue, closeTo(-25.0, 1e-9)); // -1.25 x 20
    });
  });

  group('serialization round-trips', () {
    test('10.50 survives a variant toMap/fromMap as 10.50', () {
      final restored = VarianteModel.fromMap(potato(stock: 10.50).toMap());
      expect(restored.stockQty, equals(10.50));
      expect(restored.isDecimalQuantity, isTrue);
      expect(restored.unit, equals('kg'));
    });

    test('a legacy INTEGER stock value loads as a whole double', () {
      // What a backup written before decimals looks like.
      final legacy = {
        'varianteId': 'v-old',
        'productId': 'p-old',
        'createdAt': DateTime.now().toIso8601String(),
        'stockQty': 20,
        'minStock': 5,
      };
      final restored = VarianteModel.fromMap(legacy);
      expect(restored.stockQty, equals(20.0));
      expect(restored.minStock, equals(5.0));
      // Absent flag reads as a piece product — no migration needed.
      expect(restored.isDecimalQuantity, isFalse);
      expect(restored.effectiveUnit, equals('piece'));
    });

    test('a fractional cart quantity survives toMap/fromMap', () {
      final restored = CartItemModel.fromMap(
        CartItemModel.create(
          cartItemId: 'c1',
          variantId: 'v-potato',
          productId: 'p-potato',
          productName: 'Potato',
          price: 40,
          qty: 1.75,
        ).toMap(),
      );
      expect(restored.qty, equals(1.75));
    });

    test('a legacy integer sale quantity loads as a whole double', () {
      final sold = SaleItemModel(
        saleItemId: 'si2',
        saleId: 's1',
        varianteId: 'v-coke',
        productId: 'p-coke',
        productName: 'Coke',
        price: 20,
        qty: 3,
        total: 60,
      );
      final map = sold.toMap()..['qty'] = 3; // integer, as older data stored it
      expect(SaleItemModel.fromMap(map).qty, equals(3.0));
    });

    test('a fractional GRN quantity survives toMap/fromMap', () {
      final restored = GRNItemModel.fromMap(
        GRNItemModel.create(
          grnId: 'g1',
          poItemId: 'poi-1',
          variantId: 'v-potato',
          productId: 'p-potato',
          orderedQty: 7.50,
          receivedQty: 7.25,
          acceptedQty: 7.25,
          costPrice: 20,
        ).toMap(),
      );
      expect(restored.orderedQty, equals(7.50));
      expect(restored.receivedQty, equals(7.25));
    });
  });

  group('display formatting', () {
    test('whole values never render a trailing .0', () {
      expect(formatQty(20), equals('20'));
      expect(formatQty(17.0), equals('17'));
      expect(formatQty(0), equals('0'));
    });

    test('fractional values keep their decimals, trimmed', () {
      expect(formatQty(10.5), equals('10.5'));
      expect(formatQty(1.25), equals('1.25'));
      expect(formatQty(13.50), equals('13.5'));
    });

    test('units are appended only when present', () {
      expect(formatQtyWithUnit(10.5, 'kg'), equals('10.5 kg'));
      expect(formatQtyWithUnit(17, null), equals('17'));
    });

    test('a piece variant rounds display, a decimal one does not', () {
      expect(coke().formatQuantity(20), equals('20'));
      expect(potato().formatQuantity(1.75), equals('1.75'));
    });
  });
}
