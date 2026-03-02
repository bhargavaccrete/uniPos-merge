// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cash_movement_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CashMovementStore on _CashMovementStore, Store {
  Computed<double>? _$totalCashInComputed;

  @override
  double get totalCashIn =>
      (_$totalCashInComputed ??= Computed<double>(() => super.totalCashIn,
              name: '_CashMovementStore.totalCashIn'))
          .value;
  Computed<double>? _$totalCashOutComputed;

  @override
  double get totalCashOut =>
      (_$totalCashOutComputed ??= Computed<double>(() => super.totalCashOut,
              name: '_CashMovementStore.totalCashOut'))
          .value;

  late final _$movementsAtom =
      Atom(name: '_CashMovementStore.movements', context: context);

  @override
  ObservableList<CashMovementModel> get movements {
    _$movementsAtom.reportRead();
    return super.movements;
  }

  @override
  set movements(ObservableList<CashMovementModel> value) {
    _$movementsAtom.reportWrite(value, super.movements, () {
      super.movements = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_CashMovementStore.isLoading', context: context);

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
      Atom(name: '_CashMovementStore.errorMessage', context: context);

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

  late final _$loadTodayMovementsAsyncAction =
      AsyncAction('_CashMovementStore.loadTodayMovements', context: context);

  @override
  Future<void> loadTodayMovements(DateTime dayStart) {
    return _$loadTodayMovementsAsyncAction
        .run(() => super.loadTodayMovements(dayStart));
  }

  late final _$addMovementAsyncAction =
      AsyncAction('_CashMovementStore.addMovement', context: context);

  @override
  Future<bool> addMovement(
      {required String type,
      required double amount,
      required String reason,
      String? note}) {
    return _$addMovementAsyncAction.run(() => super
        .addMovement(type: type, amount: amount, reason: reason, note: note));
  }

  @override
  String toString() {
    return '''
movements: ${movements},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
totalCashIn: ${totalCashIn},
totalCashOut: ${totalCashOut}
    ''';
  }
}
