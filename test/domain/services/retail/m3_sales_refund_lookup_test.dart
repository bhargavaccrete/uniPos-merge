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
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/common/shift_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/credit_payment_model_218.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/repositories/common/customer_repository.dart';
import 'package:billberrylite/data/repositories/common/shift_repository.dart';
import 'package:billberrylite/data/repositories/retail/sale_item_repository.dart';
import 'package:billberrylite/data/repositories/retail/sale_repository.dart';
import 'package:billberrylite/data/repositories/retail/variant_repository.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';

/// M3 — Sales Refund resolves each return's original sale by key instead of
/// copying every sale into a map.
///
/// That is only sound because every writer stores a sale under its own
/// `saleId` (so ids are unique by construction) — pinned by the contract test
/// below. The golden was RECORDED FROM THE PRE-M3 CODE
/// (`--dart-define=M3_RECORD=true`); never re-record to make a change pass.

const _record = bool.fromEnvironment('M3_RECORD');
final _goldenFile =
    File('test/domain/services/retail/goldens/m3_sales_refund_lookup.golden');

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

void main() {
  late Directory tempDir;
  late ReportService service;

  final monthStart = DateTime(2026, 5, 1);
  final monthEnd = DateTime(2026, 6, 1);

  setUp(() async {
    await locator.reset();
    Entitlements.instance.clear();

    tempDir = await Directory.systemTemp.createTemp('m3_refund_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();

    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'retail');

    await Hive.openBox<SaleModel>(HiveBoxNames.sales);
    await Hive.openBox<SaleItemModel>(HiveBoxNames.saleItems);
    await Hive.openBox<ProductModel>(HiveBoxNames.products);
    await Hive.openBox<VarianteModel>(HiveBoxNames.variants);
    await Hive.openBox<Customer>(HiveBoxNames.customer);
    await Hive.openBox<CreditPaymentModel>(HiveBoxNames.creditPayments);
    await Hive.openBox<ShiftModel>(HiveBoxNames.shift);

    locator.registerLazySingleton<SaleStore>(() => SaleStore());
    locator.registerLazySingleton<SaleItemRepository>(() => SaleItemRepository());
    locator.registerLazySingleton<VariantRepository>(() => VariantRepository());
    locator.registerLazySingleton<ProductStore>(() => ProductStore());
    locator.registerLazySingleton<CustomerRepository>(() => CustomerRepository());
    locator.registerLazySingleton<ShiftRepository>(() => ShiftRepository());
    locator.registerLazySingleton<LicenseStore>(
        () => LicenseStore(LicenseApiService()));

    service = ReportService();
  });

  tearDown(() async {
    Entitlements.instance.clear();
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  SaleModel sale(
    String id,
    String createdAt, {
    double total = 100,
    bool isReturn = false,
    String? originalSaleId,
    String paymentType = 'cash',
    String? exchangeGroupId,
    String? paymentListJson,
    String? returnReason,
    String? customerId,
    String? shiftId,
    double items = 1,
  }) {
    final s = isReturn ? -1 : 1;
    return SaleModel(
      saleId: id,
      customerId: customerId,
      totalItems: items,
      subtotal: s * total * 0.9,
      discountAmount: s * total * 0.01,
      taxAmount: s * total * 0.1,
      totalAmount: s * total,
      paymentType: paymentType,
      date: createdAt,
      createdAt: createdAt,
      updatedAt: createdAt,
      isReturn: isReturn,
      originalSaleId: originalSaleId,
      exchangeGroupId: exchangeGroupId,
      paymentListJson: paymentListJson,
      isSplitPayment: paymentListJson != null ? true : null,
      returnReason: returnReason,
      shiftId: shiftId,
    );
  }

  /// ~2,500 sales, ~20% returns. Keys are the sale ids, as every writer does.
  Future<void> seedFixture() async {
    final rnd = Random(3303);
    final sales = <String, SaleModel>{};
    final adjustments = <String, CreditPaymentModel>{};
    final forwardIds = <String>[];

    double money() => rnd.nextInt(2000000) / 100 + rnd.nextInt(1000) / 997;

    final base = DateTime(2025, 11, 1);
    for (var i = 0; i < 2500; i++) {
      final at = base.add(Duration(
          minutes: rnd.nextInt(270 * 24 * 60), microseconds: rnd.nextInt(1000000)));
      final id = 'S${i.toString().padLeft(5, '0')}';
      final roll = rnd.nextInt(10);
      if (roll < 2 && forwardIds.isNotEmpty) {
        final pick = rnd.nextInt(12);
        // Original: a real earlier sale, a missing one, or none recorded.
        final original = pick == 0
            ? 'MISSING-$i'
            : (pick == 1 ? null : forwardIds[rnd.nextInt(forwardIds.length)]);
        final exchange = rnd.nextInt(5) == 0;
        sales[id] = sale(
          id,
          at.toIso8601String(),
          total: money(),
          isReturn: true,
          originalSaleId: original,
          exchangeGroupId: exchange ? 'G$i' : null,
          paymentType: exchange ? 'split' : ['cash', 'upi', 'credit'][rnd.nextInt(3)],
          paymentListJson: exchange
              ? jsonEncode([
                  {'method': 'exchange_credit', 'amount': -money()},
                  if (rnd.nextBool()) {'method': 'cash', 'amount': -money()},
                ])
              : null,
          returnReason: rnd.nextInt(3) == 0 ? null : 'damaged',
          customerId: rnd.nextInt(2) == 0 ? 'C${rnd.nextInt(4)}' : null,
          shiftId: rnd.nextInt(2) == 0 ? 'SH${rnd.nextInt(3)}' : null,
          items: (1 + rnd.nextInt(3)).toDouble(),
        );
        if (original != null && rnd.nextInt(4) == 0) {
          adjustments['CP-$id'] = CreditPaymentModel.create(
            paymentId: 'CP-$id',
            customerId: 'C1',
            saleId: original,
            amount: money() / 3,
            paymentMode: 'return_adjustment',
            referenceId: id,
            balanceBefore: 500,
            balanceAfter: 0,
          );
        }
      } else {
        sales[id] = sale(id, at.toIso8601String(),
            total: money(), paymentType: roll == 9 ? 'credit' : 'cash');
        forwardIds.add(id);
      }
    }

    // Boundary returns against one original.
    sales['O-BOUND'] = sale('O-BOUND', DateTime(2026, 4, 20).toIso8601String(), total: 400);
    for (final e in {
      'R-start-1us': monthStart.subtract(const Duration(microseconds: 1)),
      'R-start': monthStart,
      'R-end-1us': monthEnd.subtract(const Duration(microseconds: 1)),
      'R-end': monthEnd,
    }.entries) {
      sales[e.key] = sale(e.key, e.value.toIso8601String(),
          total: 40.4, isReturn: true, originalSaleId: 'O-BOUND');
    }

    // Originals the window never sees: unparseable and UTC-stamped dates.
    sales['O-BADDATE'] = sale('O-BADDATE', 'not-a-date', total: 250);
    sales['O-UTC'] = sale('O-UTC', '2026-04-30T20:00:00.000Z', total: 250);
    sales['R-TO-BAD'] = sale('R-TO-BAD', DateTime(2026, 5, 10).toIso8601String(),
        total: 25, isReturn: true, originalSaleId: 'O-BADDATE');
    sales['R-TO-UTC'] = sale('R-TO-UTC', DateTime(2026, 5, 11).toIso8601String(),
        total: 25, isReturn: true, originalSaleId: 'O-UTC');
    sales['R-EMPTY-ORIG'] = sale('R-EMPTY-ORIG', DateTime(2026, 5, 12).toIso8601String(),
        total: 25, isReturn: true, originalSaleId: '');

    // Partial then full return of one sale, same instant (tie-break on id).
    sales['O-PF'] = sale('O-PF', DateTime(2026, 5, 2, 9).toIso8601String(), total: 300);
    sales['R-PF-partial'] = sale('R-PF-partial', DateTime(2026, 5, 3, 9).toIso8601String(),
        total: 100, isReturn: true, originalSaleId: 'O-PF');
    sales['R-PF-full'] = sale('R-PF-full', DateTime(2026, 5, 3, 9).toIso8601String(),
        total: 200, isReturn: true, originalSaleId: 'O-PF');

    await Hive.box<SaleModel>(HiveBoxNames.sales).putAll(sales);
    await Hive.box<CreditPaymentModel>(HiveBoxNames.creditPayments).putAll(adjustments);
  }

  final windows = <String, (DateTime?, DateTime?)>{
    'allTime': (null, null),
    'month': (monthStart, monthEnd),
    'startDay': (monthStart, DateTime(2026, 5, 2)),
    'endDay': (DateTime(2026, 5, 31), monthEnd),
    'startOnly': (monthStart, null),
    'endOnly': (null, monthEnd),
    'empty': (DateTime(2030, 1, 1), DateTime(2030, 2, 1)),
  };

  test('Sales Refund output matches the pre-M3 golden for every window', () async {
    await seedFixture();
    final actual = <String>[];
    for (final w in windows.entries) {
      final rows = await service.getSalesRefundReport(
          startDate: w.value.$1, endDate: w.value.$2);
      final rendered = canon(rows);
      actual.add('${w.key} ${rows.length} ${rendered.length} '
          '${sha256.convert(utf8.encode(rendered))}');
    }

    if (_record) {
      _goldenFile.parent.createSync(recursive: true);
      _goldenFile.writeAsStringSync('${actual.join('\n')}\n');
      return;
    }
    expect(_goldenFile.existsSync(), isTrue,
        reason: 'golden missing — it must be recorded from the pre-M3 code');
    final expected =
        _goldenFile.readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();
    expect(actual, expected);
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('boundaries, partial/full returns and missing originals', () async {
    await seedFixture();
    final rows = await service.getSalesRefundReport(
        startDate: monthStart, endDate: monthEnd);
    final byId = {for (final r in rows) r['returnSaleId'] as String: r};

    // [start, end) on the RETURN's own date.
    expect(byId.keys, containsAll(['R-start', 'R-end-1us']));
    expect(byId.keys, isNot(contains('R-start-1us')));
    expect(byId.keys, isNot(contains('R-end')));
    expect(byId['R-start']!['originalSaleDate'], DateTime(2026, 4, 20).toIso8601String());
    expect(byId['R-start']!['daysToReturn'], 11);

    // The original is found even when its own date is unreadable or UTC.
    expect(byId['R-TO-BAD']!['originalSaleDate'], 'not-a-date');
    expect(byId['R-TO-BAD']!['daysToReturn'], isNull);
    expect(byId['R-TO-UTC']!['originalSaleDate'], '2026-04-30T20:00:00.000Z');
    expect(byId['R-TO-UTC']!['daysToReturn'], isNotNull);

    // No such original: the row stays, with no original date.
    expect(byId['R-EMPTY-ORIG']!['originalSaleDate'], isNull);
    expect(byId['R-EMPTY-ORIG']!['daysToReturn'], isNull);

    // Partial and full return of the same sale, both listed at face value.
    expect(byId['R-PF-partial']!['refundValue'], 100.0);
    expect(byId['R-PF-full']!['refundValue'], 200.0);
    final pfOrder = rows
        .map((r) => r['returnSaleId'])
        .where((id) => (id as String).startsWith('R-PF'))
        .toList();
    expect(pfOrder, ['R-PF-full', 'R-PF-partial']); // same instant → id order
  });

  test('exchange return: exchange_credit leg excluded from paid out', () async {
    final box = Hive.box<SaleModel>(HiveBoxNames.sales);
    final at = DateTime(2026, 5, 15, 12).toIso8601String();
    await box.put('O-X', sale('O-X', DateTime(2026, 5, 14).toIso8601String(), total: 500));
    await box.put(
      'R-X',
      sale('R-X', at,
          total: 300,
          isReturn: true,
          originalSaleId: 'O-X',
          exchangeGroupId: 'G-X',
          paymentType: 'split',
          paymentListJson: jsonEncode([
            {'method': 'exchange_credit', 'amount': -250.0},
            {'method': 'cash', 'amount': -50.0},
          ])),
    );
    final rows = await service.getSalesRefundReport(
        startDate: monthStart, endDate: monthEnd);
    expect(rows, hasLength(1));
    expect(rows.single['isExchange'], isTrue);
    expect(rows.single['paidOut'], 50.0);
    expect(rows.single['originalSaleDate'], DateTime(2026, 5, 14).toIso8601String());
    expect(rows.single['daysToReturn'], 1);
  });

  test('writer contract: every sale is stored under its own saleId', () async {
    final repo = SaleRepository();
    final box = Hive.box<SaleModel>(HiveBoxNames.sales);
    final at = DateTime(2026, 5, 1).toIso8601String();

    await repo.addSale(sale('A', at));
    await repo.addSale(sale('B', at, isReturn: true, originalSaleId: 'A'));
    await repo.updateSale(sale('A', at, total: 150));

    expect(box.length, 2, reason: 'an update must replace, never duplicate');
    for (final key in box.keys) {
      expect(box.get(key)!.saleId, key);
    }
    expect(box.values.map((s) => s.saleId).toSet().length, box.length,
        reason: 'unique keys ⇒ unique saleIds');
  });
}
