// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurant_stock_take_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$RestaurantStockTakeStore on _RestaurantStockTakeStore, Store {
  Computed<List<RestaurantStockTakeModel>>? _$draftTakesComputed;

  @override
  List<RestaurantStockTakeModel> get draftTakes => (_$draftTakesComputed ??=
          Computed<List<RestaurantStockTakeModel>>(() => super.draftTakes,
              name: '_RestaurantStockTakeStore.draftTakes'))
      .value;
  Computed<int>? _$openDraftCountComputed;

  @override
  int get openDraftCount =>
      (_$openDraftCountComputed ??= Computed<int>(() => super.openDraftCount,
              name: '_RestaurantStockTakeStore.openDraftCount'))
          .value;
  Computed<List<RestaurantStockTakeItemModel>>? _$varianceItemsComputed;

  @override
  List<RestaurantStockTakeItemModel> get varianceItems =>
      (_$varianceItemsComputed ??= Computed<List<RestaurantStockTakeItemModel>>(
              () => super.varianceItems,
              name: '_RestaurantStockTakeStore.varianceItems'))
          .value;
  Computed<int>? _$countedLineCountComputed;

  @override
  int get countedLineCount => (_$countedLineCountComputed ??= Computed<int>(
          () => super.countedLineCount,
          name: '_RestaurantStockTakeStore.countedLineCount'))
      .value;
  Computed<int>? _$varianceLineCountComputed;

  @override
  int get varianceLineCount => (_$varianceLineCountComputed ??= Computed<int>(
          () => super.varianceLineCount,
          name: '_RestaurantStockTakeStore.varianceLineCount'))
      .value;
  Computed<double>? _$netVarianceQtyComputed;

  @override
  double get netVarianceQty =>
      (_$netVarianceQtyComputed ??= Computed<double>(() => super.netVarianceQty,
              name: '_RestaurantStockTakeStore.netVarianceQty'))
          .value;
  Computed<double>? _$shortageQtyComputed;

  @override
  double get shortageQty =>
      (_$shortageQtyComputed ??= Computed<double>(() => super.shortageQty,
              name: '_RestaurantStockTakeStore.shortageQty'))
          .value;
  Computed<double>? _$excessQtyComputed;

  @override
  double get excessQty =>
      (_$excessQtyComputed ??= Computed<double>(() => super.excessQty,
              name: '_RestaurantStockTakeStore.excessQty'))
          .value;
  Computed<double>? _$netVarianceValueComputed;

  @override
  double get netVarianceValue => (_$netVarianceValueComputed ??=
          Computed<double>(() => super.netVarianceValue,
              name: '_RestaurantStockTakeStore.netVarianceValue'))
      .value;

  late final _$takesAtom =
      Atom(name: '_RestaurantStockTakeStore.takes', context: context);

  @override
  ObservableList<RestaurantStockTakeModel> get takes {
    _$takesAtom.reportRead();
    return super.takes;
  }

  @override
  set takes(ObservableList<RestaurantStockTakeModel> value) {
    _$takesAtom.reportWrite(value, super.takes, () {
      super.takes = value;
    });
  }

  late final _$currentItemsAtom =
      Atom(name: '_RestaurantStockTakeStore.currentItems', context: context);

  @override
  ObservableList<RestaurantStockTakeItemModel> get currentItems {
    _$currentItemsAtom.reportRead();
    return super.currentItems;
  }

  @override
  set currentItems(ObservableList<RestaurantStockTakeItemModel> value) {
    _$currentItemsAtom.reportWrite(value, super.currentItems, () {
      super.currentItems = value;
    });
  }

  late final _$currentTakeAtom =
      Atom(name: '_RestaurantStockTakeStore.currentTake', context: context);

  @override
  RestaurantStockTakeModel? get currentTake {
    _$currentTakeAtom.reportRead();
    return super.currentTake;
  }

  @override
  set currentTake(RestaurantStockTakeModel? value) {
    _$currentTakeAtom.reportWrite(value, super.currentTake, () {
      super.currentTake = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_RestaurantStockTakeStore.isLoading', context: context);

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
      Atom(name: '_RestaurantStockTakeStore.isCommitting', context: context);

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
      Atom(name: '_RestaurantStockTakeStore.errorMessage', context: context);

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
      AsyncAction('_RestaurantStockTakeStore.loadTakes', context: context);

  @override
  Future<void> loadTakes() {
    return _$loadTakesAsyncAction.run(() => super.loadTakes());
  }

  late final _$openTakeAsyncAction =
      AsyncAction('_RestaurantStockTakeStore.openTake', context: context);

  @override
  Future<void> openTake(String takeId) {
    return _$openTakeAsyncAction.run(() => super.openTake(takeId));
  }

  late final _$startTakeAsyncAction =
      AsyncAction('_RestaurantStockTakeStore.startTake', context: context);

  @override
  Future<RestaurantStockTakeModel?> startTake({String? scopeNote}) {
    return _$startTakeAsyncAction
        .run(() => super.startTake(scopeNote: scopeNote));
  }

  late final _$countItemAsyncAction =
      AsyncAction('_RestaurantStockTakeStore.countItem', context: context);

  @override
  Future<bool> countItem(
      {required Items item,
      ItemVariante? variant,
      required double countedQty}) {
    return _$countItemAsyncAction.run(() =>
        super.countItem(item: item, variant: variant, countedQty: countedQty));
  }

  late final _$removeLineAsyncAction =
      AsyncAction('_RestaurantStockTakeStore.removeLine', context: context);

  @override
  Future<bool> removeLine(String takeItemId) {
    return _$removeLineAsyncAction.run(() => super.removeLine(takeItemId));
  }

  late final _$cancelTakeAsyncAction =
      AsyncAction('_RestaurantStockTakeStore.cancelTake', context: context);

  @override
  Future<bool> cancelTake(String takeId) {
    return _$cancelTakeAsyncAction.run(() => super.cancelTake(takeId));
  }

  late final _$commitAsyncAction =
      AsyncAction('_RestaurantStockTakeStore.commit', context: context);

  @override
  Future<RestaurantStockTakeCommitResult> commit(
      {required String shortageReason, String? note}) {
    return _$commitAsyncAction
        .run(() => super.commit(shortageReason: shortageReason, note: note));
  }

  late final _$_RestaurantStockTakeStoreActionController =
      ActionController(name: '_RestaurantStockTakeStore', context: context);

  @override
  void closeTake() {
    final _$actionInfo = _$_RestaurantStockTakeStoreActionController
        .startAction(name: '_RestaurantStockTakeStore.closeTake');
    try {
      return super.closeTake();
    } finally {
      _$_RestaurantStockTakeStoreActionController.endAction(_$actionInfo);
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
