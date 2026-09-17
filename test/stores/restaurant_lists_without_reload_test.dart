import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_grn_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_grn_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_inventory_loss_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_stock_take_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_stock_take_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_ledger_entry_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_grn_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_purchase_order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_supplier_ledger_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_supplier_repository.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/restaurant/restaurant_purchase_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/restaurant_stock_take_store.dart';
import 'package:billberrylite/domain/store/restaurant/restaurant_supplier_store.dart';

/// Screens used to reload these lists after returning from a child screen.
/// Those reloads were removed because each write already updates the store's
/// observable list. Every test compares the live store with a freshly loaded
/// instance, so a write that stops updating the list shows up here.
void main() {
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('restaurant_lists_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();

    await Hive.openBox<Items>(HiveBoxNames.restaurantItems);
    await Hive.openBox<Category>(HiveBoxNames.category);
    await Hive.openBox<StockMovementModel>(
        HiveBoxNames.restaurantStockMovements);
    await Hive.openBox<RestaurantInventoryLossModel>(
        HiveBoxNames.restaurantInventoryLosses);
    await Hive.openBox<RestaurantStockTakeModel>(
        HiveBoxNames.restaurantStockTakes);
    await Hive.openBox<RestaurantStockTakeItemModel>(
        HiveBoxNames.restaurantStockTakeItems);
    await Hive.openBox<RestaurantSupplierModel>(
        HiveBoxNames.restaurantSuppliers);
    await Hive.openBox<RestaurantSupplierLedgerEntryModel>(
        HiveBoxNames.restaurantSupplierLedger);
    await Hive.openBox<RestaurantPurchaseOrderModel>(
        HiveBoxNames.restaurantPurchaseOrders);
    await Hive.openBox<RestaurantPurchaseOrderItemModel>(
        HiveBoxNames.restaurantPurchaseOrderItems);
    await Hive.openBox<RestaurantGRNModel>(HiveBoxNames.restaurantGrns);
    await Hive.openBox<RestaurantGRNItemModel>(HiveBoxNames.restaurantGrnItems);
    await Hive.openBox(HiveBoxNames.dayManagementBox);
    await Hive.openBox(HiveBoxNames.appCounters);

    locator
      ..registerLazySingleton<LicenseStore>(
          () => LicenseStore(LicenseApiService())..licenseBypassed = true)
      ..registerLazySingleton<ItemStore>(() => ItemStore(ItemRepository()))
      ..registerLazySingleton<RestaurantSupplierRepository>(
          () => RestaurantSupplierRepository())
      ..registerLazySingleton<RestaurantSupplierLedgerRepository>(
          () => RestaurantSupplierLedgerRepository())
      ..registerLazySingleton<RestaurantSupplierStore>(
          () => RestaurantSupplierStore())
      ..registerLazySingleton<RestaurantPurchaseOrderRepository>(
          () => RestaurantPurchaseOrderRepository())
      ..registerLazySingleton<RestaurantPurchaseOrderItemRepository>(
          () => RestaurantPurchaseOrderItemRepository())
      ..registerLazySingleton<RestaurantGRNRepository>(
          () => RestaurantGRNRepository())
      ..registerLazySingleton<RestaurantGRNItemRepository>(
          () => RestaurantGRNItemRepository());
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // purchase_order_list_screen: no reload after returning from receiving.
  group('RestaurantPurchaseOrderStore.confirmGRN', () {
    test('leaves PO status and GRNs current without a screen reload',
        () async {
      await Hive.box<RestaurantPurchaseOrderModel>(
              HiveBoxNames.restaurantPurchaseOrders)
          .put(
        'po-1',
        RestaurantPurchaseOrderModel.create(
          poId: 'po-1',
          poNumber: 'PO-1',
          supplierId: 'sup-x',
          expectedDeliveryDate: '2026-09-20',
          totalItems: 10,
          status: RestaurantPOStatus.sent,
        ),
      );
      await Hive.box<Items>(HiveBoxNames.restaurantItems).put(
          'rice',
          Items(id: 'rice', name: 'Rice', trackInventory: true,
              stockQuantity: 0));
      await itemStore.loadItems();
      final store = RestaurantPurchaseOrderStore();

      await store.confirmGRN(
        poId: 'po-1',
        poNumber: 'PO-1',
        supplierId: 'sup-x',
        receivedDate: '2026-09-17',
        lines: [
          (
            poItemId: 'poi-1',
            itemId: 'rice',
            itemName: 'Rice',
            orderedQty: 10,
            receivedQty: 4,
            acceptedQty: 4,
            damagedQty: null,
            costPrice: null,
            damagedHandling: null,
          ),
        ],
      );

      expect(store.purchaseOrders.single.statusEnum,
          RestaurantPOStatus.partiallyReceived);
      expect(store.grns, hasLength(1));
      final fresh = RestaurantPurchaseOrderStore();
      expect(store.purchaseOrders.map((p) => (p.poId, p.status)),
          fresh.purchaseOrders.map((p) => (p.poId, p.status)));
      expect(store.grns.map((g) => g.grnId), fresh.grns.map((g) => g.grnId));
    });
  });

  // restaurant_supplier_list_screen: no reload after returning from detail.
  group('RestaurantSupplierStore writes from the detail screen', () {
    Future<List<(String, String, double)>> freshRows() async {
      final fresh = RestaurantSupplierStore();
      await fresh.loadSuppliers();
      return [
        for (final s in fresh.suppliers) (s.supplierId, s.name, s.currentBalance)
      ];
    }

    List<(String, String, double)> rows(RestaurantSupplierStore s) => [
          for (final x in s.suppliers) (x.supplierId, x.name, x.currentBalance)
        ];

    test('edit, payment and delete each leave the list current', () async {
      final store = restaurantSupplierStore;
      await store.loadSuppliers();
      final a = await store.addSupplier(name: 'Alpha', openingBalance: 500);
      await store.addSupplier(name: 'Beta');
      var notified = 0;
      final dispose = reaction((_) => rows(store), (_) => notified++);
      addTearDown(dispose.call);

      await store.updateSupplier(a, name: 'Alpha Foods');
      expect(rows(store), await freshRows());
      expect(rows(store).first.$2, 'Alpha Foods');

      await store.recordBalanceMovement(
        supplierId: a.supplierId,
        amount: -200,
        type: RestaurantSupplierLedgerType.payment,
        description: 'Payment',
      );
      expect(rows(store), await freshRows());
      expect(rows(store).first.$3, 300);

      await store.deleteSupplier(a.supplierId);
      expect(rows(store), await freshRows());
      expect(rows(store).map((r) => r.$2), ['Beta']);

      expect(notified, 3, reason: 'each write must reach observers');
    });
  });

  // stock_take_list_screen: no reload after returning from a take.
  group('RestaurantStockTakeStore', () {
    List<(String, String, double?)> rows(RestaurantStockTakeStore s) => [
          for (final t in s.takes) (t.takeId, t.status, t.committedNetQty)
        ];

    Future<List<(String, String, double?)>> freshRows() async {
      final fresh = RestaurantStockTakeStore();
      await fresh.loadTakes();
      return rows(fresh);
    }

    test('start, count, commit and cancel keep takes current', () async {
      await Hive.box<Items>(HiveBoxNames.restaurantItems).put(
          'flour',
          Items(id: 'flour', name: 'Flour', trackInventory: true,
              stockQuantity: 10));
      await itemStore.loadItems();
      final store = RestaurantStockTakeStore();
      await store.loadTakes();

      final first = await store.startTake();
      expect(first, isNotNull);
      expect(rows(store), await freshRows());

      final counted = await store.countItem(
          item: itemStore.getItemById('flour')!, countedQty: 12);
      expect(counted, isTrue);
      expect(rows(store), await freshRows());

      final result = await store.commit(shortageReason: 'Damaged');
      expect(result.success, isTrue, reason: result.errorMessage);
      expect(rows(store), await freshRows());
      expect(store.takes.single.isCompleted, isTrue);
      expect(store.takes.single.committedNetQty, 2);

      final second = await store.startTake();
      expect(rows(store), await freshRows());
      expect(store.takes.first.takeId, second!.takeId,
          reason: 'newest first, same as a reload');

      expect(await store.cancelTake(second.takeId), isTrue);
      expect(rows(store), await freshRows());
    });
  });

  // setup_items_list_screen: no reload after the edit-item screen.
  group('ItemStore.updateItem', () {
    test('replaces the entry observably and matches a reload', () async {
      await Hive.box<Items>(HiveBoxNames.restaurantItems)
          .put('tea', Items(id: 'tea', name: 'Tea', price: 20));
      await itemStore.loadItems();
      final seen = <String?>[];
      final dispose =
          reaction((_) => itemStore.getItemById('tea')?.name, seen.add);
      addTearDown(dispose.call);

      final ok = await itemStore.updateItem(
          itemStore.getItemById('tea')!.copyWith(name: 'Masala Tea'));

      expect(ok, isTrue);
      expect(seen, ['Masala Tea']);
      final fresh = ItemStore(ItemRepository());
      await fresh.loadItems();
      expect(fresh.items.map((i) => (i.id, i.name)),
          itemStore.items.map((i) => (i.id, i.name)));
    });
  });
}
