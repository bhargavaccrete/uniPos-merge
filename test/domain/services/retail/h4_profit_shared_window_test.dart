import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/core/plan/entitlements.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/repositories/common/category_repository.dart';
import 'package:billberrylite/data/repositories/retail/sale_item_repository.dart';
import 'package:billberrylite/data/repositories/retail/variant_repository.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/domain/store/common/category_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/retail/attribute_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';

/// H4 — the Profit screen's four tabs share one window, one line pass and one
/// cost map instead of building each four times.
///
/// The golden was RECORDED FROM THE PRE-H4 CODE (`--dart-define=H4_RECORD=true`)
/// by calling the four independent report methods. After H4 both those
/// methods AND the shared `getProfitReports` must reproduce it exactly: every
/// double in shortest round-trip form, every map in insertion order, every row
/// in order. Never re-record to make a change pass.

const _record = bool.fromEnvironment('H4_RECORD');
final _goldenFile =
    File('test/domain/services/retail/goldens/h4_profit_shared_window.golden');

String canon(Object? v) {
  if (v == null) return 'null';
  if (v is double) return 'd:$v';
  if (v is int) return 'i:$v';
  if (v is bool) return 'b:$v';
  if (v is String) return 's:${jsonEncode(v)}';
  if (v is DateTime) return 't:${v.toIso8601String()}:${v.isUtc}';
  if (v is Map) {
    return '{${v.entries.map((e) => '${canon(e.key)}=${canon(e.value)}').join(',')}}';
  }
  if (v is Iterable) return '[${v.map(canon).join(',')}]';
  return 'o:${v.runtimeType}:$v';
}

String digest(String name, Object? value) {
  final rendered = canon(value);
  return '$name ${rendered.length} ${sha256.convert(utf8.encode(rendered))}';
}

/// One fixture sale as the test knows it, for independent expectations.
class _FixtureSale {
  final String id;
  final String createdAt;
  final bool isReturn;
  _FixtureSale(this.id, this.createdAt, this.isReturn);
}

void main() {
  late Directory tempDir;

  final monthStart = DateTime(2026, 3, 1);
  final monthEnd = DateTime(2026, 4, 1);

  final windows = <String, (DateTime?, DateTime?)>{
    'allTime': (null, null), // the screen's default
    'month': (monthStart, monthEnd),
    'hotDay': (DateTime(2026, 3, 15), DateTime(2026, 3, 16)),
    'firstDay': (monthStart, DateTime(2026, 3, 2)),
    'lastDay': (DateTime(2026, 3, 31), monthEnd),
  };

  setUp(() async {
    await locator.reset();
    Entitlements.instance.clear();

    tempDir = await Directory.systemTemp.createTemp('h4_profit_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();

    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'retail');

    await Hive.openBox<SaleModel>(HiveBoxNames.sales);
    await Hive.openBox<SaleItemModel>(HiveBoxNames.saleItems);
    await Hive.openBox<ProductModel>(HiveBoxNames.products);
    await Hive.openBox<VarianteModel>(HiveBoxNames.variants);
    await Hive.openBox<Category>(HiveBoxNames.category);
    await Hive.openBox<AttributeModel>(HiveBoxNames.attributes);

    locator.registerLazySingleton<SaleStore>(() => SaleStore());
    locator.registerLazySingleton<SaleItemRepository>(() => SaleItemRepository());
    locator.registerLazySingleton<VariantRepository>(() => VariantRepository());
    locator.registerLazySingleton<ProductStore>(() => ProductStore());
    locator.registerLazySingleton<AttributeStore>(() => AttributeStore());
    locator.registerLazySingleton<CategoryStore>(
        () => CategoryStore(CategoryRepository()));
    locator.registerLazySingleton<LicenseStore>(
        () => LicenseStore(LicenseApiService()));
  });

  tearDown(() async {
    Entitlements.instance.clear();
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  final fixtureSales = <String, _FixtureSale>{};
  final fixtureLines = <String, SaleItemModel>{};

  SaleModel saleOf(
    String id,
    String createdAt, {
    bool isReturn = false,
    String paymentType = 'cash',
    String? exchangeGroupId,
    String? paymentListJson,
    double items = 1,
  }) {
    final s = isReturn ? -1 : 1;
    return SaleModel(
      saleId: id,
      totalItems: items,
      subtotal: s * 100,
      discountAmount: 0,
      taxAmount: s * 5,
      totalAmount: s * 105,
      paymentType: paymentType,
      date: createdAt,
      createdAt: createdAt,
      updatedAt: createdAt,
      isReturn: isReturn,
      originalSaleId: isReturn ? 'P-ORIG' : null,
      exchangeGroupId: exchangeGroupId,
      paymentListJson: paymentListJson,
      isSplitPayment: paymentListJson != null ? true : null,
    );
  }

  /// ~1,500 sales and ~5,000 lines. Deterministic; line keys are random hex so
  /// box order interleaves lines of different sales, days and products.
  Future<void> seed() async {
    fixtureSales.clear();
    fixtureLines.clear();
    final rnd = Random(4404);
    final sales = <String, SaleModel>{};
    var seq = 0;

    // Values that make accumulation order visible in the last bits.
    const sensitive = <double>[0.1, 0.2, 0.3, 1e15 + 0.3, 1e-3, 123456.789, 1e16, 7.77];

    void addLines(String saleId, int count) {
      for (var j = 0; j < count; j++) {
        final key = 'L${rnd.nextInt(1 << 30).toRadixString(16).padLeft(8, '0')}-${seq++}';
        final total = rnd.nextInt(6) == 0
            ? sensitive[rnd.nextInt(sensitive.length)]
            : rnd.nextInt(900000) / 100 + rnd.nextInt(1000) / 997;
        final gst = rnd.nextInt(5) == 0 ? null : total * [0, 5, 12, 18][rnd.nextInt(4)] / 118;
        final costPick = rnd.nextInt(8);
        fixtureLines[key] = SaleItemModel(
          saleItemId: key,
          saleId: saleId,
          // V0..V9 exist in the variant box (some with null / zero cost);
          // V10..V14 do not exist at all.
          varianteId: 'V${rnd.nextInt(15)}',
          productId: 'P${rnd.nextInt(6)}', // same products across many sales
          productName: rnd.nextInt(10) == 0 ? null : 'Product',
          size: rnd.nextInt(4) == 0 ? 'M' : null,
          price: total,
          qty: [1.0, 2.0, 0.5, 0.0, 3.0][rnd.nextInt(5)],
          total: total,
          taxAmount: rnd.nextInt(6) == 0 ? null : gst,
          gstAmount: rnd.nextInt(6) == 0 ? null : gst,
          costPrice: costPick < 3
              ? null // fall back to the live variant cost
              : (costPick == 3 ? 0.0 : rnd.nextInt(500000) / 100 + 0.01),
        );
      }
    }

    void addSale(SaleModel s, DateTime? at, {int lines = 0}) {
      sales[s.saleId] = s;
      fixtureSales[s.saleId] = _FixtureSale(s.saleId, s.createdAt, s.isReturn ?? false);
      addLines(s.saleId, lines);
    }

    final base = DateTime(2025, 10, 1);
    for (var i = 0; i < 1200; i++) {
      // A third of sales pile onto three hot days.
      final at = rnd.nextInt(3) == 0
          ? DateTime(2026, 3, [15, 20, 31][rnd.nextInt(3)], rnd.nextInt(24), rnd.nextInt(60))
          : base.add(Duration(minutes: rnd.nextInt(240 * 24 * 60)));
      final id = 'S${i.toString().padLeft(5, '0')}';
      final roll = rnd.nextInt(10);
      if (roll == 0) {
        addSale(saleOf(id, at.toIso8601String(), isReturn: true), at, lines: 1 + rnd.nextInt(3));
      } else if (roll == 1) {
        final group = 'EX$i';
        addSale(
          saleOf(id, at.toIso8601String(),
              isReturn: true,
              exchangeGroupId: group,
              paymentType: 'split',
              paymentListJson: jsonEncode([
                {'method': 'exchange_credit', 'amount': -80.25},
                {'method': 'cash', 'amount': -24.75},
              ])),
          at,
          lines: 1 + rnd.nextInt(3),
        );
        addSale(
          saleOf('$id-X', at.add(const Duration(seconds: 2)).toIso8601String(),
              exchangeGroupId: group,
              paymentType: 'split',
              paymentListJson: jsonEncode([
                {'method': 'exchange_credit', 'amount': 80.25},
                {'method': 'upi', 'amount': 44.1},
              ])),
          at,
          lines: 1 + rnd.nextInt(4),
        );
      } else {
        addSale(
          saleOf(id, at.toIso8601String(),
              paymentType: roll == 2 ? 'credit' : ['cash', 'upi', 'card'][rnd.nextInt(3)],
              items: (1 + rnd.nextInt(4)).toDouble()),
          at,
          lines: 1 + rnd.nextInt(6),
        );
      }
    }

    // Boundaries of the month window.
    final boundaries = <String, DateTime>{
      'B-start-1us': monthStart.subtract(const Duration(microseconds: 1)),
      'B-start': monthStart,
      'B-end-1us': monthEnd.subtract(const Duration(microseconds: 1)),
      'B-end': monthEnd,
    };
    for (final e in boundaries.entries) {
      addSale(saleOf(e.key, e.value.toIso8601String()), e.value, lines: 3);
    }

    // Odd createdAt values.
    addSale(saleOf('D-garbage', 'not-a-date'), null, lines: 2);
    addSale(saleOf('D-empty', ''), null, lines: 2);
    addSale(saleOf('D-utc', '2026-03-15T05:30:00.000Z'), null, lines: 3);
    addSale(saleOf('D-utc-start', monthStart.toUtc().toIso8601String()), null, lines: 2);

    // A sale with no lines; lines with no sale.
    addSale(saleOf('NO-LINES', DateTime(2026, 3, 15, 9).toIso8601String()), null);
    addLines('GHOST', 10);

    await Hive.box<SaleModel>(HiveBoxNames.sales).putAll(sales);
    await Hive.box<SaleItemModel>(HiveBoxNames.saleItems).putAll(fixtureLines);

    final variants = Hive.box<VarianteModel>(HiveBoxNames.variants);
    for (var i = 0; i < 10; i++) {
      await variants.put(
        'V$i',
        VarianteModel(
          varianteId: 'V$i',
          productId: 'P${i % 6}',
          costPrice: i == 0 ? null : (i == 1 ? 0.0 : i * 11.11 + 0.07),
          createdAt: DateTime(2025).toIso8601String(),
        ),
      );
    }
    await productStore.ensureLoaded();
  }

  Future<List<String>> independent(String k, DateTime? s, DateTime? e) async {
    final svc = ReportService();
    return [
      digest('overall/$k', await svc.getProfitReport(startDate: s, endDate: e)),
      digest('perDay/$k', await svc.getProfitPerDayReport(startDate: s, endDate: e)),
      digest('perItem/$k', await svc.getProfitPerItemReport(startDate: s, endDate: e)),
      digest('perSale/$k', await svc.getProfitPerSaleReport(startDate: s, endDate: e)),
    ];
  }

  List<String> readGolden() {
    expect(_goldenFile.existsSync(), isTrue,
        reason: 'golden missing — it must be recorded from the pre-H4 code');
    return _goldenFile.readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();
  }

  void expectLines(List<String> actual, List<String> expected, String path) {
    expect(actual.length, expected.length, reason: path);
    for (var i = 0; i < expected.length; i++) {
      expect(actual[i], expected[i], reason: '$path: ${expected[i].split(' ').first}');
    }
  }

  test('independent profit methods match the pre-H4 golden', () async {
    await seed();
    final actual = <String>[];
    for (final w in windows.entries) {
      actual.addAll(await independent(w.key, w.value.$1, w.value.$2));
    }

    if (_record) {
      _goldenFile.parent.createSync(recursive: true);
      _goldenFile.writeAsStringSync('${actual.join('\n')}\n');
      return;
    }
    expectLines(actual, readGolden(), 'independent');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('shared getProfitReports matches the same pre-H4 golden', () async {
    await seed();
    final actual = <String>[];
    for (final w in windows.entries) {
      final r = await ReportService()
          .getProfitReports(startDate: w.value.$1, endDate: w.value.$2);
      actual.addAll([
        digest('overall/${w.key}', r.overall),
        digest('perDay/${w.key}', r.perDay),
        digest('perItem/${w.key}', r.perItem),
        digest('perSale/${w.key}', r.perSale),
      ]);
    }
    if (_record) return;
    expectLines(actual, readGolden(), 'shared');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('shared and independent results are equal value-for-value', () async {
    await seed();
    final svc = ReportService();
    final (s, e) = windows['month']!;
    final shared = await svc.getProfitReports(startDate: s, endDate: e);
    expect(shared.overall, await svc.getProfitReport(startDate: s, endDate: e));
    expect(shared.perDay, await svc.getProfitPerDayReport(startDate: s, endDate: e));
    expect(shared.perItem, await svc.getProfitPerItemReport(startDate: s, endDate: e));
    expect(shared.perSale, await svc.getProfitPerSaleReport(startDate: s, endDate: e));
  });

  test('Overall accumulates in sale-line box order (the fixture can tell)', () async {
    await seed();
    final report =
        await ReportService().getProfitReport(startDate: monthStart, endDate: monthEnd);

    // Independent derivation: the window's signed line revenues in box (key)
    // order, and the same values reversed.
    bool inMonth(_FixtureSale s) {
      final at = DateTime.tryParse(s.createdAt);
      return at != null && !at.isBefore(monthStart) && at.isBefore(monthEnd);
    }

    final keys = fixtureLines.keys.toList()..sort();
    final revenues = <double>[];
    for (final k in keys) {
      final line = fixtureLines[k]!;
      final sale = fixtureSales[line.saleId];
      if (sale == null || !inMonth(sale)) continue;
      final sign = sale.isReturn ? -1 : 1;
      revenues.add((line.total - (line.gstAmount ?? line.taxAmount ?? 0.0)) * sign);
    }
    final forward = revenues.fold<double>(0.0, (a, b) => a + b);
    final reversed = revenues.reversed.fold<double>(0.0, (a, b) => a + b);

    expect(forward, isNot(reversed),
        reason: 'fixture must be order-sensitive or this test proves nothing');
    expect(report['totalRevenue'], forward);
    expect(report['itemCount'], revenues.length);
  });

  test('month window: -1µs out, start in, end-1µs in, end out; UTC start in', () async {
    await seed();
    final rows = await ReportService()
        .getProfitPerSaleReport(startDate: monthStart, endDate: monthEnd);
    final ids = rows.map((r) => r['saleId']).toSet();
    expect(ids, containsAll(['B-start', 'B-end-1us', 'D-utc', 'D-utc-start', 'NO-LINES']));
    expect(ids, isNot(contains('B-start-1us')));
    expect(ids, isNot(contains('B-end')));
    expect(ids, isNot(contains('D-garbage')));
    expect(ids, isNot(contains('D-empty')));
    // Returns and exchange return legs are listed as return rows.
    final exchangeLegs = rows.where((r) => (r['saleId'] as String).endsWith('-X'));
    expect(exchangeLegs.every((r) => r['isReturn'] == false), isTrue);
  });
}
