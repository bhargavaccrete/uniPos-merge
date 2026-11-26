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
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/variantmodel_305.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_repository.dart';
import 'package:billberrylite/domain/services/restaurant/cart_calculation_service.dart';
import 'package:billberrylite/domain/services/restaurant/inventory_service.dart';
import 'package:billberrylite/domain/services/restaurant/kot_layout.dart';
import 'package:billberrylite/domain/services/restaurant/kot_status_rule.dart';
import 'package:billberrylite/domain/services/restaurant/order_line_cancel.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/variant_store.dart';

import '../../../helpers/test_helpers.dart';

/// Same fake as cart_calculation_service_test: TaxFeature reads this, tax on.
class _TaxOnBusinessDetails extends BusinessDetailsRepository {
  @override
  bool get isTaxEnabled => true;
}

/// Phase 0.1 Fix A (Takeaway cancel of cooked/served lines) and Fix B
/// (Active Orders single-item cancel: last KOT + totals), each followed by
/// the Active Orders void's real served/unserved split.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('order_line_cancel_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();
    await Hive.openBox<Items>(HiveBoxNames.restaurantItems);
    await Hive.openBox<Category>(HiveBoxNames.category);
    await Hive.openBox<VariantModel>(HiveBoxNames.restaurantVariants);
    await Hive.openBox<RecipeModel>(HiveBoxNames.restaurantRecipes);
    await Hive.openBox<StockMovementModel>(
        HiveBoxNames.restaurantStockMovements);
    await Hive.openBox<AppNotificationModel>(HiveBoxNames.appNotifications);
    await Hive.openBox(HiveBoxNames.dayManagementBox);

    locator
      ..registerLazySingleton<ItemStore>(() => ItemStore(ItemRepository()))
      ..registerLazySingleton<VariantStore>(
          () => VariantStore(VariantRepositoryRes()))
      ..registerLazySingleton<RecipeRepository>(() => RecipeRepository())
      ..registerLazySingleton<NotificationStore>(
          () => NotificationStore(NotificationRepository()))
      ..registerSingleton<BusinessDetailsRepository>(_TaxOnBusinessDetails());

    final box = Hive.box<Items>(HiveBoxNames.restaurantItems);
    for (final id in ['A', 'B', 'C']) {
      await box.put(id,
          Items(id: id, name: id, trackInventory: true, stockQuantity: 10));
    }
    await itemStore.loadItems();
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  double stock(String id) =>
      Hive.box<Items>(HiveBoxNames.restaurantItems).get(id)!.stockQuantity;

  CartItem l(String id, int qty, {double price = 100}) => makeCartItem(
      id: 'line-$id', productId: id, title: id, price: price,
      quantity: qty, taxRate: 0.05);

  /// KOT 1 = [A] (status [kot1]), KOT 2 = [B, C] (status [kot2]).
  OrderModel twoKots({String kot1 = 'Cooking', String kot2 = 'Served',
          int aQty = 1}) =>
      OrderModel(
        id: 'o1',
        customerName: '',
        customerNumber: '',
        customerEmail: '',
        items: [l('A', aQty), l('B', 1), l('C', 1)],
        status: 'Cooking',
        timeStamp: DateTime(2026, 10, 22, 12),
        orderType: 'Dine In',
        totalPrice: 315,
        subTotal: 300,
        gstAmount: 15,
        isTaxInclusive: false,
        kotNumbers: [1, 2],
        itemCountAtLastKot: 3,
        kotBoundaries: [1, 3],
        kotStatuses: {1: kot1, 2: kot2},
      );

  Map<String, int> unserved(OrderModel o) => {
        for (final e in KotLayout.unservedQuantities(
          items: o.items,
          kotNumbers: o.kotNumbers,
          kotBoundaries: o.kotBoundaries,
          kotStatuses: o.kotStatuses ?? {},
          orderStatus: o.status,
        ).entries)
          e.key.id: e.value,
      };

  group('Fix A — Takeaway cancel uses the SAVED KOT status', () {
    for (final status in ['Served', 'Ready', 'Cooked', 'Completed', 'served']) {
      test('a line in a "$status" KOT counts as cooked', () {
        expect(OrderLineCancel.isCooked(twoKots(kot2: status), 'line-B'),
            isTrue);
      });
    }

    test('a line in a Cooking / Processing KOT is cancellable', () {
      expect(OrderLineCancel.isCooked(twoKots(kot1: 'Cooking'), 'line-A'),
          isFalse);
      expect(OrderLineCancel.isCooked(twoKots(kot1: 'Processing'), 'line-A'),
          isFalse);
    });

    test('a KOT with no own status falls back to the order status', () {
      final o = twoKots().copyWith(kotStatuses: {}, status: 'Served');
      expect(OrderLineCancel.isCooked(o, 'line-A'), isTrue);
    });

    test('unknown line is not treated as cooked', () {
      expect(OrderLineCancel.isCooked(twoKots(), 'line-Z'), isFalse);
    });

    test('partial cancel of an unserved line restores exactly the cancelled '
        'quantity, and a later void restores only the remainder', () async {
      final saved = twoKots(aQty: 3);
      expect(OrderLineCancel.isCooked(saved, 'line-A'), isFalse);

      // What _cancelItemImmediately commits: layout, then one restore.
      final layout = KotLayout.removeQuantity(
          items: saved.items, kotNumbers: saved.kotNumbers,
          kotBoundaries: saved.kotBoundaries,
          kotStatuses: saved.kotStatuses!, lineId: 'line-A', qty: 1);
      await InventoryService.restoreStockForOrder(
          [saved.items.first.copyWith(quantity: 1)]);
      expect(stock('A'), 11);

      final after = saved.copyWith(
          items: layout.items, kotNumbers: layout.kotNumbers,
          kotBoundaries: layout.kotBoundaries,
          kotStatuses: layout.kotStatuses);
      expect(unserved(after), {'line-A': 2},
          reason: 'void restores the 2 left, never the cancelled 1 or served B/C');
    });

    test('full cancel of an unserved line leaves nothing for the void to '
        'restore twice; served lines are never restored', () async {
      final saved = twoKots();
      final layout = KotLayout.removeQuantity(
          items: saved.items, kotNumbers: saved.kotNumbers,
          kotBoundaries: saved.kotBoundaries,
          kotStatuses: saved.kotStatuses!, lineId: 'line-A', qty: 1);
      await InventoryService.restoreStockForOrder([saved.items.first]);
      expect(stock('A'), 11);

      final after = saved.copyWith(
          items: layout.items, kotNumbers: layout.kotNumbers,
          kotBoundaries: layout.kotBoundaries,
          kotStatuses: layout.kotStatuses);
      expect(unserved(after), isEmpty);
    });
  });

  group('Phase 0.2 — one consumed rule for cancel and void', () {
    final table = {
      'Processing': false,
      'Cooking': false,
      'Ready': true,
      'Served': true,
      'Completed': true,
      'ready': true,
    };
    table.forEach((status, consumed) {
      test('"$status" consumed = $consumed', () {
        expect(KotStatusRule.isConsumed(status), consumed);
        // The commit-time cancel check and the void use the same answer.
        expect(OrderLineCancel.isCooked(twoKots(kot1: status), 'line-A'),
            consumed);
        expect(unserved(twoKots(kot1: status, kot2: 'Served'))
            .containsKey('line-A'), !consumed);
      });
    });

    test('stale screen: the KDS moved KOT 1 to Ready after the screen '
        'opened — the saved status refuses the cancel', () {
      final onScreen = twoKots(kot1: 'Cooking');
      final saved = twoKots(kot1: 'Ready');
      expect(OrderLineCancel.isCooked(onScreen, 'line-A'), isFalse);
      expect(OrderLineCancel.isCooked(saved, 'line-A'), isTrue);
    });

    test('void never restores a Ready KOT', () {
      expect(unserved(twoKots(kot1: 'Ready', kot2: 'Served')), isEmpty);
    });

    test('partial cancel across KOTs, then void: each unserved quantity is '
        'restored exactly once', () async {
      // KOT 1 [A×3] Cooking, KOT 2 [B, C] Cooking. Cancel 1 A, then all of C.
      var o = twoKots(kot1: 'Cooking', kot2: 'Cooking', aQty: 3);
      KotLayout cancel(OrderModel from, String id, int qty) =>
          KotLayout.removeQuantity(
              items: from.items, kotNumbers: from.kotNumbers,
              kotBoundaries: from.kotBoundaries,
              kotStatuses: from.kotStatuses!, lineId: id, qty: qty);
      OrderModel apply(OrderModel from, KotLayout lay) => from.copyWith(
          items: lay.items, kotNumbers: lay.kotNumbers,
          kotBoundaries: lay.kotBoundaries, kotStatuses: lay.kotStatuses);

      o = apply(o, cancel(o, 'line-A', 1));
      await InventoryService.restoreStockForOrder([l('A', 1)]);
      o = apply(o, cancel(o, 'line-C', 1));
      await InventoryService.restoreStockForOrder([l('C', 1)]);

      final voidRestock = KotLayout.unservedQuantities(
          items: o.items, kotNumbers: o.kotNumbers,
          kotBoundaries: o.kotBoundaries, kotStatuses: o.kotStatuses!,
          orderStatus: o.status);
      await InventoryService.restoreStockForRefund(voidRestock);

      // Sold A×3, B×1, C×1 from 10 each (deducted outside this test):
      // every unit comes back exactly once.
      expect([stock('A'), stock('B'), stock('C')], [13, 11, 11]);
    });
  });

  group('Fix B — Active Orders single-item cancel', () {
    test('cancelling the only line of the only KOT is refused', () {
      final only = OrderModel(
        id: 'o2',
        customerName: '',
        customerNumber: '',
        customerEmail: '',
        items: [l('A', 1)],
        status: 'Cooking',
        timeStamp: DateTime(2026, 10, 22, 12),
        orderType: 'Dine In',
        totalPrice: 105,
        kotNumbers: [1],
        itemCountAtLastKot: 1,
        kotBoundaries: [1],
        kotStatuses: {1: 'Cooking'},
      );

      expect(
        OrderLineCancel.forActiveOrders(only,
            itemIndexInOrder: 0),
        isNull,
        reason: 'an order needs at least one KOT; void it instead',
      );
    });

    test('cancelling the last line of one KOT among several drops that KOT',
        () {
      final r = OrderLineCancel.forActiveOrders(twoKots(),
          itemIndexInOrder: 0)!;
      expect(r.order.kotNumbers, [2]);
      expect(r.order.kotBoundaries, [2]);
      expect(r.order.kotStatuses, {2: 'Served'});
      expect(r.order.itemCountAtLastKot, 2);
      expect(r.cancelled.id, 'line-A');
    });

    test('totals and tax are recalculated by the cart calculation', () {
      final r = OrderLineCancel.forActiveOrders(twoKots(),
          itemIndexInOrder: 1)!;

      final expected = CartCalculationService(
        items: [l('A', 1), l('C', 1)],
        discountType: DiscountType.amount,
        discountValue: 0,
        isTaxInclusive: false,
      );
      expect(r.order.totalPrice, closeTo(expected.grandTotal, 1e-9));
      expect(r.order.gstAmount, closeTo(expected.totalGST, 1e-9));
      expect(r.order.subTotal, closeTo(expected.subtotal, 1e-9));
      expect(r.order.gstAmount, isNot(15), reason: 'tax must not stay stale');
    });

    test('a cancel in a served KOT order: the void restores only the '
        'unserved lines, once', () async {
      // KOT 1 [A] cooking, KOT 2 [B, C] served. Cancel A (unserved).
      final r = OrderLineCancel.forActiveOrders(twoKots(),
          itemIndexInOrder: 0)!;
      await InventoryService.restoreStockForOrder([r.cancelled]);
      expect(stock('A'), 11);

      expect(unserved(r.order), isEmpty,
          reason: 'A already restored by its cancel; B, C served');
    });

    test('cancel in the first KOT shifts the second KOT so the void split '
        'stays correct', () {
      // KOT 1 [A, X] cooking, KOT 2 [B] served → cancel A.
      final o = OrderModel(
        id: 'o3',
        customerName: '',
        customerNumber: '',
        customerEmail: '',
        items: [l('A', 1), l('C', 2), l('B', 1)],
        status: 'Cooking',
        timeStamp: DateTime(2026, 10, 22, 12),
        orderType: 'Dine In',
        totalPrice: 420,
        kotNumbers: [1, 2],
        itemCountAtLastKot: 3,
        kotBoundaries: [2, 3],
        kotStatuses: {1: 'Cooking', 2: 'Served'},
      );
      final r = OrderLineCancel.forActiveOrders(o,
          itemIndexInOrder: 0)!;
      expect(r.order.kotBoundaries, [1, 2]);
      expect(unserved(r.order), {'line-C': 2});
    });
  });
}
