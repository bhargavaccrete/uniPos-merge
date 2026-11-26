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
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/repositories/common/customer_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/cash_movement_repository.dart';
import 'package:billberrylite/domain/store/common/customer_store.dart';
import 'package:billberrylite/domain/store/restaurant/cash_movement_store.dart';
import 'package:billberrylite/domain/store/retail/credit_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';

import '../../../helpers/open_retail_day_fixture.dart';

/// SALE-7: two collections for the same customer at once both read the same
/// balance; each applied it, so the balance fell twice and two Cash In rows
/// were written for one payment.
void main() {
  late Directory tempDir;

  setUp(() async {
    await locator.reset();
    tempDir = await Directory.systemTemp.createTemp('credit_concurrent_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();
    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'retail');
    await Hive.openBox<SaleModel>(HiveBoxNames.sales);
    await Hive.openBox<SaleItemModel>(HiveBoxNames.saleItems);
    await Hive.openBox<Customer>(HiveBoxNames.customer);
    await Hive.openBox<CreditPaymentModel>(HiveBoxNames.creditPayments);
    await Hive.openBox<CashMovementModel>(HiveBoxNames.restaurantCashMovements);
    await Hive.openBox(HiveBoxNames.dayManagementBox);
    await openRetailDayForTest();
    await Hive.openBox(HiveBoxNames.appCounters);

    locator
      ..registerLazySingleton<SaleStore>(() => SaleStore())
      ..registerLazySingleton<CustomerStore>(() => CustomerStore(CustomerRepository()))
      ..registerLazySingleton<CashMovementRepository>(() => CashMovementRepository())
      ..registerLazySingleton<CashMovementStore>(
          () => CashMovementStore(locator<CashMovementRepository>()))
      ..registerLazySingleton<CreditStore>(() => CreditStore());

    await Hive.box<Customer>(HiveBoxNames.customer).put('C1', Customer(
      customerId: 'C1', name: 'Asha', phone: '9999999999',
      creditBalance: 500, createdAt: DateTime(2026).toIso8601String()));
    final now = DateTime.now().toIso8601String();
    await Hive.box<SaleModel>(HiveBoxNames.sales).put('S1', SaleModel.create(
      saleId: 'S1', customerId: 'C1', totalItems: 1, subtotal: 500,
      totalAmount: 500, paymentType: 'credit', grandTotal: 500,
    ).copyWith(dueAmount: 500, paidAmount: 0, status: 'due', createdAt: now));
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('two at once: one collects, the other is refused; moved once', () async {
    final store = locator<CreditStore>();
    final results = await Future.wait([
      store.receivePayment(customerId: 'C1', amount: 200, paymentMode: 'cash'),
      store.receivePayment(customerId: 'C1', amount: 200, paymentMode: 'cash'),
    ]);

    expect(results.where((r) => r.success), hasLength(1));
    expect(results.where((r) => !r.success).single.errorMessage,
        contains('already being recorded'));
    expect(Hive.box<Customer>(HiveBoxNames.customer).get('C1')!.creditBalance, 300,
        reason: 'reduced once');
    expect(Hive.box<CashMovementModel>(HiveBoxNames.restaurantCashMovements).length, 1,
        reason: 'one Cash In row');
    expect(Hive.box<CreditPaymentModel>(HiveBoxNames.creditPayments).length, 1);
  });

  test('one after the other: both collect', () async {
    final store = locator<CreditStore>();
    expect((await store.receivePayment(
        customerId: 'C1', amount: 200, paymentMode: 'cash')).success, isTrue);
    expect((await store.receivePayment(
        customerId: 'C1', amount: 100, paymentMode: 'cash')).success, isTrue);
    expect(Hive.box<Customer>(HiveBoxNames.customer).get('C1')!.creditBalance, 200);
  });
}
