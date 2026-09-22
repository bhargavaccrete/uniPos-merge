import 'package:mobx/mobx.dart';
import 'package:uuid/uuid.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_ledger_entry_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_grn_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_grn_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/repositories/restaurant/stock_movement_repository.dart';
import 'package:billberrylite/domain/services/restaurant/day_management_service.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';

part 'restaurant_purchase_order_store.g.dart';

const _uuid = Uuid();

/// One ordered/received line as collected by a screen — not a Hive model,
/// just the shape [createPurchaseOrder] and [confirmGRN] need to build their
/// respective rows. Kept as records (not a class) since nothing else needs to
/// hold onto them.
typedef PurchaseOrderLine = ({
  String itemId,
  String itemName,
  double qty,
  double? price,
});

typedef GRNReceiptLine = ({
  String poItemId,
  String itemId,
  String itemName,
  double orderedQty,
  double receivedQty,
  double acceptedQty,
  double? damagedQty,
  double? costPrice,
  String? damagedHandling,
});

/// Restaurant-scoped Purchase Order / GRN pipeline store — mirrors retail's
/// `PurchaseOrderStore` but scoped to `Items`/no-variant world (see
/// docs/inventory_recipe_system_plan.md §6). Confirming a GRN is the one
/// place raw-material stock moves; that whole flow lives in [confirmGRN] so
/// it stays atomic instead of being split across store+screen like retail's.
class RestaurantPurchaseOrderStore = _RestaurantPurchaseOrderStore
    with _$RestaurantPurchaseOrderStore;

abstract class _RestaurantPurchaseOrderStore with Store {
  final StockMovementRepository _stockMovementRepository =
      StockMovementRepository();

  // ==================== OBSERVABLES ====================

  // NOTE: suppliers are NOT mirrored here. This store used to keep its own
  // ObservableList copy, refreshed only by its own inline "add supplier",
  // so a supplier created from the Suppliers screen never appeared in the
  // Add PO picker. RestaurantSupplierStore.suppliers is the single source
  // of truth — read it directly.

  @observable
  ObservableList<RestaurantPurchaseOrderModel> purchaseOrders =
      ObservableList<RestaurantPurchaseOrderModel>();

  @observable
  ObservableList<RestaurantGRNModel> grns = ObservableList<RestaurantGRNModel>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  _RestaurantPurchaseOrderStore() {
    loadPurchaseOrders();
    loadGRNs();
  }

  // ==================== LOADERS ====================

  @action
  Future<void> loadPurchaseOrders() async {
    // Newest first. The box returns insertion order, so without this a reload
    // (screen open, GRN confirm) pushed the newest PO to the BOTTOM, undoing
    // the `insert(0, po)` that createPurchaseOrder does. Same ordering rule
    // and the same ISO-8601 string compare the repository already uses for
    // getPurchaseOrdersBySupplier.
    final loaded = restaurantPurchaseOrderRepository.getAllPurchaseOrders()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    purchaseOrders.clear();
    purchaseOrders.addAll(loaded);
  }

  @action
  Future<void> loadGRNs() async {
    final loaded = restaurantGrnRepository.getAllGRNs();
    grns.clear();
    grns.addAll(loaded);
  }

  // ==================== PURCHASE ORDERS ====================

  @action
  Future<RestaurantPurchaseOrderModel> createPurchaseOrder({
    required String supplierId,
    String? supplierName,
    required String expectedDeliveryDate,
    String? notes,
    required List<PurchaseOrderLine> lines,
  }) async {
    try {
      isLoading = true;
      errorMessage = null;

      final poId = _uuid.v4();
      final poNumber = restaurantPurchaseOrderRepository.generatePONumber();

      final totalItems = lines.fold<double>(0, (sum, l) => sum + l.qty);
      final estimatedTotal =
          lines.fold<double>(0, (sum, l) => sum + (l.qty * (l.price ?? 0)));

      final po = RestaurantPurchaseOrderModel.create(
        poId: poId,
        poNumber: poNumber,
        supplierId: supplierId,
        supplierName: supplierName,
        expectedDeliveryDate: expectedDeliveryDate,
        totalItems: totalItems,
        estimatedTotal: estimatedTotal,
        status: RestaurantPOStatus.draft,
        notes: notes,
      );
      await restaurantPurchaseOrderRepository.savePurchaseOrder(po);

      for (final line in lines) {
        final poItem = RestaurantPurchaseOrderItemModel.create(
          poId: poId,
          itemId: line.itemId,
          itemName: line.itemName,
          orderedQty: line.qty,
          estimatedPrice: line.price,
        );
        await restaurantPurchaseOrderItemRepository.saveItem(poItem);
      }

      purchaseOrders.insert(0, po);
      return po;
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> markPOSent(String poId) async {
    final index = purchaseOrders.indexWhere((p) => p.poId == poId);
    if (index == -1) return;

    final updated =
        purchaseOrders[index].copyWith(status: RestaurantPOStatus.sent.name);
    await restaurantPurchaseOrderRepository.savePurchaseOrder(updated);
    purchaseOrders[index] = updated;
  }

  // ==================== GOODS RECEIVING (GRN) ====================

  /// Confirms a goods receipt against [poId] — the ONLY place raw-material
  /// stock increments (mirrors retail's `confirmGRN`, but atomic here: it
  /// creates and saves the GRN + its items AND moves stock in one action).
  ///
  /// Note: unlike the ordered-item id, the GRN's own id/number are generated
  /// by [RestaurantGRNModel.create] itself (like [RestaurantPurchaseOrderModel]
  /// generates via the repository) — so this only needs the PO context and
  /// the collected receiving lines, not a pre-made grnId.
  @action
  Future<List<RestaurantGRNItemModel>> confirmGRN({
    required String poId,
    required String poNumber,
    required String supplierId,
    String? supplierName,
    required String receivedDate,
    String? notes,
    String? invoiceNumber,
    required List<GRNReceiptLine> lines,
  }) async {
    try {
      isLoading = true;
      errorMessage = null;

      final totalOrderedQty =
          lines.fold<double>(0, (sum, l) => sum + l.orderedQty);
      final totalReceivedQty =
          lines.fold<double>(0, (sum, l) => sum + l.receivedQty);
      // BILLABLE, not accepted: the supplier invoices for everything they
      // delivered, damaged units included. Accruing only the accepted value
      // under-states the payable, and a return credit note or a settled claim
      // — both of which credit `damagedQty * costPrice` — then pushes the
      // balance BELOW what is actually owed. Receiving 10 of which 2 are
      // damaged must accrue 10 and credit 2, leaving 8; accruing 8 and
      // crediting 2 left 6. Retail bills received for the same reason.
      final totalAmount = lines.fold<double>(
          0, (sum, l) => sum + (l.receivedQty * (l.costPrice ?? 0)));

      final grn = RestaurantGRNModel.create(
        poId: poId,
        poNumber: poNumber,
        supplierId: supplierId,
        supplierName: supplierName,
        receivedDate: receivedDate,
        totalOrderedQty: totalOrderedQty,
        totalReceivedQty: totalReceivedQty,
        totalAmount: totalAmount,
        status: RestaurantGRNStatus.confirmed,
        notes: notes,
        invoiceNumber: invoiceNumber,
      );

      final staffName =
          RestaurantSession.staffName ?? RestaurantSession.effectiveRole;
      final sessionId = await DayManagementService.getCurrentSessionId();

      final grnItems = <RestaurantGRNItemModel>[];

      for (final line in lines) {
        final grnItem = RestaurantGRNItemModel.create(
          grnId: grn.grnId,
          poItemId: line.poItemId,
          itemId: line.itemId,
          itemName: line.itemName,
          orderedQty: line.orderedQty,
          receivedQty: line.receivedQty,
          acceptedQty: line.acceptedQty,
          damagedQty: line.damagedQty,
          costPrice: line.costPrice,
          damagedHandling: line.damagedHandling,
        );
        await restaurantGrnItemRepository.saveItem(grnItem);
        grnItems.add(grnItem);

        if (line.acceptedQty <= 0) continue;

        final item = itemStore.getItemById(line.itemId);
        if (item == null) continue;

        // Through the store so the ObservableList entry is replaced and MobX
        // sees the receipt; stock and cost go in one write so neither can
        // clobber the other. Re-resolves internally, so two GRN lines for the
        // same item compound instead of both starting from `item`.
        final newStock = await itemStore.applyStockDelta(
          itemId: line.itemId,
          delta: line.acceptedQty,
          lastPurchaseCost: line.costPrice,
        );

        await _stockMovementRepository.saveMovement(StockMovementModel(
          id: _uuid.v4(),
          timestamp: DateTime.now(),
          itemId: item.id,
          variantId: null,
          itemName: item.name,
          type: 'in',
          quantity: line.acceptedQty,
          balanceAfter: newStock,
          reason: 'Purchase ($poNumber)',
          unit: item.unit ?? 'pcs',
          staffName: staffName,
          sessionId: sessionId,
        ));
      }

      await restaurantGrnRepository.saveGRN(grn);

      // Accrue the GRN's full received value as a payable against the
      // supplier — mirrors retail's GRN confirm, which bills the supplier for
      // the invoice regardless of what's later returned/claimed. Purchase
      // returns and supplier claims credit this balance back down when their
      // own credit events land (see RestaurantDamagedGoodsStore).
      //
      // Routed through RestaurantSupplierStore.recordBalanceMovement — the one
      // sanctioned path — so the movement also lands in the supplier's ledger
      // instead of silently changing a number nothing explains.
      if (totalAmount > 0) {
        await restaurantSupplierStore.recordBalanceMovement(
          supplierId: supplierId,
          amount: totalAmount,
          type: RestaurantSupplierLedgerType.purchase,
          description: 'Goods received',
          docNumber: grn.grnNumber,
          docId: grn.grnId,
          date: grn.receivedDate,
        );
      }

      // Roll the receiving progress up to the PO's status.
      final po = restaurantPurchaseOrderRepository.getPurchaseOrderById(poId);
      if (po != null) {
        final totalReceivedForPO =
            restaurantGrnRepository.getTotalReceivedQtyForPO(poId);

        RestaurantPOStatus newStatus;
        if (totalReceivedForPO >= po.totalItems) {
          newStatus = RestaurantPOStatus.completed;
        } else if (totalReceivedForPO > 0) {
          newStatus = RestaurantPOStatus.partiallyReceived;
        } else {
          newStatus = po.statusEnum;
        }

        final updatedPO = po.copyWith(status: newStatus.name);
        await restaurantPurchaseOrderRepository.savePurchaseOrder(updatedPO);
      }

      await loadPurchaseOrders();
      await loadGRNs();

      return grnItems;
    } finally {
      isLoading = false;
    }
  }

  // ==================== COMPUTED ====================

  @computed
  List<RestaurantPurchaseOrderModel> get receivablePOs =>
      purchaseOrders.where((po) => po.canReceive).toList();
}
