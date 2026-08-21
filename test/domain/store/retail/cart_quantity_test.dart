import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/retail/hive_model/cart_model_202.dart';
import 'package:billberrylite/domain/store/retail/cart_store.dart';

/// Rebuilds a cart line the way `CartStore.setQuantity` does — same factory,
/// same carry-forward list. This pins the *contract* of that rebuild without
/// needing Hive or GetIt booted (the store itself needs both).
CartItemModel rebuiltAt(CartItemModel item, int qty, {bool taxInclusive = false}) {
  return CartItemModel.create(
    cartItemId: item.cartItemId,
    variantId: item.variantId,
    productId: item.productId,
    productName: item.productName,
    attributes: item.attributes,
    price: item.price,
    qty: qty,
    barcode: item.barcode,
    gstRate: item.gstRate,
    hsnCode: item.hsnCode,
    categoryName: item.categoryName,
    taxInclusive: taxInclusive,
    originalPrice: item.originalPrice,
    overrideReason: item.overrideReason,
    overrideNote: item.overrideNote,
  );
}

CartItemModel line({
  double price = 850,
  double? originalPrice = 900,
  String? reason = 'clearance',
  String? note = 'display piece',
  int qty = 1,
  double gstRate = 18,
  bool taxInclusive = false,
}) {
  return CartItemModel.create(
    cartItemId: 'c1',
    variantId: 'v1',
    productId: 'p1',
    productName: 'Denim Shirt',
    attributes: const {'Size': 'L', 'Color': 'Blue'},
    price: price,
    qty: qty,
    barcode: '8901234567890',
    gstRate: gstRate,
    hsnCode: '6205',
    categoryName: 'Shirts',
    taxInclusive: taxInclusive,
    originalPrice: originalPrice,
    overrideReason: reason,
    overrideNote: note,
  );
}

void main() {
  group('kMaxCartLineQuantity', () {
    test('is the four-digit typo guard the UI formatter mirrors', () {
      expect(kMaxCartLineQuantity, equals(9999));
      expect(kMaxCartLineQuantity.toString().length, equals(4));
    });
  });

  group('quantity stays an int', () {
    test('CartItemModel.qty is an int', () {
      expect(line(qty: 12).qty, isA<int>());
    });

    test('a typed quantity does not introduce fractional units', () {
      final l = rebuiltAt(line(), 12);
      expect(l.qty, equals(12));
      expect(l.qty, isA<int>());
    });
  });

  // Requirement 6: the override must survive a quantity change. This is the
  // regression that would silently reprice a negotiated line to catalogue.
  group('price override survives a quantity change', () {
    test('overridden price and audit carry from qty 1 to 5', () {
      final before = line(price: 850, qty: 1);
      final after = rebuiltAt(before, 5);

      expect(after.price, equals(850));
      expect(after.originalPrice, equals(900));
      expect(after.overrideReason, equals('clearance'));
      expect(after.overrideNote, equals('display piece'));
      expect(after.isPriceOverridden, isTrue);
    });

    test('the line total is override x quantity, not catalogue x quantity', () {
      final after = rebuiltAt(line(price: 850, qty: 1), 5);
      expect(after.taxableAmount, equals(4250.0)); // 850 * 5, NOT 900 * 5
      expect(after.taxableAmount, isNot(equals(4500.0)));
    });

    test('a line with no override stays un-overridden', () {
      final before = line(price: 900, originalPrice: null, reason: null, note: null);
      final after = rebuiltAt(before, 7);
      expect(after.isPriceOverridden, isFalse);
      expect(after.originalPrice, isNull);
      expect(after.price, equals(900));
    });
  });

  group('every other sticky field carries forward', () {
    test('identity, tax and descriptor fields are preserved', () {
      final before = line(qty: 1);
      final after = rebuiltAt(before, 20);

      expect(after.cartItemId, equals(before.cartItemId));
      expect(after.variantId, equals(before.variantId));
      expect(after.productId, equals(before.productId));
      expect(after.productName, equals(before.productName));
      expect(after.barcode, equals(before.barcode));
      expect(after.gstRate, equals(before.gstRate));
      expect(after.hsnCode, equals(before.hsnCode));
      expect(after.categoryName, equals(before.categoryName));
      expect(after.attributes, equals(before.attributes));
    });
  });

  // Requirement 7: never hand-compute these.
  group('line money is recomputed by CartItemModel.create', () {
    test('tax-exclusive: GST scales with the typed quantity', () {
      final l = rebuiltAt(line(price: 100, originalPrice: null, reason: null), 12);
      expect(l.taxableAmount, equals(1200.0));
      expect(l.gstAmount, equals(216.0)); // 1200 * 0.18
      expect(l.cgstAmount, equals(108.0));
      expect(l.sgstAmount, equals(108.0));
      expect(l.total, equals(1200.0)); // exclusive: line total is ex-GST
    });

    test('tax-inclusive: GST is extracted, total equals price x qty', () {
      final l = rebuiltAt(
        line(price: 118, originalPrice: null, reason: null),
        10,
        taxInclusive: true,
      );
      expect(l.total, equals(1180.0));
      expect(l.taxableAmount, equals(1000.0)); // 1180 / 1.18
      expect(l.gstAmount, equals(180.0));
    });

    test('quantity 1 and quantity N differ only by the multiple', () {
      final one = rebuiltAt(line(price: 250, originalPrice: null, reason: null), 1);
      final four = rebuiltAt(line(price: 250, originalPrice: null, reason: null), 4);
      expect(four.taxableAmount, equals(one.taxableAmount! * 4));
      expect(four.gstAmount, equals(one.gstAmount! * 4));
    });
  });

  group('a rebuilt line round-trips through Hive maps', () {
    test('quantity and override survive toMap/fromMap', () {
      final restored = CartItemModel.fromMap(rebuiltAt(line(), 12).toMap());
      expect(restored.qty, equals(12));
      expect(restored.price, equals(850));
      expect(restored.originalPrice, equals(900));
      expect(restored.overrideReason, equals('clearance'));
    });
  });
}
