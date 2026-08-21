import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/cart_model_202.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/domain/services/restaurant/cart_calculation_service.dart';
import 'package:billberrylite/domain/services/restaurant/tax_breakdown.dart';
import 'package:billberrylite/domain/services/retail/line_discount_reason.dart';
import 'package:billberrylite/domain/services/retail/line_discount_service.dart';

/// `TaxFeature.enabled` reads `BusinessDetailsRepository.isTaxEnabled`, which hits
/// a Hive box. Same fake the engine's own tests use.
class _FakeBusinessDetailsRepository extends BusinessDetailsRepository {
  @override
  bool get isTaxEnabled => true;
}

/// Retail line-item discount: the reason vocabulary, the validation rules, and
/// the money maths through `CartCalculationService`.
///
/// The approved order of operations, which every calculation test below pins:
///   catalogue price -> price override -> LINE discount -> BILL discount on the
///   remainder -> tax
void main() {
  setUpAll(() {
    if (!locator.isRegistered<BusinessDetailsRepository>()) {
      locator.registerSingleton<BusinessDetailsRepository>(
          _FakeBusinessDetailsRepository());
    }
  });

  VarianteModel variant({double? costPrice = 600, double? mrp = 1000}) =>
      VarianteModel(
        varianteId: 'v1',
        productId: 'p1',
        sellingPrice: 1000,
        mrp: mrp,
        costPrice: costPrice,
        stockQty: 50,
        createdAt: '2026-08-21T00:00:00.000',
      );

  CalcLine line(
    double price,
    int qty, {
    double rate = 0.18,
    double lineDiscount = 0,
  }) =>
      CalcLine(
        price: price,
        quantity: qty,
        taxRate: rate,
        lineDiscount: lineDiscount,
      );

  CartCalculationService calc({
    required List<CalcLine> lines,
    DiscountType discountType = DiscountType.amount,
    double discountValue = 0,
    bool inclusive = false,
    double loyalty = 0,
  }) =>
      CartCalculationService.fromLines(
        lines: lines,
        discountType: discountType,
        discountValue: discountValue,
        isTaxInclusive: inclusive,
        discountOnItems: false,
        loyaltyRedemption: loyalty,
      );

  // ==========================================================================
  group('LineDiscountReason', () {
    test('offers exactly the agreed reasons, in order', () {
      expect(
        LineDiscountReason.all.map((r) => r.label).toList(),
        equals([
          'Customer Negotiation',
          'Promotional Discount',
          'Clearance',
          'Manager Approved',
          'Damaged Packaging',
          'Other',
        ]),
      );
    });

    test('only Other requires a note', () {
      for (final r in LineDiscountReason.all) {
        expect(r.requiresNote, r.code == 'other', reason: r.code);
      }
    });

    test('codes are unique, and byCode tolerates null/unknown', () {
      final codes = LineDiscountReason.all.map((r) => r.code).toList();
      expect(codes.toSet().length, equals(codes.length));
      expect(LineDiscountReason.byCode(null), isNull);
      expect(LineDiscountReason.byCode('retired'), isNull);
      expect(LineDiscountReason.byCode('clearance'),
          same(LineDiscountReason.clearance));
    });

    test('labelFor falls back to the raw stored value', () {
      expect(LineDiscountReason.labelFor('clearance'), 'Clearance');
      expect(LineDiscountReason.labelFor('legacy_x'), 'legacy_x');
    });

    test('isReasonComplete enforces the note only where required', () {
      expect(LineDiscountService.isReasonComplete(null, 'x'), isFalse);
      expect(
          LineDiscountService.isReasonComplete(
              LineDiscountReason.clearance, null),
          isTrue);
      expect(
          LineDiscountService.isReasonComplete(LineDiscountReason.other, '  '),
          isFalse);
      expect(
          LineDiscountService.isReasonComplete(
              LineDiscountReason.other, 'water damage'),
          isTrue);
    });
  });

  // ==========================================================================
  group('LineDiscountService.resolveAmount', () {
    test('percentage is taken off the gross', () {
      expect(
        LineDiscountService.resolveAmount(
            type: DiscountType.percentage, value: 10, gross: 900),
        closeTo(90, 0.005),
      );
    });

    // The whole reason type+value are persisted rather than only the amount.
    test('percentage re-resolves with quantity, so 10% stays 10%', () {
      expect(
        LineDiscountService.resolveAmount(
            type: DiscountType.percentage, value: 10, gross: 900 * 5),
        closeTo(450, 0.005),
      );
    });

    test('flat amount is unaffected by quantity', () {
      for (final gross in [900.0, 4500.0]) {
        expect(
          LineDiscountService.resolveAmount(
              type: DiscountType.amount, value: 90, gross: gross),
          closeTo(90, 0.005),
        );
      }
    });

    test('capped at the line, never negative', () {
      expect(
        LineDiscountService.resolveAmount(
            type: DiscountType.amount, value: 5000, gross: 300),
        closeTo(300, 0.005),
      );
      expect(
        LineDiscountService.resolveAmount(
            type: DiscountType.amount, value: -50, gross: 300),
        0,
      );
      expect(
        LineDiscountService.resolveAmount(
            type: DiscountType.percentage, value: 10, gross: 0),
        0,
      );
    });
  });

  // ==========================================================================
  group('LineDiscountService.validate', () {
    LineDiscountValidation check(
      double value, {
      DiscountType type = DiscountType.percentage,
      double unit = 900,
      int qty = 1,
      double? cost = 600,
    }) =>
        LineDiscountService.validate(
          variant: variant(costPrice: cost),
          type: type,
          value: value,
          chargedUnitPrice: unit,
          qty: qty,
        );

    test('a normal percentage above cost is OK', () {
      final r = check(10);
      expect(r.verdict, LineDiscountVerdict.ok);
      expect(r.amount, closeTo(90, 0.005));
      expect(r.effectiveUnitPrice, closeTo(810, 0.005));
    });

    test('zero is OK and means "clear"', () {
      expect(check(0).verdict, LineDiscountVerdict.ok);
      expect(check(0).amount, 0);
    });

    test('negative is blocked', () {
      final r = check(-5);
      expect(r.verdict, LineDiscountVerdict.blocked);
      expect(r.message, contains('negative'));
    });

    test('percentage over 100 is blocked', () {
      final r = check(101);
      expect(r.verdict, LineDiscountVerdict.blocked);
      expect(r.message, contains('100%'));
    });

    // Zero/negative final price stays invalid — refused, not clamped, so the
    // cashier notices rather than getting a silent zero.
    test('100% is blocked because the final price would be zero', () {
      final r = check(100);
      expect(r.verdict, LineDiscountVerdict.blocked);
      expect(r.message, contains('above zero'));
    });

    test('a flat discount at or above the line total is blocked', () {
      expect(check(900, type: DiscountType.amount).verdict,
          LineDiscountVerdict.blocked);
      expect(check(1500, type: DiscountType.amount).verdict,
          LineDiscountVerdict.blocked);
    });

    test('below cost WARNS but is allowed', () {
      // 900 - 40% = 540, under the 600 cost.
      final r = check(40);
      expect(r.verdict, LineDiscountVerdict.belowCost);
      expect(r.needsConfirmation, isTrue);
      expect(r.isAllowed, isTrue);
      expect(r.isBlocked, isFalse);
      expect(r.message, contains('below the'));
    });

    test('exactly at cost is OK, not a warning', () {
      // 900 - 300 = 600 == cost
      final r = check(300, type: DiscountType.amount);
      expect(r.verdict, LineDiscountVerdict.ok);
    });

    // Ordering: a hard block must not surface as a clickable below-cost prompt.
    test('an over-line discount is blocked, not warned, though also below cost',
        () {
      final r = check(2000, type: DiscountType.amount);
      expect(r.verdict, LineDiscountVerdict.blocked);
    });

    test('no cost price means no below-cost warning', () {
      expect(check(90, cost: null).verdict, LineDiscountVerdict.ok);
    });

    // Below-cost is measured PER UNIT, so quantity must not change the verdict.
    test('the below-cost check is per unit, not per line', () {
      expect(check(40, qty: 1).verdict, LineDiscountVerdict.belowCost);
      expect(check(40, qty: 5).verdict, LineDiscountVerdict.belowCost);
      expect(check(10, qty: 5).verdict, LineDiscountVerdict.ok);
    });

    test('below-cost measured AFTER a price override', () {
      // Override already took it to 650; a further 10% lands at 585 < 600.
      final r = check(10, unit: 650);
      expect(r.verdict, LineDiscountVerdict.belowCost);
      expect(r.effectiveUnitPrice, closeTo(585, 0.005));
    });
  });

  // ==========================================================================
  group('Engine — the approved worked example', () {
    // catalogue 1000 -> override 900 -> line 10% (90) -> bill 5% of 810 (40.50)
    // -> taxable 769.50, total discount 130.50
    test('override 900, line 10%, bill 5% gives taxable 769.50', () {
      final c = calc(
        lines: [line(900, 1, lineDiscount: 90)],
        discountType: DiscountType.percentage,
        discountValue: 5,
      );

      expect(c.itemTotal, closeTo(900, 0.005)); // gross, before all discount
      expect(c.taxableAmount, closeTo(769.50, 0.005));
      expect(c.discountAmount, closeTo(130.50, 0.005));
      expect(c.lineResults.single.lineDiscountAmount, closeTo(90, 0.005));
      expect(c.lineResults.single.billDiscountAmount, closeTo(40.50, 0.005));
      expect(c.totalGST, closeTo(138.51, 0.01)); // 769.50 * 0.18
    });

    // The bill % must NOT be taken against the original gross.
    test('the bill discount applies to the NET, not the original gross', () {
      final c = calc(
        lines: [line(900, 1, lineDiscount: 90)],
        discountType: DiscountType.percentage,
        discountValue: 5,
      );
      // 5% of 810 = 40.50, not 5% of 900 = 45.
      expect(c.lineResults.single.billDiscountAmount, closeTo(40.50, 0.005));
      expect(c.lineResults.single.billDiscountAmount, isNot(closeTo(45, 0.005)));
    });
  });

  // ==========================================================================
  group('Engine — line discount maths', () {
    test('percentage line discount, tax exclusive', () {
      final c = calc(lines: [line(1000, 1, lineDiscount: 100)]);
      expect(c.taxableAmount, closeTo(900, 0.005));
      expect(c.totalGST, closeTo(162, 0.005));
      expect(c.discountAmount, closeTo(100, 0.005));
      expect(c.grandTotal, closeTo(1062, 0.02));
    });

    test('flat line discount, tax inclusive', () {
      // 1180 incl 18% less 180 -> 1000 gross incl -> base 847.46, gst 152.54
      final c = calc(lines: [line(1180, 1, lineDiscount: 180)], inclusive: true);
      expect(c.taxableAmount, closeTo(847.46, 0.01));
      expect(c.totalGST, closeTo(152.54, 0.01));
      expect(c.grandTotal, closeTo(1000, 0.02));
    });

    test('quantity multiplies the line, discount already resolved for it', () {
      // 10% of 900x5 = 450, so net 4050.
      final c = calc(lines: [line(900, 5, lineDiscount: 450)]);
      expect(c.itemTotal, closeTo(4500, 0.005));
      expect(c.taxableAmount, closeTo(4050, 0.005));
      expect(c.lineResults.single.lineDiscountAmount, closeTo(450, 0.005));
    });

    test('a line discount is capped at its line', () {
      final c = calc(lines: [line(300, 1, lineDiscount: 5000)]);
      expect(c.lineResults.single.lineDiscountAmount, closeTo(300, 0.005));
      expect(c.taxableAmount, 0);
      expect(c.totalGST, 0);
      expect(c.grandTotal, closeTo(0, 0.02));
    });

    test('every line fully discounted gives zeros, not NaN', () {
      final c = calc(
        lines: [line(500, 1, lineDiscount: 500), line(300, 1, lineDiscount: 300)],
        discountType: DiscountType.percentage,
        discountValue: 10,
      );
      expect(c.taxableAmount.isNaN, isFalse);
      expect(c.grandTotal.isNaN, isFalse);
      expect(c.taxableAmount, 0);
      expect(c.discountAmount, closeTo(800, 0.005));
    });

    test('an over-large bill discount is capped at the NET, not the gross', () {
      final c = calc(
        lines: [line(1000, 1, lineDiscount: 400)],
        discountValue: 5000,
      );
      expect(c.taxableAmount, 0);
      expect(c.taxableAmount >= 0, isTrue);
      expect(c.discountAmount, closeTo(1000, 0.005)); // 400 line + 600 bill
    });
  });

  // ==========================================================================
  group('Engine — mixed rates and proration', () {
    test('a line discount does not move another rate\'s taxable base', () {
      final c = calc(lines: [
        line(1000, 1, rate: 0.18, lineDiscount: 400),
        line(1000, 1, rate: 0.05),
      ]);

      final l18 = c.lineResults[0];
      final l05 = c.lineResults[1];
      expect(l18.taxableAmount, closeTo(600, 0.005));
      expect(l18.gstAmount, closeTo(108, 0.005));
      expect(l05.taxableAmount, closeTo(1000, 0.005));
      expect(l05.gstAmount, closeTo(50, 0.005));
    });

    test('the order discount prorates by NET weight, not gross', () {
      // nets 600 and 1000 -> total 1600; bill 160 -> factor 0.9
      final c = calc(
        lines: [
          line(1000, 1, rate: 0.18, lineDiscount: 400),
          line(1000, 1, rate: 0.05),
        ],
        discountValue: 160,
      );
      expect(c.lineResults[0].taxableAmount, closeTo(540, 0.005));
      expect(c.lineResults[1].taxableAmount, closeTo(900, 0.005));
      expect(c.taxableAmount, closeTo(1440, 0.01));
    });

    test('two lines at the same rate behave the same', () {
      final c = calc(lines: [
        line(600, 1, lineDiscount: 100),
        line(400, 1, lineDiscount: 50),
      ]);
      expect(c.taxableAmount, closeTo(850, 0.005));
      expect(c.discountAmount, closeTo(150, 0.005));
    });

    // Proves the engine and TaxBreakdown agree on net weights — if one used
    // gross the printed per-rate table would disagree with the line amounts.
    test('engine taxable total matches TaxBreakdown, mixed rates', () {
      final lines = [
        line(1000, 1, rate: 0.18, lineDiscount: 400),
        line(1000, 1, rate: 0.05),
      ];
      final c = calc(lines: lines, discountValue: 160);

      final taxLines = TaxBreakdown.computeWithLineDiscounts(
        items: [
          (gross: 1000.0, lineDiscount: 400.0, ratePercent: 18.0),
          (gross: 1000.0, lineDiscount: 0.0, ratePercent: 5.0),
        ],
        billDiscount: 160,
        isTaxInclusive: false,
      );

      final taxableSum = taxLines.fold<double>(0, (s, l) => s + l.taxable);
      expect(taxableSum, closeTo(c.taxableAmount, 0.02));
    });
  });

  // ==========================================================================
  group('Engine — loyalty interaction', () {
    // The single highest-risk regression: the loyalty rebuild re-lists every
    // CalcLineResult field, and a defaulted lineDiscountAmount there would zero
    // every line discount but ONLY on bills where points were redeemed.
    test('line discounts are NOT scaled by a loyalty redemption', () {
      final withoutLoyalty = calc(lines: [line(1000, 1, lineDiscount: 200)]);
      final withLoyalty =
          calc(lines: [line(1000, 1, lineDiscount: 200)], loyalty: 100);

      expect(withoutLoyalty.lineResults.single.lineDiscountAmount,
          closeTo(200, 0.005));
      expect(withLoyalty.lineResults.single.lineDiscountAmount,
          closeTo(200, 0.005));
      // The taxable base DOES drop by the redemption.
      expect(withLoyalty.taxableAmount, closeTo(700, 0.01));
    });

    test('the sum of line discounts still equals the bill discount', () {
      final c = calc(
        lines: [
          line(1000, 2, rate: 0.18, lineDiscount: 300),
          line(750, 1, rate: 0.05, lineDiscount: 50),
          line(499.99, 3, rate: 0.12),
        ],
        discountType: DiscountType.percentage,
        discountValue: 7.5,
        loyalty: 120,
      );

      final sumLines =
          c.lineResults.fold<double>(0, (s, l) => s + l.discountAmount);
      expect(sumLines, closeTo(c.discountAmount, 0.02));
    });

    test('each line discount is a subset of that line total discount', () {
      final c = calc(
        lines: [
          line(1000, 1, lineDiscount: 400),
          line(1000, 1, rate: 0.05),
        ],
        discountValue: 160,
        loyalty: 50,
      );
      for (final l in c.lineResults) {
        expect(l.lineDiscountAmount, lessThanOrEqualTo(l.discountAmount + 0.01));
        expect(l.billDiscountAmount, greaterThanOrEqualTo(-0.01));
      }
    });
  });

  // ==========================================================================
  // The contract that keeps restaurant safe. Restaurant never sets lineDiscount,
  // so every new expression must reduce EXACTLY to the old one — asserted with
  // `==`, not closeTo.
  group('Restaurant bit-identity (lineDiscount == 0)', () {
    test('both engine branches are unchanged with no line discount', () {
      for (final onItems in [false, true]) {
        for (final inclusive in [false, true]) {
          for (final type in DiscountType.values) {
            for (final value in [0.0, 10.0, 150.0]) {
              final lines = [
                CalcLine(price: 250, quantity: 2, taxRate: 0.05),
                CalcLine(price: 99.99, quantity: 3, taxRate: 0.18),
                CalcLine(price: 500, quantity: 1, taxRate: 0),
              ];

              final explicitZero = CartCalculationService.fromLines(
                lines: lines
                    .map((l) => CalcLine(
                          price: l.price,
                          quantity: l.quantity,
                          taxRate: l.taxRate,
                          lineDiscount: 0,
                        ))
                    .toList(),
                discountType: type,
                discountValue: value,
                isTaxInclusive: inclusive,
                discountOnItems: onItems,
              );

              final defaulted = CartCalculationService.fromLines(
                lines: lines,
                discountType: type,
                discountValue: value,
                isTaxInclusive: inclusive,
                discountOnItems: onItems,
              );

              final ctx = 'onItems=$onItems incl=$inclusive $type $value';
              expect(defaulted.itemTotal, explicitZero.itemTotal, reason: ctx);
              expect(defaulted.taxableAmount, explicitZero.taxableAmount,
                  reason: ctx);
              expect(defaulted.discountAmount, explicitZero.discountAmount,
                  reason: ctx);
              expect(defaulted.totalGST, explicitZero.totalGST, reason: ctx);
              expect(defaulted.grandTotal, explicitZero.grandTotal, reason: ctx);
              for (var i = 0; i < lines.length; i++) {
                expect(defaulted.lineResults[i].lineDiscountAmount, 0.0,
                    reason: ctx);
                expect(defaulted.lineResults[i].discountAmount,
                    explicitZero.lineResults[i].discountAmount, reason: ctx);
                expect(defaulted.lineResults[i].taxableAmount,
                    explicitZero.lineResults[i].taxableAmount, reason: ctx);
              }
            }
          }
        }
      }
    });

    test('discountAmount still equals line + bill share with no line discount',
        () {
      final c = calc(lines: [line(1000, 1)], discountValue: 100);
      expect(c.lineResults.single.lineDiscountAmount, 0.0);
      expect(c.lineResults.single.billDiscountAmount,
          closeTo(c.lineResults.single.discountAmount, 0.005));
    });
  });

  // ==========================================================================
  group('Rounding', () {
    test('a fractional percentage lands on 2 decimals through the bill', () {
      final c = calc(
        lines: [line(333.33, 3, lineDiscount: 33.33)],
        discountType: DiscountType.percentage,
        discountValue: 7.5,
      );
      // Engine keeps full precision; the retail wrapper rounds. Assert the
      // relationship rather than a magic number.
      expect(c.taxableAmount, greaterThan(0));
      expect(c.discountAmount,
          closeTo(33.33 + (333.33 * 3 - 33.33) * 0.075, 0.01));
    });

    test('per-line taxable amounts sum to the bill taxable', () {
      final c = calc(
        lines: [
          line(199.99, 3, rate: 0.18, lineDiscount: 49.99),
          line(88.88, 7, rate: 0.05, lineDiscount: 11.11),
          line(1234.56, 1, rate: 0.12),
        ],
        discountType: DiscountType.percentage,
        discountValue: 3.33,
      );
      final sum = c.lineResults.fold<double>(0, (s, l) => s + l.taxableAmount);
      expect(sum, closeTo(c.taxableAmount, 0.01));
    });
  });

  // ==========================================================================
  group('CartItemModel line-discount persistence', () {
    CartItemModel row({
      double price = 900,
      int qty = 1,
      String? type = 'percentage',
      double? value = 10,
      double? amount = 90,
      String? reason = 'clearance',
      String? note,
    }) =>
        CartItemModel.create(
          cartItemId: 'c1',
          variantId: 'v1',
          productId: 'p1',
          productName: 'Denim Shirt',
          price: price,
          qty: qty,
          gstRate: 18,
          originalPrice: 1000,
          overrideReason: 'clearance',
          lineDiscountType: type,
          lineDiscountValue: value,
          lineDiscountAmount: amount,
          lineDiscountReason: reason,
          lineDiscountNote: note,
        );

    test('hasLineDiscount, grossAmount and netAmount', () {
      final r = row(qty: 2, amount: 180);
      expect(r.hasLineDiscount, isTrue);
      expect(r.grossAmount, closeTo(1800, 0.005));
      expect(r.netAmount, closeTo(1620, 0.005));
    });

    test('a row with no line discount reports none', () {
      final r = row(type: null, value: null, amount: null, reason: null);
      expect(r.hasLineDiscount, isFalse);
      expect(r.netAmount, closeTo(r.grossAmount, 0.005));
    });

    test('netAmount never goes negative', () {
      expect(row(price: 100, amount: 5000).netAmount, 0);
    });

    test('the price override survives alongside the discount', () {
      final r = row();
      expect(r.isPriceOverridden, isTrue);
      expect(r.originalPrice, closeTo(1000, 0.005));
      expect(r.price, closeTo(900, 0.005));
      expect(r.lineDiscountAmount, closeTo(90, 0.005));
    });

    test('round trips through toMap/fromMap', () {
      final restored = CartItemModel.fromMap(row(note: 'shop soiled').toMap());
      expect(restored.lineDiscountType, 'percentage');
      expect(restored.lineDiscountValue, closeTo(10, 0.005));
      expect(restored.lineDiscountAmount, closeTo(90, 0.005));
      expect(restored.lineDiscountReason, 'clearance');
      expect(restored.lineDiscountNote, 'shop soiled');
      // and the override is still there
      expect(restored.originalPrice, closeTo(1000, 0.005));
    });

    // Requirement 12: legacy rows must read as "no line discount".
    test('a cart row saved before the feature reads as undiscounted', () {
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
      expect(restored.hasLineDiscount, isFalse);
      expect(restored.lineDiscountAmount, isNull);
      expect(restored.lineDiscountType, isNull);
    });

    // The cart row's `total` is deliberately GROSS, mirroring the receipt's
    // Amount column. The discount shows as its own figure beside it.
    test('total stays gross — the line discount is not folded into it', () {
      final r = row(qty: 2, amount: 180);
      expect(r.total, closeTo(1800, 0.01));
    });
  });
}
