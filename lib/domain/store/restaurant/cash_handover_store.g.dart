// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cash_handover_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CashHandoverStore on _CashHandoverStore, Store {
  late final _$pendingHandoverAtom =
      Atom(name: '_CashHandoverStore.pendingHandover', context: context);

  @override
  CashHandoverModel? get pendingHandover {
    _$pendingHandoverAtom.reportRead();
    return super.pendingHandover;
  }

  @override
  set pendingHandover(CashHandoverModel? value) {
    _$pendingHandoverAtom.reportWrite(value, super.pendingHandover, () {
      super.pendingHandover = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_CashHandoverStore.isLoading', context: context);

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
      Atom(name: '_CashHandoverStore.errorMessage', context: context);

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

  late final _$loadPendingHandoverAsyncAction =
      AsyncAction('_CashHandoverStore.loadPendingHandover', context: context);

  @override
  Future<void> loadPendingHandover() {
    return _$loadPendingHandoverAsyncAction
        .run(() => super.loadPendingHandover());
  }

  late final _$createHandoverAsyncAction =
      AsyncAction('_CashHandoverStore.createHandover', context: context);

  @override
  Future<bool> createHandover(
      {required String closedBy,
      required double closedAmount,
      String? closedNote}) {
    return _$createHandoverAsyncAction.run(() => super.createHandover(
        closedBy: closedBy,
        closedAmount: closedAmount,
        closedNote: closedNote));
  }

  late final _$receiveHandoverAsyncAction =
      AsyncAction('_CashHandoverStore.receiveHandover', context: context);

  @override
  Future<CashHandoverModel?> receiveHandover(
      {required String handoverId,
      required String receivedBy,
      required double receivedAmount,
      String? receivedNote}) {
    return _$receiveHandoverAsyncAction.run(() => super.receiveHandover(
        handoverId: handoverId,
        receivedBy: receivedBy,
        receivedAmount: receivedAmount,
        receivedNote: receivedNote));
  }

  @override
  String toString() {
    return '''
pendingHandover: ${pendingHandover},
isLoading: ${isLoading},
errorMessage: ${errorMessage}
    ''';
  }
}
