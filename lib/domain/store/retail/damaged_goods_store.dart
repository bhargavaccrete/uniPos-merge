import 'package:mobx/mobx.dart';

import '../../../data/models/retail/hive_model/grn_item_model_214.dart';
import '../../../data/models/retail/hive_model/grn_model_213.dart';
import '../../../data/models/retail/hive_model/inventory_loss_model_178.dart';
import '../../../data/models/retail/hive_model/purchase_return_item_model_175.dart';
import '../../../data/models/retail/hive_model/purchase_return_model_174.dart';
import '../../../data/models/retail/hive_model/supplier_claim_item_model_177.dart';
import '../../../data/models/retail/hive_model/supplier_claim_model_176.dart';
import '../../../data/models/retail/hive_model/supplier_ledger_entry_model_179.dart';
import '../../../data/repositories/retail/inventory_loss_repository.dart';
import '../../../data/repositories/retail/purchase_return_repository.dart';
import '../../../data/repositories/retail/supplier_claim_repository.dart';
import '../../../core/di/service_locator.dart';
import '../../services/common/document_number_service.dart';

part 'damaged_goods_store.g.dart';

class DamagedGoodsStore = _DamagedGoodsStore with _$DamagedGoodsStore;

/// Owns the three outcomes a damaged GRN line can have — return to supplier,
/// claim against supplier, write off as loss.
///
/// One store for all three follows `PurchaseOrderStore`, which already owns
/// both PO and GRN. Three near-identical stores would be duplication.
///
/// **Stock is never touched here; the supplier balance is — on credit events
/// only.** Damaged units are excluded from `acceptedQty` at GRN confirm, so
/// they never entered inventory and nothing in here may add or remove any.
///
/// They WERE billed, though: a GRN accrues the full received value so it
/// matches the supplier's invoice. Recovering that value is what these
/// documents are for, and each recovers it at a different moment:
///
/// | Document | Credit event | Amount |
/// |---|---|---|
/// | Purchase return | credit note recorded | the note's face value |
/// | Supplier claim | status reaches `settled` | the claim total |
/// | Inventory loss | none — the business absorbs it | — |
///
/// Every credit is guarded by a persisted flag so it applies exactly once.
abstract class _DamagedGoodsStore with Store {
  late final PurchaseReturnRepository _returnRepository;
  late final SupplierClaimRepository _claimRepository;
  late final InventoryLossRepository _lossRepository;
  final DocumentNumberService _numbers = DocumentNumberService();

  static const String _returnPrefix = 'PR';
  static const String _claimPrefix = 'CLM';
  static const String _lossPrefix = 'LOSS';

  /// Default reason stamped on a write-off raised from receiving.
  static const String damagedOnReceiptReason = 'Damaged on receipt';

  /// Reason stamped on a write-off raised after a claim was rejected.
  static const String claimRejectedReason = 'Supplier claim rejected';

  @observable
  ObservableList<PurchaseReturnModel> purchaseReturns =
      ObservableList<PurchaseReturnModel>();

  @observable
  ObservableList<SupplierClaimModel> supplierClaims =
      ObservableList<SupplierClaimModel>();

  @observable
  ObservableList<InventoryLossModel> inventoryLosses =
      ObservableList<InventoryLossModel>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  _DamagedGoodsStore() {
    _returnRepository = PurchaseReturnRepository();
    _claimRepository = SupplierClaimRepository();
    _lossRepository = InventoryLossRepository();
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
  ///
  /// Partitions [items] by `damagedHandling` and creates the matching record
  /// for each group. Lines with no damage, or with no handling chosen, are
  /// skipped. Safe to call when nothing was damaged — it simply does nothing.
  ///
  /// Deliberately tolerant: a failure here must never make a confirmed GRN look
  /// like it failed, because the stock and supplier balance it moved are
  /// already committed. Errors surface through [errorMessage].
  @action
  Future<DamagedGoodsOutcome> recordFromGRN({
    required GRNModel grn,
    required List<GRNItemModel> items,
  }) async {
    final damaged = items
        .where((i) => (i.damagedQty ?? 0) > 0 && i.damagedHandlingEnum != null)
        .toList();

    if (damaged.isEmpty) return const DamagedGoodsOutcome();

    try {
      final toReturn = damaged
          .where((i) => i.damagedHandlingEnum == DamagedHandling.returnToSupplier)
          .toList();
      final toClaim = damaged
          .where((i) => i.damagedHandlingEnum == DamagedHandling.keepForClaim)
          .toList();
      final toWriteOff = damaged
          .where((i) => i.damagedHandlingEnum == DamagedHandling.writeOff)
          .toList();

      final returnNumber =
          toReturn.isEmpty ? null : await _createReturn(grn, toReturn);
      final claimNumber =
          toClaim.isEmpty ? null : await _createClaim(grn, toClaim);
      final lossNumbers =
          toWriteOff.isEmpty ? <String>[] : await _createLosses(grn, toWriteOff);

      return DamagedGoodsOutcome(
        returnNumber: returnNumber,
        claimNumber: claimNumber,
        lossNumbers: lossNumbers,
      );
    } catch (e) {
      errorMessage = 'Damaged-goods records could not be created: $e';
      return const DamagedGoodsOutcome();
    }
  }

  Future<String> _createReturn(
      GRNModel grn, List<GRNItemModel> items) async {
    final number = await _numbers.next(
      _returnPrefix,
      isTaken: (n) => purchaseReturns.any((r) => r.returnNumber == n),
    );

    final header = PurchaseReturnModel.create(
      returnNumber: number,
      grnId: grn.grnId,
      grnNumber: grn.grnNumber,
      poId: grn.poId,
      poNumber: grn.poNumber,
      supplierId: grn.supplierId,
      supplierName: grn.supplierName,
      totalQty: items.fold<double>(0.0, (s, i) => s + (i.damagedQty ?? 0)),
      totalAmount: items.fold<double>(0, (s, i) => s + (i.damagedAmount ?? 0)),
      notes: 'Raised automatically from ${grn.grnNumber}',
    );

    final lines = items
        .map((i) => PurchaseReturnItemModel.create(
              returnId: header.returnId,
              grnItemId: i.grnItemId,
              variantId: i.variantId,
              productId: i.productId,
              productName: i.productName,
              variantInfo: i.variantInfo,
              returnedQty: i.damagedQty ?? 0,
              costPrice: i.costPrice,
            ))
        .toList();

    await _returnRepository.save(header);
    await _returnRepository.saveItems(lines);
    purchaseReturns.insert(0, header);
    return number;
  }

  Future<String> _createClaim(GRNModel grn, List<GRNItemModel> items) async {
    final number = await _numbers.next(
      _claimPrefix,
      isTaken: (n) => supplierClaims.any((c) => c.claimNumber == n),
    );

    final header = SupplierClaimModel.create(
      claimNumber: number,
      grnId: grn.grnId,
      grnNumber: grn.grnNumber,
      poId: grn.poId,
      poNumber: grn.poNumber,
      supplierId: grn.supplierId,
      supplierName: grn.supplierName,
      totalQty: items.fold<double>(0.0, (s, i) => s + (i.damagedQty ?? 0)),
      totalAmount: items.fold<double>(0, (s, i) => s + (i.damagedAmount ?? 0)),
      notes: 'Raised automatically from ${grn.grnNumber}',
    );

    final lines = items
        .map((i) => SupplierClaimItemModel.create(
              claimId: header.claimId,
              grnItemId: i.grnItemId,
              variantId: i.variantId,
              productId: i.productId,
              productName: i.productName,
              variantInfo: i.variantInfo,
              claimedQty: i.damagedQty ?? 0,
              costPrice: i.costPrice,
            ))
        .toList();

    await _claimRepository.save(header);
    await _claimRepository.saveItems(lines);
    supplierClaims.insert(0, header);
    return number;
  }

  /// One row per damaged line — losses are flat, not a header/item document.
  Future<List<String>> _createLosses(
      GRNModel grn, List<GRNItemModel> items) async {
    final created = <InventoryLossModel>[];

    for (final item in items) {
      final number = await _numbers.next(
        _lossPrefix,
        isTaken: (n) => inventoryLosses.any((l) => l.lossNumber == n),
      );

      created.add(InventoryLossModel.create(
        lossNumber: number,
        grnId: grn.grnId,
        grnNumber: grn.grnNumber,
        grnItemId: item.grnItemId,
        poId: grn.poId,
        supplierId: grn.supplierId,
        supplierName: grn.supplierName,
        variantId: item.variantId,
        productId: item.productId,
        productName: item.productName,
        variantInfo: item.variantInfo,
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

  /// Record the supplier's credit note against a return.
  ///
  /// **This is the return's credit event.** The GRN billed these units when the
  /// goods arrived, so the supplier balance drops here — by the note's face
  /// value, which may be less than the return total when the supplier only
  /// credits part of it.
  ///
  /// [PurchaseReturnModel.creditAdjustment] owns the decision and returns `0`
  /// once [PurchaseReturnModel.creditApplied] is set, so recording a note twice
  /// cannot credit twice.
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
        PurchaseReturnModel.creditAdjustment(existing, creditAmount);

    final updated = existing.copyWith(
      status: PurchaseReturnStatus.creditReceived.name,
      creditNoteNumber: creditNoteNumber,
      creditNoteDate: date ?? DateTime.now().toIso8601String(),
      creditNoteAmount: creditAmount,
      creditApplied: adjustment != 0 ? true : null,
    );

    await _returnRepository.save(updated);

    // Balance last: the return is already persisted as credited, so a failure
    // here can't leave a flag claiming a credit that never landed.
    if (adjustment != 0) {
      await supplierStore.recordBalanceMovement(
        supplierId: existing.supplierId,
        amount: adjustment,
        type: SupplierLedgerType.returnCredit,
        description: 'Credit note $creditNoteNumber',
        docNumber: existing.returnNumber,
        docId: existing.returnId,
        referenceNo: creditNoteNumber,
        date: updated.creditNoteDate,
      );
    }

    _replaceReturn(updated);
    return true;
  }

  /// Withdraw a return that is no longer expected.
  ///
  /// **No balance movement, deliberately.** The goods never went back, so the
  /// liability the GRN accrued for them still stands. Cancelling only stops the
  /// business waiting for a credit note that isn't coming.
  @action
  Future<bool> cancelPurchaseReturn(String returnId, {String? reason}) async {
    final existing = _returnRepository.getById(returnId);
    if (existing == null || !existing.isOpen) return false;

    final updated = existing.copyWith(
      status: PurchaseReturnStatus.cancelled.name,
      notes: reason ?? existing.notes,
    );

    await _returnRepository.save(updated);
    _replaceReturn(updated);
    return true;
  }

  Future<List<PurchaseReturnItemModel>> getReturnItems(String returnId) =>
      _returnRepository.getItems(returnId);

  /// Units of a GRN line already returned — the basis for a partial return.
  Future<double> returnedQtyForGRNItem(String grnItemId) =>
      _returnRepository.returnedQtyForGRNItem(grnItemId);

  void _replaceReturn(PurchaseReturnModel updated) {
    final index =
        purchaseReturns.indexWhere((r) => r.returnId == updated.returnId);
    if (index != -1) purchaseReturns[index] = updated;
  }

  // ==================== SUPPLIER CLAIM ====================

  /// Move a claim through its lifecycle. Only a pending claim can be approved
  /// or rejected; only an approved claim can be settled — so a rejected claim
  /// can't quietly become settled later.
  ///
  /// **Settlement is the claim's credit event.** The GRN billed these units, so
  /// reaching `settled` reduces the supplier balance by the claim total.
  /// Approval moves nothing (the supplier has agreed, not paid) and rejection
  /// leaves the full amount payable.
  ///
  /// [SupplierClaimModel.claimBalanceAdjustment] owns that decision and returns
  /// `0` once `creditApplied` is set, so the credit lands exactly once even if
  /// the lifecycle guard is ever loosened.
  @action
  Future<bool> updateClaimStatus({
    required String claimId,
    required SupplierClaimStatus status,
    String? resolutionNote,
  }) async {
    final existing = _claimRepository.getById(claimId);
    if (existing == null) return false;

    final current = existing.statusEnum;
    final allowed = switch (status) {
      SupplierClaimStatus.approved => current == SupplierClaimStatus.pending,
      SupplierClaimStatus.rejected => current == SupplierClaimStatus.pending,
      SupplierClaimStatus.settled => current == SupplierClaimStatus.approved,
      SupplierClaimStatus.pending => false,
    };
    if (!allowed) {
      errorMessage =
          'A ${existing.statusDisplay.toLowerCase()} claim cannot become ${status.name}.';
      return false;
    }

    final closes = status == SupplierClaimStatus.rejected ||
        status == SupplierClaimStatus.settled;

    final adjustment =
        SupplierClaimModel.claimBalanceAdjustment(existing, status);

    final updated = existing.copyWith(
      status: status.name,
      resolutionNote: resolutionNote,
      resolvedAt: closes ? DateTime.now().toIso8601String() : null,
      creditApplied: adjustment != 0 ? true : null,
    );

    await _claimRepository.save(updated);

    if (adjustment != 0) {
      await supplierStore.recordBalanceMovement(
        supplierId: existing.supplierId,
        amount: adjustment,
        type: SupplierLedgerType.claimCredit,
        description: 'Claim ${existing.claimNumber} settled',
        docNumber: existing.claimNumber,
        docId: existing.claimId,
        date: updated.resolvedAt,
      );
    }

    final index = supplierClaims.indexWhere((c) => c.claimId == claimId);
    if (index != -1) supplierClaims[index] = updated;
    return true;
  }

  /// Write a rejected claim off as an inventory loss.
  ///
  /// Deliberately manual: the supplier refusing a claim is not by itself a
  /// decision to absorb the cost, so this stays a separate act the user takes
  /// from the claim screen rather than a side effect of rejection.
  ///
  /// **Touches neither stock nor the supplier balance.** The units never
  /// entered inventory, and the liability the GRN accrued for them is exactly
  /// what makes this a real loss — so it stays.
  ///
  /// Returns the loss numbers created, or an empty list when the claim isn't
  /// rejected or was already written off.
  @action
  Future<List<String>> writeOffRejectedClaim(String claimId) async {
    final claim = _claimRepository.getById(claimId);
    if (claim == null ||
        claim.statusEnum != SupplierClaimStatus.rejected ||
        claim.isLossRecorded) {
      return [];
    }

    try {
      final lines = await _claimRepository.getItems(claimId);
      if (lines.isEmpty) return [];

      final created = <InventoryLossModel>[];
      for (final line in lines) {
        final number = await _numbers.next(
          _lossPrefix,
          isTaken: (n) => inventoryLosses.any((l) => l.lossNumber == n),
        );

        created.add(InventoryLossModel.create(
          lossNumber: number,
          source: InventoryLossSource.claimRejected,
          grnId: claim.grnId,
          grnNumber: claim.grnNumber,
          grnItemId: line.grnItemId,
          poId: claim.poId,
          supplierId: claim.supplierId,
          supplierName: claim.supplierName,
          variantId: line.variantId,
          productId: line.productId,
          productName: line.productName,
          variantInfo: line.variantInfo,
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

  Future<List<SupplierClaimItemModel>> getClaimItems(String claimId) =>
      _claimRepository.getItems(claimId);

  // ==================== LOOKUPS ====================

  /// Every damaged-goods document raised from one GRN — used to surface the
  /// paper trail on the receiving history.
  Future<GRNDamagedDocuments> documentsForGRN(String grnId) async {
    return GRNDamagedDocuments(
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
      inventoryLosses.fold(0, (sum, l) => sum + l.quantity);

  // ==================== STOCK ADJUSTMENT LOSS ====================

  /// Record the cost of stock removed by a loss-bearing manual adjustment.
  ///
  /// **Called only by `StockAdjustmentService`, and only after the stock has
  /// already been moved.** This writes the money side, never the units — see
  /// [InventoryLossModel]'s doc for why the two are split.
  ///
  /// Unlike the GRN-sourced losses there is no supplier and no source document:
  /// nobody is going to reimburse a shop for its own breakage. Returns the loss
  /// number so the caller can surface it.
  @action
  Future<String?> recordAdjustmentLoss({
    required String variantId,
    required String productId,
    String? productName,
    String? variantInfo,
    required double quantity,
    double? costPrice,
    required String reason,
    String? note,
  }) async {
    if (quantity <= 0) return null;

    try {
      final number = await _numbers.next(
        _lossPrefix,
        isTaken: (n) => inventoryLosses.any((l) => l.lossNumber == n),
      );

      final loss = InventoryLossModel.create(
        lossNumber: number,
        source: InventoryLossSource.stockAdjustment,
        variantId: variantId,
        productId: productId,
        productName: productName,
        variantInfo: variantInfo,
        quantity: quantity,
        costPrice: costPrice,
        reason: reason,
        note: note,
      );

      await _lossRepository.save(loss);
      inventoryLosses.insert(0, loss);
      return number;
    } catch (e) {
      errorMessage = 'Loss could not be recorded: $e';
      return null;
    }
  }
}

/// What [_DamagedGoodsStore.recordFromGRN] created, so the caller can tell the
/// user which documents now exist.
class DamagedGoodsOutcome {
  final String? returnNumber;
  final String? claimNumber;
  final List<String> lossNumbers;

  const DamagedGoodsOutcome({
    this.returnNumber,
    this.claimNumber,
    this.lossNumbers = const [],
  });

  bool get isEmpty =>
      returnNumber == null && claimNumber == null && lossNumbers.isEmpty;

  /// e.g. "PR-20260813-001, CLM-20260813-001, 2 write-offs"
  String get summary {
    // Spelled out rather than with null-aware elements (`?returnNumber`):
    // build_runner ships an older analyzer than the SDK and cannot parse that
    // syntax, which blocked codegen for the entire project.
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

/// The damaged-goods paper trail for a single GRN.
class GRNDamagedDocuments {
  final List<PurchaseReturnModel> returns;
  final List<SupplierClaimModel> claims;
  final List<InventoryLossModel> losses;

  const GRNDamagedDocuments({
    this.returns = const [],
    this.claims = const [],
    this.losses = const [],
  });

  bool get isEmpty => returns.isEmpty && claims.isEmpty && losses.isEmpty;
}
