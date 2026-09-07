import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/retail/hive_model/cart_model_202.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/domain/services/restaurant/cart_calculation_service.dart'
    show DiscountType;
import 'package:billberrylite/domain/services/retail/line_discount_service.dart';
import 'package:billberrylite/domain/services/retail/quick_item_service.dart';

/// Builds a quick-item cart line exactly the way `CartStore.addQuickItem` does —
/// same id minting, same factory, same omitted catalogue fields. This pins the
/// CONTRACT of that build without needing Hive or GetIt booted (the store itself
/// needs both), mirroring how `cart_quantity_test.dart` pins `setQuantity`.
CartItemModel quickLine({
  String name = 'Local Bread',
  double price = 45,
  double gstRate = 5,
  int qty = 1,
  bool taxInclusive = false,
}) {
  final variantId = QuickItemService.newVariantId();
  return CartItemModel.create(
    cartItemId: '${variantId}_${DateTime.now().millisecondsSinceEpoch}',
    variantId: variantId,
    productId: QuickItemService.newProductId(),
    productName: name,
    price: price,
    qty: qty.toDouble(),
    gstRate: gstRate,
    taxInclusive: taxInclusive,
  );
}

/// Rebuilds a line at a new quantity the way `CartStore.setQuantity` does.
CartItemModel rebuiltAt(CartItemModel item, double qty) {
  return CartItemModel.create(
    cartItemId: item.cartItemId,
    variantId: item.variantId,
    productId: item.productId,
    productName: item.productName,
    price: item.price,
    qty: qty,
    gstRate: item.gstRate,
    hsnCode: item.hsnCode,
    categoryName: item.categoryName,
    taxInclusive: false,
    originalPrice: item.originalPrice,
    overrideReason: item.overrideReason,
    overrideNote: item.overrideNote,
  );
}

VarianteModel catalogueVariant({double? costPrice = 60}) {
  return VarianteModel.create(
    varianteId: 'v1',
    productId: 'p1',
    costPrice: costPrice,
    mrp: 120,
    sellingPrice: 100,
    stockQty: 10,
  );
}

void main() {
  // A — a quick item becomes an ordinary cart line carrying what was typed.
  group('A. a quick item is a normal cart line', () {
    test('carries the typed name, price, tax and quantity', () {
      final line = quickLine(name: 'Local Bread', price: 45, gstRate: 5);

      expect(line.productName, equals('Local Bread'));
      expect(line.price, equals(45));
      expect(line.qty, equals(1));
      expect(line.gstRate, equals(5));
    });

    test('its ids are quick-item ids, so downstream code can recognise it', () {
      final line = quickLine();

      expect(QuickItemService.isQuickItem(line.variantId), isTrue);
      expect(line.variantId, startsWith(QuickItemService.idPrefix));
      expect(line.productId, startsWith(QuickItemService.idPrefix));
    });

    test('it carries no catalogue descriptors it does not have', () {
      final line = quickLine();

      expect(line.barcode, isNull);
      expect(line.hsnCode, isNull);
      expect(line.categoryName, isNull);
      expect(line.attributes, isNull);
    });

    test('money is computed by the same factory catalogue lines use', () {
      // 45 x 1 at 5%: taxable 45, GST 2.25, split across CGST/SGST.
      final line = quickLine(price: 45, gstRate: 5);

      expect(line.taxableAmount, equals(45.0));
      expect(line.gstAmount, equals(2.25));
      // An odd half-paisa goes to CGST and SGST takes the remainder, so the two
      // always add back to gstAmount. Rounding both to 1.13 printed 2.26 — a
      // paisa more than the customer paid. See TaxSplit.
      expect(line.cgstAmount, equals(1.13));
      expect(line.sgstAmount, equals(1.12));
      expect(line.cgstAmount! + line.sgstAmount!, closeTo(line.gstAmount!, 1e-9));
    });
  });

  // B — the whole point of a unique synthetic id.
  group('B. multiple quick items stay separate lines', () {
    test('two quick items never share a variantId', () {
      final bread = quickLine(name: 'Local Bread', price: 45);
      final bag = quickLine(name: 'Plastic Bag', price: 5);

      expect(bread.variantId, isNot(equals(bag.variantId)));
      expect(bread.productId, isNot(equals(bag.productId)));
    });

    test('the cart lookup CartStore uses isolates each of them', () {
      final bread = quickLine(name: 'Local Bread', price: 45);
      final bag = quickLine(name: 'Plastic Bag', price: 5);
      final items = [bread, bag];

      // This is verbatim how every CartStore mutation finds its line.
      final breadIndex =
          items.indexWhere((i) => i.variantId == bread.variantId);
      final bagIndex = items.indexWhere((i) => i.variantId == bag.variantId);

      expect(breadIndex, equals(0));
      expect(bagIndex, equals(1));
      expect(items[breadIndex].productName, equals('Local Bread'));
      expect(items[bagIndex].productName, equals('Plastic Bag'));
    });

    test('a hundred quick items produce a hundred distinct ids', () {
      final ids = {for (var i = 0; i < 100; i++) quickLine().variantId};
      expect(ids.length, equals(100));
    });
  });

  // C — quantity behaves exactly as it does for a catalogue line.
  group('C. quantity', () {
    test('1 to 3 at 45 gives a subtotal of 135', () {
      final line = rebuiltAt(quickLine(price: 45, gstRate: 0), 3);

      expect(line.qty, equals(3));
      expect(line.taxableAmount, equals(135.0));
    });

    test('a quantity change preserves the identity and the typed price', () {
      final before = quickLine(price: 45);
      final after = rebuiltAt(before, 3);

      expect(after.variantId, equals(before.variantId));
      expect(after.productId, equals(before.productId));
      expect(after.productName, equals(before.productName));
      expect(after.price, equals(45));
      expect(QuickItemService.isQuickItem(after.variantId), isTrue);
    });
  });

  // D — the selected rate, not the store default, is what bills.
  group('D. tax', () {
    test('100 at the default 5% charges 5', () {
      final line = quickLine(price: 100, gstRate: 5);

      expect(line.gstRate, equals(5));
      expect(line.taxableAmount, equals(100.0));
      expect(line.gstAmount, equals(5.0));
    });

    test('the same line at a chosen 18% charges 18, not the default', () {
      final line = quickLine(price: 100, gstRate: 18);

      expect(line.gstRate, equals(18));
      expect(line.gstAmount, equals(18.0));
      expect(line.gstAmount, isNot(equals(5.0)));
    });

    test('tax-inclusive extracts rather than adds, as it does for catalogue',
        () {
      // 118 inclusive of 18% is 100 taxable + 18 GST, and the total stays 118.
      final line =
          quickLine(price: 118, gstRate: 18, taxInclusive: true);

      expect(line.total, equals(118.0));
      expect(line.taxableAmount, equals(100.0));
      expect(line.gstAmount, equals(18.0));
    });

    test('the chosen rate survives the Hive round-trip into the sale', () {
      final restored =
          CartItemModel.fromMap(quickLine(price: 100, gstRate: 18).toMap());

      expect(restored.gstRate, equals(18));
      expect(restored.gstAmount, equals(18.0));
      expect(restored.productName, equals('Local Bread'));
      expect(QuickItemService.isQuickItem(restored.variantId), isTrue);
    });
  });

  // E — the existing discount mechanism, reused rather than duplicated.
  group('E. item-level discount', () {
    test('a percentage resolves against the quick line gross', () {
      final line = quickLine(price: 100, gstRate: 0, qty: 1);
      final amount = LineDiscountService.resolveAmount(
        type: DiscountType.percentage,
        value: 10,
        gross: line.grossAmount,
      );

      expect(line.grossAmount, equals(100.0));
      expect(amount, equals(10.0));
    });

    test('validate accepts a null variant — no catalogue, so no cost floor',
        () {
      final result = LineDiscountService.validate(
        variant: null,
        type: DiscountType.percentage,
        value: 10,
        chargedUnitPrice: 100,
        qty: 1,
      );

      expect(result.verdict, equals(LineDiscountVerdict.ok));
      expect(result.needsConfirmation, isFalse);
      expect(result.amount, equals(10.0));
      expect(result.effectiveUnitPrice, equals(90.0));
    });

    test('the hard blocks still apply to a quick line', () {
      // A discount that empties the line is refused, catalogue or not.
      final full = LineDiscountService.validate(
        variant: null,
        type: DiscountType.percentage,
        value: 100,
        chargedUnitPrice: 100,
        qty: 1,
      );
      expect(full.isBlocked, isTrue);

      final negative = LineDiscountService.validate(
        variant: null,
        type: DiscountType.amount,
        value: -5,
        chargedUnitPrice: 100,
        qty: 1,
      );
      expect(negative.isBlocked, isTrue);
    });

    test('the line total follows a discounted quick line', () {
      final line = CartItemModel.create(
        cartItemId: 'c1',
        variantId: QuickItemService.newVariantId(),
        productId: QuickItemService.newProductId(),
        productName: 'Local Bread',
        price: 100,
        qty: 1,
        gstRate: 0,
        lineDiscountType: DiscountType.percentage.name,
        lineDiscountValue: 10,
        lineDiscountAmount: 10,
      );

      expect(line.hasLineDiscount, isTrue);
      expect(line.grossAmount, equals(100.0));
      expect(line.netAmount, equals(90.0));
    });

    // K (partial) — a catalogue line keeps its cost floor.
    test('a CATALOGUE line still warns below cost, unchanged', () {
      final result = LineDiscountService.validate(
        variant: catalogueVariant(costPrice: 60),
        type: DiscountType.percentage,
        value: 50,
        chargedUnitPrice: 100,
        qty: 1,
      );

      expect(result.verdict, equals(LineDiscountVerdict.belowCost));
      expect(result.needsConfirmation, isTrue);
      expect(result.effectiveUnitPrice, equals(50.0));
    });
  });

  // F — the predicate the POS gates Price Override on.
  group('F. price override is recognisable as not-applicable', () {
    test('a quick item is recognised', () {
      expect(QuickItemService.isQuickItem(QuickItemService.newVariantId()),
          isTrue);
    });

    test('a catalogue variant id is NOT recognised as a quick item', () {
      expect(QuickItemService.isQuickItem('v1'), isFalse);
      expect(
        QuickItemService.isQuickItem('9f8e7d6c-1234-4abc-8def-0123456789ab'),
        isFalse,
      );
      expect(QuickItemService.isQuickItem(''), isFalse);
    });

    test('the prefix cannot be produced by a catalogue uuid', () {
      // Catalogue ids are bare uuids; the prefix is not hex, so no collision.
      expect(QuickItemService.idPrefix, equals('QUICK-'));
      expect(QuickItemService.newVariantId().length,
          greaterThan(QuickItemService.idPrefix.length));
    });
  });

  // J — validation.
  group('J. validation', () {
    test('an empty or whitespace name is rejected', () {
      expect(QuickItemService.validateName(''), isNotNull);
      expect(QuickItemService.validateName('   '), isNotNull);
      expect(QuickItemService.validateName(null), isNotNull);
      expect(QuickItemService.validateName('Local Bread'), isNull);
    });

    test('a zero or negative price is rejected', () {
      expect(QuickItemService.validatePrice(0), isNotNull);
      expect(QuickItemService.validatePrice(-45), isNotNull);
      expect(QuickItemService.validatePrice(null), isNotNull);
      expect(QuickItemService.validatePrice(0.01), isNull);
      expect(QuickItemService.validatePrice(45), isNull);
    });

    test('a zero or negative quantity is rejected', () {
      expect(QuickItemService.validateQty(0), isNotNull);
      expect(QuickItemService.validateQty(-1), isNotNull);
      expect(QuickItemService.validateQty(null), isNotNull);
      expect(QuickItemService.validateQty(1), isNull);
      expect(QuickItemService.validateQty(10), isNull);
    });
  });

  // K — catalogue lines are untouched by any of this.
  group('K. catalogue lines are unaffected', () {
    test('a catalogue line is not a quick item and keeps its descriptors', () {
      final line = CartItemModel.create(
        cartItemId: 'c1',
        variantId: 'v1',
        productId: 'p1',
        productName: 'Denim Shirt',
        attributes: const {'Size': 'L'},
        price: 900,
        qty: 2,
        barcode: '8901234567890',
        gstRate: 18,
        hsnCode: '6205',
        categoryName: 'Shirts',
      );

      expect(QuickItemService.isQuickItem(line.variantId), isFalse);
      expect(line.barcode, equals('8901234567890'));
      expect(line.hsnCode, equals('6205'));
      expect(line.categoryName, equals('Shirts'));
      expect(line.attributes, equals({'Size': 'L'}));
      expect(line.taxableAmount, equals(1800.0));
      expect(line.gstAmount, equals(324.0));
    });

    test('a catalogue price override still reads as overridden', () {
      final line = CartItemModel.create(
        cartItemId: 'c1',
        variantId: 'v1',
        productId: 'p1',
        productName: 'Denim Shirt',
        price: 850,
        qty: 1,
        gstRate: 18,
        originalPrice: 900,
        overrideReason: 'clearance',
      );

      expect(line.isPriceOverridden, isTrue);
      expect(line.originalPrice, equals(900));
      expect(QuickItemService.isQuickItem(line.variantId), isFalse);
    });
  });
}
