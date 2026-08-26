import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';

import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/restaurant/db/cash_movement_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/credit_payment_model_218.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';

import 'package:billberrylite/data/repositories/common/customer_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/cash_movement_repository.dart';
import 'package:billberrylite/data/repositories/retail/credit_payment_repository.dart';
import 'package:billberrylite/data/repositories/retail/sale_item_repository.dart';
import 'package:billberrylite/data/repositories/retail/variant_repository.dart';

import 'package:billberrylite/domain/services/retail/return_service.dart';
import 'package:billberrylite/domain/store/common/customer_store.dart';
import 'package:billberrylite/domain/store/restaurant/cash_movement_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';

/// `ReturnService` — settlement, stock and the repeat-return guard.
///
/// The three defects these pin:
///   * a return of a CREDIT sale paid cash out of the till AND left the debt
///     standing, because nothing ever touched `creditBalance` or `dueAmount`;
///   * the original sale's PAYMENT IDENTITY must survive a return untouched —
///     only the receivable moves;
///   * nothing tracked how much of a line had already come back, so the same
///     units could be refunded again and again.
void main() {
  late Directory tempDir;
  late ReturnService service;

  setUp(() async {
    await locator.reset();

    tempDir = await Directory.systemTemp.createTemp('return_service_');
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

    service = ReturnService();
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // ── Seeding ───────────────────────────────────────────────────────────────

  Future<void> seedVariant({
    String id = 'v1',
    double stock = 10,
    double cost = 60,
  }) async {
    await Hive.box<VarianteModel>(HiveBoxNames.variants).put(
      id,
      VarianteModel(
        varianteId: id,
        productId: 'p1',
        stockQty: stock,
        costPrice: cost,
        sellingPrice: 100,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  /// One sale of `qty` units at 100 + 18% exclusive GST, so a unit is 118.
  Future<SaleModel> seedSale({
    String saleId = 'S1',
    double qty = 1,
    String paymentType = 'cash',
    String? customerId,
    double? dueAmount,
    double? paidAmount,
    String? status,
  }) async {
    final now = DateTime.now().toIso8601String();
    final total = 118.0 * qty;

    final sale = SaleModel(
      saleId: saleId,
      customerId: customerId,
      totalItems: qty,
      subtotal: 100.0 * qty,
      discountAmount: 0,
      taxAmount: 18.0 * qty,
      totalAmount: total,
      paymentType: paymentType,
      date: now,
      createdAt: now,
      updatedAt: now,
      totalTaxableAmount: 100.0 * qty,
      totalGstAmount: 18.0 * qty,
      grandTotal: total,
      paidAmount: paidAmount ?? total,
      dueAmount: dueAmount ?? 0,
      status: status ?? SaleStatus.paid,
    );

    await Hive.box<SaleModel>(HiveBoxNames.sales).put(saleId, sale);
    await Hive.box<SaleItemModel>(HiveBoxNames.saleItems).put(
      '$saleId-L1',
      SaleItemModel.fromCalculated(
        saleId: saleId,
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
    return sale;
  }

  Future<void> seedCustomer({
    String id = 'C1',
    double creditBalance = 0,
  }) async {
    await Hive.box<Customer>(HiveBoxNames.customer).put(
      id,
      Customer(
        customerId: id,
        name: 'Test Customer',
        phone: '9999999999',
        creditBalance: creditBalance,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  SaleModel readSale(String id) =>
      Hive.box<SaleModel>(HiveBoxNames.sales).get(id)!;

  Customer readCustomer(String id) =>
      Hive.box<Customer>(HiveBoxNames.customer).get(id)!;

  List<CreditPaymentModel> creditRows() =>
      Hive.box<CreditPaymentModel>(HiveBoxNames.creditPayments).values.toList();

  List<SaleModel> returns() => Hive.box<SaleModel>(HiveBoxNames.sales)
      .values
      .where((s) => s.isReturn ?? false)
      .toList();

  // ==========================================================================
  group('a paid sale refunds in full and leaves the original alone', () {
    test('the refund equals what was charged', () async {
      await seedVariant();
      await seedSale();

      await service.processFullReturn(
        originalSaleId: 'S1',
        refundMethod: 'cash',
      );

      expect(returns().single.totalAmount, closeTo(-118, 0.01));
    });

    test('the original sale is not written to at all', () async {
      await seedVariant();
      final before = await seedSale(paymentType: 'cash');

      await service.processFullReturn(
        originalSaleId: 'S1',
        refundMethod: 'upi',
      );

      final after = readSale('S1');
      // Settling the difference by UPI must not rewrite how the sale was paid.
      expect(after.paymentType, 'cash');
      expect(after.totalAmount, closeTo(before.totalAmount, 0.001));
      expect(after.paidAmount, closeTo(before.paidAmount, 0.001));
      expect(after.dueAmount, closeTo(before.dueAmount, 0.001));
      expect(after.status, before.status);
    });

    test('no credit row is written for a sale that was already paid', () async {
      await seedVariant();
      await seedSale();

      await service.processFullReturn(
        originalSaleId: 'S1',
        refundMethod: 'cash',
      );

      expect(creditRows(), isEmpty);
    });

    test('stock comes back', () async {
      await seedVariant(stock: 9);
      await seedSale();

      await service.processFullReturn(
        originalSaleId: 'S1',
        refundMethod: 'cash',
      );

      final variant =
          Hive.box<VarianteModel>(HiveBoxNames.variants).get('v1')!;
      expect(variant.stockQty, 10);
    });
  });

  // ==========================================================================
  group('a credit sale writes down the due before any cash moves', () {
    test('return smaller than the due reduces it and pays out nothing',
        () async {
      await seedVariant();
      await seedCustomer(creditBalance: 236); // two units outstanding
      await seedSale(
        qty: 2,
        paymentType: 'credit',
        customerId: 'C1',
        paidAmount: 0,
        dueAmount: 236,
        status: SaleStatus.due,
      );

      // One unit back: 118 of the 236 owed.
      await service.processPartialReturn(
        originalSaleId: 'S1',
        itemsToReturn: {'v1': 1},
        refundMethod: 'cash',
      );

      final sale = readSale('S1');
      expect(sale.dueAmount, closeTo(118, 0.01));
      expect(readCustomer('C1').creditBalance, closeTo(118, 0.01));
      // Nothing was ever paid, so nothing is handed back.
      expect(sale.paidAmount, closeTo(0, 0.001));
    });

    test('paidAmount is NOT raised — no money arrived', () async {
      await seedVariant();
      await seedCustomer(creditBalance: 118);
      await seedSale(
        paymentType: 'credit',
        customerId: 'C1',
        paidAmount: 0,
        dueAmount: 118,
        status: SaleStatus.due,
      );

      await service.processFullReturn(
        originalSaleId: 'S1',
        refundMethod: 'cash',
      );

      // A credit note cancels a receivable; it is not a payment. Raising
      // paidAmount here would record a payment that never happened.
      expect(readSale('S1').paidAmount, closeTo(0, 0.001));
      expect(readSale('S1').dueAmount, closeTo(0, 0.01));
    });

    test('the write-down leaves an auditable credit row', () async {
      await seedVariant();
      await seedCustomer(creditBalance: 118);
      await seedSale(
        paymentType: 'credit',
        customerId: 'C1',
        paidAmount: 0,
        dueAmount: 118,
        status: SaleStatus.due,
      );

      await service.processFullReturn(
        originalSaleId: 'S1',
        refundMethod: 'cash',
      );

      final row = creditRows().single;
      expect(row.paymentMode, ReturnService.returnAdjustmentMode);
      expect(row.amount, closeTo(118, 0.01));
      expect(row.balanceBefore, closeTo(118, 0.01));
      expect(row.balanceAfter, closeTo(0, 0.01));
      expect(row.saleId, 'S1');
    });

    test('the credit sale keeps its payment identity', () async {
      await seedVariant();
      await seedCustomer(creditBalance: 118);
      await seedSale(
        paymentType: 'credit',
        customerId: 'C1',
        paidAmount: 0,
        dueAmount: 118,
        status: SaleStatus.due,
      );

      await service.processFullReturn(
        originalSaleId: 'S1',
        refundMethod: 'upi',
      );

      // Only the receivable moves. How the sale was raised is history.
      expect(readSale('S1').paymentType, 'credit');
    });

    test('a return larger than the due clears it and refunds only the excess',
        () async {
      await seedVariant();
      await seedCustomer(creditBalance: 50);
      // Part-paid: 236 total, 50 still owed.
      await seedSale(
        qty: 2,
        paymentType: 'credit',
        customerId: 'C1',
        paidAmount: 186,
        dueAmount: 50,
        status: SaleStatus.partiallyPaid,
      );

      await service.processFullReturn(
        originalSaleId: 'S1',
        refundMethod: 'cash',
      );

      final sale = readSale('S1');
      expect(sale.dueAmount, closeTo(0, 0.01));
      expect(readCustomer('C1').creditBalance, closeTo(0, 0.01));
      // 236 back, 50 wiped the debt, 186 is genuinely owed to the customer.
      expect(creditRows().single.amount, closeTo(50, 0.01));
      // paidAmount still records what was actually collected.
      expect(sale.paidAmount, closeTo(186, 0.001));
    });
  });

  // ==========================================================================
  group('the repeat-return guard', () {
    test('three single returns of a qty-3 line are all allowed', () async {
      await seedVariant(stock: 7);
      await seedSale(qty: 3);

      for (var i = 0; i < 3; i++) {
        await service.processPartialReturn(
          originalSaleId: 'S1',
          itemsToReturn: {'v1': 1},
          refundMethod: 'cash',
        );
      }

      expect(returns().length, 3);
      expect(
        Hive.box<VarianteModel>(HiveBoxNames.variants).get('v1')!.stockQty,
        10,
      );
    });

    test('a fourth is refused, and writes nothing', () async {
      await seedVariant(stock: 7);
      await seedSale(qty: 3);

      for (var i = 0; i < 3; i++) {
        await service.processPartialReturn(
          originalSaleId: 'S1',
          itemsToReturn: {'v1': 1},
          refundMethod: 'cash',
        );
      }

      await expectLater(
        service.processPartialReturn(
          originalSaleId: 'S1',
          itemsToReturn: {'v1': 1},
          refundMethod: 'cash',
        ),
        throwsA(isA<Exception>()),
      );

      // Still exactly three returns, and stock did not creep past what was sold.
      expect(returns().length, 3);
      expect(
        Hive.box<VarianteModel>(HiveBoxNames.variants).get('v1')!.stockQty,
        10,
      );
    });

    test('over-returning in one go is refused up front', () async {
      await seedVariant(stock: 8);
      await seedSale(qty: 2);

      await expectLater(
        service.processPartialReturn(
          originalSaleId: 'S1',
          itemsToReturn: {'v1': 3},
          refundMethod: 'cash',
        ),
        throwsA(isA<Exception>()),
      );

      expect(returns(), isEmpty);
      expect(
        Hive.box<VarianteModel>(HiveBoxNames.variants).get('v1')!.stockQty,
        8,
      );
    });

    test('remainingReturnable walks down as units come back', () async {
      await seedVariant(stock: 7);
      await seedSale(qty: 3);

      expect((await service.remainingReturnable('S1'))['v1'], 3);

      await service.processPartialReturn(
        originalSaleId: 'S1',
        itemsToReturn: {'v1': 2},
        refundMethod: 'cash',
      );

      expect((await service.remainingReturnable('S1'))['v1'], 1);
    });

    test('a full return after a partial one only takes what is left', () async {
      await seedVariant(stock: 7);
      await seedSale(qty: 3);

      await service.processPartialReturn(
        originalSaleId: 'S1',
        itemsToReturn: {'v1': 1},
        refundMethod: 'cash',
      );
      await service.processFullReturn(
        originalSaleId: 'S1',
        refundMethod: 'cash',
      );

      // 118 + 236, never 118 + 354.
      final refunded =
          returns().fold<double>(0, (s, r) => s + r.totalAmount.abs());
      expect(refunded, closeTo(354, 0.02));
    });

    test('a fully returned sale reports as such and refuses more', () async {
      await seedVariant(stock: 9);
      await seedSale();

      await service.processFullReturn(
        originalSaleId: 'S1',
        refundMethod: 'cash',
      );

      expect(await service.isFullyReturned('S1'), isTrue);
      expect(await service.canReturnSale('S1'), isFalse);

      await expectLater(
        service.processFullReturn(
          originalSaleId: 'S1',
          refundMethod: 'cash',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('a partly returned sale is still returnable', () async {
      await seedVariant(stock: 7);
      await seedSale(qty: 3);

      await service.processPartialReturn(
        originalSaleId: 'S1',
        itemsToReturn: {'v1': 1},
        refundMethod: 'cash',
      );

      expect(await service.isFullyReturned('S1'), isFalse);
      expect(await service.isPartiallyReturned('S1'), isTrue);
      expect(await service.canReturnSale('S1'), isTrue);
    });

    test('a return document cannot itself be returned', () async {
      await seedVariant();
      await seedSale();

      final rtnId = await service.processFullReturn(
        originalSaleId: 'S1',
        refundMethod: 'cash',
      );

      expect(await service.canReturnSale(rtnId), isFalse);
      await expectLater(
        service.processFullReturn(
          originalSaleId: rtnId,
          refundMethod: 'cash',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ==========================================================================
  group('return lines carry the original economics', () {
    test('the line is costed exactly as the sale it reverses', () async {
      await seedVariant(cost: 60);
      await seedSale();

      final rtnId = await service.processFullReturn(
        originalSaleId: 'S1',
        refundMethod: 'cash',
      );

      final line = Hive.box<SaleItemModel>(HiveBoxNames.saleItems)
          .values
          .firstWhere((i) => i.saleId == rtnId);

      expect(line.costPrice, closeTo(60, 0.001));
      expect(line.price, closeTo(100, 0.001));
      expect(line.qty, 1); // positive, for stock restoration
      expect(line.taxableAmount, closeTo(100, 0.01));
      expect(line.gstAmount, closeTo(18, 0.01));
      expect(line.total, closeTo(118, 0.01));
    });

    test('the return header carries the tax mode it was charged under',
        () async {
      await seedVariant();
      final box = Hive.box<SaleModel>(HiveBoxNames.sales);
      await seedSale();
      await box.put('S1', readSale('S1').copyWith(isTaxInclusive: true));

      final rtnId = await service.processFullReturn(
        originalSaleId: 'S1',
        refundMethod: 'cash',
      );

      // Without this a reprinted credit note renders under today's settings.
      expect(box.get(rtnId)!.isTaxInclusive, isTrue);
    });
  });
}
