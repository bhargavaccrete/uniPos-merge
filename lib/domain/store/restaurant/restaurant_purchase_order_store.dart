import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:uuid/uuid.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_grn_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_grn_item_model.dart';
import 'package:billberrylite/domain/services/restaurant/restaurant_grn_receiving.dart';

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

/// Purchase-order rules that need no store state — kept outside the MobX
/// store so they are reachable as plain statics (a static on the private
/// _RestaurantPurchaseOrderStore is not visible through the public alias).
class RestaurantPORules {
  RestaurantPORules._();

  /// Shown when a receipt for the same PO is already being saved (S-06).
  static const String receiptInProgressMessage =
      'This receipt is already being saved.';

  /// Why an item with variants cannot be on a purchase order (BLK-18).
  static String variantItemMessage(String itemName) =>
      '$itemName has variants. Its stock is kept per variant, which a purchase '
      'order cannot record — adjust it in Manage Inventory instead.';

  /// Refuses a PO that contains an item with variants: PO and GRN lines carry
  /// no variant, so receiving it would add stock nothing sells from.
  static void refuseVariantItems(List<PurchaseOrderLine> lines) {
    for (final line in lines) {
      final item = itemStore.getItemById(line.itemId);
      if (item != null && item.hasVariants) {
        throw StateError(variantItemMessage(item.name));
      }
    }
  }

  /// Tolerance for comparing received against ordered — quantities are
  /// doubles (goods by weight), and three receipts of 3.5 against 10.5 sum to
  /// 10.499999999999998. Same value as retail's `_qtyEpsilon`.
  static const double _qtyEpsilon = 1e-6;

  /// The PO's status after a receipt, decided PER LINE — retail's
  /// `_updatePOStatusAfterGRN` rule.
  ///
  /// Comparing the PO's summed totals let a surplus on one line cover a
  /// shortage on another: A 10 / B 10 received as A 15 / B 5 summed to 20 of
  /// 20 and closed the order with five B never delivered — and a completed PO
  /// can no longer be received against. Over-receipt still satisfies its OWN
  /// line (`>=`). A cancelled order stays cancelled; an order with no lines or
  /// nothing ordered never auto-completes (`0 >= 0`).
  static RestaurantPOStatus statusAfterReceipt(RestaurantPurchaseOrderModel po) {
    if (po.statusEnum == RestaurantPOStatus.cancelled) return po.statusEnum;

    final lines = restaurantPurchaseOrderItemRepository.getItemsByPOId(po.poId);
    final totalOrdered = lines.fold<double>(0, (sum, l) => sum + l.orderedQty);
    if (lines.isEmpty || totalOrdered <= 0) return po.statusEnum;

    var allSatisfied = true;
    var anyReceived = false;
    for (final line in lines) {
      final received =
          restaurantGrnItemRepository.getTotalReceivedQtyForPOItem(line.poItemId);
      if (received > 0) anyReceived = true;
      if (received < line.orderedQty - _qtyEpsilon) allSatisfied = false;
    }

    if (allSatisfied) return RestaurantPOStatus.completed;
    if (anyReceived) return RestaurantPOStatus.partiallyReceived;
    return po.statusEnum;
  }
}

/// Restaurant-scoped Purchase Order / GRN pipeline store — mirrors retail's
/// `PurchaseOrderStore` but scoped to `Items`/no-variant world (see
/// docs/inventory_recipe_system_plan.md §6). Confirming a GRN is the one
/// place raw-material stock moves; that whole flow lives in [confirmGRN] so
/// it stays atomic instead of being split across store+screen like retail's.
class RestaurantPurchaseOrderStore = _RestaurantPurchaseOrderStore
    with _$RestaurantPurchaseOrderStore;

abstract class _RestaurantPurchaseOrderStore with Store {
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
    // BLK-18: before anything is written.
    RestaurantPORules.refuseVariantItems(lines);

    try {
      isLoading = true;
      errorMessage = null;

      final poId = _uuid.v4();
      final poNumber =
          await restaurantPurchaseOrderRepository.generatePONumber();

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

  /// Rewrites a DRAFT purchase order in place. Returns the updated PO, or
  /// null when the order may no longer be edited.
  ///
  /// Takes [poId] rather than a model because the caller holds a snapshot
  /// captured when the card was tapped — re-reading here means the draft-only
  /// rule is enforced against current state, not against what another screen
  /// saw a minute ago.
  ///
  /// The draft check MUST stay in this store, not only in the UI. Line rows
  /// are deleted and recreated (the item model has no copyWith), which mints
  /// fresh poItemIds — and RestaurantGRNItemModel.poItemId points at those.
  /// Editing a PO that had receipts against it would leave every GRN line
  /// pointing at a key nothing queries: the receipts stay in the box but
  /// getTotalReceivedQtyForPOItem silently returns 0 for all of them.
  @action
  Future<RestaurantPurchaseOrderModel?> updatePurchaseOrder({
    required String poId,
    required String supplierId,
    String? supplierName,
    required String expectedDeliveryDate,
    String? notes,
    required List<PurchaseOrderLine> lines,
  }) async {
    final existing =
        restaurantPurchaseOrderRepository.getPurchaseOrderById(poId);
    if (existing == null || !existing.canEdit) return null;
    // Belt and braces: a draft can't have receipts today (confirmGRN needs
    // canReceive), so this only fires on data written by an older build.
    if (restaurantGrnRepository.getGRNsByPOId(poId).isNotEmpty) return null;
    // BLK-18: before anything is written.
    RestaurantPORules.refuseVariantItems(lines);

    try {
      isLoading = true;
      errorMessage = null;

      // Same folds as createPurchaseOrder. totalItems is summed QUANTITY, not
      // a line count — the GRN rollup compares received qty against it, so
      // lines.length here would close a 500kg PO after 3 units arrived.
      final totalItems = lines.fold<double>(0, (sum, l) => sum + l.qty);
      final estimatedTotal =
          lines.fold<double>(0, (sum, l) => sum + (l.qty * (l.price ?? 0)));

      // Built explicitly rather than via copyWith: copyWith coalesces with
      // `notes ?? this.notes`, so clearing the notes field would silently keep
      // the old note. poId / poNumber / createdAt / status are carried over —
      // the number is what a human quotes, and a preserved createdAt keeps the
      // newest-first list ordering unchanged by an edit.
      final updated = RestaurantPurchaseOrderModel(
        poId: existing.poId,
        poNumber: existing.poNumber,
        supplierId: supplierId,
        supplierName: supplierName,
        expectedDeliveryDate: expectedDeliveryDate,
        totalItems: totalItems,
        estimatedTotal: estimatedTotal,
        status: existing.status,
        notes: notes,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now().toIso8601String(),
      );

      // Rows before header. Hive has no transaction, so if the line loop
      // throws part-way the header still describes the OLD totals rather than
      // advertising figures for rows that were never written.
      await restaurantPurchaseOrderItemRepository.deleteItemsByPOId(poId);
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
      await restaurantPurchaseOrderRepository.savePurchaseOrder(updated);

      final index = purchaseOrders.indexWhere((p) => p.poId == poId);
      if (index != -1) purchaseOrders[index] = updated;
      return updated;
    } finally {
      isLoading = false;
    }
  }

  /// Permanently removes a DRAFT purchase order and its line rows.
  /// Returns false when the guard rejects.
  @action
  Future<bool> deletePurchaseOrder(String poId) async {
    if (!canDeletePurchaseOrder(poId)) return false;

    // Items first, header second — the inverse of retail's order, deliberately.
    // A failure between the two then leaves a header with no lines: visible in
    // the list and re-deletable. The other way round leaves orphan item rows
    // keyed by a poId nothing queries, which accumulate invisibly forever.
    await restaurantPurchaseOrderItemRepository.deleteItemsByPOId(poId);
    await restaurantPurchaseOrderRepository.deletePurchaseOrder(poId);
    purchaseOrders.removeWhere((p) => p.poId == poId);
    return true;
  }

  /// Draft-only AND nothing received against it: a GRN stores poId, so
  /// deleting the PO would orphan the receiving history and the stock it
  /// already moved.
  ///
  /// Synchronous — unlike retail's, because both reads here are. Reads
  /// repositories rather than observables, so it needs no @action.
  bool canDeletePurchaseOrder(String poId) {
    final po = restaurantPurchaseOrderRepository.getPurchaseOrderById(poId);
    if (po == null || !po.canEdit) return false;
    return restaurantGrnRepository.getGRNsByPOId(poId).isEmpty;
  }

  // ==================== GOODS RECEIVING (GRN) ====================

  /// Confirms a goods receipt against [poId] — the ONLY place raw-material
  /// stock increments.
  ///
  /// Saves the GRN header as a DRAFT and its lines, then hands it to
  /// [RestaurantGrnReceiving.complete] (stock once per line, supplier payable,
  /// damaged-goods documents, and only then confirmed + PO status). A stop
  /// part-way leaves the draft for [resumeInterruptedReceipts]. A second
  /// confirm for the same PO while one is running is refused with a
  /// [StateError] — a double tap cannot save the receipt twice.
  ///
  /// Note: the GRN's own id is generated by [RestaurantGRNModel.create], but
  /// its NUMBER is minted here from the repository's shared
  /// `DocumentNumberService` counter — that writes to Hive, so it cannot run
  /// inside a synchronous factory. This still only needs the PO context and
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
    // Claimed synchronously, before any await, so a second call arriving
    // while this one runs always sees it.
    if (!_receivingPoIds.add(poId)) {
      throw StateError(RestaurantPORules.receiptInProgressMessage);
    }
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

      // A DRAFT until every step below has run — a draft counts nowhere (PO
      // completion reads confirmed receipts only) and is what a resume finds.
      final grn = RestaurantGRNModel.create(
        grnNumber: await restaurantGrnRepository.generateGRNNumber(),
        poId: poId,
        poNumber: poNumber,
        supplierId: supplierId,
        supplierName: supplierName,
        receivedDate: receivedDate,
        totalOrderedQty: totalOrderedQty,
        totalReceivedQty: totalReceivedQty,
        totalAmount: totalAmount,
        status: RestaurantGRNStatus.draft,
        notes: notes,
        invoiceNumber: invoiceNumber,
      );
      await restaurantGrnRepository.saveGRN(grn);
      _checkpoint('afterDraftHeader');

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
      }
      _checkpoint('afterLines');

      // Stock (once per line), supplier payable, damaged-goods documents,
      // then confirmed + the PO status (BLK-17) — see RestaurantGrnReceiving.
      try {
        await RestaurantGrnReceiving.complete(grn, lines: grnItems);
      } finally {
        await loadPurchaseOrders();
        await loadGRNs();
      }

      return grnItems;
    } finally {
      _receivingPoIds.remove(poId);
      isLoading = false;
    }
  }

  /// POs with a confirm running — see [confirmGRN].
  final Set<String> _receivingPoIds = {};

  /// A header/lines checkpoint for fault-injection tests; the later ones live
  /// in [RestaurantGrnReceiving].
  void _checkpoint(String name) => RestaurantGrnReceiving.checkpoint(name);

  /// Finishes every receipt a stop left as a DRAFT (see
  /// [RestaurantGrnReceiving]). Returns how many were completed. Never
  /// throws: one that fails again stays a draft for the next attempt. Cheap
  /// when there are none. Run at startup and when the purchase screens open.
  Future<int> resumeInterruptedReceipts() async {
    final drafts = restaurantGrnRepository
        .getAllGRNs()
        .where((g) =>
            g.statusEnum == RestaurantGRNStatus.draft &&
            !RestaurantGrnReceiving.isCompleting(g.grnId))
        .toList();
    if (drafts.isEmpty) return 0;

    var done = 0;
    try {
      await itemStore.ensureLoaded();
    } catch (e) {
      debugPrint('GRN resume: items not loaded: $e');
      return 0;
    }
    for (final grn in drafts) {
      try {
        if (await RestaurantGrnReceiving.complete(grn)) done++;
      } catch (e) {
        debugPrint('GRN resume failed for ${grn.grnNumber}: $e');
      }
    }
    if (done > 0) {
      await loadPurchaseOrders();
      await loadGRNs();
    }
    return done;
  }

  // ==================== COMPUTED ====================

  @computed
  List<RestaurantPurchaseOrderModel> get receivablePOs =>
      purchaseOrders.where((po) => po.canReceive).toList();
}
