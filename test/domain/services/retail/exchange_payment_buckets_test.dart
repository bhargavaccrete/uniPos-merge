import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';

import 'package:billberrylite/data/models/common/business_details.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/restaurant/db/cash_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/eodmodel_317.dart';
import 'package:billberrylite/data/models/restaurant/db/expensel_316.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/credit_payment_model_218.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';

import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/data/repositories/common/customer_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/cash_movement_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/expense_repository.dart';
import 'package:billberrylite/data/repositories/retail/credit_payment_repository.dart';
import 'package:billberrylite/data/repositories/retail/sale_item_repository.dart';
import 'package:billberrylite/data/repositories/retail/variant_repository.dart';

import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/restaurant/eod_service.dart';
import 'package:billberrylite/domain/services/retail/auth_service.dart';
import 'package:billberrylite/domain/services/retail/eod_report_service.dart';
import 'package:billberrylite/domain/services/retail/exchange_service.dart';
import 'package:billberrylite/domain/services/retail/gst_service.dart';
import 'package:billberrylite/domain/services/retail/return_service.dart';
import 'package:billberrylite/domain/store/common/customer_store.dart';
import 'package:billberrylite/domain/store/restaurant/cash_movement_store.dart';
import 'package:billberrylite/domain/store/restaurant/expense_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';
import 'package:billberrylite/util/restaurant/restaurant_auth_helper.dart';
import 'package:billberrylite/util/retail/cash_drawer_ledger.dart';

/// EOD PAYMENT BUCKETS AFTER AN EXCHANGE — real money only.
///
/// The bug these pin: the replacement sale recorded the refund method against
/// the WHOLE replacement value, so a ₹200 refund put ₹800 into the UPI bucket
/// and a ₹200 collection put ₹1200 there.
///
/// The rule now: an `exchange_credit` leg carries the value of the goods handed
/// back. It is an internal accounting entry, is SUPPRESSED from payment-method
/// totals, and never touches the drawer. Buckets show only what actually moved.
void main() {
  late Directory tempDir;
  late ExchangeService service;

  setUp(() async {
    await locator.reset();
    SharedPreferences.setMockInitialValues({
      RestaurantAuthHelper.adminPinKey:
          RestaurantAuthHelper.hashPassword('1234'),
    });

    tempDir = await Directory.systemTemp.createTemp('exchange_buckets_');
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
    await Hive.openBox<CashMovementModel>(HiveBoxNames.restaurantCashMovements);
    await Hive.openBox<StockMovementModel>(
        HiveBoxNames.restaurantStockMovements);
    await Hive.openBox<BusinessDetails>(HiveBoxNames.businessDetailsBox);
    await Hive.openBox<Expense>(HiveBoxNames.retailExpense);
    await Hive.openBox<EndOfDayReport>(HiveBoxNames.retailEOD);
    await Hive.openBox(HiveBoxNames.dayManagementBox);
    await Hive.openBox(HiveBoxNames.appCounters);

    locator.registerLazySingleton<SaleStore>(() => SaleStore());
    locator.registerLazySingleton<SaleItemRepository>(
        () => SaleItemRepository());
    locator.registerLazySingleton<VariantRepository>(() => VariantRepository());
    locator.registerLazySingleton<ProductStore>(() => ProductStore());
    locator.registerLazySingleton<CustomerStore>(
        () => CustomerStore(CustomerRepository()));
    locator.registerLazySingleton<CreditPaymentRepository>(
        () => CreditPaymentRepository());
    locator.registerLazySingleton<CashMovementRepository>(
        () => CashMovementRepository());
    locator.registerLazySingleton<CashMovementStore>(
        () => CashMovementStore(locator<CashMovementRepository>()));
    locator.registerLazySingleton<BusinessDetailsRepository>(
        () => BusinessDetailsRepository());
    locator.registerLazySingleton<ExpenseStore>(
        () => ExpenseStore(ExpenseRepository()));
    locator.registerLazySingleton<LicenseStore>(
        () => LicenseStore(LicenseApiService()));
    locator.registerLazySingleton<GstService>(() => GstService());
    locator.registerLazySingleton<AuthService>(() => AuthService());

    await authService.login('1234');
    service = ExchangeService();
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // ── Seeding ───────────────────────────────────────────────────────────────

  /// Zero-rated so every figure in the tests is the round number it looks like.
  Future<void> seedCatalogue({
    required double sold,
    required double replacement,
  }) async {
    await Hive.box<ProductModel>(HiveBoxNames.products).put(
      'p1',
      ProductModel(
        productId: 'p1',
        productName: 'Test Item',
        category: 'Apparel',
        hasVariants: true,
        createdAt: DateTime.now().toIso8601String(),
        updateAt: DateTime.now().toIso8601String(),
      ),
    );
    final box = Hive.box<VarianteModel>(HiveBoxNames.variants);
    await box.put(
      'v1',
      VarianteModel(
        varianteId: 'v1',
        productId: 'p1',
        sellingPrice: sold,
        stockQty: 9,
        costPrice: 60,
        taxRate: 0,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    await box.put(
      'v2',
      VarianteModel(
        varianteId: 'v2',
        productId: 'p1',
        sellingPrice: replacement,
        stockQty: 5,
        costPrice: 60,
        taxRate: 0,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  Future<void> seedSale({
    required double price,
    required String paymentType,
  }) async {
    // Two seconds back: the EOD window's end bound is exclusive and computed
    // as `DateTime.now()` inside the report.
    final now = DateTime.now()
        .subtract(const Duration(seconds: 2))
        .toIso8601String();

    await Hive.box<SaleModel>(HiveBoxNames.sales).put(
      'S1',
      SaleModel(
        saleId: 'S1',
        totalItems: 1,
        subtotal: price,
        discountAmount: 0,
        taxAmount: 0,
        totalAmount: price,
        paymentType: paymentType,
        date: now,
        createdAt: now,
        updatedAt: now,
        totalTaxableAmount: price,
        totalGstAmount: 0,
        grandTotal: price,
        totalPaid: price,
        paidAmount: price,
      ),
    );
    await Hive.box<SaleItemModel>(HiveBoxNames.saleItems).put(
      'S1-L1',
      SaleItemModel.fromCalculated(
        saleId: 'S1',
        varianteId: 'v1',
        productId: 'p1',
        productName: 'Test Item',
        price: price,
        qty: 1,
        discountAmount: 0,
        gstRate: 0,
        taxableAmount: price,
        gstAmount: 0,
        total: price,
        costPrice: 60,
      ),
    );
  }

  List<SaleModel> allSales() =>
      Hive.box<SaleModel>(HiveBoxNames.sales).values.toList();

  Future<ExchangeResult> exchange(String method) => service.processExchange(
        originalSaleId: 'S1',
        returnedVariantId: 'v1',
        returnQty: 1,
        replacementVariantId: 'v2',
        paymentMethod: method,
      );

  Future<EndOfDayReport> eod() => EODService.generateRetailEODReport(
        date: DateTime.now(),
        openingBalance: 1000,
        actualCash: 0,
      );

  /// One payment bucket from the generated EOD, 0 when absent.
  double bucket(EndOfDayReport report, String label) => report.paymentSummaries
      .where((p) => p.paymentType.toLowerCase() == label.toLowerCase())
      .fold<double>(0, (sum, p) => sum + p.totalAmount);

  /// Everything the exchange documents put through the drawer.
  double drawerCash() {
    final exchangeDocs = allSales().where((s) => s.saleId != 'S1');
    var total = 0.0;
    for (final sale in exchangeDocs) {
      total += CashDrawerLedger.cashComponentOf(sale);
      total -= CashDrawerLedger.cashRefundOf(sale);
    }
    return total;
  }

  // ==========================================================================
  // The user's Example 1: 1000 out, 800 back, 200 refunded by UPI.
  group('cheaper replacement — only the refund reaches the buckets', () {
    setUp(() async {
      await seedCatalogue(sold: 1000, replacement: 800);
      await seedSale(price: 1000, paymentType: 'cash');
    });

    test('UPI shows -200, not -1000 + 800 and not 800', () async {
      final r = await exchange('upi');
      expect(r.success, isTrue, reason: r.error);

      final report = await eod();
      expect(bucket(report, 'UPI'), closeTo(-200, 0.02));
    });

    test('there is NO Exchange bucket in the payment summary', () async {
      await exchange('upi');
      final report = await eod();

      // The credit leg is an accounting entry, not money. It must not appear
      // as a payment method at all.
      final labels =
          report.paymentSummaries.map((p) => p.paymentType.toLowerCase());
      expect(labels.contains('exchange'), isFalse);
      expect(labels.contains('exchange_credit'), isFalse);
      expect(bucket(report, 'Exchange'), 0);
    });

    test('a UPI refund leaves the cash drawer completely alone', () async {
      final r = await exchange('upi');
      // ignore: avoid_print
      print('DIAG success=${r.success} err=${r.error}');
      for (final sale in allSales()) {
        // ignore: avoid_print
        print('DIAG ${sale.saleId} isReturn=${sale.isReturn} '
            'total=${sale.totalAmount} type=${sale.paymentType} '
            'legs=${sale.paymentListJson} '
            'comp=${CashDrawerLedger.cashComponentOf(sale)} '
            'refund=${CashDrawerLedger.cashRefundOf(sale)}');
      }
      expect(drawerCash(), closeTo(0, 0.001));
      expect(bucket(await eod(), 'Cash'), closeTo(0, 0.001));
    });

    test('a CASH refund moves exactly -200 through the drawer', () async {
      await exchange('cash');

      expect(drawerCash(), closeTo(-200, 0.02));
      expect(bucket(await eod(), 'Cash'), closeTo(-200, 0.02));
    });

    test('the cash refund is not also counted by cashRefundsIn', () async {
      await exchange('cash');

      // It is already a signed leg in the Cash bucket; counting it here too
      // would subtract the same refund from expected cash twice.
      expect(EODReportService.cashRefundsIn(allSales()), closeTo(0, 0.001));
    });

    test('expected cash falls by exactly the refund', () async {
      await exchange('cash');
      final report = await eod();

      // Opening 1000, one 200 cash refund, nothing else.
      expect(report.closingBalance, closeTo(800, 0.02));
    });
  });

  // ==========================================================================
  // The user's Example 2: 1000 out, 1200 back, 200 collected by UPI.
  group('dearer replacement — only the collection reaches the buckets', () {
    setUp(() async {
      await seedCatalogue(sold: 1000, replacement: 1200);
      await seedSale(price: 1000, paymentType: 'cash');
    });

    test('UPI shows +200, not +1200', () async {
      final r = await exchange('upi');
      expect(r.success, isTrue, reason: r.error);

      expect(bucket(await eod(), 'UPI'), closeTo(200, 0.02));
    });

    test('a UPI collection leaves the cash drawer alone', () async {
      await exchange('upi');
      expect(drawerCash(), closeTo(0, 0.001));
    });

    test('a CASH collection moves exactly +200 through the drawer', () async {
      await exchange('cash');

      expect(drawerCash(), closeTo(200, 0.02));
      expect(bucket(await eod(), 'Cash'), closeTo(200, 0.02));
    });

    test('expected cash rises by exactly the collection', () async {
      await exchange('cash');
      final report = await eod();
      expect(report.closingBalance, closeTo(1200, 0.02));
    });
  });

  // ==========================================================================
  group('an even swap moves no money at all', () {
    test('no bucket records anything, and the drawer is untouched', () async {
      await seedCatalogue(sold: 1000, replacement: 1000);
      await seedSale(price: 1000, paymentType: 'cash');

      await exchange('upi');
      final report = await eod();

      expect(bucket(report, 'UPI'), closeTo(0, 0.001));
      expect(bucket(report, 'Cash'), closeTo(0, 0.001));
      expect(drawerCash(), closeTo(0, 0.001));
    });
  });

  // ==========================================================================
  group('each document still reconciles against itself', () {
    test('every payment leg sums to that document total', () async {
      await seedCatalogue(sold: 1000, replacement: 800);
      await seedSale(price: 1000, paymentType: 'cash');
      await exchange('upi');

      for (final sale in allSales().where((s) => s.saleId != 'S1')) {
        final legSum = sale.paymentList.fold<double>(
          0,
          (sum, leg) => sum + ((leg['amount'] as num?)?.toDouble() ?? 0),
        );
        expect(
          legSum,
          closeTo(sale.totalAmount, 0.02),
          reason: 'legs must sum to totalAmount on ${sale.saleId}',
        );
      }
    });

    test('neither document claims a money method it never saw', () async {
      await seedCatalogue(sold: 1000, replacement: 800);
      await seedSale(price: 1000, paymentType: 'cash');
      await exchange('upi');

      final replacement = allSales().firstWhere(
        (s) => s.saleId != 'S1' && !(s.isReturn ?? false),
      );

      // The ₹800 replacement was settled entirely by the returned goods.
      expect(replacement.totalAmount, closeTo(800, 0.02));
      expect(replacement.paymentType, ExchangeService.exchangeCreditMethod);
      expect(
        replacement.paymentList
            .every((l) => ExchangeService.isExchangeCredit(l['method'] as String?)),
        isTrue,
      );
    });
  });

  // ==========================================================================
  group('a plain return is untouched by any of this', () {
    test('it still contributes to cashRefundsIn, not to the buckets', () async {
      await seedCatalogue(sold: 1000, replacement: 800);
      await seedSale(price: 1000, paymentType: 'cash');

      // A plain return, no exchange involved.
      await ReturnService().processFullReturn(
        originalSaleId: 'S1',
        refundMethod: 'cash',
      );

      // Unchanged behaviour: excluded from buckets, handled by cashRefunds.
      expect(EODReportService.cashRefundsIn(allSales()), closeTo(1000, 0.02));
      expect(bucket(await eod(), 'Cash'), closeTo(1000, 0.02));
      expect((await eod()).closingBalance, closeTo(1000, 0.02));
    });
  });
}
