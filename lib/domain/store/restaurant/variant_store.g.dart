// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'variant_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$VariantStore on _VariantStore, Store {
  Computed<List<VariantModel>>? _$filteredVariantsComputed;

  @override
  List<VariantModel> get filteredVariants => (_$filteredVariantsComputed ??=
          Computed<List<VariantModel>>(() => super.filteredVariants,
              name: '_VariantStore.filteredVariants'))
      .value;
  Computed<int>? _$totalVariantsComputed;

  @override
  int get totalVariants =>
      (_$totalVariantsComputed ??= Computed<int>(() => super.totalVariants,
              name: '_VariantStore.totalVariants'))
          .value;

  late final _$variantsAtom =
      Atom(name: '_VariantStore.variants', context: context);

  @override
  ObservableList<VariantModel> get variants {
    _$variantsAtom.reportRead();
    return super.variants;
  }

  @override
  set variants(ObservableList<VariantModel> value) {
    _$variantsAtom.reportWrite(value, super.variants, () {
      super.variants = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_VariantStore.isLoading', context: context);

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
      Atom(name: '_VariantStore.errorMessage', context: context);

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
      Atom(name: '_VariantStore.searchQuery', context: context);

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

  late final _$loadVariantsAsyncAction =
      AsyncAction('_VariantStore.loadVariants', context: context);

  @override
  Future<void> loadVariants() {
    return _$loadVariantsAsyncAction.run(() => super.loadVariants());
  }

  late final _$refreshAsyncAction =
      AsyncAction('_VariantStore.refresh', context: context);

  @override
  Future<void> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  late final _$addVariantAsyncAction =
      AsyncAction('_VariantStore.addVariant', context: context);

  @override
  Future<bool> addVariant(VariantModel variant) {
    return _$addVariantAsyncAction.run(() => super.addVariant(variant));
  }

  late final _$getVariantByIdAsyncAction =
      AsyncAction('_VariantStore.getVariantById', context: context);

  @override
  Future<VariantModel?> getVariantById(String id) {
    return _$getVariantByIdAsyncAction.run(() => super.getVariantById(id));
  }

  late final _$updateVariantAsyncAction =
      AsyncAction('_VariantStore.updateVariant', context: context);

  @override
  Future<bool> updateVariant(VariantModel updatedVariant) {
    return _$updateVariantAsyncAction
        .run(() => super.updateVariant(updatedVariant));
  }

  late final _$deleteVariantAsyncAction =
      AsyncAction('_VariantStore.deleteVariant', context: context);

  @override
  Future<bool> deleteVariant(String id) {
    return _$deleteVariantAsyncAction.run(() => super.deleteVariant(id));
  }

  late final _$_VariantStoreActionController =
      ActionController(name: '_VariantStore', context: context);

  @override
  void setSearchQuery(String query) {
    final _$actionInfo = _$_VariantStoreActionController.startAction(
        name: '_VariantStore.setSearchQuery');
    try {
      return super.setSearchQuery(query);
    } finally {
      _$_VariantStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearFilters() {
    final _$actionInfo = _$_VariantStoreActionController.startAction(
        name: '_VariantStore.clearFilters');
    try {
      return super.clearFilters();
    } finally {
      _$_VariantStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearError() {
    final _$actionInfo = _$_VariantStoreActionController.startAction(
        name: '_VariantStore.clearError');
    try {
      return super.clearError();
    } finally {
      _$_VariantStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
variants: ${variants},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
searchQuery: ${searchQuery},
filteredVariants: ${filteredVariants},
totalVariants: ${totalVariants}
    ''';
  }
}
