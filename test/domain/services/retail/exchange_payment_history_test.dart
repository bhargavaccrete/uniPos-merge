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
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/credit_payment_model_218.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';

import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/data/repositories/common/customer_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/cash_movement_repository.dart';
import 'package:billberrylite/data/repositories/retail/credit_payment_repository.dart';
import 'package:billberrylite/data/repositories/retail/sale_item_repository.dart';
import 'package:billberrylite/data/repositories/retail/variant_repository.dart';

import 'package:billberrylite/domain/services/retail/auth_service.dart';
import 'package:billberrylite/domain/services/retail/exchange_service.dart';
import 'package:billberrylite/domain/services/retail/gst_service.dart';
import 'package:billberrylite/domain/services/retail/return_service.dart';
import 'package:billberrylite/domain/store/common/customer_store.dart';
import 'package:billberrylite/domain/store/restaurant/cash_movement_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';
import 'package:billberrylite/util/restaurant/restaurant_auth_helper.dart';
import '../../../helpers/open_retail_day_fixture.dart';

/// THE INVARIANT: an exchange never rewrites how the original sale was paid.
///
/// 900 paid by CASH stays 900 CASH forever, whatever method settles the
/// difference. The codebase already draws this line — `CreditStore.receivePayment`
/// moves `dueAmount` while leaving `paymentType`/`paymentListJson` untouched —
/// and an exchange must not be the thing that breaks it.
///
/// Two categories, only one of which may ever move:
///   * PAYMENT IDENTITY — paymentType, paymentListJson, totalPaid,
///     changeReturn, isSplitPayment. **Never.**
///   * BALANCE STATE — dueAmount, status. Only on an unpaid invoice, and
///     `paidAmount` stays put because a credit note is not a payment.
///
/// Both exchange legs settle through the SAME method, so the leg amounts cancel
/// down to exactly the difference in that method's bucket — whatever the
/// original used.
void main() {
  late Directory tempDir;
  late ExchangeService service;

  setUp(() async {
    await locator.reset();
    SharedPreferences.setMockInitialValues({
      RestaurantAuthHelper.adminPinKey:
          RestaurantAuthHelper.hashPassword('1234'),
    });

    tempDir = await Directory.systemTemp.createTemp('exchange_pay_');
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
    await Hive.openBox(HiveBoxNames.dayManagementBox);
    // BLK-16: returns, exchanges and collections need an open day.
    await openRetailDayForTest();
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

  Future<void> seedCatalogue({
    required double soldPrice,
    required double replacementPrice,
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
        sellingPrice: soldPrice,
        stockQty: 9,
        costPrice: 60,
        taxRate: 0, // zero-rated keeps the arithmetic in the tests obvious
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    await box.put(
      'v2',
      VarianteModel(
        varianteId: 'v2',
        productId: 'p1',
        sellingPrice: replacementPrice,
        stockQty: 5,
        costPrice: 60,
        taxRate: 0,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  /// A settled sale of one zero-rated unit, so `total == price`.
  Future<SaleModel> seedSale({
    required double price,
    required String paymentType,
    String? customerId,
    double? dueAmount,
    double? paidAmount,
    String? status,
    List<Map<String, dynamic>>? paymentList,
  }) async {
    final now = DateTime.now().toIso8601String();
    final sale = SaleModel(
      saleId: 'S1',
      customerId: customerId,
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
      changeReturn: 0,
      isSplitPayment: false,
      paidAmount: paidAmount ?? price,
      dueAmount: dueAmount ?? 0,
      status: status ?? SaleStatus.paid,
    );

    await Hive.box<SaleModel>(HiveBoxNames.sales).put('S1', sale);
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
    return sale;
  }

  SaleModel readSale(String id) =>
      Hive.box<SaleModel>(HiveBoxNames.sales).get(id)!;

  List<SaleModel> allSales() =>
      Hive.box<SaleModel>(HiveBoxNames.sales).values.toList();

  /// Everything about how the original sale was PAID must be byte-identical.
  void expectPaymentHistoryIntact(SaleModel before) {
    final after = readSale(before.saleId);
    expect(after.paymentType, before.paymentType,
        reason: 'the original payment method must never be rewritten');
    expect(after.paymentListJson, before.paymentListJson);
    expect(after.totalPaid, before.totalPaid);
    expect(after.changeReturn, before.changeReturn);
    expect(after.isSplitPayment, before.isSplitPayment);
    expect(after.subtotal, closeTo(before.subtotal, 0.001));
    expect(after.taxAmount, closeTo(before.taxAmount, 0.001));
    expect(after.totalAmount, closeTo(before.totalAmount, 0.001));
    expect(after.createdAt, before.createdAt);
  }

  /// Real money that moved through one payment method, across BOTH exchange
  /// documents.
  ///
  /// Sums the stored payment LEGS, skipping the internal exchange-credit leg —
  /// the same rule the EOD summariser applies. Summing whole `totalAmount`s by
  /// `paymentType` is what produced the bug this suite now guards: it counted
  /// the full value of the goods swapped as though it had been tendered.
  double netFor(String method) {
    var total = 0.0;
    for (final sale in allSales().where((s) => s.saleId != 'S1')) {
      for (final leg in sale.paymentList) {
        final m = (leg['method'] as String? ?? '').toLowerCase();
        if (m != method.toLowerCase()) continue;
        total += (leg['amount'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return total;
  }

  Future<ExchangeResult> exchange(String paymentMethod) => service.processExchange(
        originalSaleId: 'S1',
        returnedVariantId: 'v1',
        returnQty: 1,
        replacementVariantId: 'v2',
        paymentMethod: paymentMethod,
      );

  // ==========================================================================
  // 1. Original CASH → replacement higher → UPI difference
  group('original CASH, costlier replacement, difference by UPI', () {
    test('the original still reads CASH 900', () async {
      await seedCatalogue(soldPrice: 900, replacementPrice: 1200);
      final before = await seedSale(price: 900, paymentType: 'cash');

      final r = await exchange('upi');
      expect(r.success, isTrue, reason: r.error);

      expectPaymentHistoryIntact(before);
      expect(readSale('S1').paymentType, 'cash');
      expect(readSale('S1').totalAmount, closeTo(900, 0.01));
    });

    test('UPI nets to +300 and the cash drawer is untouched', () async {
      await seedCatalogue(soldPrice: 900, replacementPrice: 1200);
      await seedSale(price: 900, paymentType: 'cash');

      await exchange('upi');

      // -900 return + 1200 replacement, both UPI.
      expect(netFor('upi'), closeTo(300, 0.02));
      expect(netFor('cash'), closeTo(0, 0.001));
    });

    test('the difference is reported as a collection of 300', () async {
      await seedCatalogue(soldPrice: 900, replacementPrice: 1200);
      await seedSale(price: 900, paymentType: 'cash');

      final r = await exchange('upi');
      expect(r.difference, closeTo(300, 0.02));
    });
  });

  // ==========================================================================
  // 2. Original UPI → replacement higher → CASH difference
  group('original UPI, costlier replacement, difference by CASH', () {
    test('the original still reads UPI', () async {
      await seedCatalogue(soldPrice: 900, replacementPrice: 1200);
      final before = await seedSale(price: 900, paymentType: 'upi');

      final r = await exchange('cash');
      expect(r.success, isTrue, reason: r.error);

      expectPaymentHistoryIntact(before);
      expect(readSale('S1').paymentType, 'upi');
    });

    test('cash nets to +300 in, and UPI is untouched', () async {
      await seedCatalogue(soldPrice: 900, replacementPrice: 1200);
      await seedSale(price: 900, paymentType: 'upi');

      await exchange('cash');

      expect(netFor('cash'), closeTo(300, 0.02));
      expect(netFor('upi'), closeTo(0, 0.001));
    });
  });

  // ==========================================================================
  // 3. Original CARD → replacement lower → refund
  group('original CARD, cheaper replacement, refunded', () {
    test('the original still reads CARD 1200', () async {
      await seedCatalogue(soldPrice: 1200, replacementPrice: 900);
      final before = await seedSale(price: 1200, paymentType: 'card');

      final r = await exchange('cash');
      expect(r.success, isTrue, reason: r.error);

      expectPaymentHistoryIntact(before);
      expect(readSale('S1').paymentType, 'card');
      expect(readSale('S1').totalAmount, closeTo(1200, 0.01));
    });

    test('a CASH refund takes 300 out of the drawer', () async {
      await seedCatalogue(soldPrice: 1200, replacementPrice: 900);
      await seedSale(price: 1200, paymentType: 'card');

      final r = await exchange('cash');

      expect(r.difference, closeTo(-300, 0.02));
      expect(netFor('cash'), closeTo(-300, 0.02));
      expect(netFor('card'), closeTo(0, 0.001));
    });

    test('a UPI refund leaves the drawer alone', () async {
      await seedCatalogue(soldPrice: 1200, replacementPrice: 900);
      await seedSale(price: 1200, paymentType: 'card');

      await exchange('upi');

      expect(netFor('upi'), closeTo(-300, 0.02));
      expect(netFor('cash'), closeTo(0, 0.001));
    });
  });

  // ==========================================================================
  // 4. Original CREDIT with a balance still owed → the exchange is REFUSED.
  //
  // BLK-10: the return value would be written off the due AND pay for the
  // replacement — spent twice. Collect the balance first, or do a return.
  group('original CREDIT with a balance owed, exchange refused', () {
    Future<void> seedDebtor({required double owed}) async {
      await seedCatalogue(soldPrice: 1000, replacementPrice: 1000);
      await Hive.box<Customer>(HiveBoxNames.customer).put(
        'C1',
        Customer(
          customerId: 'C1',
          name: 'Debtor',
          phone: '9999999999',
          creditBalance: owed,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
    }

    /// Nothing anywhere moved: the original (balance, payment history,
    /// timestamp), the customer, credit rows, documents, stock, cash.
    void expectNothingWritten(SaleModel before, {required double owed}) {
      final after = readSale('S1');
      expect(after.dueAmount, closeTo(before.dueAmount, 0.001));
      expect(after.paidAmount, closeTo(before.paidAmount, 0.001));
      expect(after.status, before.status);
      expect(after.updatedAt, before.updatedAt);
      expectPaymentHistoryIntact(before);
      expect(
        Hive.box<Customer>(HiveBoxNames.customer).get('C1')!.creditBalance,
        closeTo(owed, 0.001),
      );
      expect(Hive.box<CreditPaymentModel>(HiveBoxNames.creditPayments).values,
          isEmpty);
      expect(allSales().map((s) => s.saleId), ['S1'],
          reason: 'no return and no replacement document');
      final variants = Hive.box<VarianteModel>(HiveBoxNames.variants);
      expect(variants.get('v1')!.stockQty, 9);
      expect(variants.get('v2')!.stockQty, 5);
      expect(
          Hive.box<StockMovementModel>(HiveBoxNames.restaurantStockMovements)
              .values,
          isEmpty);
      expect(
          Hive.box<CashMovementModel>(HiveBoxNames.restaurantCashMovements)
              .values,
          isEmpty);
    }

    test('an unpaid invoice: refused, nothing written', () async {
      await seedDebtor(owed: 1000);
      final before = await seedSale(
        price: 1000,
        paymentType: 'credit',
        customerId: 'C1',
        paidAmount: 0,
        dueAmount: 1000,
        status: SaleStatus.due,
      );

      final r = await exchange('cash');

      expect(r.success, isFalse);
      expect(r.error, ExchangeService.unpaidBalanceMessage);
      expectNothingWritten(before, owed: 1000);
    });

    test('a cheaper replacement is refused too — no cash paid out', () async {
      await seedDebtor(owed: 1000);
      await Hive.box<VarianteModel>(HiveBoxNames.variants).put(
        'v2',
        Hive.box<VarianteModel>(HiveBoxNames.variants)
            .get('v2')!
            .copyWith(sellingPrice: 700),
      );
      final before = await seedSale(
        price: 1000,
        paymentType: 'credit',
        customerId: 'C1',
        paidAmount: 0,
        dueAmount: 1000,
        status: SaleStatus.due,
      );

      final r = await exchange('cash');

      expect(r.success, isFalse);
      expect(netFor('cash'), 0);
      expectNothingWritten(before, owed: 1000);
    });

    test('a partly-paid invoice: refused, nothing written', () async {
      await seedDebtor(owed: 400);
      final before = await seedSale(
        price: 1000,
        paymentType: 'credit',
        customerId: 'C1',
        paidAmount: 600,
        dueAmount: 400,
        status: SaleStatus.partiallyPaid,
      );

      final r = await exchange('cash');

      expect(r.success, isFalse);
      expect(r.error, ExchangeService.unpaidBalanceMessage);
      expectNothingWritten(before, owed: 400);
    });
  });

  // ==========================================================================
  // 4b. A PLAIN return on a credit invoice still writes the due down first —
  // the route the refusal above points the cashier to.
  group('plain return on a credit invoice, due written down first', () {
    Future<SaleModel> seedDebtor({
      required double owed,
      required double paid,
      required String status,
    }) async {
      await seedCatalogue(soldPrice: 1000, replacementPrice: 1000);
      await Hive.box<Customer>(HiveBoxNames.customer).put(
        'C1',
        Customer(
          customerId: 'C1',
          name: 'Debtor',
          phone: '9999999999',
          creditBalance: owed,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      return seedSale(
        price: 1000,
        paymentType: 'credit',
        customerId: 'C1',
        paidAmount: paid,
        dueAmount: owed,
        status: status,
      );
    }

    Future<void> plainReturn() => ReturnService().processPartialReturn(
          originalSaleId: 'S1',
          itemsToReturn: {'v1': 1},
          refundMethod: 'cash',
        );

    test('the return offsets the due; payment identity untouched', () async {
      final before =
          await seedDebtor(owed: 1000, paid: 0, status: SaleStatus.due);

      await plainReturn();

      final after = readSale('S1');
      expect(after.dueAmount, closeTo(0, 0.01));
      // paidAmount did NOT move: a credit note is not a payment.
      expect(after.paidAmount, closeTo(0, 0.001));
      expect(after.paymentType, before.paymentType);
      expect(after.paymentListJson, before.paymentListJson);
      expect(after.totalAmount, closeTo(before.totalAmount, 0.001));
    });

    test('the write-down leaves a return_adjustment audit row', () async {
      await seedDebtor(owed: 1000, paid: 0, status: SaleStatus.due);

      await plainReturn();

      final rows = Hive.box<CreditPaymentModel>(HiveBoxNames.creditPayments)
          .values
          .toList();
      expect(rows.single.paymentMode, ReturnService.returnAdjustmentMode);
      expect(rows.single.amount, closeTo(1000, 0.01));
      expect(rows.single.balanceBefore, closeTo(1000, 0.01));
      expect(rows.single.balanceAfter, closeTo(0, 0.01));
      expect(
        Hive.box<Customer>(HiveBoxNames.customer).get('C1')!.creditBalance,
        closeTo(0, 0.01),
      );
    });

    test('a partly-paid credit sale only writes down what is still owed',
        () async {
      await seedDebtor(
          owed: 400, paid: 600, status: SaleStatus.partiallyPaid);

      await plainReturn();

      final after = readSale('S1');
      expect(after.dueAmount, closeTo(0, 0.01));
      // 400 cleared the debt; the 600 already collected is untouched.
      expect(after.paidAmount, closeTo(600, 0.001));
      expect(
        Hive.box<CreditPaymentModel>(HiveBoxNames.creditPayments)
            .values
            .single
            .amount,
        closeTo(400, 0.01),
      );
    });
  });

  // ==========================================================================
  group('a credit note is not a collection', () {
    Future<void> seedDebtor() async {
      await seedCatalogue(soldPrice: 1000, replacementPrice: 1000);
      await Hive.box<Customer>(HiveBoxNames.customer).put(
        'C1',
        Customer(
          customerId: 'C1',
          name: 'Debtor',
          phone: '9999999999',
          creditBalance: 1000,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      await seedSale(
        price: 1000,
        paymentType: 'credit',
        customerId: 'C1',
        paidAmount: 0,
        dueAmount: 1000,
        status: SaleStatus.due,
      );
    }

    test('the row is flagged as an adjustment, not a collection', () async {
      await seedDebtor();
      // A plain return: an exchange on an invoice with a balance is refused
      // (BLK-10), and the write-down this checks belongs to ReturnService.
      await ReturnService().processPartialReturn(
        originalSaleId: 'S1',
        itemsToReturn: {'v1': 1},
        refundMethod: 'cash',
      );

      final row = Hive.box<CreditPaymentModel>(HiveBoxNames.creditPayments)
          .values
          .single;
      expect(row.isReturnAdjustment, isTrue);
      expect(row.isCollection, isFalse);
    });

    test('collections stay at zero — no money actually came in', () async {
      await seedDebtor();
      // A plain return: an exchange on an invoice with a balance is refused
      // (BLK-10), and the write-down this checks belongs to ReturnService.
      await ReturnService().processPartialReturn(
        originalSaleId: 'S1',
        itemsToReturn: {'v1': 1},
        refundMethod: 'cash',
      );

      final now = DateTime.now();
      final collections = await creditPaymentRepository
          .getCollectionByModeInRange(
        now.subtract(const Duration(days: 1)),
        now.add(const Duration(days: 1)),
      );

      // Counting the write-down here would report a debt cancellation as
      // takings and overstate the day.
      expect(collections['total'], closeTo(0, 0.001));
      expect(collections['cash'], closeTo(0, 0.001));
    });

    test('a real collection still counts', () async {
      await seedDebtor();
      await creditPaymentRepository.addPayment(
        CreditPaymentModel.create(
          paymentId: 'PAY1',
          customerId: 'C1',
          saleId: 'S1',
          amount: 250,
          paymentMode: 'cash',
          balanceBefore: 1000,
          balanceAfter: 750,
        ),
      );

      final now = DateTime.now();
      final collections = await creditPaymentRepository
          .getCollectionByModeInRange(
        now.subtract(const Duration(days: 1)),
        now.add(const Duration(days: 1)),
      );

      expect(collections['cash'], closeTo(250, 0.001));
      expect(collections['total'], closeTo(250, 0.001));
    });
  });

  // ==========================================================================
  group('a non-credit original is never written to at all', () {
    test('an even swap leaves the original byte-identical', () async {
      await seedCatalogue(soldPrice: 900, replacementPrice: 900);
      final before = await seedSale(price: 900, paymentType: 'cash');

      final r = await exchange('card');
      expect(r.success, isTrue, reason: r.error);

      expectPaymentHistoryIntact(before);
      final after = readSale('S1');
      expect(after.dueAmount, closeTo(before.dueAmount, 0.001));
      expect(after.paidAmount, closeTo(before.paidAmount, 0.001));
      expect(after.status, before.status);
      // Not even the audit timestamp moved — nothing wrote to this record.
      expect(after.updatedAt, before.updatedAt);
    });
  });
}
