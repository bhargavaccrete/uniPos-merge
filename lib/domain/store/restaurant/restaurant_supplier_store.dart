import 'package:mobx/mobx.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/restaurant_supplier_model.dart';
import '../../../data/models/restaurant/db/restaurant_supplier_ledger_entry_model.dart';
import '../../../data/models/restaurant/db/restaurant_purchase_order_model.dart';
import '../../../data/models/restaurant/db/restaurant_grn_model.dart';
import '../../../data/models/restaurant/db/restaurant_purchase_return_model.dart';
import '../../../data/models/restaurant/db/restaurant_supplier_claim_model.dart';

part 'restaurant_supplier_store.g.dart';

class RestaurantSupplierStore = _RestaurantSupplierStore
    with _$RestaurantSupplierStore;

/// Owns restaurant suppliers and, critically, the ONE path that may move a
/// supplier's balance.
///
/// **The choke point.** `RestaurantSupplierModel.currentBalance` used to be
/// mutated directly from two places (GRN confirm and return/claim credits) with
/// no record of either, and payments could not be recorded at all. Every
/// movement now goes through [recordBalanceMovement], which writes a
/// [RestaurantSupplierLedgerEntryModel] row and then applies the delta. Nothing
/// else may touch the balance.
///
/// **Sign convention** — positive balance means money is owed TO the supplier:
///
/// | Movement | Sign | Raised by |
/// |---|---|---|
/// | Opening balance | + (as entered) | supplier creation / backfill |
/// | Purchase (GRN confirmed) | + full received value | `RestaurantPurchaseOrderStore.confirmGRN` |
/// | Return credit (credit note) | − | `RestaurantDamagedGoodsStore.recordCreditNote` |
/// | Claim credit (claim settled) | − | `RestaurantDamagedGoodsStore.updateClaimStatus` |
/// | Payment | − | supplier payment dialog |
/// | Adjustment | ± | supplier payment dialog |
///
/// A supplier payment is a **payables settlement**, not a sale or an expense:
/// it must never touch the cash drawer, POS payment totals, EOD sales, tax, or
/// P&L. Retail's supplier payment behaves the same way, deliberately.
abstract class _RestaurantSupplierStore with Store {
  @observable
  ObservableList<RestaurantSupplierModel> suppliers =
      ObservableList<RestaurantSupplierModel>();

  @observable
  String searchQuery = '';

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  // ==================== LOAD ====================

  @action
  Future<void> loadSuppliers() async {
    try {
      isLoading = true;
      errorMessage = null;
      final all = restaurantSupplierRepository.getAllSuppliers()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      suppliers = ObservableList.of(all);
    } catch (e) {
      errorMessage = 'Failed to load suppliers: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  void setSearchQuery(String value) => searchQuery = value;

  @computed
  List<RestaurantSupplierModel> get filteredSuppliers {
    final q = searchQuery.trim().toLowerCase();
    if (q.isEmpty) return suppliers.toList();
    return suppliers
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            (s.phone ?? '').toLowerCase().contains(q) ||
            (s.gstNumber ?? '').toLowerCase().contains(q))
        .toList();
  }

  @computed
  int get supplierCount => suppliers.length;

  /// Everything currently owed across all suppliers.
  @computed
  double get totalOutstanding =>
      suppliers.fold(0.0, (sum, s) => sum + s.currentBalance);

  // ==================== CRUD ====================

  /// Creates the supplier and, when they walked in owing money, records that
  /// as the ledger's `opening` row so the balance has a reason from the start.
  @action
  Future<RestaurantSupplierModel> addSupplier({
    required String name,
    String? phone,
    String? address,
    String? gstNumber,
    double openingBalance = 0,
  }) async {
    final supplier = RestaurantSupplierModel.create(
      name: name,
      phone: phone,
      address: address,
      gstNumber: gstNumber,
      openingBalance: openingBalance,
    );
    await restaurantSupplierRepository.saveSupplier(supplier);

    if (openingBalance != 0) {
      // Written directly rather than through recordBalanceMovement: the
      // supplier's currentBalance already equals the opening figure (set in
      // .create), so applying a delta on top would double it.
      await restaurantSupplierLedgerRepository
          .save(RestaurantSupplierLedgerEntryModel.create(
        supplierId: supplier.supplierId,
        type: RestaurantSupplierLedgerType.opening,
        amount: openingBalance,
        balanceAfter: openingBalance,
        description: 'Opening balance',
        date: supplier.createdAt,
        seq: 1,
      ));
    }

    await loadSuppliers();
    return supplier;
  }

  /// Edits contact details only. [openingBalance] is deliberately NOT editable
  /// here — it is a posted ledger row, and silently rewriting it would break
  /// the reconciliation. Correct it with an adjustment instead.
  @action
  Future<void> updateSupplier(
    RestaurantSupplierModel supplier, {
    required String name,
    String? phone,
    String? address,
    String? gstNumber,
  }) async {
    await restaurantSupplierRepository.saveSupplier(supplier.copyWith(
      name: name,
      phone: phone,
      address: address,
      gstNumber: gstNumber,
      clearPhone: phone == null || phone.isEmpty,
      clearAddress: address == null || address.isEmpty,
      clearGstNumber: gstNumber == null || gstNumber.isEmpty,
    ));
    await loadSuppliers();
  }

  /// Deletes a supplier and any ledger rows they accumulated.
  ///
  /// Callers MUST check [countReferences] first — this does not re-check, so
  /// that the UI can present the reason rather than a silent failure.
  @action
  Future<void> deleteSupplier(String supplierId) async {
    await restaurantSupplierLedgerRepository.deleteBySupplier(supplierId);
    await restaurantSupplierRepository.deleteSupplier(supplierId);
    await loadSuppliers();
  }

  // ==================== BALANCE — THE CHOKE POINT ====================

  /// The only sanctioned way to move a supplier's balance.
  ///
  /// Row first, balance second: a failure part-way leaves a row describing a
  /// movement that did not happen, which is visible and correctable. The
  /// reverse order would move money and lose its explanation.
  ///
  /// [amount] is signed — positive increases what is owed, negative reduces it.
  @action
  Future<void> recordBalanceMovement({
    required String supplierId,
    required double amount,
    required RestaurantSupplierLedgerType type,
    required String description,
    String? docNumber,
    String? docId,
    String? paymentMode,
    String? referenceNo,
    String? note,
    String? date,
  }) async {
    final supplier = restaurantSupplierRepository.getSupplierById(supplierId);
    if (supplier == null) return;

    // A supplier that predates the journal has a balance no row explains. Make
    // it real BEFORE the first movement is written, otherwise the read-time
    // "Balance brought forward" stops being synthesised the moment a row
    // exists, and this movement would appear to come from nowhere.
    await _backfillOpeningIfNeeded(supplier);

    final balanceAfter = supplier.currentBalance + amount;

    // Sequence continues from whatever is already on file, so the journal has
    // a total order even when two movements land in the same millisecond.
    final existing =
        await restaurantSupplierLedgerRepository.getBySupplier(supplierId);
    final nextSeq = existing.isEmpty
        ? 1
        : existing.map((e) => e.seq).reduce((a, b) => a > b ? a : b) + 1;

    await restaurantSupplierLedgerRepository
        .save(RestaurantSupplierLedgerEntryModel.create(
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
      seq: nextSeq,
    ));

    await restaurantSupplierRepository.saveSupplier(
      supplier.copyWith(currentBalance: balanceAfter),
    );
    await loadSuppliers();
  }

  /// One-time lazy backfill for suppliers that carried a balance before the
  /// journal existed.
  ///
  /// Writes their standing balance as a single real `opening` row so every
  /// later movement has something to follow from. **No historical transactions
  /// are invented** — one row, described as brought forward, dated to when the
  /// supplier was created. Runs at most once per supplier; after it the journal
  /// is non-empty and this is a no-op.
  Future<void> _backfillOpeningIfNeeded(RestaurantSupplierModel supplier) async {
    if (supplier.currentBalance == 0) return;
    if (restaurantSupplierLedgerRepository.hasEntries(supplier.supplierId)) {
      return;
    }

    await restaurantSupplierLedgerRepository
        .save(RestaurantSupplierLedgerEntryModel.create(
      supplierId: supplier.supplierId,
      type: RestaurantSupplierLedgerType.opening,
      amount: supplier.currentBalance,
      balanceAfter: supplier.currentBalance,
      description: 'Balance brought forward',
      date: supplier.createdAt,
      seq: 1,
    ));
  }

  /// Every movement against one supplier, oldest first.
  ///
  /// Suppliers that predate the journal have a balance but no rows. For them a
  /// read-only **Balance brought forward** entry is synthesised so the ledger
  /// still reconciles — it is never persisted, so merely opening the screen
  /// runs no migration.
  ///
  /// Synthesised only when the journal is EMPTY. Rows that exist but fail to
  /// reach `currentBalance` mean a real bug, and a plug line would hide exactly
  /// the class of problem this table was built to surface.
  Future<List<RestaurantSupplierLedgerEntryModel>> getLedger(
      String supplierId) async {
    final entries =
        await restaurantSupplierLedgerRepository.getBySupplier(supplierId);
    if (entries.isNotEmpty) return entries;

    final supplier = restaurantSupplierRepository.getSupplierById(supplierId);
    if (supplier == null || supplier.currentBalance == 0) return entries;

    return [
      RestaurantSupplierLedgerEntryModel.create(
        supplierId: supplierId,
        type: RestaurantSupplierLedgerType.opening,
        amount: supplier.currentBalance,
        balanceAfter: supplier.currentBalance,
        description: 'Balance brought forward',
        date: supplier.createdAt,
        seq: 1,
      ),
    ];
  }

  /// The Overview reconciliation for one supplier.
  Future<RestaurantSupplierAccountSummary> summaryFor(String supplierId) async {
    return summariseRestaurantLedger(await getLedger(supplierId));
  }

  // ==================== DOCUMENTS & REFERENCES ====================

  /// Every document that points at this supplier. Deleting a supplier with
  /// history would orphan these — they resolve the supplier name by id at
  /// render time — so the UI blocks it and shows the counts as the reason.
  Future<RestaurantSupplierReferences> referencesFor(String supplierId) async {
    return RestaurantSupplierReferences(
      purchaseOrders: restaurantPurchaseOrderRepository
          .getPurchaseOrdersBySupplier(supplierId),
      grns: restaurantGrnRepository.getGRNsBySupplier(supplierId),
      purchaseReturns:
          await restaurantPurchaseReturnRepository.getBySupplier(supplierId),
      claims: await restaurantSupplierClaimRepository.getBySupplier(supplierId),
    );
  }

  /// Total documents referencing this supplier — zero means safe to delete.
  Future<int> countReferences(String supplierId) async =>
      (await referencesFor(supplierId)).total;
}

/// Every document raised against one supplier, for the detail screen's
/// Documents tab and the delete guard.
class RestaurantSupplierReferences {
  final List<RestaurantPurchaseOrderModel> purchaseOrders;
  final List<RestaurantGRNModel> grns;
  final List<RestaurantPurchaseReturnModel> purchaseReturns;
  final List<RestaurantSupplierClaimModel> claims;

  const RestaurantSupplierReferences({
    this.purchaseOrders = const [],
    this.grns = const [],
    this.purchaseReturns = const [],
    this.claims = const [],
  });

  int get total =>
      purchaseOrders.length +
      grns.length +
      purchaseReturns.length +
      claims.length;

  bool get isEmpty => total == 0;

  /// Human-readable reason a delete was refused, e.g.
  /// "2 purchase orders, 1 GRN".
  String get blockingSummary {
    final parts = <String>[];
    if (purchaseOrders.isNotEmpty) {
      parts.add('${purchaseOrders.length} purchase '
          '${purchaseOrders.length == 1 ? "order" : "orders"}');
    }
    if (grns.isNotEmpty) {
      parts.add('${grns.length} GRN${grns.length == 1 ? "" : "s"}');
    }
    if (purchaseReturns.isNotEmpty) {
      parts.add('${purchaseReturns.length} '
          '${purchaseReturns.length == 1 ? "return" : "returns"}');
    }
    if (claims.isNotEmpty) {
      parts.add('${claims.length} claim${claims.length == 1 ? "" : "s"}');
    }
    return parts.join(', ');
  }
}
