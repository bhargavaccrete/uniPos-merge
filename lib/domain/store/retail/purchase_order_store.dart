import 'package:mobx/mobx.dart';

import '../../../data/models/retail/hive_model/grn_item_model_214.dart';
import '../../../data/models/retail/hive_model/grn_model_213.dart';
import '../../../data/models/retail/hive_model/purchase_order_item_model_212.dart';
import '../../../data/models/retail/hive_model/purchase_order_model_211.dart';
import '../../../data/repositories/retail/grn_item_repository.dart';
import '../../../data/repositories/retail/grn_repository.dart';
import '../../../data/repositories/retail/purchase_order_item_repository.dart';
import '../../../data/repositories/retail/purchase_order_repository.dart';


part 'purchase_order_store.g.dart';

class PurchaseOrderStore = _PurchaseOrderStore with _$PurchaseOrderStore;

abstract class _PurchaseOrderStore with Store {
  late final PurchaseOrderRepository _poRepository;
  late final PurchaseOrderItemRepository _poItemRepository;
  late final GRNRepository _grnRepository;
  late final GRNItemRepository _grnItemRepository;

  // ==================== PURCHASE ORDER STATE ====================

  @observable
  ObservableList<PurchaseOrderModel> purchaseOrders = ObservableList<PurchaseOrderModel>();

  @observable
  ObservableList<PurchaseOrderModel> searchResults = ObservableList<PurchaseOrderModel>();

  @observable
  ObservableList<PurchaseOrderItemModel> currentPOItems = ObservableList<PurchaseOrderItemModel>();

  @observable
  String searchQuery = '';

  @observable
  PurchaseOrderModel? selectedPO;

  @observable
  POStatus? statusFilter;

  // ==================== GRN STATE ====================

  @observable
  ObservableList<GRNModel> grns = ObservableList<GRNModel>();

  @observable
  ObservableList<GRNItemModel> currentGRNItems = ObservableList<GRNItemModel>();

  @observable
  GRNModel? selectedGRN;

  @observable
  ObservableList<GRNModel> currentPOGRNs = ObservableList<GRNModel>();

  _PurchaseOrderStore() {
    _poRepository = PurchaseOrderRepository();
    _poItemRepository = PurchaseOrderItemRepository();
    _grnRepository = GRNRepository();
    _grnItemRepository = GRNItemRepository();
    _init();
  }

  Future<void> _init() async {
    await loadPurchaseOrders();
    await loadGRNs();
  }

  // ==================== PURCHASE ORDER OPERATIONS ====================

  @action
  Future<void> loadPurchaseOrders() async {
    final loaded = await _poRepository.getAllPurchaseOrders();
    purchaseOrders.clear();
    purchaseOrders.addAll(loaded);
  }

  @action
  Future<void> loadPurchaseOrdersByStatus(POStatus status) async {
    statusFilter = status;
    final loaded = await _poRepository.getPurchaseOrdersByStatus(status);
    purchaseOrders.clear();
    purchaseOrders.addAll(loaded);
  }

  @action
  Future<void> loadActivePurchaseOrders() async {
    final loaded = await _poRepository.getActivePurchaseOrders();
    purchaseOrders.clear();
    purchaseOrders.addAll(loaded);
  }

  @action
  Future<String> addPurchaseOrder(PurchaseOrderModel po, List<PurchaseOrderItemModel> items) async {
    // Calculate totals
    final totalItems = items.fold<int>(0, (sum, item) => sum + item.orderedQty);
    final estimatedTotal = items.fold<double>(0.0, (sum, item) => sum + (item.estimatedTotal ?? 0));

    final updatedPO = po.copyWith(
      totalItems: totalItems,
      estimatedTotal: estimatedTotal,
    );

    await _poRepository.addPurchaseOrder(updatedPO);
    await _poItemRepository.addPOItems(items);
    purchaseOrders.insert(0, updatedPO);

    return updatedPO.poId;
  }

  @action
  Future<void> updatePurchaseOrder(PurchaseOrderModel po, List<PurchaseOrderItemModel> items) async {
    // Calculate totals
    final totalItems = items.fold<int>(0, (sum, item) => sum + item.orderedQty);
    final estimatedTotal = items.fold<double>(0.0, (sum, item) => sum + (item.estimatedTotal ?? 0));

    final updatedPO = po.copyWith(
      totalItems: totalItems,
      estimatedTotal: estimatedTotal,
    );

    await _poRepository.updatePurchaseOrder(updatedPO);

    // Delete old items and add new ones
    await _poItemRepository.deleteItemsByPOId(po.poId);
    await _poItemRepository.addPOItems(items);

    final index = purchaseOrders.indexWhere((p) => p.poId == po.poId);
    if (index != -1) {
      purchaseOrders[index] = updatedPO;
    }
  }

  @action
  Future<void> deletePurchaseOrder(String poId) async {
    await _poRepository.deletePurchaseOrder(poId);
    await _poItemRepository.deleteItemsByPOId(poId);
    purchaseOrders.removeWhere((p) => p.poId == poId);

    if (selectedPO?.poId == poId) {
      selectedPO = null;
      currentPOItems.clear();
    }
  }

  @action
  Future<void> updatePOStatus(String poId, POStatus newStatus) async {
    await _poRepository.updatePOStatus(poId, newStatus);

    final index = purchaseOrders.indexWhere((p) => p.poId == poId);
    if (index != -1) {
      final updatedPO = purchaseOrders[index].copyWith(status: newStatus.name);
      purchaseOrders[index] = updatedPO;
    }

    if (selectedPO?.poId == poId) {
      selectedPO = selectedPO!.copyWith(status: newStatus.name);
    }
  }

  @action
  Future<void> searchPurchaseOrders(String query) async {
    searchQuery = query;

    if (query.isEmpty) {
      searchResults.clear();
      return;
    }

    final results = await _poRepository.searchPurchaseOrders(query);
    searchResults.clear();
    searchResults.addAll(results);
  }

  @action
  Future<void> loadPOItems(String poId) async {
    final items = await _poItemRepository.getItemsByPOId(poId);
    currentPOItems.clear();
    currentPOItems.addAll(items);
  }

  @action
  Future<void> selectPO(PurchaseOrderModel? po) async {
    selectedPO = po;
    if (po != null) {
      await loadPOItems(po.poId);
      await loadPOGRNs(po.poId);
    } else {
      currentPOItems.clear();
      currentPOGRNs.clear();
    }
  }

  @action
  Future<void> loadPOGRNs(String poId) async {
    final loaded = await _grnRepository.getGRNsByPOId(poId);
    currentPOGRNs.clear();
    currentPOGRNs.addAll(loaded.where((grn) => grn.statusEnum == GRNStatus.confirmed));
  }

  /// Get GRN items for a specific GRN
  Future<List<GRNItemModel>> getGRNItemsForGRN(String grnId) async {
    return await _grnItemRepository.getItemsByGRNId(grnId);
  }

  @action
  void clearPOSelection() {
    selectedPO = null;
    currentPOItems.clear();
    searchResults.clear();
    searchQuery = '';
  }

  @action
  Future<void> clearStatusFilter() async {
    statusFilter = null;
    await loadPurchaseOrders();
  }

  Future<String> generatePONumber() {
    return _poRepository.generatePONumber();
  }

  /// Cancel a PO. **Draft only** — once it's been sent to the supplier or any
  /// goods have arrived, cancelling would strand the GRNs that reference it.
  /// Returns false when the PO isn't in a cancellable state.
  @action
  Future<bool> cancelPurchaseOrder(String poId) async {
    final po = _poRepository.getPurchaseOrderById(poId);
    if (po == null || po.statusEnum != POStatus.draft) return false;

    await updatePOStatus(poId, POStatus.cancelled);
    return true;
  }

  /// A PO may only be deleted while it is still a draft **and** nothing has
  /// been received against it. A GRN stores `poId`, so deleting the PO would
  /// orphan the receiving history and the stock it already moved.
  Future<bool> canDeletePurchaseOrder(String poId) async {
    final po = _poRepository.getPurchaseOrderById(poId);
    if (po == null || po.statusEnum != POStatus.draft) return false;

    final poGRNs = await _grnRepository.getGRNsByPOId(poId);
    return poGRNs.isEmpty;
  }

  // ==================== GRN OPERATIONS ====================

  @action
  Future<void> loadGRNs() async {
    final loaded = await _grnRepository.getAllGRNs();
    grns.clear();
    grns.addAll(loaded);
  }

  @action
  Future<void> loadGRNsByPO(String poId) async {
    final loaded = await _grnRepository.getGRNsByPOId(poId);
    grns.clear();
    grns.addAll(loaded);
  }

  @action
  Future<void> loadDraftGRNs() async {
    final loaded = await _grnRepository.getDraftGRNs();
    grns.clear();
    grns.addAll(loaded);
  }

  @action
  Future<String> createGRN(GRNModel grn, List<GRNItemModel> items) async {
    // Calculate totals
    final totalOrderedQty = items.fold<int>(0, (sum, item) => sum + item.orderedQty);
    final totalReceivedQty = items.fold<int>(0, (sum, item) => sum + item.receivedQty);
    final totalAmount = items.fold<double>(0.0, (sum, item) => sum + (item.totalAmount ?? 0));

    final updatedGRN = grn.copyWith(
      totalOrderedQty: totalOrderedQty,
      totalReceivedQty: totalReceivedQty,
      totalAmount: totalAmount,
    );

    await _grnRepository.addGRN(updatedGRN);
    await _grnItemRepository.addGRNItems(items);
    grns.insert(0, updatedGRN);

    return updatedGRN.grnId;
  }

  @action
  Future<void> updateGRN(GRNModel grn, List<GRNItemModel> items) async {
    // Calculate totals
    final totalOrderedQty = items.fold<int>(0, (sum, item) => sum + item.orderedQty);
    final totalReceivedQty = items.fold<int>(0, (sum, item) => sum + item.receivedQty);
    final totalAmount = items.fold<double>(0.0, (sum, item) => sum + (item.totalAmount ?? 0));

    final updatedGRN = grn.copyWith(
      totalOrderedQty: totalOrderedQty,
      totalReceivedQty: totalReceivedQty,
      totalAmount: totalAmount,
    );

    await _grnRepository.updateGRN(updatedGRN);

    // Delete old items and add new ones
    await _grnItemRepository.deleteItemsByGRNId(grn.grnId);
    await _grnItemRepository.addGRNItems(items);

    final index = grns.indexWhere((g) => g.grnId == grn.grnId);
    if (index != -1) {
      grns[index] = updatedGRN;
    }
  }

  @action
  Future<void> deleteGRN(String grnId) async {
    await _grnRepository.deleteGRN(grnId);
    await _grnItemRepository.deleteItemsByGRNId(grnId);
    grns.removeWhere((g) => g.grnId == grnId);

    if (selectedGRN?.grnId == grnId) {
      selectedGRN = null;
      currentGRNItems.clear();
    }
  }

  @action
  Future<void> loadGRNItems(String grnId) async {
    final items = await _grnItemRepository.getItemsByGRNId(grnId);
    currentGRNItems.clear();
    currentGRNItems.addAll(items);
  }

  @action
  Future<void> selectGRN(GRNModel? grn) async {
    selectedGRN = grn;
    if (grn != null) {
      await loadGRNItems(grn.grnId);
    } else {
      currentGRNItems.clear();
    }
  }

  @action
  void clearGRNSelection() {
    selectedGRN = null;
    currentGRNItems.clear();
  }

  Future<String> generateGRNNumber() {
    return _grnRepository.generateGRNNumber();
  }

  /// Confirm GRN - This is where stock gets updated!
  /// Returns the list of GRN items that were confirmed (for stock update)
  @action
  Future<List<GRNItemModel>> confirmGRN(String grnId) async {
    final grn = _grnRepository.getGRNById(grnId);
    if (grn == null || grn.statusEnum != GRNStatus.draft) {
      return [];
    }

    // Update GRN status to confirmed
    await _grnRepository.updateGRNStatus(grnId, GRNStatus.confirmed);

    // Get GRN items for stock update
    final items = await _grnItemRepository.getItemsByGRNId(grnId);

    // Update local state
    final index = grns.indexWhere((g) => g.grnId == grnId);
    if (index != -1) {
      grns[index] = grns[index].copyWith(status: GRNStatus.confirmed.name);
    }

    // Check if PO should be marked as completed
    await _updatePOStatusAfterGRN(grn.poId);

    return items;
  }

  /// Cancel a draft GRN
  @action
  Future<void> cancelGRN(String grnId) async {
    await _grnRepository.updateGRNStatus(grnId, GRNStatus.cancelled);

    final index = grns.indexWhere((g) => g.grnId == grnId);
    if (index != -1) {
      grns[index] = grns[index].copyWith(status: GRNStatus.cancelled.name);
    }
  }

  /// Update PO status based on receiving progress
  Future<void> _updatePOStatusAfterGRN(String poId) async {
    final po = _poRepository.getPurchaseOrderById(poId);
    if (po == null) return;

    // Get all PO items
    final poItems = await _poItemRepository.getItemsByPOId(poId);
    final totalOrdered = poItems.fold<int>(0, (sum, item) => sum + item.orderedQty);

    // Get total received from all confirmed GRNs
    final totalReceived = await _grnRepository.getTotalReceivedQtyForPO(poId);

    POStatus newStatus;
    if (totalReceived >= totalOrdered) {
      newStatus = POStatus.fullyCompleted;
    } else if (totalReceived > 0) {
      newStatus = POStatus.partiallyCompleted;
    } else {
      return; // No change needed
    }

    await updatePOStatus(poId, newStatus);
  }

  // ==================== HELPER METHODS ====================

  /// Get POs that can receive items (sent or partially completed)
  @computed
  List<PurchaseOrderModel> get receivablePOs {
    return purchaseOrders.where((po) => po.canReceive).toList();
  }

  /// Get list of items for creating a new GRN from a PO
  Future<List<GRNItemModel>> prepareGRNItemsFromPO(String poId, String grnId) async {
    final poItems = await _poItemRepository.getItemsByPOId(poId);

    // Get already received quantities for each PO item
    final grnItems = <GRNItemModel>[];

    for (final poItem in poItems) {
      final alreadyReceived = await _grnItemRepository.getTotalReceivedQtyForPOItem(poItem.poItemId);
      final remainingQty = poItem.orderedQty - alreadyReceived;

      if (remainingQty > 0) {
        grnItems.add( GRNItemModel.create(
          grnId: grnId,
          poItemId: poItem.poItemId,
          variantId: poItem.variantId,
          productId: poItem.productId,
          productName: poItem.productName,
          variantInfo: poItem.variantInfo,
          orderedQty: remainingQty, // Only the remaining quantity
          receivedQty: remainingQty, // Default to full receipt
          acceptedQty: remainingQty, // Default to full acceptance (no damage)
          costPrice: poItem.estimatedPrice,
        ));
      }
    }

    return grnItems;
  }

  /// Get already received quantity for a specific PO item (from confirmed GRNs)
  Future<int> getReceivedQtyForPOItem(String poItemId) async {
    return await _grnItemRepository.getTotalReceivedQtyForPOItem(poItemId);
  }

  // ==================== RECEIVING PROGRESS ====================

  /// Header-level progress for a PO, derived from the already-loaded [grns]
  /// list. Synchronous on purpose — list cards render one of these per row and
  /// a FutureBuilder per card would thrash. Reads the `grns` observable, so it
  /// stays live inside an Observer.
  ///
  /// Only CONFIRMED GRNs count; a draft GRN has moved no stock and owes no
  /// money, exactly as [confirmGRN] treats it.
  POReceiptProgress progressFor(PurchaseOrderModel po) {
    var received = 0;
    var acceptedAmount = 0.0;

    for (final grn in grns) {
      if (grn.poId != po.poId) continue;
      if (grn.statusEnum != GRNStatus.confirmed) continue;
      received += grn.totalReceivedQty;
      // GRN.totalAmount is built from acceptedQty * costPrice, so it is
      // already the accepted value — damaged units are excluded.
      acceptedAmount += grn.totalAmount ?? 0;
    }

    return POReceiptProgress(
      ordered: po.totalItems,
      received: received,
      acceptedAmount: acceptedAmount,
    );
  }

  /// Per-PO-item receiving detail, keyed by `poItemId`. Aggregated across
  /// CONFIRMED GRNs only. Async because it walks GRN items — fine for a single
  /// PO's detail sheet, too slow for a list.
  Future<Map<String, POItemReceipt>> getPOItemReceipts(String poId) async {
    final poItems = await _poItemRepository.getItemsByPOId(poId);
    final receipts = <String, POItemReceipt>{};

    for (final poItem in poItems) {
      final grnItems =
          await _grnItemRepository.getItemsByPOItemId(poItem.poItemId);

      var received = 0;
      var accepted = 0;
      var damaged = 0;

      for (final grnItem in grnItems) {
        final grn = _grnRepository.getGRNById(grnItem.grnId);
        if (grn == null || grn.statusEnum != GRNStatus.confirmed) continue;
        received += grnItem.receivedQty;
        accepted += grnItem.acceptedQty;
        damaged += grnItem.damagedQty ?? 0;
      }

      receipts[poItem.poItemId] = POItemReceipt(
        ordered: poItem.orderedQty,
        received: received,
        accepted: accepted,
        damaged: damaged,
      );
    }

    return receipts;
  }

  // ==================== COMPUTED PROPERTIES ====================

  @computed
  int get poCount => purchaseOrders.length;


  @computed
  int get draftPOCount => purchaseOrders.where((po) => po.statusEnum == POStatus.draft).length;

  @computed
  int get sentPOCount => purchaseOrders.where((po) => po.statusEnum == POStatus.sent).length;

  @computed
  int get pendingReceivingCount => purchaseOrders.where((po) => po.canReceive).length;

  @computed
  bool get hasPOSelection => selectedPO != null;

  @computed
  bool get hasGRNSelection => selectedGRN != null;

  @computed
  int get grnCount => grns.length;

  @computed
  int get draftGRNCount => grns.where((grn) => grn.statusEnum == GRNStatus.draft).length;
}

/// Header-level receiving progress for one PO.
///
/// [remaining] deliberately tracks [received], not [accepted] — that mirrors
/// the existing completion rule (a PO closes on what physically arrived, while
/// stock only takes what was accepted). Damaged units therefore reduce
/// [accepted] without leaving anything outstanding on the order.
class POReceiptProgress {
  final int ordered;
  final int received;
  final double acceptedAmount;

  const POReceiptProgress({
    required this.ordered,
    required this.received,
    required this.acceptedAmount,
  });

  int get remaining => (ordered - received).clamp(0, ordered);
  bool get hasReceipts => received > 0;
}

/// Per-line receiving detail for a PO item.
class POItemReceipt {
  final int ordered;
  final int received;
  final int accepted;
  final int damaged;

  const POItemReceipt({
    required this.ordered,
    required this.received,
    required this.accepted,
    required this.damaged,
  });

  int get remaining => (ordered - received).clamp(0, ordered);
}