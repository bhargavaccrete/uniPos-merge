import 'package:mobx/mobx.dart';

import '../../../data/models/retail/hive_model/hold_sale_item_model_210.dart';
import '../../../data/models/retail/hive_model/hold_sale_model_209.dart';
import '../../../data/repositories/retail/hold_sale_repository.dart';


part 'hold_sale_store.g.dart';

class HoldSaleStore = _HoldSaleStore with _$HoldSaleStore;

abstract class _HoldSaleStore with Store {
  final HoldSaleRepository _repository;

  _HoldSaleStore(this._repository);

  @observable
  ObservableList<HoldSaleModel> holdSales = ObservableList<HoldSaleModel>();

  @observable
  ObservableList<HoldSaleItemModel> currentHoldSaleItems = ObservableList<HoldSaleItemModel>();

  @observable
  HoldSaleModel? selectedHoldSale;

  @observable
  ObservableList<HoldSaleModel> searchResults = ObservableList<HoldSaleModel>();

  @observable
  bool isLoading = false;

  @computed
  int get holdSaleCount => holdSales.length;

  @computed
  double get totalHoldSalesValue => holdSales.fold<double>(0.0, (sum, sale) => sum + sale.subtotal);

  @computed
  int get totalItemsCount => currentHoldSaleItems.length;

  /// Initialize and load all hold sales
  @action
  Future<void> init() async {
    await _repository.init();
    await loadHoldSales();
  }

  /// Load all hold sales
  @action
  Future<void> loadHoldSales() async {
    isLoading = true;
    try {
      final sales = await _repository.getAllHoldSales();
      // Sort by most recent first
      sales.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      holdSales = ObservableList.of(sales);
    } finally {
      isLoading = false;
    }
  }

  /// Add a new hold sale with items
  @action
  Future<void> addHoldSale(HoldSaleModel holdSale, List<HoldSaleItemModel> items) async {
    await _repository.addHoldSale(holdSale);
    await _repository.addHoldSaleItems(items);
    await loadHoldSales();
  }

  /// Get hold sale by ID
  @action
  Future<HoldSaleModel?> getHoldSaleById(String holdSaleId) async {
    return await _repository.getHoldSaleById(holdSaleId);
  }

  /// Select a hold sale and load its items
  @action
  Future<void> selectHoldSale(HoldSaleModel holdSale) async {
    selectedHoldSale = holdSale;
    final items = await _repository.getItemsByHoldSaleId(holdSale.holdSaleId);
    currentHoldSaleItems = ObservableList.of(items);
  }

  /// Clear selection
  @action
  void clearSelection() {
    selectedHoldSale = null;
    currentHoldSaleItems.clear();
  }

  /// Delete a hold sale
  @action
  Future<void> deleteHoldSale(String holdSaleId) async {
    await _repository.deleteHoldSale(holdSaleId);
    await loadHoldSales();
    if (selectedHoldSale?.holdSaleId == holdSaleId) {
      clearSelection();
    }
  }

  /// Update hold sale
  @action
  Future<void> updateHoldSale(HoldSaleModel holdSale) async {
    await _repository.updateHoldSale(holdSale);
    await loadHoldSales();
  }

  /// Search hold sales by customer name or note
  @action
  Future<void> searchHoldSales(String query) async {
    if (query.isEmpty) {
      searchResults.clear();
      return;
    }

    final results = await _repository.searchHoldSales(query);
    searchResults = ObservableList.of(results);
  }

  /// Get items for a specific hold sale
  @action
  Future<List<HoldSaleItemModel>> getItemsForHoldSale(String holdSaleId) async {
    return await _repository.getItemsByHoldSaleId(holdSaleId);
  }

  /// Get oldest hold sale
  @action
  Future<HoldSaleModel?> getOldestHoldSale() async {
    return await _repository.getOldestHoldSale();
  }

  /// Clear all hold sales
  @action
  Future<void> clearAllHoldSales() async {
    await _repository.clearAllHoldSales();
    await loadHoldSales();
    clearSelection();
  }
}