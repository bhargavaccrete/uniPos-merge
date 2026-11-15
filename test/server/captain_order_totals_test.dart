import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shelf/shelf.dart';

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
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/past_order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_repository.dart';
import 'package:billberrylite/domain/services/restaurant/saved_service_charge.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/order_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';
import 'package:billberrylite/server/handlers/captain_handler.dart';
import 'package:billberrylite/util/restaurant/staticswitch.dart';

import '../helpers/open_session_fixture.dart';
import '../helpers/test_helpers.dart';

class _TaxBusiness extends BusinessDetailsRepository {
  @override
  bool get isTaxEnabled => true;
}

/// Batch 3.2 (P1 + P2) — the POS prices every Captain order itself.
///
/// P1: adding items re-prices the order in the SAME save as the new lines,
/// with the POS's own rules for an existing order (saved discount, service
/// charge at its saved %, stored tax mode) and re-derives the payment flags —
/// a fully paid order becomes payable for exactly what was added.
/// P2: a new Captain order is priced like the POS's own new order (current
/// tax mode, GST included), whatever `totalPrice` the request carries.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Map<String, bool> settingsBefore;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('captain_totals_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();
    await Hive.openBox<Items>(HiveBoxNames.restaurantItems);
    await Hive.openBox<Category>(HiveBoxNames.category);
    await Hive.openBox<VariantModel>(HiveBoxNames.restaurantVariants);
    await Hive.openBox<RecipeModel>(HiveBoxNames.restaurantRecipes);
    await Hive.openBox<StockMovementModel>(
        HiveBoxNames.restaurantStockMovements);
    await Hive.openBox<AppNotificationModel>(HiveBoxNames.appNotifications);
    await Hive.openBox<OrderModel>(HiveBoxNames.restaurantOrders);
    await Hive.openBox<PastOrderModel>(HiveBoxNames.restaurantPastOrders);
    await Hive.openBox(HiveBoxNames.appCounters);
    await Hive.openBox(HiveBoxNames.dayManagementBox);
    await Hive.openBox(HiveBoxNames.restaurantStockJournal);
    await openRestaurantSessionForTest();

    locator
      ..registerLazySingleton<ItemStore>(() => ItemStore(ItemRepository()))
      ..registerLazySingleton<VariantStore>(
          () => VariantStore(VariantRepositoryRes()))
      ..registerLazySingleton<RecipeRepository>(() => RecipeRepository())
      ..registerLazySingleton<NotificationStore>(
          () => NotificationStore(NotificationRepository()))
      ..registerLazySingleton<PastOrderRepository>(() => PastOrderRepository())
      ..registerLazySingleton<PastOrderStore>(
          () => PastOrderStore(locator<PastOrderRepository>()))
      ..registerLazySingleton<OrderRepository>(() => OrderRepository())
      ..registerLazySingleton<OrderStore>(
          () => OrderStore(locator<OrderRepository>()))
      ..registerSingleton<BusinessDetailsRepository>(_TaxBusiness());

    await Hive.box<Items>(HiveBoxNames.restaurantItems).put(
        'dish',
        Items(id: 'dish', name: 'Dish', trackInventory: true,
            stockQuantity: 100));
    await itemStore.loadItems();
    settingsBefore = Map.of(AppSettings.values);
    AppSettings.settingsNotifier.value = {
      ...settingsBefore,
      'Tax Is Inclusive': false,
      'Discount On Items': false,
      'Round Off': false,
    };
  });

  tearDown(() async {
    AppSettings.settingsNotifier.value = settingsBefore;
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  var seq = 0;
  CartItem dish(double price, int qty, {double? taxRate, String? id}) =>
      makeCartItem(
          id: id ?? 'l${seq++}', productId: 'dish', title: 'Dish', price: price,
          quantity: qty, taxRate: taxRate);

  Future<void> persist(OrderModel o) async {
    await Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).put(o.id, o);
    await orderStore.loadOrders();
  }

  OrderModel existing({
    required List<CartItem> lines,
    required double totalPrice,
    double? totalPaid,
    String? paymentListJson,
    bool? isPaid,
    String? paymentStatus,
    double? discount,
    double? serviceCharge,
    bool inclusive = false,
  }) =>
      OrderModel(
        id: 'o1',
        customerName: '',
        customerNumber: '',
        customerEmail: '',
        items: lines,
        status: 'Cooking',
        timeStamp: DateTime(2026, 11, 11, 12),
        orderType: 'Take Away',
        tableNo: '',
        totalPrice: totalPrice,
        kotNumbers: [1],
        itemCountAtLastKot: lines.length,
        kotBoundaries: [lines.length],
        kotStatuses: {1: 'Cooking'},
        totalPaid: totalPaid,
        paymentListJson: paymentListJson,
        isPaid: isPaid,
        paymentStatus: paymentStatus,
        discount: discount,
        serviceCharge: serviceCharge,
        isTaxInclusive: inclusive,
      );

  Future<(int, Map<String, dynamic>)> send(List<CartItem> lines,
      {String? orderId, double clientTotal = 0}) async {
    final response = await captainSendOrderHandler(Request(
      'POST',
      Uri.parse('http://localhost/captain/send-order'),
      body: jsonEncode({
        'items': lines.map((l) => l.toMap()).toList(),
        'orderType': 'Take Away',
        'orderId': ?orderId,
        'totalPrice': clientTotal,
        'requestId': 'totals-${DateTime.now().microsecondsSinceEpoch}-${seq++}',
      }),
    ));
    return (
      response.statusCode,
      jsonDecode(await response.readAsString()) as Map<String, dynamic>,
    );
  }

  OrderModel saved([String id = 'o1']) =>
      Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).get(id)!;

  // ==========================================================================
  group('P1 — adding items re-prices the order in the same save', () {
    const legs = '[{"method":"cash","amount":200.0}]';

    test('a fully paid order becomes payable for exactly what was added',
        () async {
      await persist(existing(
        lines: [dish(100, 2)],
        totalPrice: 200,
        totalPaid: 200,
        paymentListJson: legs,
        isPaid: true,
        paymentStatus: 'Paid',
      ));
      expect(saved().isFullyPaid, isTrue);

      final (status, _) = await send([dish(100, 1)], orderId: 'o1');
      expect(status, 200);

      final o = saved();
      expect(o.items, hasLength(2));
      expect(o.totalPrice, closeTo(300, 1e-9));
      expect(o.isFullyPaid, isFalse);
      expect(o.amountDue, closeTo(100, 1e-9));
      expect(o.isPaid, isFalse, reason: 'End of Day reads the flag');
      expect(o.paymentStatus, 'Partially Paid');
      expect(o.totalPaid, 200, reason: 'payments untouched');
      expect(o.paymentListJson, legs);
      expect(orderStore.getOrderById('o1')!.isFullyPaid, isFalse,
          reason: 'the POS screens see it too');
    });

    test('a part-paid order shows the right balance', () async {
      await persist(existing(
        lines: [dish(100, 2)],
        totalPrice: 200,
        totalPaid: 50,
        paymentStatus: 'Partially Paid',
      ));
      await send([dish(100, 1)], orderId: 'o1');
      final o = saved();
      expect(o.totalPrice, closeTo(300, 1e-9));
      expect(o.amountDue, closeTo(250, 1e-9));
      expect(o.paymentStatus, 'Partially Paid');
    });

    test('an unpaid order: total includes the added GST, still unpaid',
        () async {
      await persist(existing(lines: [dish(100, 2, taxRate: 0.05)],
          totalPrice: 210));
      await send([dish(100, 1, taxRate: 0.05)], orderId: 'o1');
      final o = saved();
      expect(o.totalPrice, closeTo(315, 1e-9));
      expect(o.subTotal, closeTo(300, 1e-9));
      expect(o.gstAmount, closeTo(15, 1e-9));
      expect(o.isPaid, isFalse);
      expect(o.paymentStatus, 'Unpaid');
    });

    test('saved discount and service-charge rate are kept', () async {
      // 200 − 20 discount = 180, service charge 10% = 18 → 198.
      await persist(existing(lines: [dish(100, 2)], totalPrice: 198,
          discount: 20, serviceCharge: 18));
      expect(SavedServiceCharge.ratePercentOf(saved(), isDelivery: false),
          closeTo(10, 1e-9));

      await send([dish(100, 1)], orderId: 'o1');
      final o = saved();
      // 300 − 20 = 280, 10% = 28 → 308.
      expect(o.discount, 20);
      expect(o.serviceCharge, closeTo(28, 1e-9));
      expect(o.totalPrice, closeTo(308, 1e-9));
      expect(SavedServiceCharge.ratePercentOf(o, isDelivery: false),
          closeTo(10, 1e-9));
    });

    test('the stored tax mode of the order is used, not the current one',
        () async {
      AppSettings.settingsNotifier.value = {
        ...AppSettings.values,
        'Tax Is Inclusive': false,
      };
      await persist(existing(lines: [dish(105, 1, taxRate: 0.05)],
          totalPrice: 105, inclusive: true));
      await send([dish(105, 1, taxRate: 0.05)], orderId: 'o1');
      final o = saved();
      expect(o.totalPrice, closeTo(210, 1e-9));
      expect(o.subTotal, closeTo(200, 1e-9));
      expect(o.gstAmount, closeTo(10, 1e-9));
    });

    test('the request\'s totalPrice is ignored', () async {
      await persist(existing(lines: [dish(100, 2)], totalPrice: 200));
      await send([dish(100, 1)], orderId: 'o1', clientTotal: 99999);
      expect(saved().totalPrice, closeTo(300, 1e-9));
    });
  });

  // ==========================================================================
  group('P2 — a new Captain order is priced by the POS', () {
    test('tax exclusive: stored total includes the GST', () async {
      final (status, body) =
          await send([dish(100, 2, taxRate: 0.05)], clientTotal: 200);
      expect(status, 200);
      final o = saved(body['orderId'] as String);
      expect(o.totalPrice, closeTo(210, 1e-9));
      expect(o.subTotal, closeTo(200, 1e-9));
      expect(o.gstAmount, closeTo(10, 1e-9));
      expect(o.isTaxInclusive, isFalse);
      expect(o.isFullyPaid, isFalse);
    });

    test('tax inclusive: GST taken out of the price, mode stored', () async {
      AppSettings.settingsNotifier.value = {
        ...AppSettings.values,
        'Tax Is Inclusive': true,
      };
      final (_, body) = await send([dish(105, 2, taxRate: 0.05)]);
      final o = saved(body['orderId'] as String);
      expect(o.totalPrice, closeTo(210, 1e-9));
      expect(o.subTotal, closeTo(200, 1e-9));
      expect(o.gstAmount, closeTo(10, 1e-9));
      expect(o.isTaxInclusive, isTrue);
    });

    test('the request\'s totalPrice is ignored (0 would read as fully paid)',
        () async {
      final (_, body) = await send([dish(100, 1)], clientTotal: 0);
      final o = saved(body['orderId'] as String);
      expect(o.totalPrice, closeTo(100, 1e-9));
      expect(o.isFullyPaid, isFalse);

      final (_, body2) = await send([dish(100, 1)], clientTotal: 5000);
      expect(saved(body2['orderId'] as String).totalPrice, closeTo(100, 1e-9));
    });

    test('matches the POS\'s own new-order pricing for the same lines',
        () async {
      final lines = [dish(120, 1, taxRate: 0.18), dish(80, 3, taxRate: 0.05)];
      final (_, body) = await send(lines);
      final o = saved(body['orderId'] as String);
      // takeaway.dart: CartCalculationService, no discount, current mode.
      // 120 + 21.60 GST, 240 + 12 GST.
      expect(o.subTotal, closeTo(360, 1e-9));
      expect(o.gstAmount, closeTo(33.6, 1e-9));
      expect(o.totalPrice, closeTo(393.6, 1e-9));
    });
  });
}
