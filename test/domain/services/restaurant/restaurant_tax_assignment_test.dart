import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/common/taxmodel_314.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/domain/services/restaurant/restaurant_tax_assignment.dart';

void main() {
  final gst5 = Tax(id: 'gst5', taxname: 'GST', taxperecentage: 5);
  final gst12 = Tax(id: 'gst12', taxname: 'GST 12', taxperecentage: 12);
  final cgst = Tax(id: 'cgst', taxname: 'CGST', taxperecentage: 2.5);
  final sgst = Tax(id: 'sgst', taxname: 'SGST', taxperecentage: 2.5);
  final pst7 = Tax(id: 'pst7', taxname: 'PST', taxperecentage: 7);
  final taxes = [gst5, gst12, cgst, sgst, pst7];
  final rates = RestaurantTaxAssignment.ratesById(taxes);

  Items item({List<String>? ids, double? rate, String name = 'Dish'}) =>
      Items(id: name, name: name, taxIds: ids, taxRate: rate);

  group('planApply', () {
    test('untaxed item gets the tax', () {
      final p = RestaurantTaxAssignment.planApply(
          currentIds: null, currentRate: null,
          taxId: 'gst5', taxRate: 0.05, rates: rates);
      expect(p.outcome, TaxApplyOutcome.applied);
      expect(p.ids, ['gst5']);
      expect(p.rate, closeTo(0.05, 1e-12));
    });

    test('imported 5% + apply GST 5% links it, stays 5% (not 10%)', () {
      final p = RestaurantTaxAssignment.planApply(
          currentIds: null, currentRate: 0.05,
          taxId: 'gst5', taxRate: 0.05, rates: rates);
      expect(p.outcome, TaxApplyOutcome.linked);
      expect(p.ids, ['gst5']);
      expect(p.rate, closeTo(0.05, 1e-12));
    });

    test('imported 5% + apply PST 7% links GST 5% first, then adds', () {
      final p = RestaurantTaxAssignment.planApply(
          currentIds: const [], currentRate: 0.05,
          taxId: 'pst7', taxRate: 0.07, rates: rates);
      expect(p.outcome, TaxApplyOutcome.applied);
      expect(p.ids, ['gst5', 'pst7']);
      expect(p.rate, closeTo(0.12, 1e-12));
    });

    test('imported rate with no matching tax is skipped, nothing guessed', () {
      final p = RestaurantTaxAssignment.planApply(
          currentIds: null, currentRate: 0.09,
          taxId: 'gst5', taxRate: 0.05, rates: rates);
      expect(p.outcome, TaxApplyOutcome.unlinkedRate);
      expect(p.ids, isNull);
      expect(p.rate, isNull);
    });

    test('same tax twice is a no-op', () {
      final p = RestaurantTaxAssignment.planApply(
          currentIds: const ['gst5'], currentRate: 0.05,
          taxId: 'gst5', taxRate: 0.05, rates: rates);
      expect(p.outcome, TaxApplyOutcome.alreadyApplied);
    });

    test('two taxes allowed (e.g. GST + PST), a third refused', () {
      final two = RestaurantTaxAssignment.planApply(
          currentIds: const ['gst5'], currentRate: 0.05,
          taxId: 'pst7', taxRate: 0.07, rates: rates);
      expect(two.outcome, TaxApplyOutcome.applied);
      expect(two.rate, closeTo(0.12, 1e-12));

      final three = RestaurantTaxAssignment.planApply(
          currentIds: const ['gst5', 'pst7'], currentRate: 0.12,
          taxId: 'gst12', taxRate: 0.12, rates: rates);
      expect(three.outcome, TaxApplyOutcome.atLimit);
    });
  });

  group('planRemove', () {
    test('removing the only tax clears both fields', () {
      final p = RestaurantTaxAssignment.planRemove(
          currentIds: const ['gst5'], currentRate: 0.05,
          taxId: 'gst5', taxRate: 0.05, rates: rates);
      expect(p, isNotNull);
      expect(p!.ids, isNull);
      expect(p.rate, isNull);
    });

    test('remaining rate is the sum of remaining taxes, not a subtraction',
        () {
      // Stale stored total (0.15) from an old edit: the remainder is PST's
      // real 7%, not 0.15 - 0.05.
      final p = RestaurantTaxAssignment.planRemove(
          currentIds: const ['gst5', 'pst7'], currentRate: 0.15,
          taxId: 'gst5', taxRate: 0.05, rates: rates);
      expect(p!.ids, ['pst7']);
      expect(p.rate, closeTo(0.07, 1e-12));
    });

    test('unknown remaining tax falls back to subtraction', () {
      final p = RestaurantTaxAssignment.planRemove(
          currentIds: const ['gst5', 'gone'], currentRate: 0.13,
          taxId: 'gst5', taxRate: 0.05, rates: rates);
      expect(p!.ids, ['gone']);
      expect(p.rate, closeTo(0.08, 1e-12));
    });

    test('tax not on the item → null', () {
      expect(
          RestaurantTaxAssignment.planRemove(
              currentIds: const ['gst5'], currentRate: 0.05,
              taxId: 'pst7', taxRate: 0.07, rates: rates),
          isNull);
    });
  });

  group('rateAfterTaxEdit', () {
    test('one-tax item follows the new %', () {
      final after = {...rates, 'gst12': 0.18};
      expect(
          RestaurantTaxAssignment.rateAfterTaxEdit(
              ids: const ['gst12'], currentRate: 0.12,
              oldRate: 0.12, newRate: 0.18, ratesAfter: after),
          closeTo(0.18, 1e-12));
    });

    test('two-tax item is the exact sum after the edit', () {
      final after = {...rates, 'pst7': 0.08};
      expect(
          RestaurantTaxAssignment.rateAfterTaxEdit(
              ids: const ['gst5', 'pst7'], currentRate: 0.12,
              oldRate: 0.07, newRate: 0.08, ratesAfter: after),
          closeTo(0.13, 1e-12));
    });

    test('unknown other tax: only the edited share moves', () {
      final after = {...rates, 'gst5': 0.06};
      expect(
          RestaurantTaxAssignment.rateAfterTaxEdit(
              ids: const ['gst5', 'gone'], currentRate: 0.08,
              oldRate: 0.05, newRate: 0.06, ratesAfter: after),
          closeTo(0.09, 1e-12));
    });
  });

  test('itemsUsing finds only items linking the tax', () {
    final items = [
      item(ids: ['gst5'], rate: 0.05, name: 'a'),
      item(ids: ['gst5', 'pst7'], rate: 0.12, name: 'b'),
      item(ids: ['pst7'], rate: 0.07, name: 'c'),
      item(name: 'd'),
    ];
    expect(RestaurantTaxAssignment.itemsUsing('gst5', items).map((i) => i.id),
        ['a', 'b']);
    expect(RestaurantTaxAssignment.itemsUsing('gst12', items), isEmpty);
  });

  group('review', () {
    List<TaxReviewReason> reasons(List<Items> items, {bool india = true}) =>
        RestaurantTaxAssignment.review(items, taxes,
                splitsIntoComponents: india)
            .map((i) => i.reason)
            .toList();

    test('clean items are not flagged', () {
      expect(
          reasons([
            item(ids: ['gst5'], rate: 0.05),
            item(),
            item(ids: ['cgst', 'sgst'], rate: 0.05),
          ]),
          isEmpty);
    });

    test('each problem is flagged once', () {
      expect(reasons([item(rate: 0.05)]), [TaxReviewReason.rateWithoutTax]);
      expect(reasons([item(ids: ['gone'], rate: 0.05)]),
          [TaxReviewReason.missingTax]);
      expect(reasons([item(ids: ['gst12'], rate: 0.10)]),
          [TaxReviewReason.rateMismatch]);
      expect(reasons([item(ids: ['gst5', 'gst12'], rate: 0.17)]),
          [TaxReviewReason.unpairedComponents]);
    });

    test('two taxes outside India are not flagged (e.g. GST + PST)', () {
      expect(reasons([item(ids: ['gst5', 'pst7'], rate: 0.12)], india: false),
          isEmpty);
    });

    test('CGST + SGST pair is fine; unequal or mis-named pairs are not', () {
      final cgst9 = Tax(id: 'c9', taxname: 'CGST', taxperecentage: 9);
      final utgst = Tax(id: 'u', taxname: 'UTGST', taxperecentage: 2.5);
      expect(RestaurantTaxAssignment.isComponentPair([cgst, sgst]), isTrue);
      expect(RestaurantTaxAssignment.isComponentPair([sgst, cgst]), isTrue);
      expect(RestaurantTaxAssignment.isComponentPair([cgst, utgst]), isTrue);
      expect(RestaurantTaxAssignment.isComponentPair([cgst9, sgst]), isFalse);
      expect(RestaurantTaxAssignment.isComponentPair([gst5, pst7]), isFalse);
      expect(RestaurantTaxAssignment.isComponentPair([cgst, cgst]), isFalse);
    });
  });
}
