// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_take_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$StockTakeStore on _StockTakeStore, Store {
  Computed<List<StockTakeModel>>? _$draftTakesComputed;

  @override
  List<StockTakeModel> get draftTakes => (_$draftTakesComputed ??=
          Computed<List<StockTakeModel>>(() => super.draftTakes,
              name: '_StockTakeStore.draftTakes'))
      .value;
  Computed<int>? _$openDraftCountComputed;

  @override
  int get openDraftCount =>
      (_$openDraftCountComputed ??= Computed<int>(() => super.openDraftCount,
              name: '_StockTakeStore.openDraftCount'))
          .value;
  Computed<List<StockTakeItemModel>>? _$varianceItemsComputed;

  @override
  List<StockTakeItemModel> get varianceItems => (_$varianceItemsComputed ??=
          Computed<List<StockTakeItemModel>>(() => super.varianceItems,
              name: '_StockTakeStore.varianceItems'))
      .value;
  Computed<int>? _$countedLineCountComputed;

  @override
  int get countedLineCount => (_$countedLineCountComputed ??= Computed<int>(
          () => super.countedLineCount,
          name: '_StockTakeStore.countedLineCount'))
      .value;
  Computed<int>? _$varianceLineCountComputed;

  @override
  int get varianceLineCount => (_$varianceLineCountComputed ??= Computed<int>(
          () => super.varianceLineCount,
          name: '_StockTakeStore.varianceLineCount'))
      .value;
  Computed<double>? _$netVarianceQtyComputed;

  @override
  double get netVarianceQty =>
      (_$netVarianceQtyComputed ??= Computed<double>(() => super.netVarianceQty,
              name: '_StockTakeStore.netVarianceQty'))
          .value;
  Computed<double>? _$shortageQtyComputed;

  @override
  double get shortageQty =>
      (_$shortageQtyComputed ??= Computed<double>(() => super.shortageQty,
              name: '_StockTakeStore.shortageQty'))
          .value;
  Computed<double>? _$excessQtyComputed;

  @override
  double get excessQty =>
      (_$excessQtyComputed ??= Computed<double>(() => super.excessQty,
              name: '_StockTakeStore.excessQty'))
          .value;
  Computed<double>? _$netVarianceValueComputed;

  @override
  double get netVarianceValue => (_$netVarianceValueComputed ??=
          Computed<double>(() => super.netVarianceValue,
              name: '_StockTakeStore.netVarianceValue'))
      .value;

  late final _$takesAtom =
      Atom(name: '_StockTakeStore.takes', context: context);

  @override
  ObservableList<StockTakeModel> get takes {
    _$takesAtom.reportRead();
    return super.takes;
  }

  @override
  set takes(ObservableList<StockTakeModel> value) {
    _$takesAtom.reportWrite(value, super.takes, () {
      super.takes = value;
    });
  }

  late final _$currentItemsAtom =
      Atom(name: '_StockTakeStore.currentItems', context: context);

  @override
  ObservableList<StockTakeItemModel> get currentItems {
    _$currentItemsAtom.reportRead();
    return super.currentItems;
  }

  @override
  set currentItems(ObservableList<StockTakeItemModel> value) {
    _$currentItemsAtom.reportWrite(value, super.currentItems, () {
      super.currentItems = value;
    });
  }

  late final _$currentTakeAtom =
      Atom(name: '_StockTakeStore.currentTake', context: context);

  @override
  StockTakeModel? get currentTake {
    _$currentTakeAtom.reportRead();
    return super.currentTake;
  }

  @override
  set currentTake(StockTakeModel? value) {
    _$currentTakeAtom.reportWrite(value, super.currentTake, () {
      super.currentTake = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_StockTakeStore.isLoading', context: context);

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

  late final _$isCommittingAtom =
      Atom(name: '_StockTakeStore.isCommitting', context: context);

  @override
  bool get isCommitting {
    _$isCommittingAtom.reportRead();
    return super.isCommitting;
  }

  @override
  set isCommitting(bool value) {
    _$isCommittingAtom.reportWrite(value, super.isCommitting, () {
      super.isCommitting = value;
    });
  }

  late final _$errorMessageAtom =
      Atom(name: '_StockTakeStore.errorMessage', context: context);

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

  late final _$loadTakesAsyncAction =
      AsyncAction('_StockTakeStore.loadTakes', context: context);

  @override
  Future<void> loadTakes() {
    return _$loadTakesAsyncAction.run(() => super.loadTakes());
  }

  late final _$openTakeAsyncAction =
      AsyncAction('_StockTakeStore.openTake', context: context);

  @override
  Future<void> openTake(String takeId) {
    return _$openTakeAsyncAction.run(() => super.openTake(takeId));
  }

  late final _$startTakeAsyncAction =
      AsyncAction('_StockTakeStore.startTake', context: context);

  @override
  Future<StockTakeModel?> startTake({String? scopeNote}) {
    return _$startTakeAsyncAction
        .run(() => super.startTake(scopeNote: scopeNote));
  }

  late final _$countVariantAsyncAction =
      AsyncAction('_StockTakeStore.countVariant', context: context);

  @override
  Future<bool> countVariant(
      {required VarianteModel variant, required double countedQty}) {
    return _$countVariantAsyncAction.run(
        () => super.countVariant(variant: variant, countedQty: countedQty));
  }

  late final _$removeLineAsyncAction =
      AsyncAction('_StockTakeStore.removeLine', context: context);

  @override
  Future<bool> removeLine(String takeItemId) {
    return _$removeLineAsyncAction.run(() => super.removeLine(takeItemId));
  }

  late final _$cancelTakeAsyncAction =
      AsyncAction('_StockTakeStore.cancelTake', context: context);

  @override
  Future<bool> cancelTake(String takeId) {
    return _$cancelTakeAsyncAction.run(() => super.cancelTake(takeId));
  }

  late final _$commitAsyncAction =
      AsyncAction('_StockTakeStore.commit', context: context);

  @override
  Future<StockTakeCommitResult> commit(
      {required StockAdjustmentReason reason, String? note}) {
    return _$commitAsyncAction
        .run(() => super.commit(reason: reason, note: note));
  }

  late final _$_StockTakeStoreActionController =
      ActionController(name: '_StockTakeStore', context: context);

  @override
  void closeTake() {
    final _$actionInfo = _$_StockTakeStoreActionController.startAction(
        name: '_StockTakeStore.closeTake');
    try {
      return super.closeTake();
    } finally {
      _$_StockTakeStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
takes: ${takes},
currentItems: ${currentItems},
currentTake: ${currentTake},
isLoading: ${isLoading},
isCommitting: ${isCommitting},
errorMessage: ${errorMessage},
draftTakes: ${draftTakes},
openDraftCount: ${openDraftCount},
varianceItems: ${varianceItems},
countedLineCount: ${countedLineCount},
varianceLineCount: ${varianceLineCount},
netVarianceQty: ${netVarianceQty},
shortageQty: ${shortageQty},
excessQty: ${excessQty},
netVarianceValue: ${netVarianceValue}
    ''';
  }
}
