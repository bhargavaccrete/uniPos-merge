import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/domain/services/retail/expiry_status.dart';

/// Optional expiry date + expiry status for retail.
///
/// Covers the lettered cases from the feature brief: no expiry (A), future
/// expiry (B), expiring soon (C), expired (D), repeat-read stability (E),
/// changing an expiry (F), clearing one (G), and that a decimal-quantity
/// product (H) and an existing pcs product (I) are both unaffected.
///
/// [expiryStatusFor] is pure, so everything here runs without Hive or GetIt.
void main() {
  // A fixed "today" so the tests never drift with the real clock.
  final today = DateTime(2026, 8, 26);

  VarianteModel variant({
    String? expiryDate,
    double stock = 0,
    bool decimal = false,
    String? unit,
  }) =>
      VarianteModel(
        varianteId: 'v1',
        productId: 'p1',
        createdAt: today.toIso8601String(),
        stockQty: stock,
        isDecimalQuantity: decimal,
        unit: unit,
        expiryDate: expiryDate,
      );

  String iso(DateTime d) => dateOnly(d).toIso8601String();

  group('A — no expiry', () {
    test('null expiry reads as noExpiry', () {
      expect(expiryStatusFor(null, asOf: today), RetailExpiryStatus.noExpiry);
    });

    test('a variant with no expiry reports hasExpiry false', () {
      final v = variant();
      expect(v.expiryDate, isNull);
      expect(v.expiryDateTime, isNull);
      expect(v.hasExpiry, isFalse);
    });

    test('noExpiry never alerts', () {
      expect(RetailExpiryStatus.noExpiry.isAlerting, isFalse);
    });

    test('unparseable stored text degrades to null, it does not throw', () {
      final v = variant(expiryDate: 'not-a-date');
      expect(v.expiryDateTime, isNull);
      expect(v.hasExpiry, isFalse);
    });
  });

  group('B — future expiry', () {
    test('well beyond the warning window is valid', () {
      final far = today.add(const Duration(days: 90));
      expect(expiryStatusFor(far, asOf: today), RetailExpiryStatus.valid);
    });

    test('valid does not alert', () {
      expect(RetailExpiryStatus.valid.isAlerting, isFalse);
    });

    test('the date round-trips through the variant unchanged', () {
      final expiry = DateTime(2026, 12, 31);
      final v = variant(expiryDate: iso(expiry));
      expect(v.expiryDateTime, equals(expiry));
      expect(v.hasExpiry, isTrue);
    });

    test('the day AFTER the warning window is still valid', () {
      final justOutside =
          today.add(const Duration(days: kExpiryWarningDays + 1));
      expect(
        expiryStatusFor(justOutside, asOf: today),
        RetailExpiryStatus.valid,
      );
    });
  });

  group('C — expiring soon', () {
    test('inside the warning window', () {
      final soon = today.add(const Duration(days: 3));
      expect(expiryStatusFor(soon, asOf: today),
          RetailExpiryStatus.expiringSoon);
    });

    test('the LAST warning day is inclusive', () {
      final boundary = today.add(const Duration(days: kExpiryWarningDays));
      expect(
        expiryStatusFor(boundary, asOf: today),
        RetailExpiryStatus.expiringSoon,
      );
    });

    test('tomorrow is expiring soon', () {
      expect(
        expiryStatusFor(today.add(const Duration(days: 1)), asOf: today),
        RetailExpiryStatus.expiringSoon,
      );
    });

    test('it alerts', () {
      expect(RetailExpiryStatus.expiringSoon.isAlerting, isTrue);
      expect(RetailExpiryStatus.expiringSoon.isExpired, isFalse);
    });

    test('a custom warning period is honoured', () {
      final in10 = today.add(const Duration(days: 10));
      expect(expiryStatusFor(in10, asOf: today), RetailExpiryStatus.valid);
      expect(
        expiryStatusFor(in10, asOf: today, warningDays: 14),
        RetailExpiryStatus.expiringSoon,
      );
    });
  });

  group('C2 — expiring today', () {
    test('the expiry day itself is its own state', () {
      expect(expiryStatusFor(today, asOf: today),
          RetailExpiryStatus.expiringToday);
    });

    test('time of day does not flip it to expired', () {
      // Same calendar day, late evening — must still read as "today".
      final lateToday = DateTime(2026, 8, 26, 23, 59);
      final asOfMorning = DateTime(2026, 8, 26, 8, 0);
      expect(
        expiryStatusFor(lateToday, asOf: asOfMorning),
        RetailExpiryStatus.expiringToday,
      );
    });

    test('it alerts but is not yet expired', () {
      expect(RetailExpiryStatus.expiringToday.isAlerting, isTrue);
      expect(RetailExpiryStatus.expiringToday.isExpired, isFalse);
    });
  });

  group('D — expired', () {
    test('yesterday is expired', () {
      expect(
        expiryStatusFor(today.subtract(const Duration(days: 1)), asOf: today),
        RetailExpiryStatus.expired,
      );
    });

    test('long past is expired', () {
      expect(
        expiryStatusFor(DateTime(2020, 1, 1), asOf: today),
        RetailExpiryStatus.expired,
      );
    });

    test('it alerts and reports as expired', () {
      expect(RetailExpiryStatus.expired.isAlerting, isTrue);
      expect(RetailExpiryStatus.expired.isExpired, isTrue);
    });
  });

  group('E — repeated evaluation is stable (no duplicate alerts)', () {
    test('the same input yields the same status every time', () {
      final soon = today.add(const Duration(days: 2));
      final results = List.generate(
        10,
        (_) => expiryStatusFor(soon, asOf: today),
      );
      expect(results.toSet(), hasLength(1));
      expect(results.first, RetailExpiryStatus.expiringSoon);
    });

    test('status is a pure function of the date — nothing accumulates', () {
      // The alert list is DERIVED, so "checking" repeatedly cannot create
      // duplicates: there is no stored alert to duplicate.
      final v = variant(expiryDate: iso(today.add(const Duration(days: 1))));
      for (var i = 0; i < 5; i++) {
        expect(
          expiryStatusFor(v.expiryDateTime, asOf: today),
          RetailExpiryStatus.expiringSoon,
        );
      }
    });
  });

  group('F — changing an expiry', () {
    test('moving the date forward drops it out of the alert window', () {
      final soon = variant(expiryDate: iso(today.add(const Duration(days: 2))));
      expect(expiryStatusFor(soon.expiryDateTime, asOf: today),
          RetailExpiryStatus.expiringSoon);

      final moved = soon.copyWith(
        expiryDate: iso(today.add(const Duration(days: 120))),
      );
      expect(expiryStatusFor(moved.expiryDateTime, asOf: today),
          RetailExpiryStatus.valid);
      expect(expiryStatusFor(moved.expiryDateTime, asOf: today).isAlerting,
          isFalse);
    });

    test('an expired item moved to the future stops being expired', () {
      final expired =
          variant(expiryDate: iso(today.subtract(const Duration(days: 5))));
      expect(expiryStatusFor(expired.expiryDateTime, asOf: today),
          RetailExpiryStatus.expired);

      final renewed =
          expired.copyWith(expiryDate: iso(today.add(const Duration(days: 60))));
      expect(expiryStatusFor(renewed.expiryDateTime, asOf: today),
          RetailExpiryStatus.valid);
    });
  });

  group('G — clearing an expiry', () {
    test('clearExpiryDate puts the field back to null', () {
      final withExpiry =
          variant(expiryDate: iso(today.add(const Duration(days: 3))));
      expect(withExpiry.hasExpiry, isTrue);

      final cleared = withExpiry.copyWith(clearExpiryDate: true);
      expect(cleared.expiryDate, isNull);
      expect(cleared.hasExpiry, isFalse);
      expect(expiryStatusFor(cleared.expiryDateTime, asOf: today),
          RetailExpiryStatus.noExpiry);
      expect(expiryStatusFor(cleared.expiryDateTime, asOf: today).isAlerting,
          isFalse);
    });

    test('WITHOUT the flag, copyWith cannot null the field', () {
      // This is why the clear flag exists at all: `x ?? this.x` preserves.
      final withExpiry =
          variant(expiryDate: iso(today.add(const Duration(days: 3))));
      final notCleared = withExpiry.copyWith();
      expect(notCleared.hasExpiry, isTrue);
    });
  });

  group('H — decimal product is unaffected', () {
    test('a decimal variant keeps its fractional stock alongside an expiry', () {
      final milk = variant(
        expiryDate: iso(today.add(const Duration(days: 1))),
        stock: 10.50,
        decimal: true,
        unit: 'liter',
      );
      expect(milk.stockQty, equals(10.50));
      expect(milk.isDecimalQuantity, isTrue);
      expect(milk.effectiveUnit, equals('liter'));
      expect(expiryStatusFor(milk.expiryDateTime, asOf: today),
          RetailExpiryStatus.expiringSoon);
    });

    test('clearing the expiry does not disturb the quantity config', () {
      final milk = variant(
        expiryDate: iso(today),
        stock: 10.50,
        decimal: true,
        unit: 'liter',
      );
      final cleared = milk.copyWith(clearExpiryDate: true);
      expect(cleared.stockQty, equals(10.50));
      expect(cleared.isDecimalQuantity, isTrue);
      expect(cleared.effectiveUnit, equals('liter'));
      expect(cleared.quantityStep, equals(0.25));
    });

    test('expiry is independent of quantity', () {
      final zeroStock = variant(
        expiryDate: iso(today.subtract(const Duration(days: 1))),
        stock: 0,
        decimal: true,
        unit: 'kg',
      );
      // No stock, still expired — status must not depend on quantity.
      expect(expiryStatusFor(zeroStock.expiryDateTime, asOf: today),
          RetailExpiryStatus.expired);
    });
  });

  group('I — existing pcs product is unregressed', () {
    test('whole-number stock and no expiry behave exactly as before', () {
      final coke = variant(stock: 20);
      expect(coke.stockQty, equals(20));
      expect(coke.stockQty % 1, equals(0));
      expect(coke.isDecimalQuantity, isFalse);
      expect(coke.effectiveUnit, equals('piece'));
      expect(coke.quantityStep, equals(1.0));
      expect(coke.formatQuantity(20), equals('20'));
      expect(expiryStatusFor(coke.expiryDateTime, asOf: today),
          RetailExpiryStatus.noExpiry);
    });

    test('a pcs product may still opt into an expiry', () {
      final biscuit = variant(
        stock: 20,
        expiryDate: iso(today.subtract(const Duration(days: 3))),
      );
      expect(biscuit.isDecimalQuantity, isFalse);
      expect(biscuit.stockQty, equals(20));
      expect(expiryStatusFor(biscuit.expiryDateTime, asOf: today),
          RetailExpiryStatus.expired);
    });

    test('a sale still lands exactly on 17', () {
      final coke = variant(stock: 20);
      expect(coke.stockQty - 3, equals(17));
    });
  });

  group('daysUntilExpiry', () {
    test('null with no expiry', () {
      expect(daysUntilExpiry(null, asOf: today), isNull);
    });

    test('0 on the day, positive ahead, negative once past', () {
      expect(daysUntilExpiry(today, asOf: today), equals(0));
      expect(daysUntilExpiry(today.add(const Duration(days: 5)), asOf: today),
          equals(5));
      expect(
        daysUntilExpiry(today.subtract(const Duration(days: 4)), asOf: today),
        equals(-4),
      );
    });

    test('ignores the time of day', () {
      expect(
        daysUntilExpiry(DateTime(2026, 8, 27, 23, 30),
            asOf: DateTime(2026, 8, 26, 1, 0)),
        equals(1),
      );
    });
  });

  group('serialization', () {
    test('an expiry survives toMap/fromMap', () {
      final expiry = DateTime(2026, 8, 30);
      final restored =
          VarianteModel.fromMap(variant(expiryDate: iso(expiry)).toMap());
      expect(restored.expiryDateTime, equals(expiry));
      expect(restored.hasExpiry, isTrue);
    });

    test('no expiry survives as null', () {
      final restored = VarianteModel.fromMap(variant().toMap());
      expect(restored.expiryDate, isNull);
      expect(restored.hasExpiry, isFalse);
    });

    test('a LEGACY map with no expiryDate key loads as null', () {
      // Exactly what a backup written before this feature looks like.
      final legacy = <String, dynamic>{
        'varianteId': 'v-old',
        'productId': 'p-old',
        'createdAt': today.toIso8601String(),
        'stockQty': 20,
      };
      final restored = VarianteModel.fromMap(legacy);
      expect(restored.expiryDate, isNull);
      expect(restored.hasExpiry, isFalse);
      expect(expiryStatusFor(restored.expiryDateTime, asOf: today),
          RetailExpiryStatus.noExpiry);
      // …and the decimal migration still reads correctly alongside it.
      expect(restored.stockQty, equals(20.0));
    });

    test('a decimal variant with an expiry round-trips both facts', () {
      final milk = variant(
        expiryDate: iso(DateTime(2026, 8, 30)),
        stock: 10.50,
        decimal: true,
        unit: 'liter',
      );
      final restored = VarianteModel.fromMap(milk.toMap());
      expect(restored.stockQty, equals(10.50));
      expect(restored.isDecimalQuantity, isTrue);
      expect(restored.unit, equals('liter'));
      expect(restored.expiryDateTime, equals(DateTime(2026, 8, 30)));
    });
  });

  group('labels', () {
    test('every status has a distinct label', () {
      final labels =
          RetailExpiryStatus.values.map((s) => s.label).toSet();
      expect(labels, hasLength(RetailExpiryStatus.values.length));
    });

    test('alerting set is exactly expired/today/soon', () {
      final alerting = RetailExpiryStatus.values
          .where((s) => s.isAlerting)
          .toSet();
      expect(alerting, {
        RetailExpiryStatus.expired,
        RetailExpiryStatus.expiringToday,
        RetailExpiryStatus.expiringSoon,
      });
    });
  });
}
