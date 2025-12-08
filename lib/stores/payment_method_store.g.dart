// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_method_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$PaymentMethodStore on _PaymentMethodStore, Store {
  Computed<List<PaymentMethod>>? _$enabledMethodsComputed;

  @override
  List<PaymentMethod> get enabledMethods => (_$enabledMethodsComputed ??=
          Computed<List<PaymentMethod>>(() => super.enabledMethods,
              name: '_PaymentMethodStore.enabledMethods'))
      .value;
  Computed<int>? _$enabledCountComputed;

  @override
  int get enabledCount =>
      (_$enabledCountComputed ??= Computed<int>(() => super.enabledCount,
              name: '_PaymentMethodStore.enabledCount'))
          .value;

  late final _$paymentMethodsAtom =
      Atom(name: '_PaymentMethodStore.paymentMethods', context: context);

  @override
  ObservableList<PaymentMethod> get paymentMethods {
    _$paymentMethodsAtom.reportRead();
    return super.paymentMethods;
  }

  @override
  set paymentMethods(ObservableList<PaymentMethod> value) {
    _$paymentMethodsAtom.reportWrite(value, super.paymentMethods, () {
      super.paymentMethods = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_PaymentMethodStore.isLoading', context: context);

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
      Atom(name: '_PaymentMethodStore.errorMessage', context: context);

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

  late final _$initAsyncAction =
      AsyncAction('_PaymentMethodStore.init', context: context);

  @override
  Future<void> init() {
    return _$initAsyncAction.run(() => super.init());
  }

  late final _$loadPaymentMethodsAsyncAction =
      AsyncAction('_PaymentMethodStore.loadPaymentMethods', context: context);

  @override
  Future<void> loadPaymentMethods() {
    return _$loadPaymentMethodsAsyncAction
        .run(() => super.loadPaymentMethods());
  }

  late final _$addPaymentMethodAsyncAction =
      AsyncAction('_PaymentMethodStore.addPaymentMethod', context: context);

  @override
  Future<void> addPaymentMethod(
      {required String name, required String value, required String iconName}) {
    return _$addPaymentMethodAsyncAction.run(() =>
        super.addPaymentMethod(name: name, value: value, iconName: iconName));
  }

  late final _$togglePaymentMethodAsyncAction =
      AsyncAction('_PaymentMethodStore.togglePaymentMethod', context: context);

  @override
  Future<void> togglePaymentMethod(String id) {
    return _$togglePaymentMethodAsyncAction
        .run(() => super.togglePaymentMethod(id));
  }

  late final _$deletePaymentMethodAsyncAction =
      AsyncAction('_PaymentMethodStore.deletePaymentMethod', context: context);

  @override
  Future<void> deletePaymentMethod(String id) {
    return _$deletePaymentMethodAsyncAction
        .run(() => super.deletePaymentMethod(id));
  }

  late final _$updatePaymentMethodAsyncAction =
      AsyncAction('_PaymentMethodStore.updatePaymentMethod', context: context);

  @override
  Future<void> updatePaymentMethod(PaymentMethod method) {
    return _$updatePaymentMethodAsyncAction
        .run(() => super.updatePaymentMethod(method));
  }

  late final _$_PaymentMethodStoreActionController =
      ActionController(name: '_PaymentMethodStore', context: context);

  @override
  void clearError() {
    final _$actionInfo = _$_PaymentMethodStoreActionController.startAction(
        name: '_PaymentMethodStore.clearError');
    try {
      return super.clearError();
    } finally {
      _$_PaymentMethodStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
paymentMethods: ${paymentMethods},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
enabledMethods: ${enabledMethods},
enabledCount: ${enabledCount}
    ''';
  }
}
