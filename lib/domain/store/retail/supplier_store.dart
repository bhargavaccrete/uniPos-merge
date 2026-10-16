import 'package:mobx/mobx.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_model_205.dart';
import 'package:billberrylite/data/repositories/retail/grn_repository.dart';
import 'package:billberrylite/data/repositories/retail/purchase_order_repository.dart';
import 'package:billberrylite/data/repositories/retail/purchase_return_repository.dart';
import 'package:billberrylite/data/repositories/retail/supplier_claim_repository.dart';
import 'package:billberrylite/data/repositories/retail/supplier_ledger_repository.dart';
import 'package:billberrylite/data/repositories/retail/supplier_repository.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_ledger_entry_model_179.dart';
import 'package:billberrylite/core/plan/plan_enforcement.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';


part 'supplier_store.g.dart';

class SupplierStore = _SupplierStore with _$SupplierStore;

abstract class _SupplierStore with Store {
  late final SupplierRepository _supplierRepository;
  late final SupplierLedgerRepository _ledgerRepository;

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
    _ledgerRepository = SupplierLedgerRepository();
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

    // The opening balance is a balance movement like any other, so it gets a
    // row too. Without one the ledger would start mid-story and never
    // reconcile with the headline figure.
    if (supplier.openingBalance != 0) {
      await _ledgerRepository.save(SupplierLedgerEntryModel.create(
        supplierId: supplier.supplierId,
        type: SupplierLedgerType.opening,
        amount: supplier.openingBalance,
        balanceAfter: supplier.openingBalance,
        description: 'Opening balance',
        date: supplier.createdAt,
      ));
    }
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
    // Only reachable for a supplier with no purchase history (the UI blocks
    // the rest), so this clears an unused account rather than real history.
    await _ledgerRepository.deleteBySupplier(supplierId);
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
  /// **The only way a supplier balance may move.**
  ///
  /// Writes one journal row, then applies the delta. The old
  /// `updateSupplierBalance(id, amount)` was deliberately removed rather than
  /// kept as a wrapper: any caller that could move the balance without leaving
  /// a row would silently reintroduce the drift this table exists to prevent.
  ///
  /// [amount] is signed — positive increases what is owed (a purchase),
  /// negative reduces it (a credit or a payment).
  ///
  /// Row first, balance second: a failure part-way leaves a row describing a
  /// movement that did not happen, which is visible and correctable. The
  /// reverse order would move money and lose its explanation.
  @action
  Future<void> recordBalanceMovement({
    required String supplierId,
    required double amount,
    required SupplierLedgerType type,
    required String description,
    String? docNumber,
    String? docId,
    String? paymentMode,
    String? referenceNo,
    String? note,
    String? date,
  }) async {
    final supplier = _supplierRepository.getSupplierById(supplierId);
    if (supplier == null) return;

    // A supplier that predates the journal has a balance no row explains. Make
    // it real BEFORE the first movement is written, otherwise the read-time
    // "Balance brought forward" stops being synthesised the moment a row
    // exists, and this movement would appear to come from nowhere.
    await _backfillOpeningIfNeeded(supplier);

    final balanceAfter = supplier.currentBalance + amount;

    await _ledgerRepository.save(SupplierLedgerEntryModel.create(
      supplierId: supplierId,
      type: type,
      amount: amount,
      balanceAfter: balanceAfter,
      description: description,
      docNumber: docNumber,
      docId: docId,
      paymentMode: paymentMode,
      referenceNo: referenceNo,
      note: note,
      date: date,
    ));

    await _supplierRepository.updateSupplierBalance(supplierId, amount);
    await loadSuppliers();
  }

  /// Whether [type] was already posted for the document [docId] — lets a
  /// resumed receipt skip an accrual it already made.
  bool hasLedgerEntryForDoc(String docId, SupplierLedgerType type) =>
      _ledgerRepository.hasEntryForDoc(docId, type.name);

  /// One-time lazy backfill for suppliers created before the journal existed.
  ///
  /// Writes their standing balance as a real `opening` row so every later
  /// movement has something to follow from. Runs at most once per supplier —
  /// after it, the journal is non-empty and this is a no-op.
  Future<void> _backfillOpeningIfNeeded(SupplierModel supplier) async {
    if (supplier.currentBalance == 0) return;
    if (_ledgerRepository.hasEntries(supplier.supplierId)) return;

    await _ledgerRepository.save(SupplierLedgerEntryModel.create(
      supplierId: supplier.supplierId,
      type: SupplierLedgerType.opening,
      amount: supplier.currentBalance,
      balanceAfter: supplier.currentBalance,
      description: 'Balance brought forward',
      date: supplier.createdAt,
    ));
  }

  /// Every movement against one supplier, oldest first.
  ///
  /// Suppliers created before the journal existed have a balance but no rows.
  /// For them a read-only **Balance brought forward** entry is synthesised so
  /// the ledger still reconciles — it is never persisted, so no migration runs.
  ///
  /// Synthesised only when the journal is EMPTY. Rows that exist but fail to
  /// reach `currentBalance` mean a real bug, and a plug line would hide exactly
  /// the class of problem this table was built to surface.
  Future<List<SupplierLedgerEntryModel>> getLedger(String supplierId) async {
    final entries = await _ledgerRepository.getBySupplier(supplierId);
    if (entries.isNotEmpty) return entries;

    final supplier = _supplierRepository.getSupplierById(supplierId);
    if (supplier == null || supplier.currentBalance == 0) return entries;

    return [
      SupplierLedgerEntryModel.create(
        supplierId: supplierId,
        type: SupplierLedgerType.opening,
        amount: supplier.currentBalance,
        balanceAfter: supplier.currentBalance,
        description: 'Balance brought forward',
        date: supplier.createdAt,
      ),
    ];
  }

  /// The Overview reconciliation for one supplier.
  Future<SupplierAccountSummary> summaryFor(String supplierId) async {
    return summariseLedger(await getLedger(supplierId));
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

  /// Why [supplierId] can't be deleted — empty when it can.
  ///
  /// Deleting also wipes the supplier's ledger, so anything that is real money
  /// or paperwork blocks it: purchase orders and receipts (which resolve the
  /// name by id), returns and claims, any journal row beyond the opening
  /// balance (a payment or credit), and a non-zero balance. The old check
  /// counted only POs and GRNs, so a supplier with payments and ₹5,000 still
  /// owed could be deleted along with its whole history.
  Future<List<String>> deleteBlockers(String supplierId) async {
    final blockers = <String>[];
    String n(int count, String what) => '$count $what${count == 1 ? '' : 's'}';

    final orders = await PurchaseOrderRepository()
        .getPurchaseOrdersBySupplier(supplierId);
    final grns = await GRNRepository().getGRNsBySupplier(supplierId);
    final returns = await PurchaseReturnRepository().getBySupplier(supplierId);
    final claims = await SupplierClaimRepository().getBySupplier(supplierId);
    final movements = (await _ledgerRepository.getBySupplier(supplierId))
        .where((e) => e.typeEnum != SupplierLedgerType.opening)
        .length;
    final balance =
        _supplierRepository.getSupplierById(supplierId)?.currentBalance ?? 0;

    if (orders.isNotEmpty) blockers.add(n(orders.length, 'purchase order'));
    if (grns.isNotEmpty) blockers.add(n(grns.length, 'goods receipt'));
    if (returns.isNotEmpty) blockers.add(n(returns.length, 'purchase return'));
    if (claims.isNotEmpty) blockers.add(n(claims.length, 'supplier claim'));
    if (movements > 0) blockers.add(n(movements, 'payment or credit'));
    if (balance.abs() > 0.009) {
      blockers.add('Outstanding balance ${balance.toStringAsFixed(2)}');
    }
    return blockers;
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