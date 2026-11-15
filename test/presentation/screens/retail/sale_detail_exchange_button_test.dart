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
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/domain/services/retail/auth_service.dart';
import 'package:billberrylite/domain/services/retail/exchange_service.dart';
import 'package:billberrylite/domain/services/retail/gst_service.dart';
import 'package:billberrylite/domain/store/common/customer_store.dart';
import 'package:billberrylite/domain/store/retail/attribute_store.dart';
import 'package:billberrylite/domain/store/restaurant/cash_movement_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';
import 'package:billberrylite/presentation/screens/retail/exchange_screen.dart';
import 'package:billberrylite/presentation/screens/retail/sale_detail_screen.dart';
import 'package:billberrylite/util/restaurant/restaurant_auth_helper.dart';

/// BLK-10, screen side: on a sale with a balance still owed, the Exchange
/// button explains why instead of opening the exchange screen (the service
/// refuses it too). A fully paid sale still opens it.
void main() {
  late Directory tempDir;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      RestaurantAuthHelper.adminPinKey:
          RestaurantAuthHelper.hashPassword('1234'),
    });
    tempDir = await Directory.systemTemp.createTemp('sale_detail_exchange_');
  });

  tearDown(() async {
    NotificationService.instance.clearAll();
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Lets the screen's Hive reads finish, then repaints.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester
          .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// One ₹1,000 sale to a known customer; [due] still owed on it.
  Future<void> boot(WidgetTester tester, {required double due}) async {
    await tester.runAsync(() async {
      await locator.reset();
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
      await Hive.openBox<CashMovementModel>(
          HiveBoxNames.restaurantCashMovements);
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
        ..registerLazySingleton<CashMovementStore>(
            () => CashMovementStore(locator<CashMovementRepository>()))
        ..registerLazySingleton<BusinessDetailsRepository>(
            () => BusinessDetailsRepository())
        ..registerLazySingleton<GstService>(() => GstService())
        ..registerLazySingleton<AuthService>(() => AuthService())
        // The item tiles describe variant attributes through it.
        ..registerLazySingleton<AttributeStore>(() => AttributeStore());
      // Admin: allowed to exchange, so the button is shown.
      await authService.login('1234');

      final now = DateTime.now().toIso8601String();
      await Hive.box<Customer>(HiveBoxNames.customer).put(
          'C1',
          Customer(
              customerId: 'C1',
              name: 'Debtor',
              phone: '9999999999',
              creditBalance: due,
              createdAt: now));
      await Hive.box<SaleModel>(HiveBoxNames.sales).put(
        'S1',
        SaleModel(
          saleId: 'S1',
          customerId: 'C1',
          totalItems: 1,
          subtotal: 1000,
          discountAmount: 0,
          taxAmount: 0,
          totalAmount: 1000,
          paymentType: due > 0 ? 'credit' : 'cash',
          date: now,
          createdAt: now,
          updatedAt: now,
          totalTaxableAmount: 1000,
          totalGstAmount: 0,
          grandTotal: 1000,
          paidAmount: 1000 - due,
          dueAmount: due,
          status: due > 0 ? SaleStatus.due : SaleStatus.paid,
        ),
      );
      await Hive.box<SaleItemModel>(HiveBoxNames.saleItems).put(
        'S1-L1',
        SaleItemModel.fromCalculated(
          saleId: 'S1',
          varianteId: 'v1',
          productId: 'p1',
          productName: 'Test Item',
          price: 1000,
          qty: 1,
          discountAmount: 0,
          gstRate: 0,
          taxableAmount: 1000,
          gstAmount: 0,
          total: 1000,
          costPrice: 60,
        ),
      );
    });

    // Tablet width: the test font's square glyphs overflow the price rows at
    // phone width (13px), which says nothing about the button under test.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 1366);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
        const MaterialApp(home: SaleDetailScreen(saleId: 'S1')));
    await settle(tester);
  }

  bool told() => NotificationService.instance.notifications
      .any((n) => n.message == ExchangeService.unpaidBalanceMessage);

  testWidgets('a balance owed: Exchange explains, and does not open',
      (tester) async {
    await boot(tester, due: 1000);
    expect(find.text('Exchange'), findsOneWidget);

    await tester.tap(find.text('Exchange'));
    await settle(tester);

    expect(find.byType(ExchangeScreen), findsNothing);
    expect(find.byType(SaleDetailScreen), findsOneWidget);
    expect(told(), isTrue);

    // Let the notice's own timer run out.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('fully paid: Exchange opens the exchange screen', (tester) async {
    await boot(tester, due: 0);

    await tester.tap(find.text('Exchange'));
    await settle(tester);

    expect(find.byType(ExchangeScreen), findsOneWidget);
    expect(told(), isFalse);
  });
}
