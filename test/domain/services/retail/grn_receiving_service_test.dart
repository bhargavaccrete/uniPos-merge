import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';

import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_item_model_214.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_model_213.dart';
import 'package:billberrylite/data/models/retail/hive_model/inventory_loss_model_178.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_item_model_212.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_model_211.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_return_item_model_175.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_return_model_174.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_claim_item_model_177.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_claim_model_176.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_ledger_entry_model_179.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_model_205.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/domain/services/retail/auth_service.dart';
import 'package:billberrylite/domain/services/retail/grn_receiving_service.dart';
import 'package:billberrylite/domain/store/retail/damaged_goods_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/purchase_order_store.dart';
import 'package:billberrylite/domain/store/retail/supplier_store.dart';

/// R-01 (double submit) and R-02 (non-atomic, unrecoverable receipt) in
/// docs/modules/retail_inventory.md.
void main() {
  late Directory tempDir;
  late ProductStore products;
  late PurchaseOrderStore poStore;
  late SupplierStore suppliers;

  const now = '2026-01-01T00:00:00.000';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('grn_receiving_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();

    await Hive.openBox<ProductModel>(HiveBoxNames.products);
    await Hive.openBox<VarianteModel>(HiveBoxNames.variants);
    await Hive.openBox<SupplierModel>(HiveBoxNames.suppliers);
    await Hive.openBox<SupplierLedgerEntryModel>(HiveBoxNames.supplierLedger);
    await Hive.openBox<PurchaseOrderModel>(HiveBoxNames.purchaseOrders);
    await Hive.openBox<PurchaseOrderItemModel>(HiveBoxNames.purchaseOrderItems);
    await Hive.openBox<GRNModel>(HiveBoxNames.grns);
    await Hive.openBox<GRNItemModel>(HiveBoxNames.grnItems);
    await Hive.openBox<PurchaseReturnModel>(HiveBoxNames.purchaseReturns);
    await Hive.openBox<PurchaseReturnItemModel>(HiveBoxNames.purchaseReturnItems);
    await Hive.openBox<SupplierClaimModel>(HiveBoxNames.supplierClaims);
    await Hive.openBox<SupplierClaimItemModel>(HiveBoxNames.supplierClaimItems);
    await Hive.openBox<InventoryLossModel>(HiveBoxNames.inventoryLosses);
    await Hive.openBox<StockMovementModel>(HiveBoxNames.restaurantStockMovements);
    await Hive.openBox(HiveBoxNames.dayManagementBox);

    // Supplier, PO (sent, 10 ordered) and the variant it is for.
    await Hive.box<SupplierModel>(HiveBoxNames.suppliers).put(
        's1', SupplierModel(supplierId: 's1', name: 'Acme', createdAt: now, updatedAt: now));
    final po = PurchaseOrderModel.create(
      poNumber: 'PO-00001',
      supplierId: 's1',
      supplierName: 'Acme',
      expectedDeliveryDate: now,
      totalItems: 10,
      status: POStatus.sent,
    );
    await Hive.box<PurchaseOrderModel>(HiveBoxNames.purchaseOrders).put(po.poId, po);
    final poItem = PurchaseOrderItemModel.create(
        poId: po.poId, variantId: 'v1', productId: 'p1', productName: 'Rice', orderedQty: 10);
    await Hive.box<PurchaseOrderItemModel>(HiveBoxNames.purchaseOrderItems)
        .put(poItem.poItemId, poItem);

    await locator.reset();
    products = ProductStore();
    poStore = PurchaseOrderStore();
    suppliers = SupplierStore();
    locator.registerSingleton<ProductStore>(products);
    locator.registerSingleton<PurchaseOrderStore>(poStore);
    locator.registerSingleton<SupplierStore>(suppliers);
    locator.registerSingleton<DamagedGoodsStore>(DamagedGoodsStore());
    locator.registerSingleton<AuthService>(AuthService());

    await products.addVariant(VarianteModel(
        varianteId: 'v1', productId: 'p1', sku: 'v1', stockQty: 5, costPrice: 40,
        createdAt: now, status: 'active'));
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  PurchaseOrderModel po() => Hive.box<PurchaseOrderModel>(HiveBoxNames.purchaseOrders).values.single;
  PurchaseOrderItemModel poItem() =>
      Hive.box<PurchaseOrderItemModel>(HiveBoxNames.purchaseOrderItems).values.single;

  (GRNModel, List<GRNItemModel>) makeGrn({double received = 8, String number = 'GRN-00001'}) {
    final grn = GRNModel.create(
      grnNumber: number,
      poId: po().poId,
      poNumber: 'PO-00001',
      supplierId: 's1',
      supplierName: 'Acme',
      receivedDate: now,
      totalOrderedQty: 10,
      totalReceivedQty: received,
      totalAmount: received * 50,
    );
    final item = GRNItemModel.create(
      grnId: grn.grnId,
      poItemId: poItem().poItemId,
      variantId: 'v1',
      productId: 'p1',
      productName: 'Rice',
      orderedQty: 10,
      receivedQty: received,
      acceptedQty: received,
      costPrice: 50,
    );
    return (grn, [item]);
  }

  Future<double> stock() async => (await products.getVariantById('v1'))!.stockQty;
  List<SupplierLedgerEntryModel> purchases() =>
      Hive.box<SupplierLedgerEntryModel>(HiveBoxNames.supplierLedger)
          .values
          .where((e) => e.type == SupplierLedgerType.purchase.name)
          .toList();
  GRNModel storedGrn() => Hive.box<GRNModel>(HiveBoxNames.grns).values.single;

  test('a receipt moves stock, cost, ledger, movement, then confirms', () async {
    final (grn, items) = makeGrn();
    final result = await GrnReceivingService.receive(grn, items);

    expect(result.success, isTrue);
    expect(await stock(), 13);
    // R-21: 5 on hand @ ₹40 + 8 received @ ₹50 → weighted, not overwritten.
    expect((await products.getVariantById('v1'))!.costPrice,
        closeTo((5 * 40 + 8 * 50) / 13, 1e-9));
    expect(purchases().single.amount, 400);
    expect(Hive.box<StockMovementModel>(HiveBoxNames.restaurantStockMovements)
        .get('grn_${items.single.grnItemId}')!.quantity, 8,
        reason: 'receipt now leaves a stock history row');
    expect(storedGrn().statusEnum, GRNStatus.confirmed);
    expect(po().statusEnum, POStatus.partiallyCompleted);
  });

  group('R-21 weighted average cost', () {
    double? avg(double onHand, double? current, double qty, double? receipt) =>
        GrnReceivingService.weightedAverageCost(
            onHand: onHand, currentCost: current,
            receivedQty: qty, receiptCost: receipt);

    test('100 @ ₹50 then 10 @ ₹80 → ₹52.73, not ₹80', () {
      expect(avg(100, 50, 10, 80), closeTo(5800 / 110, 1e-9));
    });

    test('nothing on hand (or negative) → the receipt cost', () {
      expect(avg(0, 50, 10, 80), 80);
      expect(avg(-3, 50, 10, 80), 80);
    });

    test('no current cost → the receipt cost', () {
      expect(avg(20, null, 10, 80), 80);
    });

    test('a receipt with no price leaves the cost alone', () {
      expect(avg(20, 50, 10, null), 50);
      expect(avg(20, 50, 10, 0), 50);
    });

    test('decimal quantities average by weight', () {
      expect(avg(2.5, 100, 0.5, 130), closeTo((250 + 65) / 3, 1e-9));
    });

    test('a resumed receipt does not average the same line twice', () async {
      final (grn, items) = makeGrn();
      await poStore.createGRN(grn, items);
      await GrnReceivingService.resumeInterrupted();
      final once = (await products.getVariantById('v1'))!.costPrice;

      await GrnReceivingService.resumeInterrupted();

      expect((await products.getVariantById('v1'))!.costPrice, once);
    });
  });

  group('R-24 short-close a PO', () {
    test('a partly received PO can be closed; it stops being receivable', () async {
      final (grn, items) = makeGrn(received: 8); // 8 of 10
      await GrnReceivingService.receive(grn, items);
      expect(po().statusEnum, POStatus.partiallyCompleted);

      expect(await poStore.closePurchaseOrder(po().poId), isTrue);

      expect(po().statusEnum, POStatus.closed);
      expect(po().canReceive, isFalse);
      expect(po().isCompleted, isTrue);
      expect(await stock(), 13, reason: 'received goods stand');
      expect(purchases(), hasLength(1), reason: 'supplier bill stands');
    });

    test('a draft or finished PO cannot be closed', () async {
      final draft = po().copyWith(status: POStatus.draft.name);
      await Hive.box<PurchaseOrderModel>(HiveBoxNames.purchaseOrders)
          .put(draft.poId, draft);
      expect(await poStore.closePurchaseOrder(draft.poId), isFalse);
    });

    test('a receipt resumed after closing does not reopen the order', () async {
      final (grn, items) = makeGrn(received: 2);
      await poStore.createGRN(grn, items); // interrupted before confirm
      await poStore.closePurchaseOrder(po().poId);

      await GrnReceivingService.resumeInterrupted();

      expect(po().statusEnum, POStatus.closed);
      expect(await stock(), 7, reason: 'the goods still landed');
    });
  });

  test('R-37 editing a PO leaves exactly the new lines', () async {
    final draft = po().copyWith(status: POStatus.draft.name);
    final replacement = [
      PurchaseOrderItemModel.create(
          poId: draft.poId, variantId: 'v1', productId: 'p1', orderedQty: 4),
      PurchaseOrderItemModel.create(
          poId: draft.poId, variantId: 'v1', productId: 'p1', orderedQty: 6),
    ];

    await poStore.updatePurchaseOrder(draft, replacement);

    final lines = Hive.box<PurchaseOrderItemModel>(HiveBoxNames.purchaseOrderItems)
        .values
        .where((i) => i.poId == draft.poId)
        .toList();
    expect(lines.map((l) => l.poItemId).toSet(),
        replacement.map((l) => l.poItemId).toSet(),
        reason: 'old line removed, both new lines kept');
    expect(po().totalItems, 10);
  });

  group('R-01 double submit', () {
    test('two overlapping receives of the same GRN apply once', () async {
      final (grn, items) = makeGrn();
      final results = await Future.wait([
        GrnReceivingService.receive(grn, items),
        GrnReceivingService.receive(grn, items),
      ]);

      expect(results.where((r) => r.success), hasLength(1));
      expect(await stock(), 13);
      expect(purchases(), hasLength(1));
      expect(Hive.box<GRNModel>(HiveBoxNames.grns).length, 1);
    });

    test('a second receive with an already-used GRN number is refused', () async {
      final (grn, items) = makeGrn();
      await GrnReceivingService.receive(grn, items);
      final (again, againItems) = makeGrn(); // new ids, same reserved number

      final result = await GrnReceivingService.receive(again, againItems);

      expect(result.success, isFalse);
      expect(await stock(), 13);
      expect(purchases(), hasLength(1));
    });
  });

  group('R-02 interrupted receipt resumes', () {
    test('crash right after the draft was written → resume completes it', () async {
      final (grn, items) = makeGrn();
      await poStore.createGRN(grn, items); // …and the app died here

      expect(storedGrn().statusEnum, GRNStatus.draft);
      expect(await stock(), 5);

      expect(await GrnReceivingService.resumeInterrupted(), 1);
      expect(await stock(), 13);
      expect(purchases(), hasLength(1));
      expect(storedGrn().statusEnum, GRNStatus.confirmed);
      expect(po().statusEnum, POStatus.partiallyCompleted);
    });

    test('crash after stock was applied → resume does not add it twice', () async {
      final (grn, items) = makeGrn();
      await poStore.createGRN(grn, items);
      // Simulate step 2 having completed for this line before the crash.
      await products.updateVariantStock('v1', 13);
      await Hive.box<StockMovementModel>(HiveBoxNames.restaurantStockMovements).put(
        'grn_${items.single.grnItemId}',
        StockMovementModel(
          id: 'grn_${items.single.grnItemId}',
          timestamp: DateTime.now(),
          itemId: 'p1',
          variantId: 'v1',
          itemName: 'Rice',
          type: 'in',
          quantity: 8,
          balanceAfter: 13,
          reason: 'Goods received',
          unit: 'pcs',
          staffName: 'Staff',
        ),
      );

      await GrnReceivingService.resumeInterrupted();

      expect(await stock(), 13, reason: 'line already applied — skipped');
      expect(purchases(), hasLength(1), reason: 'ledger step still ran');
      expect(storedGrn().statusEnum, GRNStatus.confirmed);
    });

    test('resume is a no-op once everything is confirmed', () async {
      final (grn, items) = makeGrn();
      await GrnReceivingService.receive(grn, items);

      expect(await GrnReceivingService.resumeInterrupted(), 0);
      expect(await stock(), 13);
      expect(purchases(), hasLength(1));
    });
  });
}
