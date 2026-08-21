// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CartStore on _CartStore, Store {
  Computed<RetailBill>? _$billComputed;

  @override
  RetailBill get bill => (_$billComputed ??=
          Computed<RetailBill>(() => super.bill, name: '_CartStore.bill'))
      .value;
  Computed<int>? _$itemCountComputed;

  @override
  int get itemCount => (_$itemCountComputed ??=
          Computed<int>(() => super.itemCount, name: '_CartStore.itemCount'))
      .value;
  Computed<int>? _$totalItemsComputed;

  @override
  int get totalItems => (_$totalItemsComputed ??=
          Computed<int>(() => super.totalItems, name: '_CartStore.totalItems'))
      .value;
  Computed<double>? _$totalPriceComputed;

  @override
  double get totalPrice =>
      (_$totalPriceComputed ??= Computed<double>(() => super.totalPrice,
              name: '_CartStore.totalPrice'))
          .value;
  Computed<double>? _$totalTaxableAmountComputed;

  @override
  double get totalTaxableAmount => (_$totalTaxableAmountComputed ??=
          Computed<double>(() => super.totalTaxableAmount,
              name: '_CartStore.totalTaxableAmount'))
      .value;
  Computed<double>? _$totalGstAmountComputed;

  @override
  double get totalGstAmount =>
      (_$totalGstAmountComputed ??= Computed<double>(() => super.totalGstAmount,
              name: '_CartStore.totalGstAmount'))
          .value;
  Computed<double>? _$totalCgstAmountComputed;

  @override
  double get totalCgstAmount => (_$totalCgstAmountComputed ??= Computed<double>(
          () => super.totalCgstAmount,
          name: '_CartStore.totalCgstAmount'))
      .value;
  Computed<double>? _$totalSgstAmountComputed;

  @override
  double get totalSgstAmount => (_$totalSgstAmountComputed ??= Computed<double>(
          () => super.totalSgstAmount,
          name: '_CartStore.totalSgstAmount'))
      .value;
  Computed<double>? _$grandTotalComputed;

  @override
  double get grandTotal =>
      (_$grandTotalComputed ??= Computed<double>(() => super.grandTotal,
              name: '_CartStore.grandTotal'))
          .value;
  Computed<BillingTabModel?>? _$activeTabComputed;

  @override
  BillingTabModel? get activeTab =>
      (_$activeTabComputed ??= Computed<BillingTabModel?>(() => super.activeTab,
              name: '_CartStore.activeTab'))
          .value;

  late final _$itemsAtom = Atom(name: '_CartStore.items', context: context);

  @override
  ObservableList<CartItemModel> get items {
    _$itemsAtom.reportRead();
    return super.items;
  }

  @override
  set items(ObservableList<CartItemModel> value) {
    _$itemsAtom.reportWrite(value, super.items, () {
      super.items = value;
    });
  }

  late final _$tabsAtom = Atom(name: '_CartStore.tabs', context: context);

  @override
  ObservableList<BillingTabModel> get tabs {
    _$tabsAtom.reportRead();
    return super.tabs;
  }

  @override
  set tabs(ObservableList<BillingTabModel> value) {
    _$tabsAtom.reportWrite(value, super.tabs, () {
      super.tabs = value;
    });
  }

  late final _$activeTabIndexAtom =
      Atom(name: '_CartStore.activeTabIndex', context: context);

  @override
  int get activeTabIndex {
    _$activeTabIndexAtom.reportRead();
    return super.activeTabIndex;
  }

  @override
  set activeTabIndex(int value) {
    _$activeTabIndexAtom.reportWrite(value, super.activeTabIndex, () {
      super.activeTabIndex = value;
    });
  }

  late final _$isTaxInclusiveAtom =
      Atom(name: '_CartStore.isTaxInclusive', context: context);

  @override
  bool get isTaxInclusive {
    _$isTaxInclusiveAtom.reportRead();
    return super.isTaxInclusive;
  }

  @override
  set isTaxInclusive(bool value) {
    _$isTaxInclusiveAtom.reportWrite(value, super.isTaxInclusive, () {
      super.isTaxInclusive = value;
    });
  }

  late final _$discountTypeAtom =
      Atom(name: '_CartStore.discountType', context: context);

  @override
  DiscountType get discountType {
    _$discountTypeAtom.reportRead();
    return super.discountType;
  }

  @override
  set discountType(DiscountType value) {
    _$discountTypeAtom.reportWrite(value, super.discountType, () {
      super.discountType = value;
    });
  }

  late final _$discountValueAtom =
      Atom(name: '_CartStore.discountValue', context: context);

  @override
  double get discountValue {
    _$discountValueAtom.reportRead();
    return super.discountValue;
  }

  @override
  set discountValue(double value) {
    _$discountValueAtom.reportWrite(value, super.discountValue, () {
      super.discountValue = value;
    });
  }

  late final _$loyaltyRedemptionAtom =
      Atom(name: '_CartStore.loyaltyRedemption', context: context);

  @override
  double get loyaltyRedemption {
    _$loyaltyRedemptionAtom.reportRead();
    return super.loyaltyRedemption;
  }

  @override
  set loyaltyRedemption(double value) {
    _$loyaltyRedemptionAtom.reportWrite(value, super.loyaltyRedemption, () {
      super.loyaltyRedemption = value;
    });
  }

  late final _$loadTaxModeAsyncAction =
      AsyncAction('_CartStore.loadTaxMode', context: context);

  @override
  Future<void> loadTaxMode() {
    return _$loadTaxModeAsyncAction.run(() => super.loadTaxMode());
  }

  late final _$addItemAsyncAction =
      AsyncAction('_CartStore.addItem', context: context);

  @override
  Future<CartOperationResult> addItem(
      ProductModel product, VarianteModel variant,
      {Category? category,
      double? priceOverride,
      double? gstRateOverride,
      int qty = 1,
      double? originalPrice,
      String? overrideReason,
      String? overrideNote,
      String? lineDiscountType,
      double? lineDiscountValue,
      String? lineDiscountReason,
      String? lineDiscountNote}) {
    return _$addItemAsyncAction.run(() => super.addItem(product, variant,
        category: category,
        priceOverride: priceOverride,
        gstRateOverride: gstRateOverride,
        qty: qty,
        originalPrice: originalPrice,
        overrideReason: overrideReason,
        overrideNote: overrideNote,
        lineDiscountType: lineDiscountType,
        lineDiscountValue: lineDiscountValue,
        lineDiscountReason: lineDiscountReason,
        lineDiscountNote: lineDiscountNote));
  }

  late final _$overrideLinePriceAsyncAction =
      AsyncAction('_CartStore.overrideLinePrice', context: context);

  @override
  Future<CartOperationResult> overrideLinePrice(
      {required String variantId,
      required double newPrice,
      required String reason,
      String? note}) {
    return _$overrideLinePriceAsyncAction.run(() => super.overrideLinePrice(
        variantId: variantId, newPrice: newPrice, reason: reason, note: note));
  }

  late final _$setLineDiscountAsyncAction =
      AsyncAction('_CartStore.setLineDiscount', context: context);

  @override
  Future<CartOperationResult> setLineDiscount(
      {required String variantId,
      required DiscountType type,
      required double value,
      required String reason,
      String? note}) {
    return _$setLineDiscountAsyncAction.run(() => super.setLineDiscount(
        variantId: variantId,
        type: type,
        value: value,
        reason: reason,
        note: note));
  }

  late final _$removeItemAsyncAction =
      AsyncAction('_CartStore.removeItem', context: context);

  @override
  Future<void> removeItem(String variantId) {
    return _$removeItemAsyncAction.run(() => super.removeItem(variantId));
  }

  late final _$setQuantityAsyncAction =
      AsyncAction('_CartStore.setQuantity', context: context);

  @override
  Future<CartOperationResult> setQuantity(String variantId, int quantity) {
    return _$setQuantityAsyncAction
        .run(() => super.setQuantity(variantId, quantity));
  }

  late final _$incrementQuantityAsyncAction =
      AsyncAction('_CartStore.incrementQuantity', context: context);

  @override
  Future<CartOperationResult> incrementQuantity(String variantId) {
    return _$incrementQuantityAsyncAction
        .run(() => super.incrementQuantity(variantId));
  }

  late final _$decrementQuantityAsyncAction =
      AsyncAction('_CartStore.decrementQuantity', context: context);

  @override
  Future<void> decrementQuantity(String variantId) {
    return _$decrementQuantityAsyncAction
        .run(() => super.decrementQuantity(variantId));
  }

  late final _$clearCartAsyncAction =
      AsyncAction('_CartStore.clearCart', context: context);

  @override
  Future<void> clearCart() {
    return _$clearCartAsyncAction.run(() => super.clearCart());
  }

  late final _$createNewTabAsyncAction =
      AsyncAction('_CartStore.createNewTab', context: context);

  @override
  Future<void> createNewTab() {
    return _$createNewTabAsyncAction.run(() => super.createNewTab());
  }

  late final _$switchTabAsyncAction =
      AsyncAction('_CartStore.switchTab', context: context);

  @override
  Future<void> switchTab(int index) {
    return _$switchTabAsyncAction.run(() => super.switchTab(index));
  }

  late final _$closeTabAsyncAction =
      AsyncAction('_CartStore.closeTab', context: context);

  @override
  Future<void> closeTab(int index) {
    return _$closeTabAsyncAction.run(() => super.closeTab(index));
  }

  late final _$addItemToTabAsyncAction =
      AsyncAction('_CartStore.addItemToTab', context: context);

  @override
  Future<CartOperationResult> addItemToTab(
      ProductModel product, VarianteModel variant,
      {Category? category,
      double? priceOverride,
      double? gstRateOverride,
      int qty = 1,
      double? originalPrice,
      String? overrideReason,
      String? overrideNote,
      String? lineDiscountType,
      double? lineDiscountValue,
      String? lineDiscountReason,
      String? lineDiscountNote}) {
    return _$addItemToTabAsyncAction.run(() => super.addItemToTab(
        product, variant,
        category: category,
        priceOverride: priceOverride,
        gstRateOverride: gstRateOverride,
        qty: qty,
        originalPrice: originalPrice,
        overrideReason: overrideReason,
        overrideNote: overrideNote,
        lineDiscountType: lineDiscountType,
        lineDiscountValue: lineDiscountValue,
        lineDiscountReason: lineDiscountReason,
        lineDiscountNote: lineDiscountNote));
  }

  late final _$removeItemFromTabAsyncAction =
      AsyncAction('_CartStore.removeItemFromTab', context: context);

  @override
  Future<void> removeItemFromTab(String variantId) {
    return _$removeItemFromTabAsyncAction
        .run(() => super.removeItemFromTab(variantId));
  }

  late final _$incrementQuantityInTabAsyncAction =
      AsyncAction('_CartStore.incrementQuantityInTab', context: context);

  @override
  Future<CartOperationResult> incrementQuantityInTab(String variantId) {
    return _$incrementQuantityInTabAsyncAction
        .run(() => super.incrementQuantityInTab(variantId));
  }

  late final _$decrementQuantityInTabAsyncAction =
      AsyncAction('_CartStore.decrementQuantityInTab', context: context);

  @override
  Future<void> decrementQuantityInTab(String variantId) {
    return _$decrementQuantityInTabAsyncAction
        .run(() => super.decrementQuantityInTab(variantId));
  }

  late final _$setQuantityInTabAsyncAction =
      AsyncAction('_CartStore.setQuantityInTab', context: context);

  @override
  Future<CartOperationResult> setQuantityInTab(String variantId, int quantity) {
    return _$setQuantityInTabAsyncAction
        .run(() => super.setQuantityInTab(variantId, quantity));
  }

  late final _$setLineDiscountInTabAsyncAction =
      AsyncAction('_CartStore.setLineDiscountInTab', context: context);

  @override
  Future<CartOperationResult> setLineDiscountInTab(
      {required String variantId,
      required DiscountType type,
      required double value,
      required String reason,
      String? note}) {
    return _$setLineDiscountInTabAsyncAction.run(() => super
        .setLineDiscountInTab(
            variantId: variantId,
            type: type,
            value: value,
            reason: reason,
            note: note));
  }

  late final _$overrideLinePriceInTabAsyncAction =
      AsyncAction('_CartStore.overrideLinePriceInTab', context: context);

  @override
  Future<CartOperationResult> overrideLinePriceInTab(
      {required String variantId,
      required double newPrice,
      required String reason,
      String? note}) {
    return _$overrideLinePriceInTabAsyncAction.run(() => super
        .overrideLinePriceInTab(
            variantId: variantId,
            newPrice: newPrice,
            reason: reason,
            note: note));
  }

  late final _$clearCartAndSaveAsyncAction =
      AsyncAction('_CartStore.clearCartAndSave', context: context);

  @override
  Future<void> clearCartAndSave() {
    return _$clearCartAndSaveAsyncAction.run(() => super.clearCartAndSave());
  }

  late final _$updateTabCustomerInfoAsyncAction =
      AsyncAction('_CartStore.updateTabCustomerInfo', context: context);

  @override
  Future<void> updateTabCustomerInfo(String? name, String? phone) {
    return _$updateTabCustomerInfoAsyncAction
        .run(() => super.updateTabCustomerInfo(name, phone));
  }

  late final _$clearAllTabsAsyncAction =
      AsyncAction('_CartStore.clearAllTabs', context: context);

  @override
  Future<void> clearAllTabs() {
    return _$clearAllTabsAsyncAction.run(() => super.clearAllTabs());
  }

  late final _$_CartStoreActionController =
      ActionController(name: '_CartStore', context: context);

  @override
  void setDiscount({DiscountType? type, double? value}) {
    final _$actionInfo = _$_CartStoreActionController.startAction(
        name: '_CartStore.setDiscount');
    try {
      return super.setDiscount(type: type, value: value);
    } finally {
      _$_CartStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setLoyaltyRedemption(double value) {
    final _$actionInfo = _$_CartStoreActionController.startAction(
        name: '_CartStore.setLoyaltyRedemption');
    try {
      return super.setLoyaltyRedemption(value);
    } finally {
      _$_CartStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void resetBillingInputs() {
    final _$actionInfo = _$_CartStoreActionController.startAction(
        name: '_CartStore.resetBillingInputs');
    try {
      return super.resetBillingInputs();
    } finally {
      _$_CartStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  dynamic setactiveTab(int index) {
    final _$actionInfo = _$_CartStoreActionController.startAction(
        name: '_CartStore.setactiveTab');
    try {
      return super.setactiveTab(index);
    } finally {
      _$_CartStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
items: ${items},
tabs: ${tabs},
activeTabIndex: ${activeTabIndex},
isTaxInclusive: ${isTaxInclusive},
discountType: ${discountType},
discountValue: ${discountValue},
loyaltyRedemption: ${loyaltyRedemption},
bill: ${bill},
itemCount: ${itemCount},
totalItems: ${totalItems},
totalPrice: ${totalPrice},
totalTaxableAmount: ${totalTaxableAmount},
totalGstAmount: ${totalGstAmount},
totalCgstAmount: ${totalCgstAmount},
totalSgstAmount: ${totalSgstAmount},
grandTotal: ${grandTotal},
activeTab: ${activeTab}
    ''';
  }
}
