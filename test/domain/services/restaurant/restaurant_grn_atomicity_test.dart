import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_grn_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_grn_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_inventory_loss_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_return_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_return_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_claim_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_claim_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_ledger_entry_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_grn_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_inventory_loss_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_purchase_order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_purchase_return_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_supplier_ledger_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/restaurant_supplier_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/stock_movement_repository.dart';
import 'package:billberrylite/domain/services/restaurant/restaurant_grn_receiving.dart';
import 'package:billberrylite/domain/services/restaurant/stock_journal.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/domain/store/restaurant/restaurant_damaged_goods_store.dart';
import 'package:billberrylite/domain/store/restaurant/restaurant_purchase_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/restaurant_supplier_store.dart';

/// S-06 — a Restaurant goods receipt is saved as a DRAFT and completed step
/// by step; a stop anywhere is finished by a resume, and nothing — stock, the
/// supplier payable, damaged-goods documents — happens twice.
///
/// The standard receipt: Rice 10 @ 55 (all good) and Oil 5 @ 20, of which 2
/// damaged and returned to the supplier. Billed 10*55 + 5*20 = 650.
void main() {
  late Directory tempDir;
  late RestaurantPurchaseOrderStore store;
  late String supplierId;
  late Map<String, String> poLine;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('restaurant_grn_atomic_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();

    await Hive.openBox<Items>(HiveBoxNames.restaurantItems);
    await Hive.openBox<Category>(HiveBoxNames.category);
    await Hive.openBox<StockMovementModel>(
        HiveBoxNames.restaurantStockMovements);
    await Hive.openBox<AppNotificationModel>(HiveBoxNames.appNotifications);
    await Hive.openBox(HiveBoxNames.dayManagementBox);
    await Hive.openBox(HiveBoxNames.restaurantStockJournal);
    await Hive.openBox(HiveBoxNames.appCounters);
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
    await Hive.openBox<RestaurantPurchaseReturnModel>(
        HiveBoxNames.restaurantPurchaseReturns);
    await Hive.openBox<RestaurantPurchaseReturnItemModel>(
        HiveBoxNames.restaurantPurchaseReturnItems);
    await Hive.openBox<RestaurantSupplierClaimModel>(
        HiveBoxNames.restaurantSupplierClaims);
    await Hive.openBox<RestaurantSupplierClaimItemModel>(
        HiveBoxNames.restaurantSupplierClaimItems);
    await Hive.openBox<RestaurantInventoryLossModel>(
        HiveBoxNames.restaurantInventoryLosses);

    locator
      ..registerLazySingleton<ItemStore>(() => ItemStore(ItemRepository()))
      ..registerLazySingleton<NotificationStore>(
          () => NotificationStore(NotificationRepository()))
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
          () => RestaurantGRNItemRepository())
      ..registerLazySingleton<RestaurantDamagedGoodsStore>(
          () => RestaurantDamagedGoodsStore());

    RestaurantGrnReceiving.failAtForTesting = null;
    RestaurantGrnReceiving.failSkipForTesting = 0;

    // Seed: two tracked items, a supplier and a sent PO with one line each.
    final items = Hive.box<Items>(HiveBoxNames.restaurantItems);
    await items.put(
        'rice',
        Items(
            id: 'rice',
            name: 'Rice',
            trackInventory: true,
            stockQuantity: 2,
            lastPurchaseCost: 50));
    await items.put('oil',
        Items(id: 'oil', name: 'Oil', trackInventory: true, stockQuantity: 0));
    await itemStore.loadItems();

    final supplier = RestaurantSupplierModel.create(name: 'Dairy Co');
    supplierId = supplier.supplierId;
    await restaurantSupplierRepository.saveSupplier(supplier);

    await restaurantPurchaseOrderRepository.savePurchaseOrder(
      RestaurantPurchaseOrderModel.create(
        poId: 'po-1',
        poNumber: 'PO-1',
        supplierId: supplierId,
        supplierName: 'Dairy Co',
        expectedDeliveryDate: '2026-11-05',
        totalItems: 15,
        status: RestaurantPOStatus.sent,
      ),
    );
    poLine = {};
    for (final (id, qty) in [('rice', 10.0), ('oil', 5.0)]) {
      final line = RestaurantPurchaseOrderItemModel.create(
          poId: 'po-1', itemId: id, itemName: id, orderedQty: qty);
      await restaurantPurchaseOrderItemRepository.saveItem(line);
      poLine[id] = line.poItemId;
    }

    store = RestaurantPurchaseOrderStore();
  });

  tearDown(() async {
    RestaurantGrnReceiving.failAtForTesting = null;
    RestaurantGrnReceiving.failSkipForTesting = 0;
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // ── helpers ────────────────────────────────────────────────────────────────

  GRNReceiptLine rice() => (
        poItemId: poLine['rice']!,
        itemId: 'rice',
        itemName: 'Rice',
        orderedQty: 10,
        receivedQty: 10,
        acceptedQty: 10,
        damagedQty: null,
        costPrice: 55,
        damagedHandling: null,
      );

  GRNReceiptLine oil({String handling = 'returnToSupplier'}) => (
        poItemId: poLine['oil']!,
        itemId: 'oil',
        itemName: 'Oil',
        orderedQty: 5,
        receivedQty: 5,
        acceptedQty: 3,
        damagedQty: 2,
        costPrice: 20,
        damagedHandling: handling,
      );

  Future<List<RestaurantGRNItemModel>> confirm([List<GRNReceiptLine>? lines]) =>
      store.confirmGRN(
        poId: 'po-1',
        poNumber: 'PO-1',
        supplierId: supplierId,
        supplierName: 'Dairy Co',
        receivedDate: '2026-11-05',
        lines: lines ?? [rice(), oil()],
      );

  Future<void> interruptAt(String checkpoint,
      {int skip = 0, List<GRNReceiptLine>? lines}) async {
    RestaurantGrnReceiving.failAtForTesting = checkpoint;
    RestaurantGrnReceiving.failSkipForTesting = skip;
    await expectLater(confirm(lines), throwsA(isA<GrnInterruptedForTesting>()));
    RestaurantGrnReceiving.failAtForTesting = null;
    RestaurantGrnReceiving.failSkipForTesting = 0;
  }

  double stockOf(String id) =>
      Hive.box<Items>(HiveBoxNames.restaurantItems).get(id)!.stockQuantity;
  List<StockMovementModel> movementsOf(String id) =>
      StockMovementRepository().movementsForItem(id);
  List<RestaurantGRNModel> grns() => restaurantGrnRepository.getAllGRNs();
  List<RestaurantSupplierLedgerEntryModel> purchaseRows() =>
      Hive.box<RestaurantSupplierLedgerEntryModel>(
              HiveBoxNames.restaurantSupplierLedger)
          .values
          .where((e) => e.type == RestaurantSupplierLedgerType.purchase.name)
          .toList();
  double supplierBalance() =>
      restaurantSupplierRepository.getSupplierById(supplierId)!.currentBalance;
  Iterable<dynamic> grnIntentKeys() => Hive.box(HiveBoxNames.restaurantStockJournal)
      .keys
      .where((k) => k.toString().startsWith(StockJournal.grnKeyPrefix));
  RestaurantPOStatus poStatus() =>
      restaurantPurchaseOrderRepository.getPurchaseOrderById('po-1')!.statusEnum;
  Future<List<RestaurantPurchaseReturnModel>> returns() =>
      RestaurantPurchaseReturnRepository().getAll();
  List<AppNotificationModel> stockChecks() =>
      Hive.box<AppNotificationModel>(HiveBoxNames.appNotifications)
          .values
          .where((n) => n.eventCode == StockJournal.reviewEvent)
          .toList();

  /// The standard receipt, completed exactly once.
  Future<void> expectReceivedOnce() async {
    expect(stockOf('rice'), 12, reason: 'rice 2 + 10, once');
    expect(stockOf('oil'), 3, reason: 'oil 0 + 3 accepted, once');
    expect(movementsOf('rice'), hasLength(1));
    expect(movementsOf('oil'), hasLength(1));
    expect(movementsOf('rice').single.balanceAfter, 12);
    expect(
        Hive.box<Items>(HiveBoxNames.restaurantItems).get('rice')!
            .lastPurchaseCost,
        55);

    expect(grns(), hasLength(1));
    expect(grns().single.statusEnum, RestaurantGRNStatus.confirmed);
    expect(poStatus(), RestaurantPOStatus.completed);

    expect(purchaseRows(), hasLength(1));
    expect(purchaseRows().single.amount, 650);
    expect(supplierBalance(), 650);

    final rets = await returns();
    expect(rets, hasLength(1), reason: 'one purchase return for the damage');
    expect(await RestaurantPurchaseReturnRepository().getItems(rets.single.returnId),
        hasLength(1));

    expect(grnIntentKeys(), isEmpty, reason: 'no intent left behind');
  }

  // ==========================================================================
  group('a normal receipt', () {
    test('completes everything once, then confirms', () async {
      final lines = await confirm();
      expect(lines, hasLength(2));
      await expectReceivedOnce();
      expect(movementsOf('rice').single.id,
          RestaurantGrnReceiving.movementId(lines.first.grnItemId));
      expect(await store.resumeInterruptedReceipts(), 0);
      await expectReceivedOnce();
    });

    test('two lines for one item: last cost wins (entered order kept)',
        () async {
      final GRNReceiptLine second = (
        poItemId: poLine['rice']!,
        itemId: 'rice',
        itemName: 'Rice',
        orderedQty: 10,
        receivedQty: 1,
        acceptedQty: 1,
        damagedQty: null,
        costPrice: 60.0,
        damagedHandling: null,
      );
      await confirm([rice(), second]);
      expect(stockOf('rice'), 13);
      expect(
          Hive.box<Items>(HiveBoxNames.restaurantItems).get('rice')!
              .lastPurchaseCost,
          60);
    });
  });

  // ==========================================================================
  group('double confirmation', () {
    test('a second confirm while the first runs is refused; one receipt',
        () async {
      final first = confirm();
      final second = confirm();
      await expectLater(
          second,
          throwsA(isA<StateError>().having((e) => e.message, 'message',
              RestaurantPORules.receiptInProgressMessage)));
      await first;
      await expectReceivedOnce();
    });

    test('the guard is released after a failure', () async {
      await interruptAt('afterStockWrite');
      // A new confirm for the same PO is allowed again (not stuck).
      await expectLater(confirm([rice()]), completes);
    });
  });

  // ==========================================================================
  group('interrupted at every write boundary, then resumed', () {
    const boundaries = [
      'afterLines',
      'beforeStockWrite',
      'afterStockWrite',
      'afterStockWritten',
      'afterMovement',
      'afterStock',
      'afterLedger',
      'afterDamaged',
    ];

    for (final cp in boundaries) {
      test('stop at $cp: draft counts nowhere; resume completes it once',
          () async {
        await interruptAt(cp);

        expect(grns().single.statusEnum, RestaurantGRNStatus.draft);
        expect(poStatus(), RestaurantPOStatus.sent,
            reason: 'a draft does not count against the PO');

        expect(await store.resumeInterruptedReceipts(), 1);
        await expectReceivedOnce();

        // A repeated resume changes nothing.
        expect(await store.resumeInterruptedReceipts(), 0);
        await expectReceivedOnce();
      });
    }

    for (final cp in ['beforeStockWrite', 'afterStockWrite', 'afterMovement']) {
      test('stop at $cp on the SECOND line: the first is not re-added',
          () async {
        await interruptAt(cp, skip: 1);
        expect(stockOf('rice'), 12, reason: 'first line already applied');
        expect(await store.resumeInterruptedReceipts(), 1);
        await expectReceivedOnce();
      });
    }

    test('stop between the stock write and its movement row: the stock is '
        'not added again, only the row is written', () async {
      await interruptAt('afterStockWrite');
      expect(stockOf('rice'), 12, reason: 'the write landed');
      expect(movementsOf('rice'), isEmpty, reason: 'its row did not');
      final intent = RestaurantGrnReceiving.intentFor(
          restaurantGrnItemRepository.getAllItems()
              .firstWhere((i) => i.itemId == 'rice')
              .grnItemId)!;
      expect(intent['state'], RestaurantGrnReceiving.applying);

      expect(await store.resumeInterruptedReceipts(), 1);
      expect(stockOf('rice'), 12, reason: 'NOT 22');
      expect(movementsOf('rice').single.balanceAfter, 12);
      await expectReceivedOnce();
    });

    test('stop after the draft header, before any line: cancelled, nothing '
        'applied, receive again', () async {
      await interruptAt('afterDraftHeader');
      expect(await store.resumeInterruptedReceipts(), 1);

      final grn = grns().single;
      expect(grn.statusEnum, RestaurantGRNStatus.cancelled);
      expect(grn.notes, contains('interrupted before all lines were saved'));
      expect(stockOf('rice'), 2);
      expect(purchaseRows(), isEmpty);
      expect(supplierBalance(), 0);
      expect(await returns(), isEmpty);
      expect(poStatus(), RestaurantPOStatus.sent);

      await confirm();
      expect(stockOf('rice'), 12);
      expect(purchaseRows(), hasLength(1));
      expect(supplierBalance(), 650);
      expect(poStatus(), RestaurantPOStatus.completed);
    });

    test('stop part-way through saving the lines: cancelled, nothing billed',
        () async {
      await interruptAt('afterLines');
      // Rewind to "only the first line was saved".
      final oilLine = restaurantGrnItemRepository
          .getAllItems()
          .firstWhere((i) => i.itemId == 'oil');
      await Hive.box<RestaurantGRNItemModel>(HiveBoxNames.restaurantGrnItems)
          .delete(oilLine.grnItemId);

      expect(await store.resumeInterruptedReceipts(), 1);
      expect(grns().single.statusEnum, RestaurantGRNStatus.cancelled);
      expect(stockOf('rice'), 2, reason: 'no partial receipt is applied');
      expect(purchaseRows(), isEmpty);
      expect(supplierBalance(), 0);
    });
  });

  // ==========================================================================
  group('stock moved after an interruption — never re-added, flagged', () {
    for (final cp in ['beforeStockWrite', 'afterStockWrite']) {
      test('stop at $cp, then a sale: the line is flagged for a count',
          () async {
        await interruptAt(cp);
        final landed = cp == 'afterStockWrite';
        expect(stockOf('rice'), landed ? 12 : 2);

        // Another write moves rice before the resume.
        await itemStore.applyStockDelta(itemId: 'rice', delta: -1);

        expect(await store.resumeInterruptedReceipts(), 1);
        expect(stockOf('rice'), landed ? 11 : 1,
            reason: 'the uncertain line is never applied a second time');
        expect(movementsOf('rice'), isEmpty);
        final riceLine = restaurantGrnItemRepository
            .getAllItems()
            .firstWhere((i) => i.itemId == 'rice');
        expect(RestaurantGrnReceiving.intentFor(riceLine.grnItemId)!['state'],
            RestaurantGrnReceiving.review);
        expect(stockChecks(), hasLength(1));
        expect(stockChecks().single.subjectId, riceLine.grnItemId);

        // The rest of the receipt still completes, once.
        expect(stockOf('oil'), 3);
        expect(grns().single.statusEnum, RestaurantGRNStatus.confirmed);
        expect(purchaseRows(), hasLength(1));
        expect(supplierBalance(), 650);

        // Resuming again neither re-applies nor re-alerts.
        await store.resumeInterruptedReceipts();
        expect(stockOf('rice'), landed ? 11 : 1);
        expect(stockChecks(), hasLength(1));
      });
    }

    test('the alert says it was a goods receipt', () async {
      await interruptAt('afterStockWrite');
      await itemStore.applyStockDelta(itemId: 'rice', delta: -1);
      await store.resumeInterruptedReceipts();
      expect(stockChecks().single.data, contains('goods receipt'));
    });
  });

  // ==========================================================================
  group('supplier payable — exactly once', () {
    Future<void> writeRowOnly() =>
        restaurantSupplierLedgerRepository.save(
          RestaurantSupplierLedgerEntryModel.create(
            supplierId: supplierId,
            type: RestaurantSupplierLedgerType.purchase,
            amount: 650,
            balanceAfter: 650,
            description: 'Goods received',
            docId: grns().single.grnId,
            seq: 1,
          ),
        );

    test('row written but the balance write lost: balance repaired, no 2nd row',
        () async {
      await interruptAt('afterStock');
      await writeRowOnly();
      expect(supplierBalance(), 0);

      await store.resumeInterruptedReceipts();
      expect(purchaseRows(), hasLength(1));
      expect(supplierBalance(), 650);
    });

    test('...and a later movement was recorded before the resume', () async {
      await interruptAt('afterStock');
      await writeRowOnly();
      await restaurantSupplierStore.recordBalanceMovement(
        supplierId: supplierId,
        amount: -100,
        type: RestaurantSupplierLedgerType.payment,
        description: 'Paid',
      );
      expect(supplierBalance(), -100);

      await store.resumeInterruptedReceipts();
      expect(purchaseRows(), hasLength(1));
      expect(supplierBalance(), 550, reason: '650 owed - 100 paid');
    });

    test('row and balance both written: nothing added', () async {
      await interruptAt('afterLedger');
      expect(supplierBalance(), 650);
      await store.resumeInterruptedReceipts();
      expect(purchaseRows(), hasLength(1));
      expect(supplierBalance(), 650);
    });
  });

  // ==========================================================================
  group('damaged-goods documents — exactly once', () {
    test('return lines saved but not its header: one return with its lines',
        () async {
      await interruptAt('afterLedger');
      // Leftover lines of a return whose header never landed.
      final oilLine = restaurantGrnItemRepository
          .getAllItems()
          .firstWhere((i) => i.itemId == 'oil');
      await RestaurantPurchaseReturnRepository().saveItems([
        RestaurantPurchaseReturnItemModel.create(
          returnId: 'orphan',
          grnItemId: oilLine.grnItemId,
          itemId: 'oil',
          itemName: 'Oil',
          returnedQty: 2,
          costPrice: 20,
        ),
      ]);

      await store.resumeInterruptedReceipts();
      await expectReceivedOnce();
    });

    test('claim: one claim after a resume', () async {
      await interruptAt('afterDamaged', lines: [rice(), oil(handling: 'keepForClaim')]);
      await store.resumeInterruptedReceipts();
      await store.resumeInterruptedReceipts();
      final claims =
          await restaurantDamagedGoodsStore.documentsForGRN(grns().single.grnId);
      expect(claims.claims, hasLength(1));
      expect(claims.returns, isEmpty);
    });

    test('write-offs: only the missing line gets one', () async {
      final GRNReceiptLine second = (
        poItemId: poLine['rice']!,
        itemId: 'rice',
        itemName: 'Rice',
        orderedQty: 10,
        receivedQty: 10,
        acceptedQty: 9,
        damagedQty: 1.0,
        costPrice: 55.0,
        damagedHandling: 'writeOff',
      );
      await interruptAt('afterLedger', lines: [second, oil(handling: 'writeOff')]);

      // One of the two write-offs was raised before the stop.
      final grn = grns().single;
      final riceLine = restaurantGrnItemRepository
          .getAllItems()
          .firstWhere((i) => i.itemId == 'rice');
      await RestaurantInventoryLossRepository().save(
        RestaurantInventoryLossModel.create(
          lossNumber: 'LOSS-EXISTING',
          grnId: grn.grnId,
          grnNumber: grn.grnNumber,
          grnItemId: riceLine.grnItemId,
          poId: 'po-1',
          supplierId: supplierId,
          supplierName: 'Dairy Co',
          itemId: 'rice',
          itemName: 'Rice',
          quantity: 1,
          costPrice: 55,
          reason: 'Damaged on receipt',
        ),
      );

      await store.resumeInterruptedReceipts();
      final losses = await RestaurantInventoryLossRepository().getByGRN(grn.grnId);
      expect(losses, hasLength(2));
      expect(losses.map((l) => l.grnItemId).toSet(), hasLength(2));
    });
  });

  // ==========================================================================
  group('the sale journal shares the box safely', () {
    test('StockJournal.recoverAll ignores goods-receipt intents', () async {
      await interruptAt('afterStockWrite');
      expect(grnIntentKeys(), isNotEmpty);
      expect(StockJournal.all(), isEmpty);
      expect(await StockJournal.recoverAll(), isEmpty);
    });
  });
}
