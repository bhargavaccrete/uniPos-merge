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
import 'package:billberrylite/core/routes/routes_name.dart';
import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/models/common/business_details.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/restaurant/db/cartmodel_308.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/ordermodel_309.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/table_Model_311.dart';
import 'package:billberrylite/data/models/restaurant/db/variantmodel_305.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/data/repositories/common/customer_repository.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/payment_method_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/cart_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/past_order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/table_repository.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/domain/store/common/customer_store.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/restaurant/order_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/table_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';
import 'package:billberrylite/models/payment_method.dart';
import 'package:billberrylite/presentation/screens/restaurant/start%20order/cart/cart.dart';
import 'package:billberrylite/presentation/screens/restaurant/start%20order/cart/takeaway.dart';
import 'package:billberrylite/stores/payment_method_store.dart';

import '../../../helpers/open_session_fixture.dart';
import '../../../helpers/test_helpers.dart';

class _NoTaxBusiness extends BusinessDetailsRepository {
  @override
  bool get isTaxEnabled => false;
}

/// SALE-5, screen side: Takeaway's Place Order had no in-progress guard, so a
/// second tap while the first was still checking the day and the bill cap
/// placed a second order and a second KOT.
void main() {
  late Directory tempDir;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('takeaway_tap_');
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

  final lines = [
    makeCartItem(id: 'l1', productId: 'paneer', title: 'Paneer Tikka', price: 100,
        quantity: 2),
  ];

  Future<void> boot(WidgetTester tester) async {
    await tester.runAsync(() async {
      Hive.init(tempDir.path);
      await HiveInit.registerRestaurantAdapters();
      await AppConfig.init();
      await AppConfig.box.put('businessMode', 'restaurant');
      await Hive.openBox<Items>(HiveBoxNames.restaurantItems);
      await Hive.openBox<Category>(HiveBoxNames.category);
      await Hive.openBox<CartItem>(HiveBoxNames.restaurantCart);
      await Hive.openBox<VariantModel>(HiveBoxNames.restaurantVariants);
      await Hive.openBox<RecipeModel>(HiveBoxNames.restaurantRecipes);
      await Hive.openBox<StockMovementModel>(HiveBoxNames.restaurantStockMovements);
      await Hive.openBox<AppNotificationModel>(HiveBoxNames.appNotifications);
      await Hive.openBox<OrderModel>(HiveBoxNames.restaurantOrders);
      await Hive.openBox<PastOrderModel>(HiveBoxNames.restaurantPastOrders);
      await Hive.openBox<TableModel>(HiveBoxNames.restaurantTables);
      await Hive.openBox<Customer>(HiveBoxNames.customer);
      await Hive.openBox<BusinessDetails>(HiveBoxNames.businessDetailsBox);
      await Hive.openBox<PaymentMethod>('paymentMethodsBox');
      await Hive.openBox(HiveBoxNames.appCounters);
      await Hive.openBox(HiveBoxNames.dayManagementBox);
      await openRestaurantSessionForTest();
      // Hive's first write to a box from inside the fake clock never settles
      // (see menu_cart_reactivity_test): warm every box Place Order writes.
      Future<void> warm<T>(String name, T value) async {
        final b = Hive.box<T>(name);
        await b.put('__warmup__', value);
        await b.delete('__warmup__');
      }
      final dummy = makeCartItem(id: 'w', title: 'w', price: 1, quantity: 1);
      await warm<CartItem>(HiveBoxNames.restaurantCart, dummy);
      await warm<OrderModel>(HiveBoxNames.restaurantOrders, OrderModel(
          id: 'w', customerName: '', customerNumber: '', customerEmail: '',
          items: [dummy], status: 'Processing', timeStamp: DateTime(2026),
          orderType: 'Take Away', totalPrice: 1, kotNumbers: [1],
          itemCountAtLastKot: 1, kotBoundaries: [1]));
      await warm<StockMovementModel>(HiveBoxNames.restaurantStockMovements,
          StockMovementModel(id: 'w', timestamp: DateTime(2026), itemId: 'w',
              itemName: 'w', type: 'out', quantity: 1, balanceAfter: 0,
              reason: 'w', unit: 'pcs', staffName: 'w'));
      await warm<dynamic>(HiveBoxNames.appCounters, 0);
      await warm<dynamic>(HiveBoxNames.dayManagementBox, 0);
      await Hive.box<Items>(HiveBoxNames.restaurantItems).put('paneer', Items(
        id: 'paneer', name: 'Paneer Tikka', trackInventory: true,
        stockQuantity: 5, allowOrderWhenOutOfStock: false));

      locator
        ..registerLazySingleton<ItemStore>(() => ItemStore(ItemRepository()))
        ..registerLazySingleton<VariantStore>(() => VariantStore(VariantRepositoryRes()))
        ..registerLazySingleton<RecipeRepository>(() => RecipeRepository())
        ..registerLazySingleton<NotificationStore>(
            () => NotificationStore(NotificationRepository()))
        ..registerLazySingleton<PastOrderRepository>(() => PastOrderRepository())
        ..registerLazySingleton<PastOrderStore>(
            () => PastOrderStore(locator<PastOrderRepository>()))
        ..registerLazySingleton<OrderRepository>(() => OrderRepository())
        ..registerLazySingleton<OrderStore>(() => OrderStore(locator<OrderRepository>()))
        ..registerLazySingleton<TableStore>(() => TableStore(TableRepository()))
        ..registerLazySingleton<CustomerStore>(() => CustomerStore(CustomerRepository()))
        ..registerLazySingleton<CartStoreRes>(() => CartStoreRes(CartRepository()))
        ..registerLazySingleton<BusinessDetailsRepository>(() => _NoTaxBusiness())
        ..registerLazySingleton<LicenseStore>(
            () => LicenseStore(LicenseApiService())..licenseBypassed = true)
        ..registerLazySingleton<PaymentMethodRepository>(() => PaymentMethodRepository())
        ..registerLazySingleton<PaymentMethodStore>(
            () => PaymentMethodStore(locator<PaymentMethodRepository>()));
      await itemStore.loadItems();
    });

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 1366);
    addTearDown(tester.view.reset);

    // Hosted as the Start Order route, which is where a placed order returns
    // to (`returnToStartOrder`), so the success path stays on this screen.
    await tester.pumpWidget(MaterialApp(
      home: const Scaffold(body: SizedBox()),
      initialRoute: RouteNames.restaurantStartOrder,
      routes: {
        RouteNames.restaurantStartOrder: (_) => Scaffold(
              body: Takeaway(
                isexisting: false,
                isdelivery: false,
                isDineIn: false,
                cartItems: [for (final l in lines) CartItemStatus(l, true)],
                onAddtoCart: (_) {},
                onIncreseQty: (_) {},
                onDecreseQty: (_) {},
              ),
            ),
      },
    ));
    await settle(tester);
  }

  testWidgets('two quick taps on Place Order: one order', (tester) async {
    await boot(tester);
    // Open the Place Order dialog.
    final open = find.text('Place Order').first;
    await tester.ensureVisible(open);
    await tester.tap(open);
    await settle(tester);

    // The dialog's own Place Order button (after its title).
    final confirm = find.text('Place Order').last;
    await tester.tap(confirm);
    await tester.tap(confirm, warnIfMissed: false);
    await settle(tester, rounds: 60);

    expect(Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).length, 1,
        reason: 'one order, one KOT');
    expect(Hive.box<Items>(HiveBoxNames.restaurantItems).get('paneer')!.stockQuantity, 3,
        reason: 'stock deducted once');
    await tester.pump(const Duration(seconds: 3));
  });

}
