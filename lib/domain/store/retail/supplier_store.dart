import 'package:mobx/mobx.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_model_205.dart';
import 'package:billberrylite/data/repositories/retail/grn_repository.dart';
import 'package:billberrylite/data/repositories/retail/purchase_order_repository.dart';
import 'package:billberrylite/data/repositories/retail/supplier_repository.dart';
import 'package:billberrylite/core/plan/plan_enforcement.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';


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

  /// Plan gate for adding a supplier: module + add action allowed, AND under
  /// the cap. No-op (true) until a retail manifest is present — see
  /// `PlanEnforce`.
  bool get canAddSupplier =>
      PlanEnforce.allows(RetailEntKeys.suppliers) &&
      PlanEnforce.allows(RetailEntKeys.suppliersAdd) &&
      PlanEnforce.withinLimit(RetailEntKeys.suppliersMax, suppliers.length);

  /// The suppliers cap for messages; null = unlimited.
  int? get supplierLimit => PlanEnforce.limit(RetailEntKeys.suppliersMax);

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
  void setSearchQuery(String query) {
    searchQuery = query;
  }

  /// Reactive alternative to [searchSuppliers] — filters the in-memory list
  /// instead of re-querying the box, so results can't arrive out of order and
  /// an add/edit shows up immediately. Same fields as the repository search.
  @computed
  List<SupplierModel> get filteredSuppliers {
    if (searchQuery.isEmpty) return suppliers;
    final query = searchQuery.toLowerCase();
    return suppliers.where((supplier) {
      return supplier.name.toLowerCase().contains(query) ||
          (supplier.phone?.contains(query) ?? false) ||
          (supplier.gstNumber?.toLowerCase().contains(query) ?? false);
    }).toList();
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

  /// Purchase orders and GRNs that point at this supplier. Deleting a supplier
  /// with history would orphan those records — they resolve the supplier name
  /// by id at render time — so the UI blocks it.
  Future<int> countReferences(String supplierId) async {
    final orders = await PurchaseOrderRepository()
        .getPurchaseOrdersBySupplier(supplierId);
    final grns = await GRNRepository().getGRNsBySupplier(supplierId);
    return orders.length + grns.length;
  }

  @computed
  int get supplierCount => suppliers.length;

  @computed
  bool get hasSelection => selectedSupplier != null;

  /// Net payable across every supplier — advances (negative balances) offset
  /// what's owed.
  ///
  /// Derived from the [suppliers] observable, NOT from the repository's
  /// box-wide fold. A computed that reads no observable gives MobX nothing to
  /// invalidate on, so the old version could serve a cached total after a
  /// balance changed.
  @computed
  double get totalOutstanding =>
      suppliers.fold(0.0, (sum, s) => sum + s.currentBalance);
}