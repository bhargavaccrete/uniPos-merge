// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CartStorer on _CartStorer, Store {
  Computed<int>? _$itemCountComputed;

  @override
  int get itemCount => (_$itemCountComputed ??=
          Computed<int>(() => super.itemCount, name: '_CartStorer.itemCount'))
      .value;
  Computed<int>? _$totalQuantityComputed;

  @override
  int get totalQuantity =>
      (_$totalQuantityComputed ??= Computed<int>(() => super.totalQuantity,
              name: '_CartStorer.totalQuantity'))
          .value;
  Computed<double>? _$subtotalComputed;

  @override
  double get subtotal => (_$subtotalComputed ??=
          Computed<double>(() => super.subtotal, name: '_CartStorer.subtotal'))
      .value;
  Computed<double>? _$totalTaxComputed;

  @override
  double get totalTax => (_$totalTaxComputed ??=
          Computed<double>(() => super.totalTax, name: '_CartStorer.totalTax'))
      .value;
  Computed<double>? _$totalDiscountComputed;

  @override
  double get totalDiscount =>
      (_$totalDiscountComputed ??= Computed<double>(() => super.totalDiscount,
              name: '_CartStorer.totalDiscount'))
          .value;
  Computed<double>? _$grandTotalComputed;

  @override
  double get grandTotal =>
      (_$grandTotalComputed ??= Computed<double>(() => super.grandTotal,
              name: '_CartStorer.grandTotal'))
          .value;
  Computed<bool>? _$isEmptyComputed;

  @override
  bool get isEmpty => (_$isEmptyComputed ??=
          Computed<bool>(() => super.isEmpty, name: '_CartStorer.isEmpty'))
      .value;
  Computed<bool>? _$isNotEmptyComputed;

  @override
  bool get isNotEmpty =>
      (_$isNotEmptyComputed ??= Computed<bool>(() => super.isNotEmpty,
              name: '_CartStorer.isNotEmpty'))
          .value;

  late final _$isLoadingAtom =
      Atom(name: '_CartStorer.isLoading', context: context);

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
      Atom(name: '_CartStorer.errorMessage', context: context);

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

  late final _$lastOperationMessageAtom =
      Atom(name: '_CartStorer.lastOperationMessage', context: context);

  @override
  String? get lastOperationMessage {
    _$lastOperationMessageAtom.reportRead();
    return super.lastOperationMessage;
  }

  @override
  set lastOperationMessage(String? value) {
    _$lastOperationMessageAtom.reportWrite(value, super.lastOperationMessage,
        () {
      super.lastOperationMessage = value;
    });
  }

  late final _$loadCartItemsAsyncAction =
      AsyncAction('_CartStorer.loadCartItems', context: context);

  @override
  Future<void> loadCartItems() {
    return _$loadCartItemsAsyncAction.run(() => super.loadCartItems());
  }

  late final _$addToCartAsyncAction =
      AsyncAction('_CartStorer.addToCart', context: context);

  @override
  Future<Map<String, dynamic>> addToCart(CartItem item) {
    return _$addToCartAsyncAction.run(() => super.addToCart(item));
  }

  late final _$removeFromCartAsyncAction =
      AsyncAction('_CartStorer.removeFromCart', context: context);

  @override
  Future<void> removeFromCart(String itemId) {
    return _$removeFromCartAsyncAction.run(() => super.removeFromCart(itemId));
  }

  late final _$updateQuantityAsyncAction =
      AsyncAction('_CartStorer.updateQuantity', context: context);

  @override
  Future<void> updateQuantity(String itemId, int newQuantity) {
    return _$updateQuantityAsyncAction
        .run(() => super.updateQuantity(itemId, newQuantity));
  }

  late final _$incrementQuantityAsyncAction =
      AsyncAction('_CartStorer.incrementQuantity', context: context);

  @override
  Future<void> incrementQuantity(String itemId) {
    return _$incrementQuantityAsyncAction
        .run(() => super.incrementQuantity(itemId));
  }

  late final _$decrementQuantityAsyncAction =
      AsyncAction('_CartStorer.decrementQuantity', context: context);

  @override
  Future<void> decrementQuantity(String itemId) {
    return _$decrementQuantityAsyncAction
        .run(() => super.decrementQuantity(itemId));
  }

  late final _$clearCartAsyncAction =
      AsyncAction('_CartStorer.clearCart', context: context);

  @override
  Future<void> clearCart() {
    return _$clearCartAsyncAction.run(() => super.clearCart());
  }

  late final _$_CartStorerActionController =
      ActionController(name: '_CartStorer', context: context);

  @override
  void clearError() {
    final _$actionInfo = _$_CartStorerActionController.startAction(
        name: '_CartStorer.clearError');
    try {
      return super.clearError();
    } finally {
      _$_CartStorerActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearLastMessage() {
    final _$actionInfo = _$_CartStorerActionController.startAction(
        name: '_CartStorer.clearLastMessage');
    try {
      return super.clearLastMessage();
    } finally {
      _$_CartStorerActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
errorMessage: ${errorMessage},
lastOperationMessage: ${lastOperationMessage},
itemCount: ${itemCount},
totalQuantity: ${totalQuantity},
subtotal: ${subtotal},
totalTax: ${totalTax},
totalDiscount: ${totalDiscount},
grandTotal: ${grandTotal},
isEmpty: ${isEmpty},
isNotEmpty: ${isNotEmpty}
    ''';
  }
}
