import 'package:mobx/mobx.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/restaurant_grn_item_model.dart';
import '../../../data/models/restaurant/db/restaurant_grn_model.dart';
import '../../../data/models/restaurant/db/restaurant_inventory_loss_model.dart';
import '../../../data/models/restaurant/db/restaurant_purchase_return_item_model.dart';
import '../../../data/models/restaurant/db/restaurant_purchase_return_model.dart';
import '../../../data/models/restaurant/db/restaurant_supplier_claim_item_model.dart';
import '../../../data/models/restaurant/db/restaurant_supplier_claim_model.dart';
import '../../../data/repositories/restaurant/restaurant_inventory_loss_repository.dart';
import '../../../data/repositories/restaurant/restaurant_purchase_return_repository.dart';
import '../../../data/repositories/restaurant/restaurant_supplier_claim_repository.dart';
import '../../services/common/document_number_service.dart';

part 'restaurant_damaged_goods_store.g.dart';

class RestaurantDamagedGoodsStore = _RestaurantDamagedGoodsStore
    with _$RestaurantDamagedGoodsStore;

/// Owns the three outcomes a damaged GRN line can have — return to supplier,
/// claim against supplier, or straight write-off. Mirrors retail's
/// `DamagedGoodsStore`, scoped to restaurant's Items/Supplier models.
///
/// **Stock is never touched here; the supplier balance is — on credit events
/// only.** Damaged units are excluded from `acceptedQty` at GRN confirm, so
/// they never entered inventory and nothing in here may add or remove any.
///
/// They WERE billed, though: `RestaurantPurchaseOrderStore.confirmGRN`
/// accrues the GRN's full value onto `RestaurantSupplierModel.currentBalance`
/// so it matches the supplier's invoice. Recovering that value is what these
/// documents are for:
///
/// | Document | Credit event | Amount |
/// |---|---|---|
/// | Purchase return | credit note recorded | the note's face value |
/// | Supplier claim | status reaches `settled` | the claim total |
/// | Inventory loss (write-off) | none — the business absorbs it | — |
///
/// **No separate ledger-entry model.** Retail records every balance change as
/// a `SupplierLedgerEntryModel` row; restaurant's typeId range (100-149) is
/// fully claimed by this feature's other 7 models, so credits here adjust
/// `RestaurantSupplierModel.currentBalance` directly. A per-movement ledger
/// can be added later under a new ID range if restaurant needs the same
/// statement-of-account view retail has.
///
/// Every credit is guarded by a persisted flag so it applies exactly once.
abstract class _RestaurantDamagedGoodsStore with Store {
  late final RestaurantPurchaseReturnRepository _returnRepository;
  late final RestaurantSupplierClaimRepository _claimRepository;
  late final RestaurantInventoryLossRepository _lossRepository;
  final DocumentNumberService _numbers = DocumentNumberService();

  static const String _returnPrefix = 'PR';
  static const String _claimPrefix = 'CLM';
  static const String _lossPrefix = 'LOSS';

  static const String damagedOnReceiptReason = 'Damaged on receipt';
  static const String claimRejectedReason = 'Supplier claim rejected';

  @observable
  ObservableList<RestaurantPurchaseReturnModel> purchaseReturns =
      ObservableList<RestaurantPurchaseReturnModel>();

  @observable
  ObservableList<RestaurantSupplierClaimModel> supplierClaims =
      ObservableList<RestaurantSupplierClaimModel>();

  @observable
  ObservableList<RestaurantInventoryLossModel> inventoryLosses =
      ObservableList<RestaurantInventoryLossModel>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  _RestaurantDamagedGoodsStore() {
    _returnRepository = RestaurantPurchaseReturnRepository();
    _claimRepository = RestaurantSupplierClaimRepository();
    _lossRepository = RestaurantInventoryLossRepository();
    _init();
  }

  Future<void> _init() async => loadAll();

  @action
  Future<void> loadAll() async {
    try {
      isLoading = true;
      final returns = await _returnRepository.getAll();
      final claims = await _claimRepository.getAll();
      final losses = await _lossRepository.getAll();

      purchaseReturns = ObservableList.of(returns);
      supplierClaims = ObservableList.of(claims);
      inventoryLosses = ObservableList.of(losses);
    } catch (e) {
      errorMessage = 'Failed to load damaged-goods records: $e';
    } finally {
      isLoading = false;
    }
  }

  // ==================== ENTRY POINT ====================

  /// Called once from receiving, immediately after a GRN is confirmed.
  /// Partitions [items] by `damagedHandling` and creates the matching record
  /// for each group. Safe to call when nothing was damaged.
  @action
  Future<RestaurantDamagedGoodsOutcome> recordFromGRN({
    required RestaurantGRNModel grn,
    required List<RestaurantGRNItemModel> items,
  }) async {
    final damaged = items
        .where((i) => (i.damagedQty ?? 0) > 0 && i.damagedHandling != null)
        .toList();

    if (damaged.isEmpty) return const RestaurantDamagedGoodsOutcome();

    try {
      final toReturn =
          damaged.where((i) => i.damagedHandling == 'returnToSupplier').toList();
      final toClaim =
          damaged.where((i) => i.damagedHandling == 'keepForClaim').toList();
      final toWriteOff =
          damaged.where((i) => i.damagedHandling == 'writeOff').toList();

      final returnNumber =
          toReturn.isEmpty ? null : await _createReturn(grn, toReturn);
      final claimNumber =
          toClaim.isEmpty ? null : await _createClaim(grn, toClaim);
      final lossNumbers =
          toWriteOff.isEmpty ? <String>[] : await _createLosses(grn, toWriteOff);

      return RestaurantDamagedGoodsOutcome(
        returnNumber: returnNumber,
        claimNumber: claimNumber,
        lossNumbers: lossNumbers,
      );
    } catch (e) {
      errorMessage = 'Damaged-goods records could not be created: $e';
      return const RestaurantDamagedGoodsOutcome();
    }
  }

  Future<String> _createReturn(
      RestaurantGRNModel grn, List<RestaurantGRNItemModel> items) async {
    final number = await _numbers.next(
      _returnPrefix,
      isTaken: (n) => purchaseReturns.any((r) => r.returnNumber == n),
    );

    final header = RestaurantPurchaseReturnModel.create(
      returnNumber: number,
      grnId: grn.grnId,
      grnNumber: grn.grnNumber,
      poId: grn.poId,
      poNumber: grn.poNumber,
      supplierId: grn.supplierId,
      supplierName: grn.supplierName,
      totalQty: items.fold<double>(0, (s, i) => s + (i.damagedQty ?? 0)),
      totalAmount: items.fold<double>(
          0, (s, i) => s + ((i.damagedQty ?? 0) * (i.costPrice ?? 0))),
      notes: 'Raised automatically from ${grn.grnNumber}',
    );

    final lines = items
        .map((i) => RestaurantPurchaseReturnItemModel.create(
              returnId: header.returnId,
              grnItemId: i.grnItemId,
              itemId: i.itemId,
              itemName: i.itemName,
              returnedQty: i.damagedQty ?? 0,
              costPrice: i.costPrice,
            ))
        .toList();

    await _returnRepository.save(header);
    await _returnRepository.saveItems(lines);
    purchaseReturns.insert(0, header);
    return number;
  }

  Future<String> _createClaim(
      RestaurantGRNModel grn, List<RestaurantGRNItemModel> items) async {
    final number = await _numbers.next(
      _claimPrefix,
      isTaken: (n) => supplierClaims.any((c) => c.claimNumber == n),
    );

    final header = RestaurantSupplierClaimModel.create(
      claimNumber: number,
      grnId: grn.grnId,
      grnNumber: grn.grnNumber,
      poId: grn.poId,
      poNumber: grn.poNumber,
      supplierId: grn.supplierId,
      supplierName: grn.supplierName,
      totalQty: items.fold<double>(0, (s, i) => s + (i.damagedQty ?? 0)),
      totalAmount: items.fold<double>(
          0, (s, i) => s + ((i.damagedQty ?? 0) * (i.costPrice ?? 0))),
      notes: 'Raised automatically from ${grn.grnNumber}',
    );

    final lines = items
        .map((i) => RestaurantSupplierClaimItemModel.create(
              claimId: header.claimId,
              grnItemId: i.grnItemId,
              itemId: i.itemId,
              itemName: i.itemName,
              claimedQty: i.damagedQty ?? 0,
              costPrice: i.costPrice,
            ))
        .toList();

    await _claimRepository.save(header);
    await _claimRepository.saveItems(lines);
    supplierClaims.insert(0, header);
    return number;
  }

  Future<List<String>> _createLosses(
      RestaurantGRNModel grn, List<RestaurantGRNItemModel> items) async {
    final created = <RestaurantInventoryLossModel>[];

    for (final item in items) {
      final number = await _numbers.next(
        _lossPrefix,
        isTaken: (n) => inventoryLosses.any((l) => l.lossNumber == n),
      );

      created.add(RestaurantInventoryLossModel.create(
        lossNumber: number,
        grnId: grn.grnId,
        grnNumber: grn.grnNumber,
        grnItemId: item.grnItemId,
        poId: grn.poId,
        supplierId: grn.supplierId,
        supplierName: grn.supplierName,
        itemId: item.itemId,
        itemName: item.itemName,
        quantity: item.damagedQty ?? 0,
        costPrice: item.costPrice,
        reason: damagedOnReceiptReason,
      ));
    }

    await _lossRepository.saveAll(created);
    inventoryLosses.insertAll(0, created);
    return created.map((l) => l.lossNumber).toList();
  }

  // ==================== PURCHASE RETURN ====================

  /// Record the supplier's credit note against a return. This is the
  /// return's credit event — the GRN billed these units when they arrived,
  /// so the supplier balance drops here.
  @action
  Future<bool> recordCreditNote({
    required String returnId,
    required String creditNoteNumber,
    double? amount,
    String? date,
  }) async {
    final existing = _returnRepository.getById(returnId);
    if (existing == null) return false;

    final creditAmount = amount ?? existing.totalAmount;
    final adjustment =
        RestaurantPurchaseReturnModel.creditAdjustment(existing, creditAmount);

    final updated = existing.copyWith(
      status: RestaurantPurchaseReturnStatus.creditReceived.name,
      creditNoteNumber: creditNoteNumber,
      creditNoteDate: date ?? DateTime.now().toIso8601String(),
      creditNoteAmount: creditAmount,
      creditApplied: adjustment != 0 ? true : null,
    );

    await _returnRepository.save(updated);

    if (adjustment != 0) {
      await _applyBalanceAdjustment(existing.supplierId, adjustment);
    }

    _replaceReturn(updated);
    return true;
  }

  /// Withdraw a return that is no longer expected. No balance movement — the
  /// goods never went back, so the liability the GRN accrued still stands.
  @action
  Future<bool> cancelPurchaseReturn(String returnId, {String? reason}) async {
    final existing = _returnRepository.getById(returnId);
    if (existing == null || !existing.isOpen) return false;

    final updated = existing.copyWith(
      status: RestaurantPurchaseReturnStatus.cancelled.name,
      notes: reason ?? existing.notes,
    );

    await _returnRepository.save(updated);
    _replaceReturn(updated);
    return true;
  }

  Future<List<RestaurantPurchaseReturnItemModel>> getReturnItems(
          String returnId) =>
      _returnRepository.getItems(returnId);

  Future<double> returnedQtyForGRNItem(String grnItemId) =>
      _returnRepository.returnedQtyForGRNItem(grnItemId);

  void _replaceReturn(RestaurantPurchaseReturnModel updated) {
    final index =
        purchaseReturns.indexWhere((r) => r.returnId == updated.returnId);
    if (index != -1) purchaseReturns[index] = updated;
  }

  // ==================== SUPPLIER CLAIM ====================

  /// Move a claim through its lifecycle. Only a pending claim can be approved
  /// or rejected; only an approved claim can be settled. Settlement is the
  /// claim's credit event.
  @action
  Future<bool> updateClaimStatus({
    required String claimId,
    required RestaurantSupplierClaimStatus status,
    String? resolutionNote,
  }) async {
    final existing = _claimRepository.getById(claimId);
    if (existing == null) return false;

    final current = existing.statusEnum;
    final allowed = switch (status) {
      RestaurantSupplierClaimStatus.approved =>
        current == RestaurantSupplierClaimStatus.pending,
      RestaurantSupplierClaimStatus.rejected =>
        current == RestaurantSupplierClaimStatus.pending,
      RestaurantSupplierClaimStatus.settled =>
        current == RestaurantSupplierClaimStatus.approved,
      RestaurantSupplierClaimStatus.pending => false,
    };
    if (!allowed) {
      errorMessage =
          'A ${existing.statusDisplay.toLowerCase()} claim cannot become ${status.name}.';
      return false;
    }

    final closes = status == RestaurantSupplierClaimStatus.rejected ||
        status == RestaurantSupplierClaimStatus.settled;

    final adjustment =
        RestaurantSupplierClaimModel.claimBalanceAdjustment(existing, status);

    final updated = existing.copyWith(
      status: status.name,
      resolutionNote: resolutionNote,
      resolvedAt: closes ? DateTime.now().toIso8601String() : null,
      creditApplied: adjustment != 0 ? true : null,
    );

    await _claimRepository.save(updated);

    if (adjustment != 0) {
      await _applyBalanceAdjustment(existing.supplierId, adjustment);
    }

    final index = supplierClaims.indexWhere((c) => c.claimId == claimId);
    if (index != -1) supplierClaims[index] = updated;
    return true;
  }

  /// Write a rejected claim off as an inventory loss. Deliberately manual —
  /// a rejection isn't by itself a decision to absorb the cost.
  @action
  Future<List<String>> writeOffRejectedClaim(String claimId) async {
    final claim = _claimRepository.getById(claimId);
    if (claim == null ||
        claim.statusEnum != RestaurantSupplierClaimStatus.rejected ||
        claim.isLossRecorded) {
      return [];
    }

    try {
      final lines = await _claimRepository.getItems(claimId);
      if (lines.isEmpty) return [];

      final created = <RestaurantInventoryLossModel>[];
      for (final line in lines) {
        final number = await _numbers.next(
          _lossPrefix,
          isTaken: (n) => inventoryLosses.any((l) => l.lossNumber == n),
        );

        created.add(RestaurantInventoryLossModel.create(
          lossNumber: number,
          source: RestaurantInventoryLossSource.claimRejected,
          grnId: claim.grnId,
          grnNumber: claim.grnNumber,
          grnItemId: line.grnItemId,
          poId: claim.poId,
          supplierId: claim.supplierId,
          supplierName: claim.supplierName,
          itemId: line.itemId,
          itemName: line.itemName,
          quantity: line.claimedQty,
          costPrice: line.costPrice,
          reason: claimRejectedReason,
          note: 'Claim ${claim.claimNumber} rejected by supplier',
        ));
      }

      await _lossRepository.saveAll(created);
      inventoryLosses.insertAll(0, created);

      final updated = claim.copyWith(lossRecorded: true);
      await _claimRepository.save(updated);
      final index = supplierClaims.indexWhere((c) => c.claimId == claimId);
      if (index != -1) supplierClaims[index] = updated;

      return created.map((l) => l.lossNumber).toList();
    } catch (e) {
      errorMessage = 'Write-off could not be recorded: $e';
      return [];
    }
  }

  Future<List<RestaurantSupplierClaimItemModel>> getClaimItems(String claimId) =>
      _claimRepository.getItems(claimId);

  // ==================== LOOKUPS ====================

  Future<RestaurantGRNDamagedDocuments> documentsForGRN(String grnId) async {
    return RestaurantGRNDamagedDocuments(
      returns: await _returnRepository.getByGRN(grnId),
      claims: await _claimRepository.getByGRN(grnId),
      losses: await _lossRepository.getByGRN(grnId),
    );
  }

  // ==================== COMPUTED ====================

  @computed
  int get openReturnCount => purchaseReturns.where((r) => r.isOpen).length;

  @computed
  int get openClaimCount => supplierClaims.where((c) => c.isOpen).length;

  @computed
  double get openClaimValue => supplierClaims
      .where((c) => c.isOpen)
      .fold(0.0, (sum, c) => sum + c.totalAmount);

  @computed
  double get totalLossValue =>
      inventoryLosses.fold(0.0, (sum, l) => sum + l.lossValue);

  @computed
  double get totalLossQty =>
      inventoryLosses.fold(0.0, (sum, l) => sum + l.quantity);

  // ==================== SUPPLIER BALANCE ====================

  /// Applies a signed adjustment to a supplier's running balance — negative
  /// reduces what is owed. Direct field mutation (see class doc for why
  /// there's no separate ledger-entry model here).
  Future<void> _applyBalanceAdjustment(String supplierId, double adjustment) async {
    final supplier = restaurantSupplierRepository.getSupplierById(supplierId);
    if (supplier == null) return;
    await restaurantSupplierRepository.saveSupplier(
      supplier.copyWith(currentBalance: supplier.currentBalance + adjustment),
    );
  }
}

/// What [_RestaurantDamagedGoodsStore.recordFromGRN] created.
class RestaurantDamagedGoodsOutcome {
  final String? returnNumber;
  final String? claimNumber;
  final List<String> lossNumbers;

  const RestaurantDamagedGoodsOutcome({
    this.returnNumber,
    this.claimNumber,
    this.lossNumbers = const [],
  });

  bool get isEmpty =>
      returnNumber == null && claimNumber == null && lossNumbers.isEmpty;

  String get summary {
    final parts = <String>[
      if (returnNumber != null) returnNumber!,
      if (claimNumber != null) claimNumber!,
      if (lossNumbers.length == 1)
        lossNumbers.first
      else if (lossNumbers.length > 1)
        '${lossNumbers.length} write-offs',
    ];
    return parts.join(', ');
  }
}

/// The damaged-goods paper trail for a single restaurant GRN.
class RestaurantGRNDamagedDocuments {
  final List<RestaurantPurchaseReturnModel> returns;
  final List<RestaurantSupplierClaimModel> claims;
  final List<RestaurantInventoryLossModel> losses;

  const RestaurantGRNDamagedDocuments({
    this.returns = const [],
    this.claims = const [],
    this.losses = const [],
  });

  bool get isEmpty => returns.isEmpty && claims.isEmpty && losses.isEmpty;
}
