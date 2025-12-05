import 'package:mobx/mobx.dart';
import 'package:unipos/data/models/retail/hive_model/supplier_model_205.dart';
import 'package:unipos/data/repositories/retail/supplier_repository.dart';


part 'supplier_store.g.dart';

class SupplierStore = _SupplierStore with _$SupplierStore;

abstract class _SupplierStore with Store {
  late final SupplierRepository _supplierRepository;

  @observable
  ObservableList<SupplierModel> suppliers = ObservableList<SupplierModel>();

  @observable
  ObservableList<SupplierModel> searchResults = ObservableList<SupplierModel>();

  @observable
  String searchQuery = '';

  @observable
  SupplierModel? selectedSupplier;

  _SupplierStore() {
    _supplierRepository = SupplierRepository();
    _init();
  }

  Future<void> _init() async {
    await loadSuppliers();
  }

  // ==================== SUPPLIER OPERATIONS ====================

  @action
  Future<void> loadSuppliers() async {
    final loadedSuppliers = await _supplierRepository.getAllSuppliers();
    suppliers.clear();
    suppliers.addAll(loadedSuppliers);
  }

  @action
  Future<void> addSupplier(SupplierModel supplier) async {
    await _supplierRepository.addSupplier(supplier);
    suppliers.insert(0, supplier);
  }

  @action
  Future<void> updateSupplier(SupplierModel supplier) async {
    await _supplierRepository.updateSupplier(supplier);

    final index = suppliers.indexWhere((s) => s.supplierId == supplier.supplierId);
    if (index != -1) {
      suppliers[index] = supplier;
    }
  }

  @action
  Future<void> deleteSupplier(String supplierId) async {
    await _supplierRepository.deleteSupplier(supplierId);
    suppliers.removeWhere((s) => s.supplierId == supplierId);

    if (selectedSupplier?.supplierId == supplierId) {
      selectedSupplier = null;
    }
  }

  @action
  Future<void> searchSuppliers(String query) async {
    searchQuery = query;

    if (query.isEmpty) {
      searchResults.clear();
      return;
    }

    final results = await _supplierRepository.searchSuppliers(query);
    searchResults.clear();
    searchResults.addAll(results);
  }

  @action
  void selectSupplier(SupplierModel? supplier) {
    selectedSupplier = supplier;
  }

  @action
  void clearSelection() {
    selectedSupplier = null;
    searchResults.clear();
    searchQuery = '';
  }

  @action
  Future<void> updateSupplierBalance(String supplierId, double amount) async {
    await _supplierRepository.updateSupplierBalance(supplierId, amount);
    await loadSuppliers();
  }

  @computed
  int get supplierCount => suppliers.length;

  @computed
  bool get hasSelection => selectedSupplier != null;

  @computed
  double get totalOutstanding => _supplierRepository.getTotalOutstanding();
}