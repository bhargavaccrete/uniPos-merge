import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/restaurant/db/cartmodel_308.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/variantmodel_305.dart';
import 'package:billberrylite/data/repositories/common/customer_repository.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/past_order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_repository.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/services/restaurant/refund_service.dart';
import 'package:billberrylite/domain/store/common/customer_store.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';

import '../../../helpers/test_helpers.dart';
import '../../../helpers/open_session_fixture.dart';
import '../../../helpers/sign_in_fixture.dart';

/// Refunds record HOW the money went back (cash, UPI, split across both) in
/// the existing refund-event JSON, checked before anything is written; and a
/// part-paid voided order can refund only what it collected.
void main() {
  setUpAll(() => signInForTest());
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('refund_legs_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();
    await Hive.openBox<Items>(HiveBoxNames.restaurantItems);
    await Hive.openBox<Category>(HiveBoxNames.category);
    await Hive.openBox<VariantModel>(HiveBoxNames.restaurantVariants);
    await Hive.openBox<RecipeModel>(HiveBoxNames.restaurantRecipes);
    await Hive.openBox<StockMovementModel>(HiveBoxNames.restaurantStockMovements);
    await Hive.openBox<AppNotificationModel>(HiveBoxNames.appNotifications);
    await Hive.openBox<PastOrderModel>(HiveBoxNames.restaurantPastOrders);
    await Hive.openBox<Customer>(HiveBoxNames.customer);
    await Hive.openBox(HiveBoxNames.dayManagementBox);
    await openRestaurantSessionForTest();
    locator
      ..registerLazySingleton<LicenseStore>(
          () => LicenseStore(LicenseApiService())..licenseBypassed = true)
      ..registerLazySingleton<ItemStore>(() => ItemStore(ItemRepository()))
      ..registerLazySingleton<VariantStore>(() => VariantStore(VariantRepositoryRes()))
      ..registerLazySingleton<RecipeRepository>(() => RecipeRepository())
      ..registerLazySingleton<NotificationStore>(
          () => NotificationStore(NotificationRepository()))
      ..registerLazySingleton<CustomerStore>(() => CustomerStore(CustomerRepository()))
      ..registerLazySingleton<PastOrderRepository>(() => PastOrderRepository())
      ..registerLazySingleton<PastOrderStore>(
          () => PastOrderStore(locator<PastOrderRepository>()));
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  PastOrderModel saved() =>
      Hive.box<PastOrderModel>(HiveBoxNames.restaurantPastOrders).get('o1')!;

  final soup = makeCartItem(id: 'l1', productId: 'soup', title: 'Soup', price: 100, quantity: 3);

  Future<PastOrderModel> order({
    double total = 300,
    String status = 'COMPLETED',
    double? totalPaid,
    String? paymentListJson,
    String paymentmode = 'Cash',
  }) async {
    final o = PastOrderModel(
      id: 'o1',
      customerName: '',
      totalPrice: total,
      items: [soup],
      orderAt: DateTime.now(),
      orderType: 'Dine In',
      paymentmode: paymentmode,
      orderStatus: status,
      totalPaid: totalPaid,
      paymentListJson: paymentListJson,
      kotNumbers: [1],
      kotBoundaries: [1],
    );
    await Hive.box<PastOrderModel>(HiveBoxNames.restaurantPastOrders).put(o.id, o);
    return o;
  }

  PartialRefundResult refund(int qty, double amount, {List<RefundLeg>? legs}) =>
      PartialRefundResult(
        itemsToRefund: {soup: qty},
        reason: 'test',
        totalRefundAmount: amount,
        itemsToRestock: const <CartItem, int>{},
        refundLegs: legs,
      );

  List<Map<String, dynamic>> storedEvents() =>
      List<Map<String, dynamic>>.from(jsonDecode(saved().refundEventsJson!) as List);

  test('a cash refund is saved with its method', () async {
    final o = await order();
    await RefundService.processRefund(
        order: o, refundResult: refund(1, 100, legs: [(method: 'Cash', amount: 100)]));
    expect(storedEvents().single['legs'], [{'method': 'Cash', 'amount': 100.0}]);
    expect(saved().refundAmount, 100);
  });

  test('a split refund saves each method and amount', () async {
    final o = await order();
    await RefundService.processRefund(
        order: o,
        refundResult: refund(1, 100,
            legs: [(method: 'Cash', amount: 60), (method: 'UPI', amount: 40)]));
    expect(storedEvents().single['legs'], [
      {'method': 'Cash', 'amount': 60.0},
      {'method': 'UPI', 'amount': 40.0},
    ]);
  });

  test('a refund without methods is saved exactly as before (no legs key)', () async {
    final o = await order();
    await RefundService.processRefund(order: o, refundResult: refund(1, 100));
    expect(storedEvents().single.containsKey('legs'), isFalse);
  });

  group('refused before anything is written', () {
    Future<void> refused(List<RefundLeg> legs) async {
      final o = await order();
      await expectLater(
        RefundService.processRefund(order: o, refundResult: refund(1, 100, legs: legs)),
        throwsA(isA<Exception>()),
      );
      expect(saved().refundAmount ?? 0, 0);
      expect(saved().refundEventsJson, isNull);
      expect(saved().items.single.refundedQuantity ?? 0, 0);
    }

    test('methods that do not add up to the refund', () =>
        refused([(method: 'Cash', amount: 60), (method: 'UPI', amount: 30)]));
    test('a method with no name', () => refused([(method: ' ', amount: 100)]));
    test('a method with a zero amount', () =>
        refused([(method: 'Cash', amount: 100), (method: 'UPI', amount: 0)]));
  });

  test('a refund trimmed by the cap takes the trim off the last method', () async {
    final o = await order(total: 299.995);
    await RefundService.processRefund(
        order: o,
        refundResult: refund(3, 300,
            legs: [(method: 'Cash', amount: 200), (method: 'UPI', amount: 100)]));
    final legs = storedEvents().single['legs'] as List;
    final total = legs.fold<double>(0, (s, l) => s + ((l as Map)['amount'] as num));
    expect(total, closeTo(saved().refundAmount!, 1e-9));
    expect((legs.first as Map)['amount'], 200);
  });

  group('part-paid voided orders', () {
    test('can refund only what was collected', () async {
      final o = await order(status: 'VOIDED', total: 500, totalPaid: 200);
      expect(RefundService.getRemainingRefundableAmount(o), 200);
      await expectLater(
        RefundService.processRefund(order: o, refundResult: refund(3, 300)),
        throwsA(isA<Exception>()),
        reason: 'never the whole bill of 500',
      );
      await RefundService.processRefund(
          order: o, refundResult: refund(2, 200, legs: [(method: 'Cash', amount: 200)]));
      expect(saved().refundAmount, 200);
      expect(RefundService.getRemainingRefundableAmount(saved()), 0);
    });

    test('with recorded payment legs, the legs are the limit', () async {
      final o = await order(
        status: 'VOIDED',
        total: 500,
        totalPaid: 150,
        paymentListJson: jsonEncode([{'method': 'upi', 'amount': 150}]),
      );
      expect(RefundService.getRemainingRefundableAmount(o), 150);
    });

    test('a normal order keeps its bill total as the limit', () async {
      final o = await order(total: 300, totalPaid: 100);
      expect(RefundService.getRemainingRefundableAmount(o), 300);
    });
  });
}
