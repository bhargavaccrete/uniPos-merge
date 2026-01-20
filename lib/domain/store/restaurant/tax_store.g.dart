// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tax_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$TaxStore on _TaxStore, Store {
  Computed<List<Tax>>? _$filteredTaxesComputed;

  @override
  List<Tax> get filteredTaxes => (_$filteredTaxesComputed ??=
          Computed<List<Tax>>(() => super.filteredTaxes,
              name: '_TaxStore.filteredTaxes'))
      .value;
  Computed<int>? _$totalTaxesComputed;

  @override
  int get totalTaxes => (_$totalTaxesComputed ??=
          Computed<int>(() => super.totalTaxes, name: '_TaxStore.totalTaxes'))
      .value;

  late final _$taxesAtom = Atom(name: '_TaxStore.taxes', context: context);

  @override
  ObservableList<Tax> get taxes {
    _$taxesAtom.reportRead();
    return super.taxes;
  }

  @override
  set taxes(ObservableList<Tax> value) {
    _$taxesAtom.reportWrite(value, super.taxes, () {
      super.taxes = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_TaxStore.isLoading', context: context);

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
      Atom(name: '_TaxStore.errorMessage', context: context);

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
      Atom(name: '_TaxStore.searchQuery', context: context);

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

  late final _$loadTaxesAsyncAction =
      AsyncAction('_TaxStore.loadTaxes', context: context);

  @override
  Future<void> loadTaxes() {
    return _$loadTaxesAsyncAction.run(() => super.loadTaxes());
  }

  late final _$refreshAsyncAction =
      AsyncAction('_TaxStore.refresh', context: context);

  @override
  Future<void> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  late final _$addTaxAsyncAction =
      AsyncAction('_TaxStore.addTax', context: context);

  @override
  Future<bool> addTax(Tax tax) {
    return _$addTaxAsyncAction.run(() => super.addTax(tax));
  }

  late final _$getTaxByIdAsyncAction =
      AsyncAction('_TaxStore.getTaxById', context: context);

  @override
  Future<Tax?> getTaxById(String id) {
    return _$getTaxByIdAsyncAction.run(() => super.getTaxById(id));
  }

  late final _$updateTaxAsyncAction =
      AsyncAction('_TaxStore.updateTax', context: context);

  @override
  Future<bool> updateTax(Tax updatedTax) {
    return _$updateTaxAsyncAction.run(() => super.updateTax(updatedTax));
  }

  late final _$deleteTaxAsyncAction =
      AsyncAction('_TaxStore.deleteTax', context: context);

  @override
  Future<bool> deleteTax(String id) {
    return _$deleteTaxAsyncAction.run(() => super.deleteTax(id));
  }

  late final _$_TaxStoreActionController =
      ActionController(name: '_TaxStore', context: context);

  @override
  void setSearchQuery(String query) {
    final _$actionInfo = _$_TaxStoreActionController.startAction(
        name: '_TaxStore.setSearchQuery');
    try {
      return super.setSearchQuery(query);
    } finally {
      _$_TaxStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearError() {
    final _$actionInfo =
        _$_TaxStoreActionController.startAction(name: '_TaxStore.clearError');
    try {
      return super.clearError();
    } finally {
      _$_TaxStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
taxes: ${taxes},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
searchQuery: ${searchQuery},
filteredTaxes: ${filteredTaxes},
totalTaxes: ${totalTaxes}
    ''';
  }
}
