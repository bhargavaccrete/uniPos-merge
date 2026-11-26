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
import 'package:billberrylite/core/init/mode_services.dart';
import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/models/common/business_details.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/common/shift_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_value_model_220.dart';
import 'package:billberrylite/data/models/retail/hive_model/billing_tab_model_173.dart';
import 'package:billberrylite/data/models/retail/hive_model/bundle_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/cart_model_202.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_attribute_model_221.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/data/repositories/common/customer_repository.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/common/shift_repository.dart';
import 'package:billberrylite/data/repositories/payment_method_repository.dart';
import 'package:billberrylite/data/repositories/retail/bundle_repository.dart';
import 'package:billberrylite/data/repositories/retail/cart_repository.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/domain/services/retail/auth_service.dart';
import 'package:billberrylite/domain/services/retail/gst_service.dart';
import 'package:billberrylite/domain/store/common/customer_store.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/retail/attribute_store.dart';
import 'package:billberrylite/domain/store/retail/cart_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';
import 'package:billberrylite/models/payment_method.dart';
import 'package:billberrylite/presentation/screens/retail/checkout_screen.dart';
import 'package:billberrylite/stores/payment_method_store.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';

import '../../../helpers/open_retail_day_fixture.dart';

class _NoTaxBusiness extends BusinessDetailsRepository {
  @override
  bool get isTaxEnabled => false;
}

/// WF-3: after a Retail restart the till opens straight on the POS (the
/// dashboard, which used to restore the shift, is skipped). The first sale
/// must still carry the open shift's ID, restored by startup.
void main() {
  late Directory tempDir;
  const now = '2026-01-01T00:00:00.000';

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    // What the previous process left behind: an open shift's ID.
    SharedPreferences.setMockInitialValues(
        {'restaurant_current_shift_id': 'shift-7'});
    tempDir = await Directory.systemTemp.createTemp('checkout_shift_restart_');
  });

  tearDown(() async {
    NotificationService.instance.clearAll();
    ModeServices.resetForTesting();
    await locator.reset();
    await Future.any<void>([
      Hive.close(),
      Future<void>.delayed(const Duration(seconds: 5)),
    ]);
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<void> settle(WidgetTester tester, {int rounds = 10}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('the first sale after a restart carries the restored shift ID',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.runAsync(() async {
      Hive.init(tempDir.path);
      await HiveInit.registerRetailAdapters();
      await AppConfig.init();
      await AppConfig.box.put('businessMode', 'retail');
      for (final open in [
        () => Hive.openBox<ProductModel>(HiveBoxNames.products),
        () => Hive.openBox<VarianteModel>(HiveBoxNames.variants),
        () => Hive.openBox<RetailBundleModel>(HiveBoxNames.bundles),
        () => Hive.openBox<CartItemModel>(HiveBoxNames.cartItems),
        () => Hive.openBox<BillingTabModel>(HiveBoxNames.billingTabs),
        () => Hive.openBox<SaleModel>(HiveBoxNames.sales),
        () => Hive.openBox<SaleItemModel>(HiveBoxNames.saleItems),
        () => Hive.openBox<Customer>(HiveBoxNames.customer),
        () => Hive.openBox<StockMovementModel>(HiveBoxNames.restaurantStockMovements),
        () => Hive.openBox<AppNotificationModel>(HiveBoxNames.appNotifications),
        () => Hive.openBox<AttributeModel>(HiveBoxNames.attributes),
        () => Hive.openBox<AttributeValueModel>(HiveBoxNames.attributeValues),
        () => Hive.openBox<ProductAttributeModel>(HiveBoxNames.productAttributes),
        () => Hive.openBox<BusinessDetails>(HiveBoxNames.businessDetailsBox),
        () => Hive.openBox<PaymentMethod>('paymentMethodsBox'),
        () => Hive.openBox(HiveBoxNames.dayManagementBox),
        () => Hive.openBox(HiveBoxNames.appCounters),
        () => Hive.openBox(HiveBoxNames.retailCheckoutJournal),
        () => Hive.openBox<ShiftModel>(HiveBoxNames.shift),
      ]) {
        await open();
      }
      await openRetailDayForTest();
      await Hive.box<ShiftModel>(HiveBoxNames.shift).put(
          'shift-7',
          ShiftModel(
              id: 'shift-7',
              staffId: 'admin',
              staffName: 'Admin',
              startTime: DateTime.now().subtract(const Duration(hours: 2))));

      final products = ProductStore();
      locator
        ..registerSingleton<ProductStore>(products)
        ..registerSingleton<BundleRepository>(BundleRepository())
        ..registerSingleton<AuthService>(AuthService())
        ..registerSingleton<CustomerStore>(CustomerStore(CustomerRepository()))
        ..registerSingleton<GstService>(GstService())
        ..registerSingleton<BusinessDetailsRepository>(_NoTaxBusiness())
        ..registerSingleton<AttributeStore>(AttributeStore())
        ..registerSingleton<SaleStore>(SaleStore())
        ..registerSingleton<NotificationStore>(NotificationStore(NotificationRepository()))
        ..registerSingleton<LicenseStore>(
            LicenseStore(LicenseApiService())..licenseBypassed = true)
        ..registerSingleton<PaymentMethodRepository>(PaymentMethodRepository())
        ..registerSingleton<PaymentMethodStore>(
            PaymentMethodStore(locator<PaymentMethodRepository>()))
        ..registerSingleton<ShiftRepository>(ShiftRepository());

      // A fresh process: nothing in memory yet.
      expect(RestaurantSession.currentShiftId, isNull);
      // Startup (the real WF-3 session steps), before the POS opens.
      ModeServices.steps = ModeStartupSteps(
        loadRetailSettings: () async {},
        startLocalNotifications: () async {},
        startPushNotifications: () async {},
      );
      await ModeServices.start();
      expect(RestaurantSession.currentShiftId, 'shift-7');

      await products.ensureLoaded();
      await products.addProduct(ProductModel(productId: 'p1', productName: 'Pen',
          category: '', hasVariants: false, createdAt: now, updateAt: now));
      await products.addVariant(VarianteModel(varianteId: 'v1', productId: 'p1',
          stockQty: 10, sellingPrice: 100, createdAt: now, status: 'active'));
      final sold = CartItemModel(cartItemId: 'c1', variantId: 'v1', productId: 'p1',
          productName: 'Pen', price: 100, qty: 2, total: 200, addedAt: now);
      await Hive.box<BillingTabModel>(HiveBoxNames.billingTabs).put('T1',
          BillingTabModel(id: 'T1', name: 'Tab 1', items: [sold],
              createdAt: DateTime(2026), updatedAt: DateTime(2026)));
      await Hive.box<CartItemModel>(HiveBoxNames.cartItems).put('c1', sold);
      locator.registerSingleton<CartStore>(CartStore(CartRepository()));
    });

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 1366);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      home: const Scaffold(body: SizedBox()),
    ));
    navigator.currentState!
        .push(MaterialPageRoute<bool>(builder: (_) => const CheckoutScreen()));
    await settle(tester);

    final fields = find.byType(EditableText);
    final texts = [
      for (final e in fields.evaluate()) (e.widget as EditableText).controller.text,
    ];
    final amountAt = texts.indexOf('200.00');
    expect(amountAt, greaterThanOrEqualTo(0));
    await tester.enterText(fields.at(amountAt + 1), '200');
    await settle(tester);
    final button = find.text('Complete Payment');
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await settle(tester, rounds: 60);

    final sales = Hive.box<SaleModel>(HiveBoxNames.sales).values.toList();
    expect(sales, hasLength(1));
    expect(sales.single.shiftId, 'shift-7',
        reason: 'the Staff Performance report reads the staff from this ID');
    await tester.pump(const Duration(seconds: 3));
  });
}
