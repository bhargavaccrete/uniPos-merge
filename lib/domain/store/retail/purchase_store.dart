import 'package:mobx/mobx.dart';

import '../../../data/models/retail/hive_model/purchase_Item_model_206.dart';
import '../../../data/models/retail/hive_model/purchase_model_207.dart';
import '../../../data/repositories/retail/purchase_item_repository.dart';
import '../../../data/repositories/retail/purchase_repository.dart';


part 'purchase_store.g.dart';

class PurchaseStore = _PurchaseStore with _$PurchaseStore;

abstract class _PurchaseStore with Store {
  late final PurchaseRepository _purchaseRepository;
  late final PurchaseItemRepository _purchaseItemRepository;

  @observable
  ObservableList<PurchaseModel> purchases = ObservableList<PurchaseModel>();

  @observable
  ObservableList<PurchaseModel> searchResults = ObservableList<PurchaseModel>();

  @observable
  ObservableList<PurchaseItemModel> currentPurchaseItems = ObservableList<PurchaseItemModel>();

  @observable
  String searchQuery = '';

  @observable
  PurchaseModel? selectedPurchase;

  @observable
  String? selectedSupplierId;

  _PurchaseStore() {
    _purchaseRepository = PurchaseRepository();
    _purchaseItemRepository = PurchaseItemRepository();
    _init();
  }

  Future<void> _init() async {
    await loadPurchases();
  }

  // ==================== PURCHASE OPERATIONS ====================

  @action
  Future<void> loadPurchases() async {
    final loadedPurchases = await _purchaseRepository.getAllPurchases();
    purchases.clear();
    purchases.addAll(loadedPurchases);
  }

  @action
  Future<void> addPurchase(PurchaseModel purchase, List<PurchaseItemModel> items) async {
    await _purchaseRepository.addPurchase(purchase);
    await _purchaseItemRepository.addPurchaseItems(items);
    purchases.insert(0, purchase);
  }

  @action
  Future<void> updatePurchase(PurchaseModel purchase, List<PurchaseItemModel> items) async {
    await _purchaseRepository.updatePurchase(purchase);

    // Delete old items and add new ones
    await _purchaseItemRepository.deleteItemsByPurchaseId(purchase.purchaseId);
    await _purchaseItemRepository.addPurchaseItems(items);

    final index = purchases.indexWhere((p) => p.purchaseId == purchase.purchaseId);
    if (index != -1) {
      purchases[index] = purchase;
    }
  }

  @action
  Future<void> deletePurchase(String purchaseId) async {
    await _purchaseRepository.deletePurchase(purchaseId);
    await _purchaseItemRepository.deleteItemsByPurchaseId(purchaseId);
    purchases.removeWhere((p) => p.purchaseId == purchaseId);

    if (selectedPurchase?.purchaseId == purchaseId) {
      selectedPurchase = null;
      currentPurchaseItems.clear();
    }
  }

  @action
  Future<void> searchPurchases(String query) async {
    searchQuery = query;

    if (query.isEmpty) {
      searchResults.clear();
      return;
    }

    final results = await _purchaseRepository.searchPurchases(query);
    searchResults.clear();
    searchResults.addAll(results);
  }

  @action
  Future<void> loadPurchasesBySupplier(String supplierId) async {
    selectedSupplierId = supplierId;
    final supplierPurchases = await _purchaseRepository.getPurchasesBySupplier(supplierId);
    purchases.clear();
    purchases.addAll(supplierPurchases);
  }

  @action
  Future<void> loadPurchaseItems(String purchaseId) async {
    final items = await _purchaseItemRepository.getItemsByPurchaseId(purchaseId);
    currentPurchaseItems.clear();
    currentPurchaseItems.addAll(items);
  }

  @action
  Future<void> selectPurchase(PurchaseModel? purchase) async {
    selectedPurchase = purchase;
    if (purchase != null) {
      await loadPurchaseItems(purchase.purchaseId);
    } else {
      currentPurchaseItems.clear();
    }
  }

  @action
  void clearSelection() {
    selectedPurchase = null;
    currentPurchaseItems.clear();
    searchResults.clear();
    searchQuery = '';
  }

  @action
  Future<void> clearSupplierFilter() async {
    selectedSupplierId = null;
    await loadPurchases();
  }

  // ==================== PURCHASE ITEM OPERATIONS ====================

  @action
  Future<List<PurchaseItemModel>> getItemsByPurchaseId(String purchaseId) async {
    return await _purchaseItemRepository.getItemsByPurchaseId(purchaseId);
  }

  @action
  Future<List<PurchaseItemModel>> getVariantPurchaseHistory(String variantId) async {
    return await _purchaseItemRepository.getVariantPurchaseHistory(variantId);
  }

  @action
  Future<List<PurchaseItemModel>> getProductPurchaseHistory(String productId) async {
    return await _purchaseItemRepository.getProductPurchaseHistory(productId);
  }

  @action
  Future<double> getLastPurchasePrice(String variantId) async {
    return await _purchaseItemRepository.getLastPurchasePrice(variantId);
  }

  @action
  Future<double> getAverageCostPrice(String variantId) async {
    return await _purchaseItemRepository.getAverageCostPrice(variantId);
  }

  // ==================== COMPUTED PROPERTIES ====================

  @computed
  int get purchaseCount => purchases.length;

  @computed
  bool get hasSelection => selectedPurchase != null;

  @computed
  double get totalPurchaseAmount =>
      purchases.fold(0.0, (sum, purchase) => sum + purchase.totalAmount);

  @computed
  int get totalItems => currentPurchaseItems.length;
}