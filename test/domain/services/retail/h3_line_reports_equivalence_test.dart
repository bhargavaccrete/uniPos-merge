import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/core/plan/entitlements.dart';
import 'package:billberrylite/data/models/common/business_details.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/common/shift_model.dart';
import 'package:billberrylite/data/models/restaurant/db/cash_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/expensel_316.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:billberrylite/data/models/retail/hive_model/credit_payment_model_218.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/data/repositories/common/category_repository.dart';
import 'package:billberrylite/data/repositories/common/customer_repository.dart';
import 'package:billberrylite/data/repositories/common/shift_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/expense_repository.dart';
import 'package:billberrylite/data/repositories/retail/sale_item_repository.dart';
import 'package:billberrylite/data/repositories/retail/variant_repository.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/domain/store/common/category_store.dart';
import 'package:billberrylite/domain/store/restaurant/expense_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/retail/attribute_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';

/// H3 — the retail line-level reports read sales and sale lines without
/// copying whole boxes. That must not move a single paisa, row or ordering.
///
/// The golden file was RECORDED FROM THE PRE-OPTIMIZATION CODE
/// (`--dart-define=H3_RECORD=true`) against the deterministic fixture below,
/// and every report that goes through `_salesInWindow`, `_signedLinesInWindow`
/// or `_itemsBySaleId` is compared against it. Each entry is the SHA-256 of a
/// canonical rendering: doubles in shortest round-trip form (so equality is
/// exact, not within a tolerance), ints/doubles/strings/dates type-tagged,
/// maps in insertion order, lists in order.
///
/// Never re-record to make a change pass. A mismatch means behaviour moved.

const _record = bool.fromEnvironment('H3_RECORD');
final _goldenFile =
    File('test/domain/services/retail/goldens/h3_line_reports.golden');

String canon(Object? v) {
  if (v == null) return 'null';
  if (v is double) return 'd:$v';
  if (v is int) return 'i:$v';
  if (v is bool) return 'b:$v';
  if (v is String) return 's:${jsonEncode(v)}';
  if (v is DateTime) return 't:${v.toIso8601String()}:${v.isUtc}';
  if (v is SaleModel) {
    return 'sale:${canon([
          v.saleId,
          v.createdAt,
          v.totalAmount,
          v.taxAmount,
          v.paymentType,
          v.isReturn,
        ])}';
  }
  if (v is CreditPaymentModel) return 'cp:${canon(v.toString())}';
  if (v is Map) {
    return '{${v.entries.map((e) => '${canon(e.key)}=${canon(e.value)}').join(',')}}';
  }
  if (v is Iterable) return '[${v.map(canon).join(',')}]';
  return 'o:${v.runtimeType}:$v';
}

void main() {
  late Directory tempDir;

  final monthStart = DateTime(2026, 6, 1);
  final monthEnd = DateTime(2026, 7, 1);
  final dayStart = DateTime(2026, 6, 15);
  final dayEnd = DateTime(2026, 6, 16);

  setUp(() async {
    await locator.reset();
    Entitlements.instance.clear();

    tempDir = await Directory.systemTemp.createTemp('h3_line_reports_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BusinessDetailsAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantCashMovement)) {
      Hive.registerAdapter(CashMovementModelAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantExpense1)) {
      Hive.registerAdapter(ExpenseAdapter());
    }

    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'retail');

    await Hive.openBox<SaleModel>(HiveBoxNames.sales);
    await Hive.openBox<SaleItemModel>(HiveBoxNames.saleItems);
    await Hive.openBox<ProductModel>(HiveBoxNames.products);
    await Hive.openBox<VarianteModel>(HiveBoxNames.variants);
    await Hive.openBox<Category>(HiveBoxNames.category);
    await Hive.openBox<AttributeModel>(HiveBoxNames.attributes);
    await Hive.openBox<Customer>(HiveBoxNames.customer);
    await Hive.openBox<CreditPaymentModel>(HiveBoxNames.creditPayments);
    await Hive.openBox<ShiftModel>(HiveBoxNames.shift);
    await Hive.openBox<CashMovementModel>(HiveBoxNames.restaurantCashMovements);
    await Hive.openBox<Expense>(HiveBoxNames.retailExpense);
    await Hive.openBox<BusinessDetails>(HiveBoxNames.businessDetailsBox);

    locator.registerLazySingleton<SaleStore>(() => SaleStore());
    locator.registerLazySingleton<SaleItemRepository>(() => SaleItemRepository());
    locator.registerLazySingleton<VariantRepository>(() => VariantRepository());
    locator.registerLazySingleton<ProductStore>(() => ProductStore());
    locator.registerLazySingleton<AttributeStore>(() => AttributeStore());
    locator.registerLazySingleton<CategoryStore>(
        () => CategoryStore(CategoryRepository()));
    locator.registerLazySingleton<CustomerRepository>(() => CustomerRepository());
    locator.registerLazySingleton<ShiftRepository>(() => ShiftRepository());
    locator.registerLazySingleton<ExpenseStore>(
        () => ExpenseStore(ExpenseRepository()));
    locator.registerLazySingleton<LicenseStore>(
        () => LicenseStore(LicenseApiService()));
    locator.registerLazySingleton<BusinessDetailsRepository>(
        () => BusinessDetailsRepository());
    await businessDetailsRepository
        .save(BusinessDetails(storeName: 'Test Store', country: 'India'));
  });

  tearDown(() async {
    Entitlements.instance.clear();
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // ── Fixture helpers ───────────────────────────────────────────────────────

  final sales = <String, SaleModel>{};
  final lines = <String, SaleItemModel>{};

  SaleModel saleOf(
    String saleId,
    String createdAt, {
    required double total,
    double tax = 0,
    double discount = 0,
    bool isReturn = false,
    String paymentType = 'cash',
    String? originalSaleId,
    String? exchangeGroupId,
    String? paymentListJson,
    bool? isSplitPayment,
    int? loyaltyPointsUsed,
    String? customerId,
    String? shiftId,
    double items = 1,
  }) {
    final s = isReturn ? -1 : 1;
    return SaleModel(
      saleId: saleId,
      customerId: customerId,
      totalItems: items,
      subtotal: s * (total - tax),
      discountAmount: s * discount,
      taxAmount: s * tax,
      totalAmount: s * total,
      paymentType: paymentType,
      date: createdAt,
      createdAt: createdAt,
      updatedAt: createdAt,
      isReturn: isReturn,
      originalSaleId: originalSaleId,
      totalTaxableAmount: s * (total - tax),
      totalGstAmount: s * tax,
      grandTotal: s * total,
      paymentListJson: paymentListJson,
      isSplitPayment: isSplitPayment,
      loyaltyPointsUsed: loyaltyPointsUsed,
      exchangeGroupId: exchangeGroupId,
      shiftId: shiftId,
    );
  }

  /// Builds a fixture of ~3,000 sales and ~10,000 lines. Deterministic.
  ///
  /// Line keys are random hex so Hive's key order interleaves lines from
  /// different sales and periods — iteration order is part of what is pinned.
  void buildFixture() {
    sales.clear();
    lines.clear();
    final rnd = Random(20260917);
    var lineSeq = 0;

    double messy(int max) => rnd.nextInt(max) / 100 + rnd.nextInt(1000) / 997;

    String lineKey() =>
        'L${rnd.nextInt(1 << 30).toRadixString(16).padLeft(8, '0')}-${lineSeq++}';

    void addLines(String saleId, int count, {bool quickOnly = false}) {
      for (var j = 0; j < count; j++) {
        final isQuick = quickOnly || rnd.nextInt(12) == 0;
        final qtyPick = rnd.nextInt(10);
        final qty = qtyPick == 0
            ? 0.0
            : (qtyPick == 1 ? rnd.nextInt(3000) / 1000 : (1 + rnd.nextInt(5)).toDouble());
        final price = rnd.nextInt(15) == 0 ? 0.0 : messy(90000);
        final gross = price * qty;
        final disc = rnd.nextInt(4) == 0 ? gross * rnd.nextInt(30) / 100 : 0.0;
        final rates = <double?>[null, 0, 5, 12, 12.5, 18];
        final rate = rates[rnd.nextInt(rates.length)];
        final taxable = gross - disc;
        final gst = rate == null ? null : taxable * rate / 100;
        final hasOverride = rnd.nextInt(8) == 0;
        final key = lineKey();
        lines[key] = SaleItemModel(
          saleItemId: key,
          saleId: saleId,
          varianteId: isQuick
              ? 'QUICK-${rnd.nextInt(1 << 20)}'
              : 'V${rnd.nextInt(40)}',
          productId: isQuick ? 'QUICK-P${rnd.nextInt(1 << 20)}' : 'P${rnd.nextInt(15)}',
          productName: rnd.nextInt(10) == 0
              ? null
              : (isQuick ? ['Gift Wrap', 'gift wrap ', 'Carry Bag', ''][rnd.nextInt(4)] : 'Product ${rnd.nextInt(15)}'),
          size: rnd.nextInt(5) == 0 ? 'L' : null,
          color: rnd.nextInt(5) == 0 ? 'Red' : null,
          price: price,
          qty: qty,
          total: taxable + (gst ?? 0),
          discountAmount: rnd.nextInt(6) == 0 ? null : disc,
          taxAmount: rnd.nextInt(7) == 0 ? null : gst,
          gstAmount: rnd.nextInt(7) == 0 ? null : gst,
          taxableAmount: rnd.nextInt(9) == 0 ? null : taxable,
          gstRate: rate,
          costPrice: rnd.nextInt(3) == 0 ? null : messy(50000),
          originalPrice: hasOverride ? price + messy(5000) : null,
          overrideReason: hasOverride ? 'manager_approval' : null,
          lineDiscountAmount: rnd.nextInt(5) == 0 ? disc / 2 : null,
          lineDiscountReason: rnd.nextInt(9) == 0 ? 'damaged' : null,
        );
      }
    }

    String iso(DateTime d) => d.toIso8601String();

    // History spread across two years, window included.
    final historyStart = DateTime(2025, 1, 1);
    final saleIds = <String>[];
    for (var i = 0; i < 2600; i++) {
      final at = historyStart.add(Duration(
        minutes: rnd.nextInt(730 * 24 * 60),
        microseconds: rnd.nextInt(1000000),
      ));
      final id = 'S${i.toString().padLeft(5, '0')}';
      final roll = rnd.nextInt(20);
      if (roll < 3 && saleIds.isNotEmpty) {
        // Return against an earlier sale.
        final exchange = roll == 0 ? 'EX-$i' : null;
        sales[id] = saleOf(
          id,
          iso(at),
          total: messy(200000),
          tax: messy(20000),
          isReturn: true,
          originalSaleId: saleIds[rnd.nextInt(saleIds.length)],
          exchangeGroupId: exchange,
          paymentType: exchange != null ? 'split' : 'cash',
          paymentListJson: exchange != null
              ? jsonEncode([
                  {'method': 'exchange_credit', 'amount': -messy(100000)},
                  {'method': 'cash', 'amount': -messy(50000)},
                ])
              : null,
          isSplitPayment: exchange != null ? true : null,
          shiftId: rnd.nextInt(2) == 0 ? 'SH1' : null,
        );
        if (exchange != null) {
          final fwd = '$id-X';
          sales[fwd] = saleOf(
            fwd,
            iso(at.add(const Duration(seconds: 1))),
            total: messy(300000),
            tax: messy(30000),
            exchangeGroupId: exchange,
            paymentType: 'split',
            paymentListJson: jsonEncode([
              {'method': 'exchange_credit', 'amount': messy(100000)},
              {'method': 'upi', 'amount': messy(50000)},
            ]),
            isSplitPayment: true,
          );
          addLines(fwd, 1 + rnd.nextInt(3));
        }
      } else {
        sales[id] = saleOf(
          id,
          iso(at),
          total: messy(500000),
          tax: messy(40000),
          discount: rnd.nextInt(4) == 0 ? messy(10000) : 0,
          paymentType: ['cash', 'upi', 'card', 'credit'][rnd.nextInt(4)],
          loyaltyPointsUsed: rnd.nextInt(10) == 0 ? rnd.nextInt(50) : null,
          customerId: rnd.nextInt(3) == 0 ? 'C${rnd.nextInt(5)}' : null,
          shiftId: rnd.nextInt(2) == 0 ? 'SH${rnd.nextInt(3)}' : null,
        );
        saleIds.add(id);
      }
      addLines(id, 1 + rnd.nextInt(6));
    }

    // Boundary sales around the month and day windows.
    final boundaries = <String, DateTime>{
      'B-month-start-1us': monthStart.subtract(const Duration(microseconds: 1)),
      'B-month-start': monthStart,
      'B-month-end-1us': monthEnd.subtract(const Duration(microseconds: 1)),
      'B-month-end': monthEnd,
      'B-month-end+1us': monthEnd.add(const Duration(microseconds: 1)),
      'B-day-start-1us': dayStart.subtract(const Duration(microseconds: 1)),
      'B-day-start': dayStart,
      'B-day-end-1us': dayEnd.subtract(const Duration(microseconds: 1)),
      'B-day-end': dayEnd,
    };
    for (final e in boundaries.entries) {
      sales[e.key] = saleOf(e.key, iso(e.value), total: messy(90000), tax: messy(9000));
      addLines(e.key, 2);
    }

    // UTC-stamped createdAt values, including instants on the local boundaries.
    final utc = <String, String>{
      'U-mid': '2026-06-10T05:00:00.000Z',
      'U-start': monthStart.toUtc().toIso8601String(),
      'U-start-1us':
          monthStart.subtract(const Duration(microseconds: 1)).toUtc().toIso8601String(),
      'U-end': monthEnd.toUtc().toIso8601String(),
      'U-day-noon': DateTime(2026, 6, 15, 12).toUtc().toIso8601String(),
    };
    for (final e in utc.entries) {
      sales[e.key] = saleOf(e.key, e.value, total: messy(90000), tax: messy(9000));
      addLines(e.key, 3);
    }

    // Unparseable / odd createdAt values.
    for (final e in {
      'M-garbage': 'not-a-date',
      'M-empty': '',
      'M-overflow': '2026-13-45T10:00:00', // accepted and normalised by tryParse
      'M-dateonly': '2026-06-20',
    }.entries) {
      sales[e.key] = saleOf(e.key, e.value, total: messy(90000), tax: messy(9000));
      addLines(e.key, 2);
    }

    // Two box keys carrying the same saleId, both inside the window.
    sales['DUP-A'] = saleOf('S-DUP', iso(DateTime(2026, 6, 12, 9)), total: 100, tax: 5);
    sales['DUP-B'] = saleOf('S-DUP', iso(DateTime(2026, 6, 12, 11)),
        total: 200, tax: 10, isReturn: true, originalSaleId: 'S00001');
    addLines('S-DUP', 3);

    // A window sale with only quick items; a window sale with no lines.
    sales['Q-ONLY'] = saleOf('Q-ONLY', iso(DateTime(2026, 6, 15, 14)), total: 55, tax: 0);
    addLines('Q-ONLY', 4, quickOnly: true);
    sales['NO-LINES'] = saleOf('NO-LINES', iso(DateTime(2026, 6, 15, 15)), total: 10);

    // Lines whose sale does not exist.
    addLines('ORPHAN-SALE', 25);
  }

  Future<void> seedFixture() async {
    buildFixture();
    await Hive.box<SaleModel>(HiveBoxNames.sales).putAll(sales);
    await Hive.box<SaleItemModel>(HiveBoxNames.saleItems).putAll(lines);

    final variants = Hive.box<VarianteModel>(HiveBoxNames.variants);
    for (var i = 0; i < 40; i += 2) {
      await variants.put(
        'V$i',
        VarianteModel(
          varianteId: 'V$i',
          productId: 'P${i % 15}',
          costPrice: i % 6 == 0 ? null : i * 13.37 + 0.01,
          createdAt: DateTime(2025).toIso8601String(),
        ),
      );
    }
    final products = Hive.box<ProductModel>(HiveBoxNames.products);
    for (var i = 0; i < 15; i++) {
      await products.put(
        'P$i',
        ProductModel(
          productId: 'P$i',
          productName: 'Product $i',
          category: i % 4 == 0 ? '' : 'CAT${i % 3}',
          hasVariants: false,
          createdAt: DateTime(2025).toIso8601String(),
          updateAt: DateTime(2025).toIso8601String(),
        ),
      );
    }
    await productStore.ensureLoaded();
    await productStore.loadProducts();
  }

  /// Every affected report, for every window shape, rendered canonically.
  Future<Map<String, String>> snapshotAll() async {
    final out = <String, String>{};
    final windows = <String, (DateTime?, DateTime?)>{
      'month': (monthStart, monthEnd),
      'day': (dayStart, dayEnd),
      'firstDay': (monthStart, monthStart.add(const Duration(days: 1))),
      'unbounded': (null, null),
      'startOnly': (monthStart, null),
      'endOnly': (null, monthEnd),
    };

    Future<void> take(String name, Future<Object?> Function() run) async {
      out[name] = canon(await run());
    }

    for (final w in windows.entries) {
      final (s, e) = w.value;
      final k = w.key;
      final svc = ReportService();
      await take('product/$k', () => svc.getProductWiseSalesReport(startDate: s, endDate: e));
      await take('variant/$k', () => svc.getVariantWiseSalesReport(startDate: s, endDate: e));
      await take('category/$k', () => svc.getCategoryWiseSalesReport(startDate: s, endDate: e));
      await take('topSelling/$k',
          () => svc.getTopSellingProductsReport(limit: 20, startDate: s, endDate: e));
      await take('quickItems/$k', () => svc.getQuickItemsReport(startDate: s, endDate: e));
      await take('discount/$k', () => svc.getDiscountReport(startDate: s, endDate: e));
      await take('gst/$k', () => svc.getGstSummaryReport(startDate: s, endDate: e));
      await take('profit/$k', () => svc.getProfitReport(startDate: s, endDate: e));
      await take('profitPerItem/$k', () => svc.getProfitPerItemReport(startDate: s, endDate: e));
      await take('profitPerSale/$k', () => svc.getProfitPerSaleReport(startDate: s, endDate: e));
      await take('profitPerDay/$k', () => svc.getProfitPerDayReport(startDate: s, endDate: e));
      await take('salesRefund/$k', () => svc.getSalesRefundReport(startDate: s, endDate: e));
      await take('cashDrawer/$k', () => svc.getCashDrawerReport(startDate: s, endDate: e));
    }
    final svc = ReportService();
    await take('daily/2026-06-15', () => svc.getDailySalesReport(DateTime(2026, 6, 15)));
    await take('daily/2026-06-01', () => svc.getDailySalesReport(DateTime(2026, 6, 1)));
    await take('daily/2026-06-30', () => svc.getDailySalesReport(DateTime(2026, 6, 30)));
    await take('monthly/2026-06', () => svc.getMonthlySalesReport(2026, 6));
    await take('monthly/2025-12', () => svc.getMonthlySalesReport(2025, 12));
    return out;
  }

  String digestLine(String name, String rendered) =>
      '$name ${rendered.length} ${sha256.convert(utf8.encode(rendered))}';

  test('every affected report is identical to the pre-H3 golden', () async {
    await seedFixture();
    final snap = await snapshotAll();
    final actual = [for (final e in snap.entries) digestLine(e.key, e.value)];

    if (_record) {
      _goldenFile.parent.createSync(recursive: true);
      _goldenFile.writeAsStringSync('${actual.join('\n')}\n');
      return;
    }

    expect(_goldenFile.existsSync(), isTrue,
        reason: 'golden missing — it must be recorded from the pre-H3 code');
    final expected = _goldenFile
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toList();
    expect(actual.length, expected.length);
    for (var i = 0; i < expected.length; i++) {
      expect(actual[i], expected[i], reason: 'report output changed: ${expected[i].split(' ').first}');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  group('pinned semantics (hold before and after H3)', () {
    test('[start, end): -1µs out, start in, end-1µs in, end out, end+1µs out', () async {
      final box = Hive.box<SaleModel>(HiveBoxNames.sales);
      final items = Hive.box<SaleItemModel>(HiveBoxNames.saleItems);
      final stamps = <String, DateTime>{
        'before': monthStart.subtract(const Duration(microseconds: 1)),
        'start': monthStart,
        'lastMicro': monthEnd.subtract(const Duration(microseconds: 1)),
        'end': monthEnd,
        'after': monthEnd.add(const Duration(microseconds: 1)),
      };
      for (final e in stamps.entries) {
        final iso = e.value.toIso8601String();
        await box.put(e.key, saleOf(e.key, iso, total: 10));
        await items.put(
          'line-${e.key}',
          SaleItemModel(
            saleItemId: 'line-${e.key}',
            saleId: e.key,
            varianteId: 'V-${e.key}',
            productId: 'P-${e.key}',
            productName: e.key,
            price: 10,
            qty: 1,
            total: 10,
          ),
        );
      }
      final rows = await ReportService()
          .getProductWiseSalesReport(startDate: monthStart, endDate: monthEnd);
      expect(rows.map((r) => r['productId']).toSet(), {'P-start', 'P-lastMicro'});
    });

    test('unparseable createdAt: dropped silently when bounded, counted when unbounded', () async {
      final box = Hive.box<SaleModel>(HiveBoxNames.sales);
      await box.put('ok', saleOf('ok', DateTime(2026, 6, 15, 10).toIso8601String(), total: 50));
      await box.put('bad', saleOf('bad', 'not-a-date', total: 70));
      await box.put('empty', saleOf('empty', '', total: 80));

      final bounded = await ReportService().getMonthlySalesReport(2026, 6);
      expect(bounded['skippedRows'], 0);

      final gstUnbounded = await ReportService().getGstSummaryReport();
      expect(gstUnbounded['skippedRows'], 2);
      final gstBounded = await ReportService()
          .getGstSummaryReport(startDate: monthStart, endDate: monthEnd);
      expect(gstBounded['skippedRows'], 0);
    });

    test('return and exchange lines net against the sale; orphans and outsiders ignored', () async {
      final box = Hive.box<SaleModel>(HiveBoxNames.sales);
      final items = Hive.box<SaleItemModel>(HiveBoxNames.saleItems);
      final inWindow = DateTime(2026, 6, 15, 10).toIso8601String();
      final outside = DateTime(2026, 5, 15, 10).toIso8601String();

      SaleItemModel line(String id, String saleId, double qty, double total) => SaleItemModel(
            saleItemId: id,
            saleId: saleId,
            varianteId: 'V1',
            productId: 'P1',
            productName: 'Tea',
            price: qty == 0 ? 0 : total / qty,
            qty: qty,
            total: total,
            taxAmount: total * 0.05,
            gstAmount: total * 0.05,
            taxableAmount: total * 0.95,
            gstRate: 5,
          );

      await box.put('sale', saleOf('sale', inWindow, total: 300.1));
      await box.put('ret', saleOf('ret', inWindow, total: 100.2, isReturn: true, originalSaleId: 'sale'));
      await box.put(
        'exch',
        saleOf('exch', inWindow,
            total: 50.3,
            isReturn: true,
            originalSaleId: 'sale',
            exchangeGroupId: 'G1',
            paymentType: 'split',
            isSplitPayment: true,
            paymentListJson: jsonEncode([
              {'method': 'exchange_credit', 'amount': -50.3},
            ])),
      );
      await box.put('old', saleOf('old', outside, total: 999));
      await items.putAll({
        'a1': line('a1', 'sale', 3, 300.1),
        'a2': line('a2', 'ret', 1, 100.2),
        'a3': line('a3', 'exch', 0.5, 50.3),
        'a4': line('a4', 'old', 7, 999),
        'a5': line('a5', 'ghost', 11, 1234),
      });

      final rows = await ReportService()
          .getProductWiseSalesReport(startDate: monthStart, endDate: monthEnd);
      expect(rows, hasLength(1));
      expect(rows.single['totalQuantity'], 1.5);
      expect(rows.single['totalRevenue'], 149.6);

      final gst = await ReportService()
          .getGstSummaryReport(startDate: monthStart, endDate: monthEnd);
      expect(gst['lineCount'], 3);
      expect(gst['saleCount'], 1);
      expect(gst['returnCount'], 2);
    });
  });
}
