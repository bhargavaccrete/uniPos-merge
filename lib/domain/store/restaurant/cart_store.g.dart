// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CartStore on _CartStore, Store {
  Computed<double>? _$cartTotalComputed;

  @override
  double get cartTotal => (_$cartTotalComputed ??=
          Computed<double>(() => super.cartTotal, name: '_CartStore.cartTotal'))
      .value;
  Computed<int>? _$totalItemsComputed;

  @override
  int get totalItems => (_$totalItemsComputed ??=
          Computed<int>(() => super.totalItems, name: '_CartStore.totalItems'))
      .value;
  Computed<int>? _$totalQuantityComputed;

  @override
  int get totalQuantity =>
      (_$totalQuantityComputed ??= Computed<int>(() => super.totalQuantity,
              name: '_CartStore.totalQuantity'))
          .value;
  Computed<bool>? _$isEmptyComputed;

  @override
  bool get isEmpty => (_$isEmptyComputed ??=
          Computed<bool>(() => super.isEmpty, name: '_CartStore.isEmpty'))
      .value;
  Computed<bool>? _$isNotEmptyComputed;

  @override
  bool get isNotEmpty => (_$isNotEmptyComputed ??=
          Computed<bool>(() => super.isNotEmpty, name: '_CartStore.isNotEmpty'))
      .value;

  late final _$cartItemsAtom =
      Atom(name: '_CartStore.cartItems', context: context);

  @override
  ObservableList<CartItem> get cartItems {
    _$cartItemsAtom.reportRead();
    return super.cartItems;
  }

  @override
  set cartItems(ObservableList<CartItem> value) {
    _$cartItemsAtom.reportWrite(value, super.cartItems, () {
      super.cartItems = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_CartStore.isLoading', context: context);

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
      Atom(name: '_CartStore.errorMessage', context: context);

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

  late final _$loadCartItemsAsyncAction =
      AsyncAction('_CartStore.loadCartItems', context: context);

  @override
  Future<void> loadCartItems() {
    return _$loadCartItemsAsyncAction.run(() => super.loadCartItems());
  }

  late final _$refreshAsyncAction =
      AsyncAction('_CartStore.refresh', context: context);

  @override
  Future<void> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  late final _$addToCartAsyncAction =
      AsyncAction('_CartStore.addToCart', context: context);

  @override
  Future<Map<String, dynamic>> addToCart(CartItem item) {
    return _$addToCartAsyncAction.run(() => super.addToCart(item));
  }

  late final _$removeFromCartAsyncAction =
      AsyncAction('_CartStore.removeFromCart', context: context);

  @override
  Future<bool> removeFromCart(String itemId) {
    return _$removeFromCartAsyncAction.run(() => super.removeFromCart(itemId));
  }

  late final _$updateQuantityAsyncAction =
      AsyncAction('_CartStore.updateQuantity', context: context);

  @override
  Future<bool> updateQuantity(String itemId, int newQuantity) {
    return _$updateQuantityAsyncAction
        .run(() => super.updateQuantity(itemId, newQuantity));
  }

  late final _$clearCartAsyncAction =
      AsyncAction('_CartStore.clearCart', context: context);

  @override
  Future<bool> clearCart() {
    return _$clearCartAsyncAction.run(() => super.clearCart());
  }

  late final _$getCartItemCountAsyncAction =
      AsyncAction('_CartStore.getCartItemCount', context: context);

  @override
  Future<int> getCartItemCount() {
    return _$getCartItemCountAsyncAction.run(() => super.getCartItemCount());
  }

  late final _$getCartTotalAsyncAction =
      AsyncAction('_CartStore.getCartTotal', context: context);

  @override
  Future<double> getCartTotal() {
    return _$getCartTotalAsyncAction.run(() => super.getCartTotal());
  }

  late final _$_CartStoreActionController =
      ActionController(name: '_CartStore', context: context);

  @override
  void clearError() {
    final _$actionInfo =
        _$_CartStoreActionController.startAction(name: '_CartStore.clearError');
    try {
      return super.clearError();
    } finally {
      _$_CartStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
cartItems: ${cartItems},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
cartTotal: ${cartTotal},
totalItems: ${totalItems},
totalQuantity: ${totalQuantity},
isEmpty: ${isEmpty},
isNotEmpty: ${isNotEmpty}
    ''';
  }
}
