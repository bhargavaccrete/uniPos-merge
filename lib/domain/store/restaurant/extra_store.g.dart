// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'extra_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ExtraStore on _ExtraStore, Store {
  Computed<List<Extramodel>>? _$filteredExtrasComputed;

  @override
  List<Extramodel> get filteredExtras => (_$filteredExtrasComputed ??=
          Computed<List<Extramodel>>(() => super.filteredExtras,
              name: '_ExtraStore.filteredExtras'))
      .value;
  Computed<int>? _$totalExtrasComputed;

  @override
  int get totalExtras =>
      (_$totalExtrasComputed ??= Computed<int>(() => super.totalExtras,
              name: '_ExtraStore.totalExtras'))
          .value;

  late final _$extrasAtom = Atom(name: '_ExtraStore.extras', context: context);

  @override
  ObservableList<Extramodel> get extras {
    _$extrasAtom.reportRead();
    return super.extras;
  }

  @override
  set extras(ObservableList<Extramodel> value) {
    _$extrasAtom.reportWrite(value, super.extras, () {
      super.extras = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_ExtraStore.isLoading', context: context);

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
      Atom(name: '_ExtraStore.errorMessage', context: context);

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

  late final _$searchQueryAtom =
      Atom(name: '_ExtraStore.searchQuery', context: context);

  @override
  String get searchQuery {
    _$searchQueryAtom.reportRead();
    return super.searchQuery;
  }

  @override
  set searchQuery(String value) {
    _$searchQueryAtom.reportWrite(value, super.searchQuery, () {
      super.searchQuery = value;
    });
  }

  late final _$loadExtrasAsyncAction =
      AsyncAction('_ExtraStore.loadExtras', context: context);

  @override
  Future<void> loadExtras() {
    return _$loadExtrasAsyncAction.run(() => super.loadExtras());
  }

  late final _$refreshAsyncAction =
      AsyncAction('_ExtraStore.refresh', context: context);

  @override
  Future<void> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  late final _$addExtraAsyncAction =
      AsyncAction('_ExtraStore.addExtra', context: context);

  @override
  Future<bool> addExtra(Extramodel extra) {
    return _$addExtraAsyncAction.run(() => super.addExtra(extra));
  }

  late final _$getExtraByIdAsyncAction =
      AsyncAction('_ExtraStore.getExtraById', context: context);

  @override
  Future<Extramodel?> getExtraById(String id) {
    return _$getExtraByIdAsyncAction.run(() => super.getExtraById(id));
  }

  late final _$updateExtraAsyncAction =
      AsyncAction('_ExtraStore.updateExtra', context: context);

  @override
  Future<bool> updateExtra(Extramodel updatedExtra) {
    return _$updateExtraAsyncAction.run(() => super.updateExtra(updatedExtra));
  }

  late final _$deleteExtraAsyncAction =
      AsyncAction('_ExtraStore.deleteExtra', context: context);

  @override
  Future<bool> deleteExtra(String id) {
    return _$deleteExtraAsyncAction.run(() => super.deleteExtra(id));
  }

  late final _$addToppingAsyncAction =
      AsyncAction('_ExtraStore.addTopping', context: context);

  @override
  Future<bool> addTopping(String extraId, Topping topping) {
    return _$addToppingAsyncAction
        .run(() => super.addTopping(extraId, topping));
  }

  late final _$removeToppingAsyncAction =
      AsyncAction('_ExtraStore.removeTopping', context: context);

  @override
  Future<bool> removeTopping(String extraId, int toppingIndex) {
    return _$removeToppingAsyncAction
        .run(() => super.removeTopping(extraId, toppingIndex));
  }

  late final _$updateToppingAsyncAction =
      AsyncAction('_ExtraStore.updateTopping', context: context);

  @override
  Future<bool> updateTopping(
      String extraId, int toppingIndex, Topping updatedTopping) {
    return _$updateToppingAsyncAction
        .run(() => super.updateTopping(extraId, toppingIndex, updatedTopping));
  }

  late final _$_ExtraStoreActionController =
      ActionController(name: '_ExtraStore', context: context);

  @override
  void setSearchQuery(String query) {
    final _$actionInfo = _$_ExtraStoreActionController.startAction(
        name: '_ExtraStore.setSearchQuery');
    try {
      return super.setSearchQuery(query);
    } finally {
      _$_ExtraStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearError() {
    final _$actionInfo = _$_ExtraStoreActionController.startAction(
        name: '_ExtraStore.clearError');
    try {
      return super.clearError();
    } finally {
      _$_ExtraStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
extras: ${extras},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
searchQuery: ${searchQuery},
filteredExtras: ${filteredExtras},
totalExtras: ${totalExtras}
    ''';
  }
}
