import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/restaurant/db/cartmodel_308.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/ordermodel_309.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/variantmodel_305.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/past_order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/stock_movement_repository.dart';
import 'package:billberrylite/domain/services/restaurant/place_new_order.dart';
import 'package:billberrylite/domain/services/restaurant/settle_new_order.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/order_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';

import '../../../helpers/test_helpers.dart';

/// An order store whose save fails the way the real one reports it.
class _RefusingOrderStore extends OrderStore {
  _RefusingOrderStore(super.repository);
  @override
  Future<bool> addOrder(OrderModel order) async => false;
}

/// A past-order store whose save fails the way the real one reports it.
class _RefusingPastOrderStore extends PastOrderStore {
  _RefusingPastOrderStore(super.repository);
  @override
  Future<bool> addOrder(PastOrderModel pastOrder) async => false;
}

/// SALE-3: Place Order and Quick Settle used to deduct stock (and then print
/// the KOT and report success) even when the order was never saved.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  Future<void> open({bool refuseActive = false, bool refusePast = false}) async {
    await Hive.openBox<Items>(HiveBoxNames.restaurantItems);
    await Hive.openBox<Category>(HiveBoxNames.category);
    await Hive.openBox<VariantModel>(HiveBoxNames.restaurantVariants);
    await Hive.openBox<RecipeModel>(HiveBoxNames.restaurantRecipes);
    await Hive.openBox<StockMovementModel>(HiveBoxNames.restaurantStockMovements);
    await Hive.openBox<AppNotificationModel>(HiveBoxNames.appNotifications);
    await Hive.openBox<OrderModel>(HiveBoxNames.restaurantOrders);
    await Hive.openBox<PastOrderModel>(HiveBoxNames.restaurantPastOrders);
    await Hive.openBox(HiveBoxNames.appCounters);
    await Hive.openBox(HiveBoxNames.dayManagementBox);
    locator
      ..registerLazySingleton<ItemStore>(() => ItemStore(ItemRepository()))
      ..registerLazySingleton<VariantStore>(() => VariantStore(VariantRepositoryRes()))
      ..registerLazySingleton<RecipeRepository>(() => RecipeRepository())
      ..registerLazySingleton<NotificationStore>(
          () => NotificationStore(NotificationRepository()))
      ..registerLazySingleton<PastOrderRepository>(() => PastOrderRepository())
      ..registerLazySingleton<PastOrderStore>(() => refusePast
          ? _RefusingPastOrderStore(locator<PastOrderRepository>())
          : PastOrderStore(locator<PastOrderRepository>()))
      ..registerLazySingleton<OrderRepository>(() => OrderRepository())
      ..registerLazySingleton<OrderStore>(() => refuseActive
          ? _RefusingOrderStore(locator<OrderRepository>())
          : OrderStore(locator<OrderRepository>()));
    await Hive.box<Items>(HiveBoxNames.restaurantItems).put('paneer', Items(
      id: 'paneer', name: 'Paneer Tikka', trackInventory: true,
      stockQuantity: 5, allowOrderWhenOutOfStock: false));
    await itemStore.loadItems();
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('place_new_order_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  List<CartItem> paneer(int qty) => [makeCartItem(id: 'l1', productId: 'paneer',
      title: 'Paneer Tikka', price: 100, quantity: qty)];
  double stock() => Hive.box<Items>(HiveBoxNames.restaurantItems).get('paneer')!.stockQuantity;
  int rows() => StockMovementRepository().movementsForItem('paneer').length;

  OrderModel order(List<CartItem> lines) => OrderModel(
        id: 'o1', customerName: '', customerNumber: '', customerEmail: '',
        items: lines, status: 'Processing', timeStamp: DateTime.now(),
        orderType: 'Take Away', totalPrice: 200, kotNumbers: [1],
        itemCountAtLastKot: lines.length, kotBoundaries: [lines.length]);

  group('Place Order (new)', () {
    test('saved → stock deducted with the stamped lines', () async {
      await open();
      final sale = await PlaceNewOrder.commit(
          items: paneer(2), build: (lines) async => order(lines));
      expect(sale.refused, isFalse);
      expect(stock(), 3);
      expect(Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).get('o1')!
          .items.single.hasStockStamp, isTrue);
    });

    test('save fails → throws, nothing deducted, no order', () async {
      await open(refuseActive: true);
      await expectLater(
          PlaceNewOrder.commit(items: paneer(2), build: (lines) async => order(lines)),
          throwsA(isA<OrderSaveFailedException>()));
      expect(stock(), 5);
      expect(rows(), 0);
      expect(Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).isEmpty, isTrue);
    });

    test('not enough stock → refused, nothing written', () async {
      await open();
      var built = false;
      final sale = await PlaceNewOrder.commit(items: paneer(9), build: (lines) async {
        built = true;
        return order(lines);
      });
      expect(sale.refused, isTrue);
      expect(built, isFalse);
      expect(stock(), 5);
    });
  });

  group('Quick Settle (SettleNewOrder)', () {
    Future<SettleNewOrderResult> quickSettle() => SettleNewOrder.commit(
          items: paneer(2),
          build: (lines, kot, bill) async => PastOrderModel(
            id: 'q1', customerName: 'Quick Settle', totalPrice: 200, items: lines,
            orderAt: DateTime.now(), orderType: 'Take Away', paymentmode: 'cash',
            subTotal: 200, gstRate: 0, gstAmount: 0, kotNumbers: [kot],
            kotBoundaries: [lines.length], billNumber: bill),
        );

    test('save fails → throws, nothing deducted', () async {
      await open(refusePast: true);
      await expectLater(quickSettle(), throwsA(isA<OrderSaveFailedException>()));
      expect(stock(), 5);
      expect(rows(), 0);
    });

    test('saved → deducted once', () async {
      await open();
      final r = await quickSettle();
      expect(r.refused, isFalse);
      expect(stock(), 3);
    });
  });
}
