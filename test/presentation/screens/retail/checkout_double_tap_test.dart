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
import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/models/common/business_details.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
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
import 'package:billberrylite/data/repositories/payment_method_repository.dart';
import 'package:billberrylite/data/repositories/retail/bundle_repository.dart';
import 'package:billberrylite/data/repositories/retail/cart_repository.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/domain/services/retail/auth_service.dart';
import 'package:billberrylite/domain/services/retail/gst_service.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
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

import '../../../helpers/open_retail_day_fixture.dart';

class _NoTaxBusiness extends BusinessDetailsRepository {
  @override
  bool get isTaxEnabled => false;
}

/// A slow disk: the daily-bill-cap read (the first await of a checkout)
/// waits until the test releases it, so the first tap is still in flight
/// when the second one lands.
class _SlowSales extends SaleStore {
  final Completer<void> gate = Completer<void>();
  int capReads = 0;

  @override
  Future<List<SaleModel>> getTodaySales() async {
    capReads++;
    await gate.future;
    return super.getTodaySales();
  }
}

/// SALE-1, screen side: the processing flag was set only after the bill-cap
/// and stock checks awaited, so a second tap on Complete Payment ran a whole
/// second checkout — two invoices, stock and customer posted twice.
void main() {
  late Directory tempDir;
  const now = '2026-01-01T00:00:00.000';

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('checkout_tap_');
  });

  tearDown(() async {
    NotificationService.instance.clearAll();
    await locator.reset();
    // See receive_payment_double_tap_test: a close begun under the widget
    // test's fake clock can wait forever.
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

  final navigator = GlobalKey<NavigatorState>();
  late _SlowSales sales;

  Future<void> boot(WidgetTester tester) async {
    await tester.runAsync(() async {
      await locator.reset();
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
      ]) {
        await open();
      }
      await openRetailDayForTest();

      final products = ProductStore();
      locator
        ..registerSingleton<ProductStore>(products)
        ..registerSingleton<BundleRepository>(BundleRepository())
        ..registerSingleton<AuthService>(AuthService())
        ..registerSingleton<CustomerStore>(CustomerStore(CustomerRepository()))
        ..registerSingleton<GstService>(GstService())
        ..registerSingleton<BusinessDetailsRepository>(_NoTaxBusiness())
        ..registerSingleton<AttributeStore>(AttributeStore())
        ..registerSingleton<SaleStore>(sales = _SlowSales())
        ..registerSingleton<NotificationStore>(NotificationStore(NotificationRepository()))
        ..registerSingleton<LicenseStore>(
            LicenseStore(LicenseApiService())..licenseBypassed = true)
        ..registerSingleton<PaymentMethodRepository>(PaymentMethodRepository())
        ..registerSingleton<PaymentMethodStore>(
            PaymentMethodStore(locator<PaymentMethodRepository>()));
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
  }

  testWidgets('two quick taps on Complete Payment: one sale', (tester) async {
    await boot(tester);
    // Tender the bill in cash, as the cashier would: the payment widget
    // validates on edit.
    final fields = find.byType(EditableText);
    final texts = [
      for (final e in fields.evaluate()) (e.widget as EditableText).controller.text,
    ];
    final amountAt = texts.indexOf('200.00');
    expect(amountAt, greaterThanOrEqualTo(0), reason: 'the amount box holds the bill');
    // "Cash Received" is the box right after the amount.
    await tester.enterText(fields.at(amountAt + 1), '200');
    await settle(tester);

    final button = find.text('Complete Payment');
    expect(button, findsOneWidget);
    await tester.ensureVisible(button);
    await tester.pump();

    await tester.tap(button);
    await tester.tap(button);
    // Both taps are in before the first checkout gets past its first read.
    sales.gate.complete();
    await settle(tester, rounds: 60);

    expect(sales.capReads, 1, reason: 'the second tap never started a checkout');
    expect(Hive.box<SaleModel>(HiveBoxNames.sales).length, 1, reason: 'one invoice');
    expect(Hive.box<VarianteModel>(HiveBoxNames.variants).get('v1')!.stockQty, 8,
        reason: 'stock deducted once');
    expect(Hive.box(HiveBoxNames.retailCheckoutJournal).isEmpty, isTrue,
        reason: 'the sale finished');
    await tester.pump(const Duration(seconds: 3));
  });
}
