import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/domain/store/common/customer_store.dart';
import 'package:billberrylite/domain/store/restaurant/cash_movement_store.dart';
import 'package:billberrylite/domain/store/retail/credit_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';
import 'package:billberrylite/presentation/screens/retail/receive_payment_screen.dart';

import '../../../helpers/open_retail_day_fixture.dart';

/// Counts collections and holds the first one open until the test releases
/// it, so the first tap is still in flight when the second one lands.
class _SlowCredit extends CreditStore {
  final Completer<void> gate = Completer<void>();
  int calls = 0;

  @override
  Future<CreditPaymentResult> receivePayment({
    required String customerId,
    required double amount,
    required String paymentMode,
    String? referenceId,
    String? note,
  }) async {
    calls++;
    await gate.future;
    return super.receivePayment(
      customerId: customerId,
      amount: amount,
      paymentMode: paymentMode,
      referenceId: referenceId,
      note: note,
    );
  }
}

/// SALE-7, screen side: two taps on Receive Payment before the first finished
/// used to start two collections (the guard was set only after the day
/// check). The second tap must be ignored outright.
void main() {
  late Directory tempDir;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('receive_payment_tap_');
  });

  tearDown(() async {
    NotificationService.instance.clearAll();
    await locator.reset();
    // Writes the screen began inside the widget test's fake clock can leave
    // Hive's close waiting forever (a harness limit, not app behaviour). The
    // assertions have already read the boxes; the file runs in its own isolate.
    await Future.any<void>([
      Hive.close(),
      Future<void>.delayed(const Duration(seconds: 5)),
    ]);
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {
      // Files still held by the unclosed boxes; the OS temp dir cleans up.
    }
  });

  /// Lets the screen's real Hive I/O finish, then repaints.
  Future<void> settle(WidgetTester tester, {int rounds = 10}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  late _SlowCredit credit;

  Future<Customer> boot(WidgetTester tester) async {
    late Customer customer;
    await tester.runAsync(() async {
      await locator.reset();
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
      await Hive.openBox(HiveBoxNames.appCounters);
      await openRetailDayForTest();
      locator
        ..registerLazySingleton<SaleStore>(() => SaleStore())
        ..registerLazySingleton<CustomerStore>(() => CustomerStore(CustomerRepository()))
        ..registerLazySingleton<CashMovementRepository>(() => CashMovementRepository())
        ..registerLazySingleton<CashMovementStore>(
            () => CashMovementStore(locator<CashMovementRepository>()))
        ..registerSingleton<CreditStore>(credit = _SlowCredit());

      final now = DateTime.now().toIso8601String();
      customer = Customer(customerId: 'C1', name: 'Debtor', phone: '9999999999',
          creditBalance: 500, createdAt: now);
      await Hive.box<Customer>(HiveBoxNames.customer).put('C1', customer);
      await Hive.box<SaleModel>(HiveBoxNames.sales).put('S1', SaleModel(
        saleId: 'S1', customerId: 'C1', totalItems: 1, subtotal: 500,
        discountAmount: 0, taxAmount: 0, totalAmount: 500, paymentType: 'credit',
        date: now, createdAt: now, updatedAt: now, totalTaxableAmount: 500,
        totalGstAmount: 0, grandTotal: 500, paidAmount: 0, dueAmount: 500,
        status: SaleStatus.due,
      ));
    });

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 1366);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: ReceivePaymentScreen(customer: customer)));
    await settle(tester);
    return customer;
  }

  testWidgets('two quick taps: one collection, the second tap ignored', (tester) async {
    await boot(tester);
    await tester.enterText(find.byType(TextFormField).first, '200');
    await tester.pump();

    // The button label, not the app bar title (Scaffold builds its body first).
    final button = find.text('Receive Payment').first;
    await tester.ensureVisible(button);
    await tester.pump();
    // Both taps land before the first collection can finish.
    // Back to back, no frame between: the button has not been rebuilt as
    // disabled yet, and the first collection is held inside the store.
    await tester.tap(button);
    await tester.tap(button);
    credit.gate.complete();
    await settle(tester, rounds: 60);

    expect(credit.calls, 1, reason: 'the second tap never started a collection');

    expect(Hive.box<CreditPaymentModel>(HiveBoxNames.creditPayments).length, 1);
    expect(Hive.box<CashMovementModel>(HiveBoxNames.restaurantCashMovements).length, 1);
    expect(Hive.box<Customer>(HiveBoxNames.customer).get('C1')!.creditBalance, 300);
    expect(
      NotificationService.instance.notifications
          .any((n) => n.message.contains('already being recorded')),
      isFalse,
      reason: 'the second tap never reached the store',
    );

    // Close the success dialog and let the notices expire.
    await tester.tap(find.text('Done'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 3));
  });
}
