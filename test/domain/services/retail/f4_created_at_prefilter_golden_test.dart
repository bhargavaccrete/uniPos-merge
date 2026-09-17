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

/// Task 4F — the `createdAt` string pre-filter must not move a single sale.
///
/// Goldens were RECORDED FROM THE PRE-4F CODE (`--dart-define=F4_RECORD=true`),
/// one file per local UTC offset, because instants in `Z`/offset strings land
/// differently against local windows in each zone. Run under another offset
/// with e.g. `TZ=EST+5EDT+4` (fixed −5 h) or `TZ=WST-13` (fixed +13 h) — the
/// Windows Dart VM honours only fixed whole-hour offsets from `TZ`.
///
/// Never re-record to make a change pass.

const _record = bool.fromEnvironment('F4_RECORD');

String canon(Object? v) {
  if (v == null) return 'null';
  if (v is double) return 'd:$v';
  if (v is int) return 'i:$v';
  if (v is bool) return 'b:$v';
  if (v is String) return 's:${jsonEncode(v)}';
  if (v is DateTime) return 't:${v.toIso8601String()}:${v.isUtc}';
  if (v is SaleModel) return 'sale:${v.saleId}:${jsonEncode(v.createdAt)}:${v.totalAmount}';
  if (v is Map) {
    return '{${v.entries.map((e) => '${canon(e.key)}=${canon(e.value)}').join(',')}}';
  }
  if (v is Iterable) return '[${v.map(canon).join(',')}]';
  return 'o:${v.runtimeType}:$v';
}

void main() {
  late Directory tempDir;

  final start = DateTime(2026, 6, 1);
  final end = DateTime(2026, 7, 1);
  final offsetMinutes = start.timeZoneOffset.inMinutes;
  final goldenFile = File(
      'test/domain/services/retail/goldens/f4_created_at_prefilter_tz$offsetMinutes.golden');

  setUp(() async {
    await locator.reset();
    Entitlements.instance.clear();

    tempDir = await Directory.systemTemp.createTemp('f4_prefilter_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(BusinessDetailsAdapter());
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
    locator.registerLazySingleton<CategoryStore>(() => CategoryStore(CategoryRepository()));
    locator.registerLazySingleton<CustomerRepository>(() => CustomerRepository());
    locator.registerLazySingleton<ShiftRepository>(() => ShiftRepository());
    locator.registerLazySingleton<ExpenseStore>(() => ExpenseStore(ExpenseRepository()));
    locator.registerLazySingleton<LicenseStore>(() => LicenseStore(LicenseApiService()));
    locator.registerLazySingleton<BusinessDetailsRepository>(() => BusinessDetailsRepository());
    await businessDetailsRepository.save(BusinessDetails(storeName: 'T', country: 'India'));
  });

  tearDown(() async {
    Entitlements.instance.clear();
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Every createdAt shape the pre-filter must either decide correctly or
  /// hand to `tryParse` untouched.
  List<String> specialStamps() {
    String iso(DateTime d) => d.toIso8601String();
    final out = <String>[];
    for (final bound in [start, end]) {
      for (final days in [-5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5]) {
        final day = DateTime(bound.year, bound.month, bound.day + days);
        out.addAll([
          iso(day), // 23 chars, midnight
          iso(day.add(const Duration(microseconds: 1))), // 26 chars
          iso(day.subtract(const Duration(microseconds: 1))), // 26 chars, 23:59:59.999999
          iso(day.subtract(const Duration(milliseconds: 1))), // 23 chars
          iso(DateTime(day.year, day.month, day.day, 12, 30, 15, 250, 125)),
        ]);
      }
    }
    out.addAll([
      // Canonical shape, invalid fields — tryParse normalises these.
      '2026-02-30T10:00:00.000',
      '2026-13-01T10:00:00.000',
      '2026-00-01T10:00:00.000',
      '2026-01-00T10:00:00.000',
      '2026-01-01T24:00:00.000',
      '2026-01-01T00:60:00.000',
      '2026-01-01T00:00:60.000',
      '2026-05-32T10:00:00.000', // → 1 June: inside the window
      '2026-05-31T24:00:00.000', // → 1 June 00:00: inside
      '2026-06-31T10:00:00.000', // → 1 July: excluded at the end
      '2026-06-30T24:00:00.000', // → 1 July 00:00: excluded
      '2026-04-45T10:00:00.000', // → 15 May
      '2026-07-00T10:00:00.000', // → 30 June: inside
      '2027-02-29T10:00:00.000', // not a leap year → 1 March
      '2028-02-29T10:00:00.000', // leap year: valid
      '2026-06-15T99:99:99.999999',
      // Non-canonical — must always go through tryParse.
      '2026-06-10T05:00:00.000Z',
      '2026-05-31T20:00:00.000Z',
      '2026-06-30T20:00:00.000Z',
      '2026-06-10T10:30:00+05:30',
      '2026-06-30T23:30:00-05:00',
      '2026-05-31T23:30:00+13:00',
      '2026-06-15',
      '2026-07-01',
      '2026-06-15 10:30:00',
      '2026-06-15T10:30:00,123',
      '2026-06-15T10:30',
      '2026-06-15T10:30:00',
      '2026-06-15T10:30:00.1234567',
      '2026-06-15T10:30:00.12',
      '2026-06-15t10:30:00.000',
      ' 2026-06-15T10:30:00.000',
      '20260615T103000',
      '+02026-06-15T10:30:00.000',
      'not-a-date',
      '',
      '2026-06-15T10:30:00.000 ',
      '2026/06/15T10:30:00.000',
      '2026-06-15X10:30:00.000',
      'abcd-ef-ghTij:kl:mn.opq',
    ]);
    return out;
  }

  Future<void> seed() async {
    final rnd = Random(4604);
    final sales = <String, SaleModel>{};
    final lines = <String, SaleItemModel>{};
    var n = 0;

    void add(String createdAt, {bool isReturn = false}) {
      final id = 'S${(n++).toString().padLeft(5, '0')}';
      final total = rnd.nextInt(90000) / 100 + rnd.nextInt(1000) / 997;
      final s = isReturn ? -1 : 1;
      sales[id] = SaleModel(
        saleId: id,
        totalItems: 1,
        subtotal: s * total * 0.9,
        discountAmount: 0,
        taxAmount: s * total * 0.1,
        totalAmount: s * total,
        paymentType: ['cash', 'upi', 'card', 'credit'][rnd.nextInt(4)],
        date: createdAt,
        createdAt: createdAt,
        updatedAt: createdAt,
        isReturn: isReturn,
        originalSaleId: isReturn ? 'S00000' : null,
      );
      for (var j = 0; j < 1 + rnd.nextInt(3); j++) {
        final key = 'L${rnd.nextInt(1 << 30).toRadixString(16)}-$n-$j';
        final lt = rnd.nextInt(50000) / 100;
        lines[key] = SaleItemModel(
          saleItemId: key,
          saleId: id,
          varianteId: 'V${rnd.nextInt(20)}',
          productId: 'P${rnd.nextInt(8)}',
          productName: 'Product',
          price: lt,
          qty: 1,
          total: lt,
          taxAmount: lt * 0.05,
          gstAmount: lt * 0.05,
          taxableAmount: lt * 0.95,
          gstRate: 5,
          costPrice: rnd.nextBool() ? lt * 0.6 : null,
        );
      }
    }

    // Bulk canonical history, both lengths, two years.
    final base = DateTime(2025, 6, 1);
    for (var i = 0; i < 5000; i++) {
      final at = base.add(Duration(
          minutes: rnd.nextInt(730 * 24 * 60),
          microseconds: rnd.nextBool() ? 0 : rnd.nextInt(1000000)));
      add(at.toIso8601String(), isReturn: rnd.nextInt(10) == 0);
    }
    for (final stamp in specialStamps()) {
      add(stamp);
      add(stamp, isReturn: true);
    }

    await Hive.box<SaleModel>(HiveBoxNames.sales).putAll(sales);
    await Hive.box<SaleItemModel>(HiveBoxNames.saleItems).putAll(lines);
    await productStore.ensureLoaded();
  }

  test('reports and range reads match the pre-4F golden for this UTC offset', () async {
    await seed();
    final windows = <String, (DateTime?, DateTime?)>{
      'month': (start, end),
      'startOnly': (start, null),
      'endOnly': (null, end),
      'allTime': (null, null),
      'empty': (DateTime(2030, 1, 1), DateTime(2030, 1, 2)),
      'oneDay': (DateTime(2026, 6, 15), DateTime(2026, 6, 16)),
      'midDayBounds': (DateTime(2026, 6, 1, 13, 45), DateTime(2026, 6, 3, 2, 15)),
      'utcBounds': (DateTime.utc(2026, 6, 1), DateTime.utc(2026, 7, 1)),
    };

    final out = <String>[];
    Future<void> take(String name, Object? value) async {
      final r = canon(value);
      out.add('$name ${r.length} ${sha256.convert(utf8.encode(r))}');
    }

    for (final w in windows.entries) {
      final (s, e) = w.value;
      final k = w.key;
      final svc = ReportService();
      await take('gst/$k', await svc.getGstSummaryReport(startDate: s, endDate: e));
      await take('product/$k', await svc.getProductWiseSalesReport(startDate: s, endDate: e));
      await take('profitPerSale/$k', await svc.getProfitPerSaleReport(startDate: s, endDate: e));
      await take('profitPerDay/$k', await svc.getProfitPerDayReport(startDate: s, endDate: e));
      await take('refund/$k', await svc.getSalesRefundReport(startDate: s, endDate: e));
      await take('cashDrawer/$k', await svc.getCashDrawerReport(startDate: s, endDate: e));
      await take('discount/$k', await svc.getDiscountReport(startDate: s, endDate: e));
      if (s != null && e != null) {
        await take('repoRange/$k', await saleStore.getSalesByDateRange(s, e));
      }
    }
    final svc = ReportService();
    await take('daily/2026-06-01', await svc.getDailySalesReport(DateTime(2026, 6, 1)));
    await take('daily/2026-06-30', await svc.getDailySalesReport(DateTime(2026, 6, 30)));
    await take('monthly/2026-06', await svc.getMonthlySalesReport(2026, 6));

    if (_record) {
      goldenFile.parent.createSync(recursive: true);
      goldenFile.writeAsStringSync('${out.join('\n')}\n');
      // ignore: avoid_print
      print('F4 recorded ${goldenFile.path} (${out.length} entries)');
      return;
    }
    expect(goldenFile.existsSync(), isTrue,
        reason: 'no pre-4F golden for UTC offset $offsetMinutes min — '
            'it must be recorded from the pre-4F code under this offset');
    final expected = goldenFile.readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();
    expect(out.length, expected.length);
    for (var i = 0; i < expected.length; i++) {
      expect(out[i], expected[i], reason: 'changed: ${expected[i].split(' ').first}');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
