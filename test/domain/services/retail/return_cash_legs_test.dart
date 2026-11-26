import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/restaurant/db/cash_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/eodmodel_317.dart';
import 'package:billberrylite/data/models/restaurant/db/expensel_316.dart';
import 'package:billberrylite/data/models/retail/hive_model/credit_payment_model_218.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/repositories/common/customer_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/cash_movement_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/expense_repository.dart';
import 'package:billberrylite/data/repositories/retail/credit_payment_repository.dart';
import 'package:billberrylite/data/repositories/retail/sale_item_repository.dart';
import 'package:billberrylite/data/repositories/retail/variant_repository.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/restaurant/eod_service.dart';
import 'package:billberrylite/domain/services/retail/eod_report_service.dart';
import 'package:billberrylite/domain/services/retail/return_service.dart';
import 'package:billberrylite/domain/store/common/customer_store.dart';
import 'package:billberrylite/domain/store/restaurant/cash_movement_store.dart';
import 'package:billberrylite/domain/store/restaurant/expense_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';
import 'package:billberrylite/util/retail/cash_drawer_ledger.dart';
import '../../../helpers/open_retail_day_fixture.dart';

/// BLK-11: a return on a sale with an unpaid balance writes the value off the
/// balance first and pays out only the rest. The return document now records
/// that split as legs, so the Cash Drawer and EOD take only the cash actually
/// handed back off the expected cash — not the whole return value.
void main() {
  late Directory tempDir;
  late ReturnService service;

  setUp(() async {
    await locator.reset();
    tempDir = await Directory.systemTemp.createTemp('return_cash_legs_');
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
    await Hive.openBox<Expense>(HiveBoxNames.retailExpense);
    await Hive.openBox<EndOfDayReport>(HiveBoxNames.retailEOD);
    await Hive.openBox(HiveBoxNames.dayManagementBox);
    // BLK-16: returns, exchanges and collections need an open day.
    await openRetailDayForTest();
    await Hive.openBox(HiveBoxNames.appCounters);

    locator
      ..registerLazySingleton<SaleStore>(() => SaleStore())
      ..registerLazySingleton<SaleItemRepository>(() => SaleItemRepository())
      ..registerLazySingleton<VariantRepository>(() => VariantRepository())
      ..registerLazySingleton<ProductStore>(() => ProductStore())
      ..registerLazySingleton<CustomerStore>(
          () => CustomerStore(CustomerRepository()))
      ..registerLazySingleton<CreditPaymentRepository>(
          () => CreditPaymentRepository())
      ..registerLazySingleton<CashMovementRepository>(
          () => CashMovementRepository())
      ..registerLazySingleton<CashMovementStore>(
          () => CashMovementStore(locator<CashMovementRepository>()))
      ..registerLazySingleton<ExpenseStore>(
          () => ExpenseStore(ExpenseRepository()))
      // ReportService consults the plan's report window via LicenseStore.
      ..registerLazySingleton<LicenseStore>(
          () => LicenseStore(LicenseApiService()));

    await Hive.box<VarianteModel>(HiveBoxNames.variants).put(
      'v1',
      VarianteModel(
        varianteId: 'v1',
        productId: 'p1',
        stockQty: 10,
        costPrice: 60,
        sellingPrice: 100,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    service = ReturnService();
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// [qty] units at 100 + 18% GST (118 each). [paid] collected now, the rest
  /// owed; [paidLegs] is how checkout stores what was tendered.
  Future<void> seedSale({
    double qty = 1,
    double? paid,
    String paymentType = 'cash',
    String? customerId = 'C1',
    List<Map<String, dynamic>>? paidLegs,
  }) async {
    final total = 118.0 * qty;
    final paidAmount = paid ?? total;
    final due = total - paidAmount;
    // In the past: the EOD window's end bound is exclusive and taken at
    // generation time (same reason as retail_eod_returns_test).
    final at = DateTime.now()
        .subtract(const Duration(seconds: 5))
        .toIso8601String();

    if (customerId != null) {
      await Hive.box<Customer>(HiveBoxNames.customer).put(
        customerId,
        Customer(
          customerId: customerId,
          name: 'Asha',
          phone: '9999999999',
          creditBalance: due,
          createdAt: at,
        ),
      );
    }
    await Hive.box<SaleModel>(HiveBoxNames.sales).put(
      'S1',
      SaleModel(
        saleId: 'S1',
        customerId: customerId,
        totalItems: qty,
        subtotal: 100.0 * qty,
        discountAmount: 0,
        taxAmount: 18.0 * qty,
        totalAmount: total,
        paymentType: paymentType,
        paymentListJson: paidLegs == null ? null : jsonEncode(paidLegs),
        isSplitPayment: paidLegs == null ? null : paidLegs.length > 1,
        date: at,
        createdAt: at,
        updatedAt: at,
        totalTaxableAmount: 100.0 * qty,
        totalGstAmount: 18.0 * qty,
        totalCgstAmount: 9.0 * qty,
        totalSgstAmount: 9.0 * qty,
        grandTotal: total,
        paidAmount: paidAmount,
        dueAmount: due,
        status: due <= 0
            ? SaleStatus.paid
            : (paidAmount > 0 ? SaleStatus.partiallyPaid : SaleStatus.due),
      ),
    );
    await Hive.box<SaleItemModel>(HiveBoxNames.saleItems).put(
      'S1-L1',
      SaleItemModel.fromCalculated(
        saleId: 'S1',
        varianteId: 'v1',
        productId: 'p1',
        productName: 'Test Item',
        price: 100,
        qty: qty,
        discountAmount: 0,
        gstRate: 18,
        taxableAmount: 100.0 * qty,
        gstAmount: 18.0 * qty,
        total: total,
        costPrice: 60,
      ),
    );
  }

  Future<SaleModel> returnUnits(double qty, {String method = 'cash'}) async {
    final id = await service.processPartialReturn(
      originalSaleId: 'S1',
      itemsToReturn: {'v1': qty},
      refundMethod: method,
    );
    return Hive.box<SaleModel>(HiveBoxNames.sales).get(id)!;
  }

  List<SaleModel> allSales() =>
      Hive.box<SaleModel>(HiveBoxNames.sales).values.toList();

  Map<String, double> legsOf(SaleModel s) => {
        for (final l in s.paymentList)
          l['method'] as String: (l['amount'] as num).toDouble(),
      };

  group('the return document records where the value went', () {
    test('pay-later sale: all of it cleared the balance, no cash out',
        () async {
      await seedSale(paid: 0, paymentType: 'credit');
      final r = await returnUnits(1);

      expect(legsOf(r), {'credit': closeTo(-118, 0.001)});
      expect(r.paymentType, ReturnService.dueLegMethod);
      expect(r.totalAmount, closeTo(-118, 0.001), reason: 'header unchanged');
      expect(CashDrawerLedger.cashRefundOf(r), 0);
      expect(EODReportService.cashRefundsIn(allSales()), 0);
      expect(CashDrawerLedger.settledLegsOf(r),
          {'credit': closeTo(-118, 0.001)});
      // The write-off itself is unchanged.
      expect(Hive.box<Customer>(HiveBoxNames.customer).get('C1')!.creditBalance,
          closeTo(0, 0.001));
      expect(allSales().firstWhere((s) => s.saleId == 'S1').dueAmount,
          closeTo(0, 0.001));
    });

    test('part-paid sale, refunded by cash: only the paid part leaves',
        () async {
      await seedSale(paid: 18, paidLegs: [
        {'method': 'cash', 'amount': 18.0},
      ]);
      final r = await returnUnits(1);

      expect(legsOf(r), {
        'credit': closeTo(-100, 0.001),
        'cash': closeTo(-18, 0.001),
      });
      expect(r.paymentType, 'cash');
      expect(r.isSplitPayment, isTrue);
      expect(CashDrawerLedger.cashRefundOf(r), closeTo(18, 0.001));
      expect(EODReportService.cashRefundsIn(allSales()), closeTo(18, 0.001));
    });

    test('part-paid sale, refunded by UPI: no cash out', () async {
      await seedSale(paid: 18, paidLegs: [
        {'method': 'upi', 'amount': 18.0},
      ]);
      final r = await returnUnits(1, method: 'upi');

      expect(legsOf(r), {
        'credit': closeTo(-100, 0.001),
        'upi': closeTo(-18, 0.001),
      });
      expect(CashDrawerLedger.cashRefundOf(r), 0);
      expect(EODReportService.cashRefundsIn(allSales()), 0);
    });

    test('returning less than is owed: all against the balance', () async {
      await seedSale(qty: 2, paid: 0, paymentType: 'credit'); // 236 owed
      final r = await returnUnits(1); // 118 back

      expect(legsOf(r), {'credit': closeTo(-118, 0.001)});
      expect(EODReportService.cashRefundsIn(allSales()), 0);
    });
  });

  group('unchanged when no balance is involved', () {
    test('paid cash sale: no legs, the full value is the cash refund',
        () async {
      await seedSale();
      final r = await returnUnits(1);

      expect(r.paymentListJson, isNull);
      expect(r.paymentType, 'cash');
      expect(CashDrawerLedger.cashRefundOf(r), closeTo(118, 0.001));
      expect(EODReportService.cashRefundsIn(allSales()), closeTo(118, 0.001));
    });

    test('balance but no customer: refunded in full, as before', () async {
      await seedSale(paid: 0, customerId: null);
      final r = await returnUnits(1);

      expect(r.paymentListJson, isNull);
      expect(EODReportService.cashRefundsIn(allSales()), closeTo(118, 0.001));
    });

    test('a return saved before this change counts exactly as before', () {
      SaleModel oldReturn(String id, String method) => SaleModel(
            saleId: id,
            totalItems: 1,
            subtotal: -100,
            discountAmount: 0,
            taxAmount: -18,
            totalAmount: -118,
            paymentType: method,
            date: DateTime.now().toIso8601String(),
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
            isReturn: true,
            originalSaleId: 'S0',
            grandTotal: -118,
          );
      expect(
          EODReportService.cashRefundsIn(
              [oldReturn('R1', 'cash'), oldReturn('R2', 'upi')]),
          closeTo(118, 0.001));
    });
  });

  group('End of Day expected cash', () {
    Future<double> expectedCash() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final report = await EODService.generateRetailEODReport(
        date: DateTime.now(),
        openingBalance: 1000,
        actualCash: 1000,
      );
      return report.closingBalance;
    }

    test('a pay-later sale returned: expected cash does not move', () async {
      await seedSale(paid: 0, paymentType: 'credit');
      await returnUnits(1);

      expect(await expectedCash(), closeTo(1000, 0.01),
          reason: 'no cash came in or went out');
    });

    test('a part-paid sale returned: only the refunded cash comes off',
        () async {
      await seedSale(paid: 18, paidLegs: [
        {'method': 'cash', 'amount': 18.0},
      ]);
      await returnUnits(1);

      // 18 came in at the sale, 18 went back on the return.
      expect(await expectedCash(), closeTo(1000, 0.01));
    });
  });
}
