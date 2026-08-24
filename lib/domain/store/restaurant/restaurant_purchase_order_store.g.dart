// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurant_purchase_order_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$RestaurantPurchaseOrderStore on _RestaurantPurchaseOrderStore, Store {
  Computed<List<RestaurantPurchaseOrderModel>>? _$receivablePOsComputed;

  @override
  List<RestaurantPurchaseOrderModel> get receivablePOs =>
      (_$receivablePOsComputed ??= Computed<List<RestaurantPurchaseOrderModel>>(
              () => super.receivablePOs,
              name: '_RestaurantPurchaseOrderStore.receivablePOs'))
          .value;

  late final _$suppliersAtom =
      Atom(name: '_RestaurantPurchaseOrderStore.suppliers', context: context);

  @override
  ObservableList<RestaurantSupplierModel> get suppliers {
    _$suppliersAtom.reportRead();
    return super.suppliers;
  }

  @override
  set suppliers(ObservableList<RestaurantSupplierModel> value) {
    _$suppliersAtom.reportWrite(value, super.suppliers, () {
      super.suppliers = value;
    });
  }

  late final _$purchaseOrdersAtom = Atom(
      name: '_RestaurantPurchaseOrderStore.purchaseOrders', context: context);

  @override
  ObservableList<RestaurantPurchaseOrderModel> get purchaseOrders {
    _$purchaseOrdersAtom.reportRead();
    return super.purchaseOrders;
  }

  @override
  set purchaseOrders(ObservableList<RestaurantPurchaseOrderModel> value) {
    _$purchaseOrdersAtom.reportWrite(value, super.purchaseOrders, () {
      super.purchaseOrders = value;
    });
  }

  late final _$grnsAtom =
      Atom(name: '_RestaurantPurchaseOrderStore.grns', context: context);

  @override
  ObservableList<RestaurantGRNModel> get grns {
    _$grnsAtom.reportRead();
    return super.grns;
  }

  @override
  set grns(ObservableList<RestaurantGRNModel> value) {
    _$grnsAtom.reportWrite(value, super.grns, () {
      super.grns = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_RestaurantPurchaseOrderStore.isLoading', context: context);

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

  late final _$errorMessageAtom = Atom(
      name: '_RestaurantPurchaseOrderStore.errorMessage', context: context);

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

  late final _$loadSuppliersAsyncAction = AsyncAction(
      '_RestaurantPurchaseOrderStore.loadSuppliers',
      context: context);

  @override
  Future<void> loadSuppliers() {
    return _$loadSuppliersAsyncAction.run(() => super.loadSuppliers());
  }

  late final _$loadPurchaseOrdersAsyncAction = AsyncAction(
      '_RestaurantPurchaseOrderStore.loadPurchaseOrders',
      context: context);

  @override
  Future<void> loadPurchaseOrders() {
    return _$loadPurchaseOrdersAsyncAction
        .run(() => super.loadPurchaseOrders());
  }

  late final _$loadGRNsAsyncAction =
      AsyncAction('_RestaurantPurchaseOrderStore.loadGRNs', context: context);

  @override
  Future<void> loadGRNs() {
    return _$loadGRNsAsyncAction.run(() => super.loadGRNs());
  }

  late final _$addSupplierAsyncAction = AsyncAction(
      '_RestaurantPurchaseOrderStore.addSupplier',
      context: context);

  @override
  Future<RestaurantSupplierModel> addSupplier(
      {required String name,
      String? phone,
      String? address,
      String? gstNumber}) {
    return _$addSupplierAsyncAction.run(() => super.addSupplier(
        name: name, phone: phone, address: address, gstNumber: gstNumber));
  }

  late final _$createPurchaseOrderAsyncAction = AsyncAction(
      '_RestaurantPurchaseOrderStore.createPurchaseOrder',
      context: context);

  @override
  Future<RestaurantPurchaseOrderModel> createPurchaseOrder(
      {required String supplierId,
      String? supplierName,
      required String expectedDeliveryDate,
      String? notes,
      required List<
              ({String itemId, String itemName, double? price, double qty})>
          lines}) {
    return _$createPurchaseOrderAsyncAction.run(() => super.createPurchaseOrder(
        supplierId: supplierId,
        supplierName: supplierName,
        expectedDeliveryDate: expectedDeliveryDate,
        notes: notes,
        lines: lines));
  }

  late final _$markPOSentAsyncAction =
      AsyncAction('_RestaurantPurchaseOrderStore.markPOSent', context: context);

  @override
  Future<void> markPOSent(String poId) {
    return _$markPOSentAsyncAction.run(() => super.markPOSent(poId));
  }

  late final _$confirmGRNAsyncAction =
      AsyncAction('_RestaurantPurchaseOrderStore.confirmGRN', context: context);

  @override
  Future<List<RestaurantGRNItemModel>> confirmGRN(
      {required String poId,
      required String poNumber,
      required String supplierId,
      String? supplierName,
      required String receivedDate,
      String? notes,
      String? invoiceNumber,
      required List<
              ({
                double acceptedQty,
                double? costPrice,
                String? damagedHandling,
                double? damagedQty,
                String itemId,
                String itemName,
                double orderedQty,
                String poItemId,
                double receivedQty
              })>
          lines}) {
    return _$confirmGRNAsyncAction.run(() => super.confirmGRN(
        poId: poId,
        poNumber: poNumber,
        supplierId: supplierId,
        supplierName: supplierName,
        receivedDate: receivedDate,
        notes: notes,
        invoiceNumber: invoiceNumber,
        lines: lines));
  }

  @override
  String toString() {
    return '''
suppliers: ${suppliers},
purchaseOrders: ${purchaseOrders},
grns: ${grns},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
receivablePOs: ${receivablePOs}
    ''';
  }
}
