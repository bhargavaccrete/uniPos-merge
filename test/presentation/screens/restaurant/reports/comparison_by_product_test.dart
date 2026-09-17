import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/data/models/restaurant/db/cartmodel_308.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/comparisonbyproduct/comparisonproduct.dart';
import 'package:billberrylite/util/restaurant/order_status_filter.dart';

import '../../../../helpers/test_helpers.dart';

/// Comparison by Product moved its calculation out of the Observer. These pin
/// that the extracted [calculateProductComparison] is the old
/// `_calculateComparisonData` — same buckets, boundaries, and row order.

// ── The pre-change implementation, verbatim except that `DateTime.now()`,
//    `widget.period`, `selectedYear` and `ReportHistoryWindow.cutoff` are
//    parameters. This is the reference, not the code under test.
List<ProductComparisonData> legacyCalculate(
  List<PastOrderModel> pastOrders,
  ComparisonPeriod widgetPeriod,
  int selectedYear,
  DateTime now,
  DateTime? cutoffParam,
) {
  final allOrders = pastOrders.toList();

  DateTime currentStart, currentEnd, previousStart, previousEnd;
  String currentLabel, previousLabel;

  switch (widgetPeriod) {
    case ComparisonPeriod.Today:
      currentStart = DateTime(now.year, now.month, now.day);
      currentEnd = currentStart.add(const Duration(days: 1));
      previousStart = currentStart.subtract(const Duration(days: 1));
      previousEnd = currentStart;
      currentLabel = 'Today';
      previousLabel = 'Yesterday';
      break;

    case ComparisonPeriod.ThisWeek:
      final weekDay = now.weekday;
      currentStart = now.subtract(Duration(days: weekDay - 1));
      currentStart = DateTime(currentStart.year, currentStart.month, currentStart.day);
      currentEnd = currentStart.add(const Duration(days: 7));
      previousStart = currentStart.subtract(const Duration(days: 7));
      previousEnd = currentStart;
      currentLabel = 'This Week';
      previousLabel = 'Last Week';
      break;

    case ComparisonPeriod.MonthWise:
      currentStart = DateTime(now.year, now.month, 1);
      currentEnd = DateTime(now.year, now.month + 1, 1);
      previousStart = DateTime(now.year, now.month - 1, 1);
      previousEnd = currentStart;
      currentLabel = DateFormat('MMMM yyyy').format(now);
      previousLabel = DateFormat('MMMM yyyy').format(DateTime(now.year, now.month - 1, 1));
      break;

    case ComparisonPeriod.YearWise:
      currentStart = DateTime(selectedYear, 1, 1);
      currentEnd = DateTime(selectedYear + 1, 1, 1);
      previousStart = DateTime(selectedYear - 1, 1, 1);
      previousEnd = DateTime(selectedYear, 1, 1);
      currentLabel = '$selectedYear';
      previousLabel = '${selectedYear - 1}';
      break;
  }

  Map<String, int> currentQuantities = {};
  Map<String, int> previousQuantities = {};

  final cutoff = cutoffParam;

  for (final order in allOrders) {
    final orderStatus = order.orderStatus?.toUpperCase() ?? '';
    if (OrderStatusFilter.isExcludedFromRevenue(orderStatus)) continue;
    if (order.orderAt == null) continue;
    if (cutoff != null && order.orderAt!.isBefore(cutoff)) continue;

    if (order.orderAt!.isAfter(currentStart.subtract(const Duration(seconds: 1))) &&
        order.orderAt!.isBefore(currentEnd)) {
      for (final item in order.items) {
        final effectiveQty = item.quantity - (item.refundedQuantity ?? 0);
        if (effectiveQty > 0) {
          currentQuantities[item.title] = (currentQuantities[item.title] ?? 0) + effectiveQty;
        }
      }
    }
    else if (order.orderAt!.isAfter(previousStart.subtract(const Duration(seconds: 1))) &&
        order.orderAt!.isBefore(previousEnd)) {
      for (final item in order.items) {
        final effectiveQty = item.quantity - (item.refundedQuantity ?? 0);
        if (effectiveQty > 0) {
          previousQuantities[item.title] = (previousQuantities[item.title] ?? 0) + effectiveQty;
        }
      }
    }
  }

  final allProducts = {...currentQuantities.keys, ...previousQuantities.keys};

  final List<ProductComparisonData> comparisonList = [];
  for (final productName in allProducts) {
    final currentQty = currentQuantities[productName] ?? 0;
    final previousQty = previousQuantities[productName] ?? 0;
    final difference = currentQty - previousQty;

    double growthPercentage = 0.0;
    if (previousQty > 0) {
      growthPercentage = ((currentQty - previousQty) / previousQty) * 100;
    } else if (currentQty > 0) {
      growthPercentage = double.infinity;
    }

    comparisonList.add(ProductComparisonData(
      productName: productName,
      previousPeriodQty: previousQty,
      currentPeriodQty: currentQty,
      difference: difference,
      growthPercentage: growthPercentage,
      currentLabel: currentLabel,
      previousLabel: previousLabel,
    ));
  }

  comparisonList.sort((a, b) => b.currentPeriodQty.compareTo(a.currentPeriodQty));

  return comparisonList;
}

/// The pre-change export rows and summary (minus 'Generated'), verbatim.
(List<List<String>>, Map<String, String>) legacyExport(List<ProductComparisonData> comparisonData) {
  final data = comparisonData.map((product) => [
    product.productName,
    product.previousPeriodQty.toString(),
    product.currentPeriodQty.toString(),
    '${product.difference > 0 ? '+' : ''}${product.difference}',
    product.growthPercentage.isInfinite
        ? 'New'
        : '${product.growthPercentage >= 0 ? '+' : ''}${product.growthPercentage.toStringAsFixed(1)}%',
  ]).toList();

  final totalCurrent = comparisonData.fold<int>(0, (sum, p) => sum + p.currentPeriodQty);
  final totalPrevious = comparisonData.fold<int>(0, (sum, p) => sum + p.previousPeriodQty);
  final totalDifference = totalCurrent - totalPrevious;
  final overallGrowthStr = totalPrevious == 0
      ? (totalCurrent > 0 ? 'New' : '0%')
      : () {
          final g = ((totalCurrent - totalPrevious) / totalPrevious) * 100;
          return '${g >= 0 ? '+' : ''}${g.toStringAsFixed(1)}%';
        }();

  final summary = {
    'Comparison Period': '${comparisonData.first.previousLabel} vs ${comparisonData.first.currentLabel}',
    'Total Products': comparisonData.length.toString(),
    'Total Previous Period': totalPrevious.toString(),
    'Total Current Period': totalCurrent.toString(),
    'Total Difference': '${totalDifference > 0 ? '+' : ''}$totalDifference',
    'Overall Growth': overallGrowthStr,
  };
  return (data, summary);
}

/// Table cell text as the pre-change DataTable built it.
String legacyTableDifference(ProductComparisonData data) =>
    data.difference > 0 ? '+${data.difference}' : '${data.difference}';
String legacyTableGrowth(ProductComparisonData data) => data.growthPercentage.isInfinite
    ? 'New'
    : '${data.growthPercentage >= 0 ? '+' : ''}${data.growthPercentage.toStringAsFixed(1)}%';

// ── Fixtures ────────────────────────────────────────────────────────────────

int _seq = 0;

PastOrderModel order(
  DateTime? at,
  List<CartItem> items, {
  String status = 'COMPLETED',
}) {
  _seq++;
  return PastOrderModel(
    id: 'o$_seq',
    customerName: 'C$_seq',
    totalPrice: 100,
    items: items,
    orderAt: at,
    orderType: 'Take Away',
    paymentmode: 'cash',
    orderStatus: status,
    kotNumbers: [_seq],
    kotBoundaries: [items.length],
  );
}

CartItem line(String title, int qty, {int? refunded}) => makeCartItem(
      id: 'i-$title',
      title: title,
      price: 10,
      quantity: qty,
      refundedQuantity: refunded,
    );

List<Object> snapshot(List<ProductComparisonData> rows) => [
      for (final r in rows)
        [
          r.productName,
          r.previousPeriodQty,
          r.currentPeriodQty,
          r.difference,
          r.growthPercentage,
          r.currentLabel,
          r.previousLabel,
        ],
    ];

// Wednesday. Week starts Monday 2026-09-14.
final now = DateTime(2026, 9, 16, 14);

List<ProductComparisonData> calc(
  List<PastOrderModel> orders,
  ComparisonPeriod period, {
  int year = 2026,
  DateTime? cutoff,
}) =>
    calculateProductComparison(
      orders: orders,
      period: period,
      selectedYear: year,
      now: now,
      cutoff: cutoff,
    );

/// Which column a single order at [at] lands in.
String bucketOf(ComparisonPeriod period, DateTime at, {int year = 2026}) {
  final rows = calc([order(at, [line('P', 1)])], period, year: year);
  expect(snapshot(rows), snapshot(legacyCalculate([order(at, [line('P', 1)])], period, year, now, null)));
  if (rows.isEmpty) return 'excluded';
  return rows.single.currentPeriodQty > 0 ? 'current' : 'previous';
}

void main() {
  group('boundary assignment (isAfter(start - 1s) preserved)', () {
    final windows = <ComparisonPeriod, ({DateTime start, DateTime end, DateTime prevStart})>{
      ComparisonPeriod.Today: (
        start: DateTime(2026, 9, 16),
        end: DateTime(2026, 9, 17),
        prevStart: DateTime(2026, 9, 15),
      ),
      ComparisonPeriod.ThisWeek: (
        start: DateTime(2026, 9, 14),
        end: DateTime(2026, 9, 21),
        prevStart: DateTime(2026, 9, 7),
      ),
      ComparisonPeriod.MonthWise: (
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 10, 1),
        prevStart: DateTime(2026, 8, 1),
      ),
      ComparisonPeriod.YearWise: (
        start: DateTime(2026),
        end: DateTime(2027),
        prevStart: DateTime(2025),
      ),
    };

    for (final entry in windows.entries) {
      final period = entry.key;
      final w = entry.value;

      test('${period.name}: start - 1s is previous', () {
        expect(bucketOf(period, w.start.subtract(const Duration(seconds: 1))), 'previous');
      });
      test('${period.name}: start - 500ms is CURRENT (inside the 1s lead-in)', () {
        expect(bucketOf(period, w.start.subtract(const Duration(milliseconds: 500))), 'current');
      });
      test('${period.name}: exactly start is current', () {
        expect(bucketOf(period, w.start), 'current');
      });
      test('${period.name}: end - 1µs is current', () {
        expect(bucketOf(period, w.end.subtract(const Duration(microseconds: 1))), 'current');
      });
      test('${period.name}: exactly end is excluded', () {
        expect(bucketOf(period, w.end), 'excluded');
      });
      test('${period.name}: previousStart - 1s is excluded', () {
        expect(bucketOf(period, w.prevStart.subtract(const Duration(seconds: 1))), 'excluded');
      });
      test('${period.name}: previousStart - 500ms is previous', () {
        expect(bucketOf(period, w.prevStart.subtract(const Duration(milliseconds: 500))), 'previous');
      });
    }
  });

  group('current vs previous aggregation', () {
    test('statuses, null orderAt, cutoff and refunded quantity', () {
      final today = DateTime(2026, 9, 16, 10);
      final yesterday = DateTime(2026, 9, 15, 10);
      final orders = [
        order(today, [line('Tea', 3, refunded: 1), line('Samosa', 2)]),
        order(yesterday, [line('Tea', 1), line('Coffee', 4)]),
        order(today, [line('Tea', 9)], status: 'VOIDED'),
        order(today, [line('Tea', 9)], status: 'void'),
        order(today, [line('Tea', 9)], status: 'CANCELLED'),
        order(today, [line('Tea', 9)], status: 'FULLY_REFUNDED'),
        order(today, [line('Tea', 1)], status: 'PARTIALLY_REFUNDED'),
        order(null, [line('Tea', 9)]),
        order(today, [line('Fully Returned', 2, refunded: 2)]),
      ];

      final rows = calc(orders, ComparisonPeriod.Today);
      expect(snapshot(rows), snapshot(legacyCalculate(orders, ComparisonPeriod.Today, 2026, now, null)));

      final byName = {for (final r in rows) r.productName: r};
      expect(byName.keys.toSet(), {'Tea', 'Samosa', 'Coffee'});
      expect(byName['Tea']!.currentPeriodQty, 3); // (3-1) + 1 partial
      expect(byName['Tea']!.previousPeriodQty, 1);
      expect(byName['Tea']!.growthPercentage, 200.0);
      expect(byName['Samosa']!.growthPercentage, double.infinity);
      expect(byName['Coffee']!.growthPercentage, -100.0);
      expect(byName['Coffee']!.difference, -4);

      // Cutoff after yesterday drops the previous column entirely.
      final clamped = calc(orders, ComparisonPeriod.Today, cutoff: DateTime(2026, 9, 16));
      expect(snapshot(clamped),
          snapshot(legacyCalculate(orders, ComparisonPeriod.Today, 2026, now, DateTime(2026, 9, 16))));
      expect(clamped.every((r) => r.previousPeriodQty == 0), isTrue);
    });

    test('large mixed history matches the legacy implementation for every period, year and cutoff', () {
      final rnd = Random(42);
      const statuses = [
        'COMPLETED', 'COMPLETED', 'COMPLETED', 'PARTIALLY_REFUNDED',
        'VOIDED', 'CANCELLED', 'FULLY_REFUNDED', 'completed',
      ];
      final base = DateTime(2024, 11, 1);
      final orders = <PastOrderModel>[];
      for (var i = 0; i < 1500; i++) {
        final at = i % 97 == 0
            ? null
            : base.add(Duration(minutes: rnd.nextInt(700 * 24 * 60), milliseconds: rnd.nextInt(1000)));
        final lines = <CartItem>[
          for (var j = 0; j < 1 + rnd.nextInt(3); j++)
            line('Product ${rnd.nextInt(45)}', 1 + rnd.nextInt(3),
                refunded: rnd.nextInt(5) == 0 ? rnd.nextInt(2) : null),
        ];
        orders.add(order(at, lines, status: statuses[rnd.nextInt(statuses.length)]));
      }

      for (final period in ComparisonPeriod.values) {
        for (final year in [2026, 2025]) {
          for (final cutoff in [null, DateTime(2026, 8, 20), DateTime(2025, 6, 1)]) {
            final actual = calc(orders, period, year: year, cutoff: cutoff);
            final expected = legacyCalculate(orders, period, year, now, cutoff);
            expect(snapshot(actual), snapshot(expected),
                reason: '$period year=$year cutoff=$cutoff');
          }
        }
      }

      // The fixture must actually exercise the >32-element sort with ties.
      final month = calc(orders, ComparisonPeriod.MonthWise);
      expect(month.length, greaterThan(32));
      final qtys = month.map((r) => r.currentPeriodQty).toList();
      expect(qtys.toSet().length, lessThan(qtys.length));
    });
  });

  group('export == screen', () {
    test('export rows are the table rows, in order, with identical cell text', () {
      final rnd = Random(7);
      final orders = [
        for (var i = 0; i < 300; i++)
          order(DateTime(2026, 8, 1).add(Duration(hours: rnd.nextInt(46 * 24))),
              [line('Dish ${rnd.nextInt(40)}', 1 + rnd.nextInt(4))]),
      ];
      final data = calc(orders, ComparisonPeriod.MonthWise);
      expect(data, isNotEmpty);

      final export = productComparisonExport(data);
      final (legacyRows, legacySummary) = legacyExport(data);

      expect(export.headers, [
        'Product Name',
        data.first.previousLabel,
        data.first.currentLabel,
        'Difference',
        'Growth %',
      ]);
      expect(export.rows, legacyRows);
      expect(export.summary, legacySummary);

      for (var i = 0; i < data.length; i++) {
        expect(export.rows[i][0], data[i].productName);
        expect(data[i].differenceLabel, legacyTableDifference(data[i]));
        expect(data[i].growthLabel, legacyTableGrowth(data[i]));
        expect(export.rows[i][3], data[i].differenceLabel);
        expect(export.rows[i][4], data[i].growthLabel);
      }
    });

    test('labels for zero, negative and new products', () {
      final orders = [
        order(DateTime(2026, 9, 16, 9), [line('Same', 2), line('New', 1)]),
        order(DateTime(2026, 9, 15, 9), [line('Same', 2), line('Gone', 3)]),
      ];
      final data = calc(orders, ComparisonPeriod.Today);
      final byName = {for (final r in data) r.productName: r};
      expect(byName['Same']!.differenceLabel, '0');
      expect(byName['Same']!.growthLabel, '+0.0%');
      expect(byName['New']!.differenceLabel, '+1');
      expect(byName['New']!.growthLabel, 'New');
      expect(byName['Gone']!.differenceLabel, '-3');
      expect(byName['Gone']!.growthLabel, '-100.0%');
      expect(productComparisonExport(data).summary, legacyExport(data).$2);
    });
  });
}
