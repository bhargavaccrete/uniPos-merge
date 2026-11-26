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
import 'package:billberrylite/domain/services/retail/retail_day_gate.dart';
import 'package:billberrylite/domain/services/retail/return_service.dart';
import 'package:billberrylite/domain/store/common/customer_store.dart';
import 'package:billberrylite/domain/store/restaurant/cash_movement_store.dart';
import 'package:billberrylite/domain/store/retail/credit_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';
import 'package:billberrylite/util/restaurant/restaurant_auth_helper.dart';
import 'package:billberrylite/util/restaurant/staticswitch.dart';

import '../../../helpers/open_retail_day_fixture.dart';
import '../../../helpers/open_session_fixture.dart';

/// A drawer that refuses every movement, the way a real one does while an End
/// of Day is pending.
class _RefusingCashMovementStore extends CashMovementStore {
  _RefusingCashMovementStore(super.repository);

  @override
  Future<bool> addMovement({
    required String type,
    required double amount,
    required String reason,
    String? note,
    bool systemClose = false,
  }) async {
    errorMessage = 'Day has ended. Complete End of Day to unlock.';
    return false;
  }
}

/// BLK-16: retail returns, exchanges and credit collections need an open day,
/// by the same rule billing uses — otherwise they fall outside every End of
/// Day, or (collections) update the balance with no Cash In row. A refused
/// action writes nothing at all.
void main() {
  late Directory tempDir;

  Future<void> setUpStores({bool refusingDrawer = false}) async {
    await locator.reset();
    SharedPreferences.setMockInitialValues({
      RestaurantAuthHelper.adminPinKey:
          RestaurantAuthHelper.hashPassword('1234'),
    });
    tempDir = await Directory.systemTemp.createTemp('retail_day_gate_');
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
      ..registerLazySingleton<CashMovementStore>(() => refusingDrawer
          ? _RefusingCashMovementStore(locator<CashMovementRepository>())
          : CashMovementStore(locator<CashMovementRepository>()))
      ..registerLazySingleton<BusinessDetailsRepository>(
          () => BusinessDetailsRepository())
      ..registerLazySingleton<GstService>(() => GstService())
      ..registerLazySingleton<AuthService>(() => AuthService());
    // Admin, so an exchange gets past its permission check to the day check.
    await authService.login('1234');

    final now = DateTime.now().toIso8601String();
    await Hive.box<ProductModel>(HiveBoxNames.products).put(
      'p1',
      ProductModel(
        productId: 'p1',
        productName: 'Test Item',
        category: 'Apparel',
        hasVariants: true,
        createdAt: now,
        updateAt: now,
      ),
    );
    for (final id in ['v1', 'v2']) {
      await Hive.box<VarianteModel>(HiveBoxNames.variants).put(
        id,
        VarianteModel(
          varianteId: id,
          productId: 'p1',
          sellingPrice: 118,
          stockQty: 5,
          costPrice: 60,
          taxRate: 0,
          createdAt: now,
        ),
      );
    }
    await Hive.box<Customer>(HiveBoxNames.customer).put(
      'C1',
      Customer(
        customerId: 'C1',
        name: 'Asha',
        phone: '9999999999',
        creditBalance: 118,
        createdAt: now,
      ),
    );
    // One ₹118 pay-later sale, all of it still owed.
    await Hive.box<SaleModel>(HiveBoxNames.sales).put(
      'S1',
      SaleModel(
        saleId: 'S1',
        customerId: 'C1',
        totalItems: 1,
        subtotal: 118,
        discountAmount: 0,
        taxAmount: 0,
        totalAmount: 118,
        paymentType: 'credit',
        date: now,
        createdAt: now,
        updatedAt: now,
        totalTaxableAmount: 118,
        totalGstAmount: 0,
        grandTotal: 118,
        paidAmount: 0,
        dueAmount: 118,
        status: SaleStatus.due,
      ),
    );
    await Hive.box<SaleItemModel>(HiveBoxNames.saleItems).put(
      'S1-L1',
      SaleItemModel.fromCalculated(
        saleId: 'S1',
        varianteId: 'v1',
        productId: 'p1',
        productName: 'Test Item',
        price: 118,
        qty: 1,
        discountAmount: 0,
        gstRate: 0,
        taxableAmount: 118,
        gstAmount: 0,
        total: 118,
        costPrice: 60,
      ),
    );
  }

  tearDown(() async {
    AppSettings.maxSessionDurationHoursNotifier.value = 24;
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // ── day states ─────────────────────────────────────────────────────────────
  Future<void> openYesterdaysDay() => openRestaurantSessionForTest(
      startTime: DateTime.now().subtract(const Duration(days: 1)));

  // ── what must not move on a refusal ────────────────────────────────────────
  late Map<String, Object?> before;
  Map<String, Object?> snapshot() => {
        'sales': {
          for (final s in Hive.box<SaleModel>(HiveBoxNames.sales).values)
            s.saleId: [s.dueAmount, s.paidAmount, s.status, s.updatedAt],
        },
        'stock': [
          for (final v in Hive.box<VarianteModel>(HiveBoxNames.variants).values)
            v.stockQty,
        ],
        'credit':
            Hive.box<Customer>(HiveBoxNames.customer).get('C1')!.creditBalance,
        'creditRows':
            Hive.box<CreditPaymentModel>(HiveBoxNames.creditPayments).length,
        'cash':
            Hive.box<CashMovementModel>(HiveBoxNames.restaurantCashMovements)
                .length,
        'stockMoves':
            Hive.box<StockMovementModel>(HiveBoxNames.restaurantStockMovements)
                .length,
        'counters': Hive.box(HiveBoxNames.appCounters).toMap().toString(),
      };

  Matcher refused(String text) =>
      throwsA(predicate((e) => e.toString().contains(text), 'says "$text"'));

  Future<void> plainReturn() => ReturnService().processPartialReturn(
        originalSaleId: 'S1',
        itemsToReturn: {'v1': 1},
        refundMethod: 'cash',
      );

  Future<ExchangeResult> exchange() => ExchangeService().processExchange(
        originalSaleId: 'S1',
        returnedVariantId: 'v1',
        returnQty: 1,
        replacementVariantId: 'v2',
        paymentMethod: 'cash',
      );

  Future<CreditPaymentResult> collect(double amount, {String mode = 'cash'}) =>
      CreditStore().receivePayment(
          customerId: 'C1', amount: amount, paymentMode: mode);

  // ==========================================================================
  group('the day rule', () {
    setUp(() => setUpStores());

    test('a day opened today is open', () async {
      await openRetailDayForTest();
      expect(await RetailDayGate.check(), isNull);
    });

    test('no day, or a closed one, is not started', () async {
      expect(await RetailDayGate.check(), RetailDayBlock.dayNotStarted);
      await openRestaurantSessionForTest(closed: true);
      expect(await RetailDayGate.check(), RetailDayBlock.dayNotStarted);
    });

    test("yesterday's day still open: End of Day pending", () async {
      await openYesterdaysDay();
      expect(await RetailDayGate.check(), RetailDayBlock.eodPending);
    });

    test('a day older than the auto-close limit: End of Day pending',
        () async {
      await openRetailDayForTest();
      AppSettings.maxSessionDurationHoursNotifier.value = 0;
      expect(await RetailDayGate.check(), RetailDayBlock.eodPending);
    });
  });

  // ==========================================================================
  group('a return', () {
    setUp(() => setUpStores());

    test('with no day open: refused, nothing written', () async {
      before = snapshot();
      await expectLater(plainReturn(), refused('Start the day first'));
      expect(snapshot(), before);
    });

    test('with End of Day pending: refused, nothing written', () async {
      await openYesterdaysDay();
      before = snapshot();
      await expectLater(plainReturn(), refused('Complete End of Day'));
      expect(snapshot(), before);
    });

    test('with the day open: goes through', () async {
      await openRetailDayForTest();
      await plainReturn();
      expect(Hive.box<SaleModel>(HiveBoxNames.sales).length, 2);
    });
  });

  // ==========================================================================
  group('an exchange', () {
    setUp(() => setUpStores());

    Future<void> payInFull() async {
      final sale = Hive.box<SaleModel>(HiveBoxNames.sales).get('S1')!;
      await Hive.box<SaleModel>(HiveBoxNames.sales).put('S1',
          sale.copyWith(dueAmount: 0, paidAmount: 118, status: SaleStatus.paid));
    }

    test('with no day open: refused, no number used, nothing written',
        () async {
      await payInFull();
      before = snapshot();
      final r = await exchange();
      expect(r.success, isFalse);
      expect(r.error, RetailDayGate.messageFor(RetailDayBlock.dayNotStarted));
      expect(snapshot(), before);
    });

    test('with End of Day pending: refused, nothing written', () async {
      await payInFull();
      await openYesterdaysDay();
      before = snapshot();
      final r = await exchange();
      expect(r.error, RetailDayGate.messageFor(RetailDayBlock.eodPending));
      expect(snapshot(), before);
    });

    test('with the day open: goes through', () async {
      await payInFull();
      await openRetailDayForTest();
      final r = await exchange();
      expect(r.success, isTrue, reason: r.error);
    });
  });

  // ==========================================================================
  group('a credit collection', () {
    setUp(() => setUpStores());

    test('with no day open: refused, nothing written', () async {
      before = snapshot();
      final r = await collect(118);
      expect(r.success, isFalse);
      expect(r.errorMessage, RetailDayGate.messageFor(RetailDayBlock.dayNotStarted));
      expect(snapshot(), before);
    });

    test('with End of Day pending: refused, nothing written', () async {
      await openYesterdaysDay();
      before = snapshot();
      final r = await collect(118);
      expect(r.success, isFalse);
      expect(r.errorMessage, RetailDayGate.messageFor(RetailDayBlock.eodPending));
      expect(snapshot(), before);
    });

    test('cash, with the day open: Cash In for exactly what was collected',
        () async {
      await openRetailDayForTest();
      // More than is owed: only the 118 due is collected.
      final r = await collect(200);
      expect(r.success, isTrue, reason: r.errorMessage);

      final moves =
          Hive.box<CashMovementModel>(HiveBoxNames.restaurantCashMovements)
              .values
              .toList();
      expect(moves, hasLength(1));
      expect(moves.single.type, 'in');
      expect(moves.single.amount, closeTo(118, 0.001));
      expect(Hive.box<SaleModel>(HiveBoxNames.sales).get('S1')!.dueAmount,
          closeTo(0, 0.001));
      expect(
          Hive.box<Customer>(HiveBoxNames.customer).get('C1')!.creditBalance,
          closeTo(0, 0.001));
    });

    test('UPI, with the day open: collected, no Cash In', () async {
      await openRetailDayForTest();
      final r = await collect(118, mode: 'upi');
      expect(r.success, isTrue, reason: r.errorMessage);
      expect(
          Hive.box<CashMovementModel>(HiveBoxNames.restaurantCashMovements)
              .values,
          isEmpty);
      expect(Hive.box<SaleModel>(HiveBoxNames.sales).get('S1')!.dueAmount,
          closeTo(0, 0.001));
    });
  });

  group('a credit collection whose Cash In is refused', () {
    setUp(() => setUpStores(refusingDrawer: true));

    test('fails, and the invoices and balance do not move', () async {
      await openRetailDayForTest();
      before = snapshot();
      final r = await collect(118);
      expect(r.success, isFalse);
      expect(r.errorMessage, contains('nothing was collected'));
      expect(snapshot(), before);
    });
  });
}
