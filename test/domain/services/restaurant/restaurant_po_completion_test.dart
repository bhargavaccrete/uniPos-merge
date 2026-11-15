import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_grn_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_grn_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_stock_take_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_stock_take_model.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_grn_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_purchase_order_repository.dart';
import 'package:billberrylite/domain/services/restaurant/purchasable_item_rule.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/restaurant_purchase_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/restaurant_stock_take_store.dart';

/// BLK-17: a Restaurant PO is completed only when EVERY line has been
/// received in full — a surplus on one line can no longer close the order
/// while another is short. BLK-18: items with variants are kept off purchase
/// orders (their stock is per variant; PO/GRN lines have none).
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('restaurant_po_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();
    await Hive.openBox<RestaurantPurchaseOrderModel>(
        HiveBoxNames.restaurantPurchaseOrders);
    await Hive.openBox<RestaurantPurchaseOrderItemModel>(
        HiveBoxNames.restaurantPurchaseOrderItems);
    await Hive.openBox<RestaurantGRNModel>(HiveBoxNames.restaurantGrns);
    await Hive.openBox<RestaurantGRNItemModel>(HiveBoxNames.restaurantGrnItems);
    await Hive.openBox<Items>(HiveBoxNames.restaurantItems);
    await Hive.openBox<Category>(HiveBoxNames.category);

    locator
      ..registerLazySingleton<RestaurantPurchaseOrderRepository>(
          () => RestaurantPurchaseOrderRepository())
      ..registerLazySingleton<RestaurantPurchaseOrderItemRepository>(
          () => RestaurantPurchaseOrderItemRepository())
      ..registerLazySingleton<RestaurantGRNRepository>(
          () => RestaurantGRNRepository())
      ..registerLazySingleton<RestaurantGRNItemRepository>(
          () => RestaurantGRNItemRepository())
      ..registerLazySingleton<ItemStore>(() => ItemStore(ItemRepository()));
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // ── seeding ────────────────────────────────────────────────────────────────

  /// A sent PO with one line per entry of [ordered]; returns line ids by key.
  Future<(RestaurantPurchaseOrderModel, Map<String, String>)> order(
      Map<String, double> ordered,
      {RestaurantPOStatus status = RestaurantPOStatus.sent}) async {
    final po = RestaurantPurchaseOrderModel.create(
      poId: 'PO-1',
      poNumber: 'PO-00001',
      supplierId: 'S1',
      supplierName: 'Dairy Co',
      expectedDeliveryDate: DateTime.now().toIso8601String(),
      totalItems: ordered.values.fold(0.0, (a, b) => a + b),
      estimatedTotal: 0,
      status: status,
    );
    await restaurantPurchaseOrderRepository.savePurchaseOrder(po);
    final lineIds = <String, String>{};
    for (final e in ordered.entries) {
      final line = RestaurantPurchaseOrderItemModel.create(
          poId: po.poId, itemId: e.key, itemName: e.key, orderedQty: e.value);
      await restaurantPurchaseOrderItemRepository.saveItem(line);
      lineIds[e.key] = line.poItemId;
    }
    return (po, lineIds);
  }

  var grnCount = 0;

  /// A goods receipt against the PO: [received] per line key, [damaged]
  /// included in it. [status] confirmed unless said otherwise.
  Future<void> receive(Map<String, String> lineIds, Map<String, double> received,
      {Map<String, double> damaged = const {},
      RestaurantGRNStatus status = RestaurantGRNStatus.confirmed}) async {
    grnCount++;
    final grn = RestaurantGRNModel.create(
      grnNumber: 'GRN-$grnCount',
      poId: 'PO-1',
      poNumber: 'PO-00001',
      supplierId: 'S1',
      supplierName: 'Dairy Co',
      receivedDate: DateTime.now().toIso8601String(),
      totalOrderedQty: 0,
      totalReceivedQty: received.values.fold(0.0, (a, b) => a + b),
      totalAmount: 0,
      status: status,
    );
    await restaurantGrnRepository.saveGRN(grn);
    for (final e in received.entries) {
      final bad = damaged[e.key] ?? 0;
      await restaurantGrnItemRepository.saveItem(RestaurantGRNItemModel.create(
        grnId: grn.grnId,
        poItemId: lineIds[e.key]!,
        itemId: e.key,
        orderedQty: 0,
        receivedQty: e.value,
        acceptedQty: e.value - bad,
        damagedQty: bad,
      ));
    }
  }

  RestaurantPOStatus status(RestaurantPurchaseOrderModel po) =>
      RestaurantPORules.statusAfterReceipt(po);

  // ==========================================================================
  group('BLK-17 — completion is decided per line', () {
    test('A 15 / B 5 against 10 / 10 stays partially received', () async {
      final (po, ids) = await order({'A': 10, 'B': 10});
      await receive(ids, {'A': 15, 'B': 5});
      expect(status(po), RestaurantPOStatus.partiallyReceived,
          reason: 'the totals match (20 of 20) but B is 5 short');
    });

    test('every line in full completes it', () async {
      final (po, ids) = await order({'A': 10, 'B': 10});
      await receive(ids, {'A': 10, 'B': 10});
      expect(status(po), RestaurantPOStatus.completed);
    });

    test('over-receipt on one line still needs the other line', () async {
      final (po, ids) = await order({'A': 10, 'B': 10});
      await receive(ids, {'A': 12, 'B': 9});
      expect(status(po), RestaurantPOStatus.partiallyReceived);
      await receive(ids, {'B': 1});
      expect(status(po), RestaurantPOStatus.completed,
          reason: 'over-receipt satisfies its own line');
    });

    test('decimal receipts that add up to the order complete it', () async {
      final (po, ids) = await order({'A': 10.5});
      for (var i = 0; i < 3; i++) {
        await receive(ids, {'A': 3.5});
      }
      expect(status(po), RestaurantPOStatus.completed,
          reason: '3.5 × 3 sums to 10.499999999999998 in floating point');
    });

    test('damaged units count as received (your decision)', () async {
      final (po, ids) = await order({'A': 10});
      await receive(ids, {'A': 10}, damaged: {'A': 10});
      expect(status(po), RestaurantPOStatus.completed);
    });

    test('a cancelled receipt does not count', () async {
      final (po, ids) = await order({'A': 10});
      await receive(ids, {'A': 10}, status: RestaurantGRNStatus.cancelled);
      expect(status(po), RestaurantPOStatus.sent);
      expect(restaurantGrnItemRepository.getTotalReceivedQtyForPOItem(ids['A']!),
          0);
    });

    test('lines without a saved receipt header do not count', () async {
      final (po, ids) = await order({'A': 10});
      // An interrupted confirm: the line saved, the header never.
      await restaurantGrnItemRepository.saveItem(RestaurantGRNItemModel.create(
          grnId: 'GRN-missing',
          poItemId: ids['A']!,
          itemId: 'A',
          orderedQty: 10,
          receivedQty: 10,
          acceptedQty: 10));
      expect(status(po), RestaurantPOStatus.sent);
    });

    test('nothing received leaves it as it was', () async {
      final (po, _) = await order({'A': 10});
      expect(status(po), RestaurantPOStatus.sent);
    });

    test('a cancelled order is never reopened', () async {
      final (po, ids) =
          await order({'A': 10}, status: RestaurantPOStatus.cancelled);
      await receive(ids, {'A': 10});
      expect(status(po), RestaurantPOStatus.cancelled);
    });

    test('an order with no lines never auto-completes', () async {
      final (po, _) = await order({});
      expect(status(po), RestaurantPOStatus.sent, reason: '0 >= 0 must not close it');
    });
  });

  // ==========================================================================
  group('BLK-18 — items with variants stay off purchase orders', () {
    Items trade(String id, {List<ItemVariante>? variants}) => Items(
          id: id,
          name: 'Item $id',
          productType: ProductType.tradeItem,
          trackInventory: true,
          variant: variants,
        );

    test('the PO picker rule drops an item with variants', () {
      expect(PurchasableItemRule.isPurchasable(trade('a'), hasRecipe: false),
          isTrue);
      expect(
          PurchasableItemRule.isPurchasable(
              trade('b', variants: [ItemVariante(variantId: 'v', price: 10)]),
              hasRecipe: false),
          isFalse);
    });

    test('creating or editing a PO with such an item is refused', () async {
      await Hive.box<Items>(HiveBoxNames.restaurantItems).putAll({
        'plain': trade('plain'),
        'coke': trade('coke', variants: [ItemVariante(variantId: 'v', price: 10)]),
      });
      await itemStore.loadItems();

      expect(
        () => RestaurantPORules.refuseVariantItems([
          (itemId: 'plain', itemName: 'Plain', qty: 1, price: null),
          (itemId: 'coke', itemName: 'Coke', qty: 1, price: null),
        ]),
        throwsA(isA<StateError>().having((e) => e.message, 'message',
            contains('Item coke has variants'))),
      );
      // A PO with no such item is unaffected.
      RestaurantPORules.refuseVariantItems([
        (itemId: 'plain', itemName: 'Plain', qty: 1, price: null),
      ]);
    });

    test('a stock take refuses to count such an item; others still count',
        () async {
      await Hive.openBox<RestaurantStockTakeModel>(
          HiveBoxNames.restaurantStockTakes);
      await Hive.openBox<RestaurantStockTakeItemModel>(
          HiveBoxNames.restaurantStockTakeItems);
      await Hive.openBox(HiveBoxNames.appCounters);

      final takes = RestaurantStockTakeStore();
      expect(await takes.startTake(), isNotNull);

      final coke =
          trade('coke', variants: [ItemVariante(variantId: 'v', price: 10)]);
      expect(await takes.countItem(item: coke, countedQty: 4), isFalse);
      expect(takes.errorMessage, contains('has variants'));
      expect(takes.currentItems, isEmpty, reason: 'no line written');

      expect(await takes.countItem(item: trade('plain'), countedQty: 4),
          isTrue);
      expect(takes.currentItems.single.itemId, 'plain');
    });
  });
}
