import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/domain/services/retail/expiry_alert_service.dart';
import 'package:billberrylite/domain/services/retail/expiry_status.dart';

/// Expiry ALERT GENERATION — the derived list itself.
///
/// Exercises `buildAlerts`, the pure half of [ExpiryAlertService]; the
/// store-reading wrappers only supply candidates. Covers "a notification is
/// generated" for expiring-soon (C) and expired (D), that repeated checks
/// never duplicate (E), that editing (F) and clearing (G) an expiry are
/// reflected immediately, and that decimal (H) and pcs (I) products both work.
void main() {
  final today = DateTime(2026, 8, 26);
  String iso(DateTime d) => dateOnly(d).toIso8601String();

  VarianteModel variant({
    String id = 'v1',
    String? expiryDate,
    double stock = 0,
    bool decimal = false,
    String? unit,
  }) =>
      VarianteModel(
        varianteId: id,
        productId: 'p1',
        createdAt: today.toIso8601String(),
        stockQty: stock,
        isDecimalQuantity: decimal,
        unit: unit,
        expiryDate: expiryDate,
      );

  ExpiryCandidate candidate(VarianteModel v, {String name = 'Product'}) => (
        productId: v.productId,
        productName: name,
        variantLabel: '',
        variant: v,
      );

  // The three worked products from the brief.
  final milk = variant(
    id: 'milk',
    expiryDate: iso(today.add(const Duration(days: 1))), // tomorrow
    stock: 10.50,
    decimal: true,
    unit: 'liter',
  );
  final biscuit = variant(
    id: 'biscuit',
    expiryDate: iso(today.subtract(const Duration(days: 10))), // past
    stock: 20,
  );
  final coke = variant(id: 'coke', stock: 20); // no expiry

  List<Map<String, dynamic>> alertsFor(List<VarianteModel> vs) =>
      ExpiryAlertService.buildAlerts(
        vs.map((v) => candidate(v, name: v.varianteId)).toList(),
        asOf: today,
      );

  group('C — expiring soon generates an alert', () {
    test('Milk (expires tomorrow) is alerted as Expiring Soon', () {
      final rows = alertsFor([milk]);
      expect(rows, hasLength(1));
      expect(rows.first['status'], RetailExpiryStatus.expiringSoon);
      expect(rows.first['variantId'], equals('milk'));
      expect(rows.first['daysUntil'], equals(1));
    });

    test('the alert identifies the product and carries the expiry date', () {
      final rows = alertsFor([milk]);
      expect(rows.first['productName'], equals('milk'));
      expect(rows.first['expiryDate'], equals(milk.expiryDate));
    });

    test('a far-future product generates nothing', () {
      final fresh = variant(
        id: 'fresh',
        expiryDate: iso(today.add(const Duration(days: 200))),
      );
      expect(alertsFor([fresh]), isEmpty);
    });
  });

  group('D — expired generates an alert', () {
    test('Biscuit (past date) is alerted as Expired', () {
      final rows = alertsFor([biscuit]);
      expect(rows, hasLength(1));
      expect(rows.first['status'], RetailExpiryStatus.expired);
      expect(rows.first['daysUntil'], equals(-10));
    });

    test('expired sorts ABOVE expiring-soon', () {
      final rows = alertsFor([milk, biscuit]);
      expect(rows.map((r) => r['variantId']), equals(['biscuit', 'milk']));
    });

    test('summary splits expired from expiring-soon', () {
      final summary = ExpiryAlertService.summarise(alertsFor([milk, biscuit]));
      expect(summary['totalAlerts'], equals(2));
      expect(summary['expiredCount'], equals(1));
      expect(summary['expiringSoonCount'], equals(1));
    });
  });

  group('A — no expiry generates nothing', () {
    test('Coke is absent from the alert list', () {
      expect(alertsFor([coke]), isEmpty);
    });

    test('Coke stays absent even beside alerting products', () {
      final rows = alertsFor([milk, biscuit, coke]);
      expect(rows.map((r) => r['variantId']), isNot(contains('coke')));
      expect(rows, hasLength(2));
    });

    test('an empty catalogue produces an empty summary', () {
      final summary = ExpiryAlertService.summarise(alertsFor([]));
      expect(summary['totalAlerts'], equals(0));
      expect(summary['expiredCount'], equals(0));
      expect(summary['expiringSoonCount'], equals(0));
    });
  });

  group('E — repeated checks never duplicate', () {
    test('ten consecutive reads return an identical list', () {
      final runs = List.generate(10, (_) => alertsFor([milk, biscuit, coke]));
      for (final run in runs) {
        expect(run, hasLength(2));
        expect(run.map((r) => r['variantId']), equals(['biscuit', 'milk']));
      }
    });

    test('nothing accumulates across reads — the list is derived', () {
      // The failure this guards against is an alert STORE growing on each
      // app open. There is no store, so the count cannot drift.
      var previous = alertsFor([milk, biscuit]).length;
      for (var i = 0; i < 5; i++) {
        final now = alertsFor([milk, biscuit]).length;
        expect(now, equals(previous));
        previous = now;
      }
    });
  });

  group('F — changing an expiry updates the alert immediately', () {
    test('moving Milk to a future date removes its alert', () {
      expect(alertsFor([milk]), hasLength(1));

      final moved = milk.copyWith(
        expiryDate: iso(today.add(const Duration(days: 180))),
      );
      expect(alertsFor([moved]), isEmpty);
    });

    test('the OLD alert cannot linger — only the current date is read', () {
      final moved = milk.copyWith(
        expiryDate: iso(today.add(const Duration(days: 180))),
      );
      final rows = alertsFor([moved, biscuit]);
      expect(rows.map((r) => r['variantId']), equals(['biscuit']));
      expect(rows.map((r) => r['variantId']), isNot(contains('milk')));
    });

    test('bringing a date closer creates the alert', () {
      final fresh = variant(
        id: 'fresh',
        expiryDate: iso(today.add(const Duration(days: 200))),
      );
      expect(alertsFor([fresh]), isEmpty);

      final nearer = fresh.copyWith(
        expiryDate: iso(today.add(const Duration(days: 2))),
      );
      expect(alertsFor([nearer]), hasLength(1));
    });
  });

  group('G — clearing an expiry removes the alert', () {
    test('cleared Milk drops out of the list entirely', () {
      expect(alertsFor([milk]), hasLength(1));

      final cleared = milk.copyWith(clearExpiryDate: true);
      expect(cleared.hasExpiry, isFalse);
      expect(alertsFor([cleared]), isEmpty);
      expect(
        expiryStatusFor(cleared.expiryDateTime, asOf: today),
        RetailExpiryStatus.noExpiry,
      );
    });

    test('clearing one leaves the others alone', () {
      final cleared = milk.copyWith(clearExpiryDate: true);
      final rows = alertsFor([cleared, biscuit]);
      expect(rows, hasLength(1));
      expect(rows.first['variantId'], equals('biscuit'));
    });
  });

  group('H/I — quantity behaviour is untouched by expiry', () {
    test('Milk keeps 10.50 litre in its alert row', () {
      final row = alertsFor([milk]).first;
      expect(row['currentStock'], equals(10.50));
      expect(row['unit'], equals('liter'));
    });

    test('Biscuit reports whole pcs and no unit label', () {
      final row = alertsFor([biscuit]).first;
      expect(row['currentStock'], equals(20.0));
      expect((row['currentStock'] as num) % 1, equals(0));
      // A piece product carries no unit suffix, as before.
      expect(row['unit'], isNull);
    });

    test('stock is exposed as num, never int — decimals must not crash', () {
      for (final row in alertsFor([milk, biscuit])) {
        expect(row['currentStock'], isA<num>());
      }
    });

    test('a zero-stock expired product still alerts', () {
      // Expiry is independent of quantity — it must not be filtered by stock.
      final empty = variant(
        id: 'empty',
        expiryDate: iso(today.subtract(const Duration(days: 1))),
        stock: 0,
      );
      expect(alertsFor([empty]), hasLength(1));
    });
  });

  group('warning period', () {
    test('the default window is the shared constant', () {
      final atBoundary = variant(
        id: 'boundary',
        expiryDate: iso(today.add(const Duration(days: kExpiryWarningDays))),
      );
      expect(alertsFor([atBoundary]), hasLength(1));
    });

    test('a widened window pulls more products in', () {
      final in10 = variant(
        id: 'in10',
        expiryDate: iso(today.add(const Duration(days: 10))),
      );
      expect(alertsFor([in10]), isEmpty);

      final widened = ExpiryAlertService.buildAlerts(
        [candidate(in10, name: 'in10')],
        asOf: today,
        warningDays: 14,
      );
      expect(widened, hasLength(1));
    });
  });
}
