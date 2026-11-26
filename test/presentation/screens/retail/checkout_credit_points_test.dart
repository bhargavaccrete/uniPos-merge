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

import '../../../helpers/open_retail_day_fixture.dart';

class _Business extends BusinessDetailsRepository {
  _Business(this.tax);
  final bool tax;
  @override
  bool get isTaxEnabled => tax;
}

/// R6: a partial payment's balance obeys the customer's credit limit.
/// R8: the sale records — and the customer loses — only the points the bill
/// actually applied.
void main() {
  late Directory tempDir;
  const now = '2026-01-01T00:00:00.000';

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('checkout_credit_points_');
  });

  tearDown(() async {
    NotificationService.instance.clearAll();
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

  final navigator = GlobalKey<NavigatorState>();

  Future<void> boot(
    WidgetTester tester, {
    required Customer customer,
    required bool tax,
    required double gstRate,
  }) async {
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
      final customers = CustomerStore(CustomerRepository());
      locator
        ..registerSingleton<ProductStore>(products)
        ..registerSingleton<BundleRepository>(BundleRepository())
        ..registerSingleton<AuthService>(AuthService())
        ..registerSingleton<CustomerStore>(customers)
        ..registerSingleton<GstService>(GstService())
        ..registerSingleton<BusinessDetailsRepository>(_Business(tax))
        ..registerSingleton<AttributeStore>(AttributeStore())
        ..registerSingleton<SaleStore>(SaleStore())
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
          productName: 'Pen', price: 100, qty: 2, total: 200, addedAt: now,
          gstRate: gstRate);
      await Hive.box<BillingTabModel>(HiveBoxNames.billingTabs).put('T1',
          BillingTabModel(id: 'T1', name: 'Tab 1', items: [sold],
              createdAt: DateTime(2026), updatedAt: DateTime(2026)));
      await Hive.box<CartItemModel>(HiveBoxNames.cartItems).put('c1', sold);
      await Hive.box<Customer>(HiveBoxNames.customer).put(customer.customerId, customer);
      locator.registerSingleton<CartStore>(CartStore(CartRepository()));
      customers.selectCustomer(customer);
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

  Future<void> completePayment(WidgetTester tester, {int rounds = 60}) async {
    final button = find.text('Complete Payment');
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await settle(tester, rounds: rounds);
  }

  Customer customer({double limit = 0, int points = 0}) => Customer(
        customerId: 'C1',
        name: 'Asha',
        phone: '9999999999',
        creditLimit: limit,
        loyaltyPoints: points,
        createdAt: now,
      );

  int sales() => Hive.box<SaleModel>(HiveBoxNames.sales).length;

  group('R6: partial payment and the credit limit', () {
    Future<void> partialPay(WidgetTester tester,
        {required double limit, int rounds = 60}) async {
      await boot(tester, customer: customer(limit: limit), tax: false, gstRate: 0);
      final partial = find.byType(Switch).first;
      await tester.ensureVisible(partial);
      await tester.tap(partial);
      await settle(tester);
      // ₹200 bill, ₹50 collected now → ₹150 on account.
      await tester.enterText(
          find.byWidgetPredicate((w) => w is EditableText && w.controller.text == '200.00'),
          '50');
      await settle(tester);
      await completePayment(tester, rounds: rounds);
    }

    testWidgets('a balance above the credit limit is refused', (tester) async {
      // Checked before the notice's own 3-second timer removes it.
      await partialPay(tester, limit: 100, rounds: 12);
      expect(sales(), 0, reason: 'nothing written');
      expect(Hive.box<Customer>(HiveBoxNames.customer).get('C1')!.creditBalance, 0);
      expect(
        NotificationService.instance.notifications
            .any((n) => n.message.contains('Credit limit exceeded')),
        isTrue,
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('a balance within the limit goes through', (tester) async {
      await partialPay(tester, limit: 500);
      expect(sales(), 1);
      expect(Hive.box<Customer>(HiveBoxNames.customer).get('C1')!.creditBalance, 150);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  testWidgets('R8: 118 points on ₹200 + 18%: capped at 200, records 200',
      (tester) async {
    // ₹200 + 18% exclusive = ₹236; points reduce the pre-tax ₹200 only.
    await boot(tester, customer: customer(points: 300), tax: true, gstRate: 18);
    // The switch on the loyalty card itself, not the partial-payment one.
    final points = find.descendant(
      of: find.ancestor(
          of: find.text('Redeem Loyalty Points'), matching: find.byType(Row)).last,
      matching: find.byType(Switch),
    );
    await tester.ensureVisible(points);
    await tester.tap(points);
    await settle(tester);
    expect(find.textContaining('redeem 200'), findsOneWidget,
        reason: 'not 236 — the tax cannot be paid with points');

    await completePayment(tester);
    final sale = Hive.box<SaleModel>(HiveBoxNames.sales).values.single;
    expect(sale.loyaltyPointsUsed, 200);
    expect(Hive.box<Customer>(HiveBoxNames.customer).get('C1')!.loyaltyPoints, 100,
        reason: 'lost exactly the points applied');
    await tester.pump(const Duration(seconds: 3));
  });
}
