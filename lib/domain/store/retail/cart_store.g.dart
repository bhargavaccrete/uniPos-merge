// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CartStore on _CartStore, Store {
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

  late final _$addItemAsyncAction =
      AsyncAction('_CartStore.addItem', context: context);

  @override
  Future<CartOperationResult> addItem(
      ProductModel product, VarianteModel variant,
      {CategoryModel? category}) {
    return _$addItemAsyncAction
        .run(() => super.addItem(product, variant, category: category));
  }

  late final _$removeItemAsyncAction =
      AsyncAction('_CartStore.removeItem', context: context);

  @override
  Future<void> removeItem(String variantId) {
    return _$removeItemAsyncAction.run(() => super.removeItem(variantId));
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
      {CategoryModel? category}) {
    return _$addItemToTabAsyncAction
        .run(() => super.addItemToTab(product, variant, category: category));
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
