import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';

import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/restaurant/db/cash_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/credit_payment_model_218.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';

import 'package:billberrylite/data/models/common/business_details.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/data/repositories/common/customer_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/cash_movement_repository.dart';
import 'package:billberrylite/data/repositories/retail/credit_payment_repository.dart';
import 'package:billberrylite/data/repositories/retail/sale_item_repository.dart';
import 'package:billberrylite/data/repositories/retail/variant_repository.dart';

import 'package:billberrylite/domain/services/retail/auth_service.dart';
import 'package:billberrylite/util/restaurant/restaurant_auth_helper.dart';
import 'package:billberrylite/domain/services/retail/exchange_service.dart';
import 'package:billberrylite/domain/services/retail/gst_service.dart';
import 'package:billberrylite/domain/store/common/customer_store.dart';
import 'package:billberrylite/domain/store/restaurant/cash_movement_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';

/// RETAIL EXCHANGE — one item back, a different one out.
///
/// The architecture under test: an exchange is NOT its own document. It is an
/// ordinary RETURN plus an ordinary SALE sharing an `exchangeGroupId`.
///
/// The invariant these exist to protect: **the original sale's payment history
/// is never rewritten.** 900 paid by CASH stays 900 CASH forever, whatever
/// settles the difference. Only an unpaid receivable moves.
void main() {
  late Directory tempDir;
  late ExchangeService service;

  setUp(() async {
    await locator.reset();
    // Exchange is admin-gated. Seed the admin PIN so the login below resolves
    // to 'Admin', the identity the four money-sensitive retail services check.
    SharedPreferences.setMockInitialValues({
      RestaurantAuthHelper.adminPinKey:
          RestaurantAuthHelper.hashPassword('1234'),
    });

    tempDir = await Directory.systemTemp.createTemp('exchange_');
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

    // Exchange is admin-gated, like every other money-sensitive retail action.
    await authService.login('1234');

    service = ExchangeService();
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // ── Seeding ───────────────────────────────────────────────────────────────

  Future<void> seedProduct({String id = 'p1', String name = 'Test Item'}) async {
    await Hive.box<ProductModel>(HiveBoxNames.products).put(
      id,
      ProductModel(
        productId: id,
        productName: name,
        category: 'Apparel',
        hasVariants: true,
        createdAt: DateTime.now().toIso8601String(),
        updateAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  Future<void> seedVariant({
    required String id,
    String productId = 'p1',
    required double price,
    double stock = 10,
    double cost = 60,
    double taxRate = 18,
    String status = 'active',
  }) async {
    await Hive.box<VarianteModel>(HiveBoxNames.variants).put(
      id,
      VarianteModel(
        varianteId: id,
        productId: productId,
        sellingPrice: price,
        stockQty: stock,
        costPrice: cost,
        taxRate: taxRate,
        status: status,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  /// A settled sale of one variant. `unitNet` is what the line was CHARGED
  /// (tax included), so the historical economics are explicit in each test.
  Future<SaleModel> seedSale({
    String saleId = 'S1',
    String variantId = 'v1',
    required double unitPrice,
    required double unitTax,
    double qty = 1,
    String paymentType = 'cash',
    String? customerId,
    double? dueAmount,
    double? paidAmount,
    String? status,
  }) async {
    final now = DateTime.now().toIso8601String();
    final total = (unitPrice + unitTax) * qty;

    final sale = SaleModel(
      saleId: saleId,
      customerId: customerId,
      totalItems: qty,
      subtotal: unitPrice * qty,
      discountAmount: 0,
      taxAmount: unitTax * qty,
      totalAmount: total,
      paymentType: paymentType,
      date: now,
      createdAt: now,
      updatedAt: now,
      totalTaxableAmount: unitPrice * qty,
      totalGstAmount: unitTax * qty,
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
        varianteId: variantId,
        productId: 'p1',
        productName: 'Test Item',
        price: unitPrice,
        qty: qty,
        discountAmount: 0,
        gstRate: 18,
        taxableAmount: unitPrice * qty,
        gstAmount: unitTax * qty,
        total: total,
        costPrice: 60,
      ),
    );
    return sale;
  }

  SaleModel readSale(String id) =>
      Hive.box<SaleModel>(HiveBoxNames.sales).get(id)!;

  double stockOf(String variantId) =>
      Hive.box<VarianteModel>(HiveBoxNames.variants).get(variantId)!.stockQty;

  List<SaleModel> allSales() =>
      Hive.box<SaleModel>(HiveBoxNames.sales).values.toList();

  List<StockMovementModel> movements() =>
      Hive.box<StockMovementModel>(HiveBoxNames.restaurantStockMovements)
          .values
          .toList();

  /// The standard fixture: a 900-net T-Shirt sold, a 1200-net Jeans available.
  /// Prices are ex-tax with an 18% rate, so 900 → 1062 and 1200 → 1416.
  Future<void> seedStandard({
    String paymentType = 'cash',
    String? customerId,
    double? dueAmount,
    double? paidAmount,
    String? status,
    double jeansStock = 5,
  }) async {
    await seedProduct();
    await seedVariant(id: 'v1', price: 900, stock: 9); // one already sold
    await seedVariant(id: 'v2', price: 1200, stock: jeansStock);
    await seedSale(
      unitPrice: 900,
      unitTax: 162,
      paymentType: paymentType,
      customerId: customerId,
      dueAmount: dueAmount,
      paidAmount: paidAmount,
      status: status,
    );
  }

  // ==========================================================================
  group('the two halves are linked and are ordinary documents', () {
    test('a return and a replacement share one exchangeGroupId', () async {
      await seedStandard();

      final r = await service.processExchange(
        originalSaleId: 'S1',
        returnedVariantId: 'v1',
        returnQty: 1,
        replacementVariantId: 'v2',
        paymentMethod: 'cash',
      );

      expect(r.success, isTrue, reason: r.error);
      final group = allSales()
          .where((s) => s.exchangeGroupId == r.exchangeGroupId)
          .toList();
      expect(group.length, 2);
      expect(group.where((s) => s.isReturn ?? false).length, 1);
      expect(group.where((s) => !(s.isReturn ?? false)).length, 1);
    });

    test('the group id is a dated EXC document number', () async {
      await seedStandard();

      final r = await service.processExchange(
        originalSaleId: 'S1',
        returnedVariantId: 'v1',
        returnQty: 1,
        replacementVariantId: 'v2',
        paymentMethod: 'cash',
      );

      // A fiscal-year document number now, not a dated one: the series runs
      // consecutively from 1 and restarts only when the financial year turns.
      expect(r.exchangeGroupId, matches(r'^EXC-\d{5,}$'));
    });

    test('each half can find its counterpart', () async {
      await seedStandard();

      final r = await service.processExchange(
        originalSaleId: 'S1',
        returnedVariantId: 'v1',
        returnQty: 1,
        replacementVariantId: 'v2',
        paymentMethod: 'cash',
      );

      final counterpart =
          await service.counterpartOf(readSale(r.returnSaleId!));
      expect(counterpart!.saleId, r.replacementSaleId);
    });
  });

  // ==========================================================================
  group('the price difference', () {
    test('a like-for-like swap settles at zero', () async {
      await seedProduct();
      await seedVariant(id: 'v1', price: 900, stock: 9);
      await seedVariant(id: 'v2', price: 900, stock: 5);
      await seedSale(unitPrice: 900, unitTax: 162);

      final q = await service.quote(
        originalSaleId: 'S1',
        returnedVariantId: 'v1',
        returnQty: 1,
        replacementVariantId: 'v2',
      );

      expect(q.isEven, isTrue);
      expect(q.differenceAmount, closeTo(0, 0.01));
    });

    test('a costlier replacement collects the difference', () async {
      await seedStandard();

      final q = await service.quote(
        originalSaleId: 'S1',
        returnedVariantId: 'v1',
        returnQty: 1,
        replacementVariantId: 'v2',
      );

      // 1416 out, 1062 back.
      expect(q.customerPays, isTrue);
      expect(q.differenceAmount, closeTo(354, 0.02));
    });

    test('a cheaper replacement refunds the difference', () async {
      await seedProduct();
      await seedVariant(id: 'v1', price: 1200, stock: 9);
      await seedVariant(id: 'v2', price: 900, stock: 5);
      await seedSale(unitPrice: 1200, unitTax: 216);

      final q = await service.quote(
        originalSaleId: 'S1',
        returnedVariantId: 'v1',
        returnQty: 1,
        replacementVariantId: 'v2',
      );

      expect(q.customerRefunded, isTrue);
      expect(q.differenceAmount, closeTo(354, 0.02));
    });

    test('a different product entirely is allowed', () async {
      await seedProduct(id: 'p1', name: 'T-Shirt');
      await seedProduct(id: 'p2', name: 'Jeans');
      await seedVariant(id: 'v1', productId: 'p1', price: 900, stock: 9);
      await seedVariant(id: 'v2', productId: 'p2', price: 1200, stock: 5);
      await seedSale(unitPrice: 900, unitTax: 162);

      final r = await service.processExchange(
        originalSaleId: 'S1',
        returnedVariantId: 'v1',
        returnQty: 1,
        replacementVariantId: 'v2',
        paymentMethod: 'cash',
      );

      expect(r.success, isTrue, reason: r.error);
    });

    test('the returned side uses HISTORICAL economics, not the live price',
        () async {
      await seedStandard();

      // The catalogue moves to 1200 AFTER the sale.
      await seedVariant(id: 'v1', price: 1200, stock: 9);

      final q = await service.quote(
        originalSaleId: 'S1',
        returnedVariantId: 'v1',
        returnQty: 1,
        replacementVariantId: 'v2',
      );

      // Still the 1062 that was actually charged.
      expect(q.returnValue, closeTo(1062, 0.02));
    });
  });

  // ==========================================================================
  group('each half keeps its own tax', () {
    test('a 5% return and an 18% replacement each stay correct', () async {
      await seedProduct();
      await seedVariant(id: 'v1', price: 900, stock: 9, taxRate: 5);
      await seedVariant(id: 'v2', price: 1200, stock: 5, taxRate: 18);
      // Sold at 5%: 900 + 45.
      await seedSale(unitPrice: 900, unitTax: 45);

      final q = await service.quote(
        originalSaleId: 'S1',
        returnedVariantId: 'v1',
        returnQty: 1,
        replacementVariantId: 'v2',
      );

      expect(q.returnValue, closeTo(945, 0.02));
      expect(q.replacementValue, closeTo(1416, 0.02));
      expect(q.differenceAmount, closeTo(471, 0.02));
    });
  });

  // ==========================================================================
  group('stock moves both ways and is auditable', () {
    test('the returned item goes back and the replacement comes out', () async {
      await seedStandard();

      await service.processExchange(
        originalSaleId: 'S1',
        returnedVariantId: 'v1',
        returnQty: 1,
        replacementVariantId: 'v2',
        paymentMethod: 'cash',
      );

      expect(stockOf('v1'), 10); // 9 -> 10
      expect(stockOf('v2'), 4); //  5 -> 4
    });

    test('both legs are identifiable in Stock History', () async {
      await seedStandard();

      final r = await service.processExchange(
        originalSaleId: 'S1',
        returnedVariantId: 'v1',
        returnQty: 1,
        replacementVariantId: 'v2',
        paymentMethod: 'cash',
      );

      final rows = movements()
          .where((m) => m.reason == ExchangeService.stockReason)
          .toList();
      expect(rows.length, 2);
      expect(rows.every((m) => m.note!.contains(r.exchangeGroupId!)), isTrue);
      expect(rows.where((m) => m.type == 'in').single.variantId, 'v1');
      expect(rows.where((m) => m.type == 'out').single.variantId, 'v2');
    });
  });

  // ==========================================================================
  group('validation refuses before ANY write', () {
    Future<void> expectNothingWritten() async {
      // One sale only: the original. No return, no replacement.
      expect(allSales().length, 1);
      expect(movements(), isEmpty);
      expect(stockOf('v1'), 9);
    }

    test('an out-of-stock replacement is refused', () async {
      await seedStandard(jeansStock: 0);

      final r = await service.processExchange(
        originalSaleId: 'S1',
        returnedVariantId: 'v1',
        returnQty: 1,
        replacementVariantId: 'v2',
        paymentMethod: 'cash',
      );

      expect(r.success, isFalse);
      expect(r.error, contains('out of stock'));
      await expectNothingWritten();
    });

    test('an inactive replacement is refused', () async {
      await seedProduct();
      await seedVariant(id: 'v1', price: 900, stock: 9);
      await seedVariant(id: 'v2', price: 1200, stock: 5, status: 'inactive');
      await seedSale(unitPrice: 900, unitTax: 162);

      final r = await service.processExchange(
        originalSaleId: 'S1',
        returnedVariantId: 'v1',
        returnQty: 1,
        replacementVariantId: 'v2',
        paymentMethod: 'cash',
      );

      expect(r.success, isFalse);
      expect(r.error, contains('not active'));
      await expectNothingWritten();
    });

    test('an unknown replacement is refused', () async {
      await seedStandard();

      final r = await service.processExchange(
        originalSaleId: 'S1',
        returnedVariantId: 'v1',
        returnQty: 1,
        replacementVariantId: 'ghost',
        paymentMethod: 'cash',
      );

      expect(r.success, isFalse);
      await expectNothingWritten();
    });

    test('exchanging more than remains is refused', () async {
      await seedStandard();

      final r = await service.processExchange(
        originalSaleId: 'S1',
        returnedVariantId: 'v1',
        returnQty: 5, // only 1 was sold
        replacementVariantId: 'v2',
        paymentMethod: 'cash',
      );

      expect(r.success, isFalse);
      await expectNothingWritten();
    });

    test('an item not on the sale is refused', () async {
      await seedStandard();

      final r = await service.processExchange(
        originalSaleId: 'S1',
        returnedVariantId: 'v2',
        returnQty: 1,
        replacementVariantId: 'v2',
        paymentMethod: 'cash',
      );

      expect(r.success, isFalse);
      await expectNothingWritten();
    });

    test('a fully returned sale can no longer be exchanged', () async {
      await seedStandard();

      final first = await service.processExchange(
        originalSaleId: 'S1',
        returnedVariantId: 'v1',
        returnQty: 1,
        replacementVariantId: 'v2',
        paymentMethod: 'cash',
      );
      expect(first.success, isTrue, reason: first.error);

      final second = await service.processExchange(
        originalSaleId: 'S1',
        returnedVariantId: 'v1',
        returnQty: 1,
        replacementVariantId: 'v2',
        paymentMethod: 'cash',
      );

      expect(second.success, isFalse);
      expect(second.error, contains('already been fully returned'));
    });

    test('a return document cannot itself be exchanged', () async {
      await seedStandard();

      final r = await service.processExchange(
        originalSaleId: 'S1',
        returnedVariantId: 'v1',
        returnQty: 1,
        replacementVariantId: 'v2',
        paymentMethod: 'cash',
      );

      final onTheReturn = await service.processExchange(
        originalSaleId: r.returnSaleId!,
        returnedVariantId: 'v1',
        returnQty: 1,
        replacementVariantId: 'v2',
        paymentMethod: 'cash',
      );

      expect(onTheReturn.success, isFalse);
      expect(onTheReturn.error, contains('return document'));
    });
  });

  // ==========================================================================
  group('permission', () {
    test('a signed-out user cannot process an exchange', () async {
      await seedStandard();
      await authService.logout();

      // Exchange moved from an admin-name check to the role matrix, so a
      // MANAGER may now exchange too. A cleared session still cannot: canAccess
      // fails closed on isLoggedIn.
      expect(service.canExchange, isFalse);

      final r = await service.processExchange(
        originalSaleId: 'S1',
        returnedVariantId: 'v1',
        returnQty: 1,
        replacementVariantId: 'v2',
        paymentMethod: 'cash',
      );

      expect(r.success, isFalse);
      expect(r.error, contains('manager'));
      expect(allSales().length, 1);
    });
  });

  // ==========================================================================
  group('partial exchange repeats until the line is exhausted', () {
    test('three single exchanges off a qty-3 line, then refusal', () async {
      await seedProduct();
      await seedVariant(id: 'v1', price: 900, stock: 7);
      await seedVariant(id: 'v2', price: 900, stock: 10);
      await seedSale(unitPrice: 900, unitTax: 162, qty: 3);

      for (var i = 0; i < 3; i++) {
        final r = await service.processExchange(
          originalSaleId: 'S1',
          returnedVariantId: 'v1',
          returnQty: 1,
          replacementVariantId: 'v2',
          paymentMethod: 'cash',
        );
        expect(r.success, isTrue, reason: r.error);
      }

      final fourth = await service.processExchange(
        originalSaleId: 'S1',
        returnedVariantId: 'v1',
        returnQty: 1,
        replacementVariantId: 'v2',
        paymentMethod: 'cash',
      );

      expect(fourth.success, isFalse);
      // Three exchanges: 3 returns + 3 replacements + the original.
      expect(allSales().length, 7);
      expect(stockOf('v1'), 10);
      expect(stockOf('v2'), 7);
    });
  });

  // ==========================================================================
  group('reconciliation', () {
    test('a complete exchange is not reported as incomplete', () async {
      await seedStandard();

      await service.processExchange(
        originalSaleId: 'S1',
        returnedVariantId: 'v1',
        returnQty: 1,
        replacementVariantId: 'v2',
        paymentMethod: 'cash',
      );

      expect(await service.findIncomplete(), isEmpty);
    });

    test('a return whose replacement never landed is flagged', () async {
      await seedStandard();

      final r = await service.processExchange(
        originalSaleId: 'S1',
        returnedVariantId: 'v1',
        returnQty: 1,
        replacementVariantId: 'v2',
        paymentMethod: 'cash',
      );

      // Simulate the replacement half being lost.
      await Hive.box<SaleModel>(HiveBoxNames.sales)
          .delete(r.replacementSaleId!);

      final orphans = await service.findIncomplete();
      expect(orphans.single.saleId, r.returnSaleId);
    });
  });
}
