// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurant_damaged_goods_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$RestaurantDamagedGoodsStore on _RestaurantDamagedGoodsStore, Store {
  Computed<int>? _$openReturnCountComputed;

  @override
  int get openReturnCount =>
      (_$openReturnCountComputed ??= Computed<int>(() => super.openReturnCount,
              name: '_RestaurantDamagedGoodsStore.openReturnCount'))
          .value;
  Computed<int>? _$openClaimCountComputed;

  @override
  int get openClaimCount =>
      (_$openClaimCountComputed ??= Computed<int>(() => super.openClaimCount,
              name: '_RestaurantDamagedGoodsStore.openClaimCount'))
          .value;
  Computed<double>? _$openClaimValueComputed;

  @override
  double get openClaimValue =>
      (_$openClaimValueComputed ??= Computed<double>(() => super.openClaimValue,
              name: '_RestaurantDamagedGoodsStore.openClaimValue'))
          .value;
  Computed<double>? _$totalLossValueComputed;

  @override
  double get totalLossValue =>
      (_$totalLossValueComputed ??= Computed<double>(() => super.totalLossValue,
              name: '_RestaurantDamagedGoodsStore.totalLossValue'))
          .value;
  Computed<double>? _$totalLossQtyComputed;

  @override
  double get totalLossQty =>
      (_$totalLossQtyComputed ??= Computed<double>(() => super.totalLossQty,
              name: '_RestaurantDamagedGoodsStore.totalLossQty'))
          .value;

  late final _$purchaseReturnsAtom = Atom(
      name: '_RestaurantDamagedGoodsStore.purchaseReturns', context: context);

  @override
  ObservableList<RestaurantPurchaseReturnModel> get purchaseReturns {
    _$purchaseReturnsAtom.reportRead();
    return super.purchaseReturns;
  }

  @override
  set purchaseReturns(ObservableList<RestaurantPurchaseReturnModel> value) {
    _$purchaseReturnsAtom.reportWrite(value, super.purchaseReturns, () {
      super.purchaseReturns = value;
    });
  }

  late final _$supplierClaimsAtom = Atom(
      name: '_RestaurantDamagedGoodsStore.supplierClaims', context: context);

  @override
  ObservableList<RestaurantSupplierClaimModel> get supplierClaims {
    _$supplierClaimsAtom.reportRead();
    return super.supplierClaims;
  }

  @override
  set supplierClaims(ObservableList<RestaurantSupplierClaimModel> value) {
    _$supplierClaimsAtom.reportWrite(value, super.supplierClaims, () {
      super.supplierClaims = value;
    });
  }

  late final _$inventoryLossesAtom = Atom(
      name: '_RestaurantDamagedGoodsStore.inventoryLosses', context: context);

  @override
  ObservableList<RestaurantInventoryLossModel> get inventoryLosses {
    _$inventoryLossesAtom.reportRead();
    return super.inventoryLosses;
  }

  @override
  set inventoryLosses(ObservableList<RestaurantInventoryLossModel> value) {
    _$inventoryLossesAtom.reportWrite(value, super.inventoryLosses, () {
      super.inventoryLosses = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_RestaurantDamagedGoodsStore.isLoading', context: context);

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$errorMessageAtom =
      Atom(name: '_RestaurantDamagedGoodsStore.errorMessage', context: context);

  @override
  String? get errorMessage {
    _$errorMessageAtom.reportRead();
    return super.errorMessage;
  }

  @override
  set errorMessage(String? value) {
    _$errorMessageAtom.reportWrite(value, super.errorMessage, () {
      super.errorMessage = value;
    });
  }

  late final _$loadAllAsyncAction =
      AsyncAction('_RestaurantDamagedGoodsStore.loadAll', context: context);

  @override
  Future<void> loadAll() {
    return _$loadAllAsyncAction.run(() => super.loadAll());
  }

  late final _$recordFromGRNAsyncAction = AsyncAction(
      '_RestaurantDamagedGoodsStore.recordFromGRN',
      context: context);

  @override
  Future<RestaurantDamagedGoodsOutcome> recordFromGRN(
      {required RestaurantGRNModel grn,
      required List<RestaurantGRNItemModel> items}) {
    return _$recordFromGRNAsyncAction
        .run(() => super.recordFromGRN(grn: grn, items: items));
  }

  late final _$recordCreditNoteAsyncAction = AsyncAction(
      '_RestaurantDamagedGoodsStore.recordCreditNote',
      context: context);

  @override
  Future<bool> recordCreditNote(
      {required String returnId,
      required String creditNoteNumber,
      double? amount,
      String? date}) {
    return _$recordCreditNoteAsyncAction.run(() => super.recordCreditNote(
        returnId: returnId,
        creditNoteNumber: creditNoteNumber,
        amount: amount,
        date: date));
  }

  late final _$cancelPurchaseReturnAsyncAction = AsyncAction(
      '_RestaurantDamagedGoodsStore.cancelPurchaseReturn',
      context: context);

  @override
  Future<bool> cancelPurchaseReturn(String returnId, {String? reason}) {
    return _$cancelPurchaseReturnAsyncAction
        .run(() => super.cancelPurchaseReturn(returnId, reason: reason));
  }

  late final _$updateClaimStatusAsyncAction = AsyncAction(
      '_RestaurantDamagedGoodsStore.updateClaimStatus',
      context: context);

  @override
  Future<bool> updateClaimStatus(
      {required String claimId,
      required RestaurantSupplierClaimStatus status,
      String? resolutionNote}) {
    return _$updateClaimStatusAsyncAction.run(() => super.updateClaimStatus(
        claimId: claimId, status: status, resolutionNote: resolutionNote));
  }

  late final _$writeOffRejectedClaimAsyncAction = AsyncAction(
      '_RestaurantDamagedGoodsStore.writeOffRejectedClaim',
      context: context);

  @override
  Future<List<String>> writeOffRejectedClaim(String claimId) {
    return _$writeOffRejectedClaimAsyncAction
        .run(() => super.writeOffRejectedClaim(claimId));
  }

  @override
  String toString() {
    return '''
purchaseReturns: ${purchaseReturns},
supplierClaims: ${supplierClaims},
inventoryLosses: ${inventoryLosses},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
openReturnCount: ${openReturnCount},
openClaimCount: ${openClaimCount},
openClaimValue: ${openClaimValue},
totalLossValue: ${totalLossValue},
totalLossQty: ${totalLossQty}
    ''';
  }
}
