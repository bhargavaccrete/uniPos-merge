import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/retail/hive_model/cart_model_202.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/domain/services/retail/price_override_reason.dart';
import 'package:billberrylite/domain/services/retail/price_override_service.dart';

/// A variant priced the way the requirement's worked example describes:
/// catalogue 900, MRP 1000, cost 600.
VarianteModel _variant({
  double? sellingPrice = 900,
  double? mrp = 1000,
  double? costPrice = 600,
}) {
  return VarianteModel(
    varianteId: 'v1',
    productId: 'p1',
    sellingPrice: sellingPrice,
    mrp: mrp,
    costPrice: costPrice,
    stockQty: 10,
    createdAt: '2026-08-21T00:00:00.000',
  );
}

void main() {
  group('PriceOverrideReason', () {
    test('offers exactly the agreed reasons, in order', () {
      expect(
        PriceOverrideReason.all.map((r) => r.label).toList(),
        equals([
          'Customer Negotiation',
          'Special Customer Price',
          'Clearance',
          'Damaged Packaging',
          'Manager Approved',
          'Pricing Correction',
          'Other',
        ]),
      );
    });

    test('only Other requires a note', () {
      for (final reason in PriceOverrideReason.all) {
        expect(
          reason.requiresNote,
          reason.code == 'other',
          reason: reason.code,
        );
      }
    });

    test('codes are unique and stable', () {
      final codes = PriceOverrideReason.all.map((r) => r.code).toList();
      expect(codes.toSet().length, equals(codes.length));
      expect(codes, contains('customer_negotiation'));
      expect(codes, contains('pricing_correction'));
    });

    test('byCode tolerates null and unknown', () {
      expect(PriceOverrideReason.byCode(null), isNull);
      expect(PriceOverrideReason.byCode('retired_reason'), isNull);
      expect(
        PriceOverrideReason.byCode('clearance'),
        same(PriceOverrideReason.clearance),
      );
    });

    test('labelFor falls back to the raw stored value', () {
      expect(PriceOverrideReason.labelFor('clearance'), equals('Clearance'));
      expect(PriceOverrideReason.labelFor('legacy_x'), equals('legacy_x'));
    });

    test('isReasonComplete enforces the note only where required', () {
      expect(PriceOverrideService.isReasonComplete(null, 'anything'), isFalse);
      expect(
        PriceOverrideService.isReasonComplete(
            PriceOverrideReason.clearance, null),
        isTrue,
      );
      expect(
        PriceOverrideService.isReasonComplete(PriceOverrideReason.other, null),
        isFalse,
      );
      expect(
        PriceOverrideService.isReasonComplete(PriceOverrideReason.other, '   '),
        isFalse,
      );
      expect(
        PriceOverrideService.isReasonComplete(
            PriceOverrideReason.other, 'water damage'),
        isTrue,
      );
    });
  });

  group('PriceOverrideService.validate', () {
    PriceOverrideValidation check(double newPrice, {double current = 900}) =>
        PriceOverrideService.validate(
          variant: _variant(),
          newPrice: newPrice,
          currentPrice: current,
        );

    test('a normal discount below MRP and above cost is OK', () {
      final r = check(850);
      expect(r.verdict, PriceOverrideVerdict.ok);
      expect(r.isAllowed, isTrue);
      expect(r.needsConfirmation, isFalse);
    });

    test('exactly MRP is allowed', () {
      expect(check(1000).verdict, PriceOverrideVerdict.ok);
    });

    test('above MRP is BLOCKED, never confirmable', () {
      final r = check(1000.01);
      expect(r.verdict, PriceOverrideVerdict.blocked);
      expect(r.isBlocked, isTrue);
      expect(r.message, contains('MRP'));
    });

    test('zero is blocked', () {
      expect(check(0).verdict, PriceOverrideVerdict.blocked);
    });

    test('negative is blocked', () {
      expect(check(-50).verdict, PriceOverrideVerdict.blocked);
    });

    // Ordering matters: a negative price must not surface as a soft
    // "below cost - are you sure?" the cashier can click straight through.
    test('zero/negative is blocked rather than warned, even though it is also '
        'below cost', () {
      expect(check(-1).verdict, PriceOverrideVerdict.blocked);
      expect(check(-1).message, contains('greater than zero'));
    });

    test('exactly cost price is allowed without a warning', () {
      expect(check(600).verdict, PriceOverrideVerdict.ok);
    });

    test('below cost WARNS but is allowed', () {
      final r = check(500);
      expect(r.verdict, PriceOverrideVerdict.belowCost);
      expect(r.needsConfirmation, isTrue);
      expect(r.isAllowed, isTrue);
      expect(r.isBlocked, isFalse);
      expect(r.message, contains('below cost'));
    });

    test('same as the current charged price is a no-op, blocked', () {
      expect(check(850, current: 850).verdict, PriceOverrideVerdict.blocked);
    });

    test('reverting to catalogue price is allowed when currently overridden',
        () {
      // Line currently charging 850; typing 900 (catalogue) is a legitimate
      // revert, not a no-op.
      expect(check(900, current: 850).verdict, PriceOverrideVerdict.ok);
    });

    test('no MRP on the variant means no ceiling', () {
      final r = PriceOverrideService.validate(
        variant: _variant(mrp: null),
        newPrice: 5000,
        currentPrice: 900,
      );
      expect(r.verdict, PriceOverrideVerdict.ok);
    });

    test('zero MRP is treated as "not set", not as a zero ceiling', () {
      final r = PriceOverrideService.validate(
        variant: _variant(mrp: 0),
        newPrice: 1200,
        currentPrice: 900,
      );
      expect(r.verdict, PriceOverrideVerdict.ok);
    });

    test('no cost price means no below-cost warning', () {
      final r = PriceOverrideService.validate(
        variant: _variant(costPrice: null),
        newPrice: 10,
        currentPrice: 900,
      );
      expect(r.verdict, PriceOverrideVerdict.ok);
    });
  });

  group('CartItemModel price override', () {
    CartItemModel line({
      double price = 850,
      double? originalPrice = 900,
      String? reason = 'clearance',
      String? note,
      int qty = 1,
      double gstRate = 18,
      bool taxInclusive = false,
    }) {
      return CartItemModel.create(
        cartItemId: 'c1',
        variantId: 'v1',
        productId: 'p1',
        productName: 'Denim Shirt',
        price: price,
        qty: qty,
        gstRate: gstRate,
        taxInclusive: taxInclusive,
        originalPrice: originalPrice,
        overrideReason: reason,
        overrideNote: note,
      );
    }

    test('null originalPrice means not overridden', () {
      final normal = line(price: 900, originalPrice: null, reason: null);
      expect(normal.isPriceOverridden, isFalse);
      expect(normal.originalPrice, isNull);
      expect(normal.overrideReason, isNull);
    });

    test('an overridden line reports itself as overridden', () {
      expect(line().isPriceOverridden, isTrue);
      expect(line().originalPrice, equals(900));
      expect(line().overrideReason, equals('clearance'));
    });

    // The whole point of the design: `price` stays the charged figure, so the
    // per-line money is computed from the OVERRIDE, not the catalogue price.
    test('line money is computed from the overridden price', () {
      final l = line(price: 850, qty: 2, gstRate: 18);
      expect(l.price, equals(850));
      expect(l.taxableAmount, equals(1700.0)); // 850 * 2, exclusive
      expect(l.gstAmount, equals(306.0)); // 1700 * 0.18
      expect(l.cgstAmount, equals(153.0));
      expect(l.sgstAmount, equals(153.0));
    });

    test('tax-inclusive mode extracts GST from the overridden price', () {
      final l = line(price: 850, qty: 1, gstRate: 18, taxInclusive: true);
      expect(l.taxableAmount, closeTo(720.34, 0.01)); // 850 / 1.18
      expect(l.gstAmount, closeTo(129.66, 0.01));
      expect(l.total, equals(850.0));
    });

    test('override survives a toMap/fromMap round trip', () {
      final restored = CartItemModel.fromMap(
        line(note: 'display piece').toMap(),
      );
      expect(restored.price, equals(850));
      expect(restored.originalPrice, equals(900));
      expect(restored.overrideReason, equals('clearance'));
      expect(restored.overrideNote, equals('display piece'));
      expect(restored.isPriceOverridden, isTrue);
    });

    test('fromMap tolerates a cart row saved before the fields existed', () {
      final legacy = {
        'cartItemId': 'c1',
        'variantId': 'v1',
        'productId': 'p1',
        'productName': 'Old Line',
        'price': 900.0,
        'qty': 1,
        'total': 900.0,
        'addedAt': '2026-01-01T00:00:00.000',
      };
      final restored = CartItemModel.fromMap(legacy);
      expect(restored.isPriceOverridden, isFalse);
      expect(restored.originalPrice, isNull);
    });
  });

  group('SaleItemModel price override audit', () {
    SaleItemModel sold({double? originalPrice = 900}) =>
        SaleItemModel.fromCalculated(
          saleId: 's1',
          varianteId: 'v1',
          productId: 'p1',
          productName: 'Denim Shirt',
          price: 850,
          qty: 1,
          discountAmount: 0,
          gstRate: 18,
          taxableAmount: 850,
          gstAmount: 153,
          total: 1003,
          costPrice: 600,
          originalPrice: originalPrice,
          overrideReason: 'clearance',
          overrideNote: null,
        );

    test('fromCalculated carries the audit through', () {
      final s = sold();
      expect(s.price, equals(850)); // charged
      expect(s.originalPrice, equals(900)); // catalogue
      expect(s.overrideReason, equals('clearance'));
      expect(s.isPriceOverridden, isTrue);
    });

    test('delta per unit is what the override gave away', () {
      expect(sold().overrideDeltaPerUnit, equals(50));
    });

    test('a non-overridden line has zero delta and no audit', () {
      final s = sold(originalPrice: null);
      expect(s.isPriceOverridden, isFalse);
      expect(s.overrideDeltaPerUnit, equals(0));
    });

    // `SaleItemModel.create` (the factory return_service uses) reads
    // AppConfig.isRestaurant for its tax mode, so it cannot be constructed
    // without Hive booted. The audit plumbing it passes through is the plain
    // constructor, which is testable — this covers the shape of a return line.
    test('a return line mirrors the original line audit', () {
      final returnLine = SaleItemModel(
        saleItemId: 'ri1',
        saleId: 'RTN_1',
        varianteId: 'v1',
        productId: 'p1',
        productName: 'Denim Shirt',
        price: 850,
        qty: 1,
        total: 1003,
        costPrice: 600,
        originalPrice: 900,
        overrideReason: 'customer_negotiation',
        overrideNote: 'regular',
      );
      expect(returnLine.price, equals(850));
      expect(returnLine.originalPrice, equals(900));
      expect(returnLine.overrideReason, equals('customer_negotiation'));
      expect(returnLine.overrideNote, equals('regular'));
      expect(returnLine.isPriceOverridden, isTrue);
    });

    test('audit survives a toMap/fromMap round trip', () {
      final restored = SaleItemModel.fromMap(sold().toMap());
      expect(restored.price, equals(850));
      expect(restored.originalPrice, equals(900));
      expect(restored.overrideReason, equals('clearance'));
    });

    test('fromMap tolerates a sale line saved before the fields existed', () {
      final legacy = {
        'saleItemId': 'si1',
        'saleId': 's1',
        'varianteId': 'v1',
        'productId': 'p1',
        'price': 900.0,
        'qty': 1,
        'total': 1062.0,
      };
      final restored = SaleItemModel.fromMap(legacy);
      expect(restored.isPriceOverridden, isFalse);
      expect(restored.overrideDeltaPerUnit, equals(0));
    });

    // Requirement 9: a refund must return what was taken. The return line is
    // built from the SALE line's price, so this is the figure that matters.
    test('the stored charged price is what a return would refund', () {
      final s = sold();
      const returnQty = 1;
      expect(s.price * returnQty, equals(850)); // not the catalogue 900
    });
  });
}
