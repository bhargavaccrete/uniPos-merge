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
import 'package:billberrylite/util/common/loyalty_points.dart';

import '../../../helpers/open_retail_day_fixture.dart';

class _NoTax extends BusinessDetailsRepository {
  @override
  bool get isTaxEnabled => false;
}

/// LOY-1: a loyalty redemption belongs to the customer it was made for.
///
/// Asha (C1, 150 points) redeems on a ₹200 bill (no tax) → ₹50 to pay. Before
/// the fix, switching the bill to a walk-in or to Bina (C2, 0 points) kept
/// the ₹150 off and deducted nobody's points: the posting step skips a short
/// balance silently. Now a customer change drops the redemption, and the
/// commit re-checks the customer's SAVED balance on both the paid and the
/// Pay Later path.
void main() {
  late Directory tempDir;
  const now = '2026-01-01T00:00:00.000';

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('checkout_loyalty_');
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
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  final navigator = GlobalKey<NavigatorState>();

  Customer asha({int points = 150, double limit = 0}) => Customer(
        customerId: 'C1',
        name: 'Asha',
        phone: '9999999999',
        loyaltyPoints: points,
        creditLimit: limit,
        createdAt: now,
      );
  // A function, not a shared instance: a HiveObject can be stored in only one
  // box, and every test opens fresh boxes.
  Customer bina() => Customer(
        customerId: 'C2',
        name: 'Bina',
        phone: '8888888888',
        createdAt: now,
      );

  Future<void> boot(WidgetTester tester, {Customer? first}) async {
    final attached = first ?? asha();
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
        () => Hive.openBox<StockMovementModel>(
            HiveBoxNames.restaurantStockMovements),
        () => Hive.openBox<AppNotificationModel>(
            HiveBoxNames.appNotifications),
        () => Hive.openBox<AttributeModel>(HiveBoxNames.attributes),
        () => Hive.openBox<AttributeValueModel>(HiveBoxNames.attributeValues),
        () => Hive.openBox<ProductAttributeModel>(
            HiveBoxNames.productAttributes),
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
        ..registerSingleton<BusinessDetailsRepository>(_NoTax())
        ..registerSingleton<AttributeStore>(AttributeStore())
        ..registerSingleton<SaleStore>(SaleStore())
        ..registerSingleton<NotificationStore>(
            NotificationStore(NotificationRepository()))
        ..registerSingleton<LicenseStore>(
            LicenseStore(LicenseApiService())..licenseBypassed = true)
        ..registerSingleton<PaymentMethodRepository>(PaymentMethodRepository())
        ..registerSingleton<PaymentMethodStore>(
            PaymentMethodStore(locator<PaymentMethodRepository>()));
      await products.ensureLoaded();
      await products.addProduct(ProductModel(
          productId: 'p1', productName: 'Pen', category: '',
          hasVariants: false, createdAt: now, updateAt: now));
      await products.addVariant(VarianteModel(
          varianteId: 'v1', productId: 'p1', stockQty: 10,
          sellingPrice: 100, createdAt: now, status: 'active'));
      final sold = CartItemModel(
          cartItemId: 'c1', variantId: 'v1', productId: 'p1',
          productName: 'Pen', price: 100, qty: 2, total: 200, addedAt: now,
          gstRate: 0);
      await Hive.box<BillingTabModel>(HiveBoxNames.billingTabs).put(
          'T1',
          BillingTabModel(id: 'T1', name: 'Tab 1', items: [sold],
              createdAt: DateTime(2026), updatedAt: DateTime(2026)));
      await Hive.box<CartItemModel>(HiveBoxNames.cartItems).put('c1', sold);
      final box = Hive.box<Customer>(HiveBoxNames.customer);
      await box.put(attached.customerId, attached);
      await box.put('C2', bina());
      locator.registerSingleton<CartStore>(CartStore(CartRepository()));
      customers.selectCustomer(attached);
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

  Finder loyaltySwitch() => find.descendant(
        of: find.ancestor(
            of: find.text('Redeem Loyalty Points'),
            matching: find.byType(Row)).last,
        matching: find.byType(Switch),
      );

  Future<void> redeem(WidgetTester tester) async {
    await tester.ensureVisible(loyaltySwitch());
    await tester.tap(loyaltySwitch());
    await settle(tester);
    expect(retailCartStore.bill.loyaltyRedemption, 150);
    expect(retailCartStore.bill.grandTotal, 50);
  }

  /// Through the real picker: checkout's customer card → Customer Selection.
  Future<void> openPicker(WidgetTester tester) async {
    final card = find.text('Asha').first;
    await tester.ensureVisible(card);
    await tester.tap(card);
    await settle(tester);
  }

  /// Types cash received = the amount due, as the cashier would. A changed
  /// total clears that box (SplitPaymentWidget.didUpdateWidget); it is the
  /// only empty field on the screen.
  Future<void> completePayment(WidgetTester tester, {int rounds = 60}) async {
    final cashReceived = find.byWidgetPredicate(
        (w) => w is EditableText && w.controller.text.isEmpty);
    if (cashReceived.evaluate().isNotEmpty) {
      await tester.ensureVisible(cashReceived.first);
      await tester.enterText(cashReceived.first,
          retailCartStore.bill.grandTotal.toStringAsFixed(2));
      await settle(tester, rounds: 3);
    }
    final button = find.text('Complete Payment');
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await settle(tester, rounds: rounds);
  }

  Customer savedCustomer(String id) =>
      Hive.box<Customer>(HiveBoxNames.customer).get(id)!;
  List<SaleModel> sales() =>
      Hive.box<SaleModel>(HiveBoxNames.sales).values.toList();
  bool notified(String text) => NotificationService.instance.notifications
      .any((n) => n.message.contains(text));

  group('customer switching drops the redemption', () {
    testWidgets('Asha → walk-in (Remove): full price, nobody loses points',
        (tester) async {
      await boot(tester);
      await redeem(tester);

      await openPicker(tester);
      await tester.tap(find.text('Remove'));
      await settle(tester);

      expect(customerStore.selectedCustomer, isNull);
      expect(retailCartStore.loyaltyRedemption, 0);
      expect(retailCartStore.bill.grandTotal, 200);
      expect(find.text('Redeem Loyalty Points'), findsNothing);

      await completePayment(tester);
      final sale = sales().single;
      expect(sale.loyaltyPointsUsed, 0);
      expect(sale.grandTotal, 200);
      expect(sale.customerId, isNull);
      expect(savedCustomer('C1').loyaltyPoints, 150);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Asha → Bina (0 points): full price on Bina, Asha untouched',
        (tester) async {
      await boot(tester);
      await redeem(tester);

      await openPicker(tester);
      await tester.tap(find.text('Bina'));
      await settle(tester);

      expect(customerStore.selectedCustomer?.customerId, 'C2');
      expect(retailCartStore.loyaltyRedemption, 0);
      expect(retailCartStore.bill.grandTotal, 200);

      await completePayment(tester);
      final sale = sales().single;
      expect(sale.customerId, 'C2');
      expect(sale.loyaltyPointsUsed, 0);
      expect(sale.grandTotal, 200);
      expect(savedCustomer('C1').loyaltyPoints, 150);
      expect(savedCustomer('C2').loyaltyPoints, LoyaltyPoints.earnedFor(200),
          reason: 'Bina only earns on her full-price bill');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('picking the same customer again keeps a valid redemption',
        (tester) async {
      await boot(tester);
      await redeem(tester);

      await tester.runAsync(
          () async => retailCartStore.selectSaleCustomer(asha()));
      await settle(tester);

      expect(retailCartStore.loyaltyRedemption, 150);
      expect(tester.widget<Switch>(loyaltySwitch()).value, isTrue);

      await completePayment(tester);
      expect(sales().single.loyaltyPointsUsed, 150);
      expect(savedCustomer('C1').loyaltyPoints,
          150 - 150 + LoyaltyPoints.earnedFor(50),
          reason: 'existing behaviour: exactly the applied points deducted');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('the loyalty switch follows the store after a switch',
        (tester) async {
      await boot(tester, first: asha(points: 300));
      await tester.ensureVisible(loyaltySwitch());
      await tester.tap(loyaltySwitch());
      await settle(tester);
      expect(tester.widget<Switch>(loyaltySwitch()).value, isTrue);

      // Another customer with points: the card stays, the switch is off.
      await tester.runAsync(() async => retailCartStore.selectSaleCustomer(
            Customer(customerId: 'C3', name: 'Chetan', loyaltyPoints: 500,
                createdAt: now),
          ));
      await settle(tester);
      expect(retailCartStore.loyaltyRedemption, 0);
      expect(tester.widget<Switch>(loyaltySwitch()).value, isFalse);
    });
  });

  group('commit re-checks the saved balance', () {
    testWidgets('points spent elsewhere since: paid sale refused, points off',
        (tester) async {
      await boot(tester);
      await redeem(tester);
      // Another sale or an edit left Asha with 40 points; the picked copy
      // still says 150.
      await tester.runAsync(() => Hive.box<Customer>(HiveBoxNames.customer)
          .put('C1', asha(points: 40)));

      await completePayment(tester, rounds: 12);

      expect(sales(), isEmpty, reason: 'nothing written');
      expect(retailCartStore.loyaltyRedemption, 0);
      expect(retailCartStore.bill.grandTotal, 200);
      expect(savedCustomer('C1').loyaltyPoints, 40);
      expect(notified('Asha has 40 points, but 150 were applied.'), isTrue);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('customer detached outside the picker: refused, points off',
        (tester) async {
      await boot(tester);
      await redeem(tester);
      // e.g. the customer was deleted, which clears the selection directly.
      await tester.runAsync(() async => customerStore.selectCustomer(null));
      await settle(tester);

      await completePayment(tester, rounds: 12);

      expect(sales(), isEmpty);
      expect(retailCartStore.loyaltyRedemption, 0);
      expect(notified('Loyalty points need a customer on the bill.'), isTrue);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Pay Later is checked the same way', (tester) async {
      await boot(tester, first: asha(limit: 1000));
      await redeem(tester);
      await tester.runAsync(() => Hive.box<Customer>(HiveBoxNames.customer)
          .put('C1', asha(points: 10, limit: 1000)));

      final payLater = find.text('Pay Later');
      await tester.ensureVisible(payLater);
      await tester.tap(payLater);
      await settle(tester, rounds: 12);

      expect(find.text('Confirm Pay Later'), findsNothing,
          reason: 'refused before the confirmation');
      expect(sales(), isEmpty);
      expect(retailCartStore.loyaltyRedemption, 0);
      expect(savedCustomer('C1').creditBalance, 0);
      expect(savedCustomer('C1').loyaltyPoints, 10);
      expect(notified('Asha has 10 points, but 150 were applied.'), isTrue);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('a valid redemption still goes through', (tester) async {
      await boot(tester);
      await redeem(tester);

      await completePayment(tester);

      final sale = sales().single;
      expect(sale.loyaltyPointsUsed, 150);
      expect(sale.grandTotal, 50);
      expect(savedCustomer('C1').loyaltyPoints,
          150 - 150 + LoyaltyPoints.earnedFor(50));
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
