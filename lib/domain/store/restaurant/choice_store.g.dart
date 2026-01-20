// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'choice_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ChoiceStore on _ChoiceStore, Store {
  Computed<List<ChoicesModel>>? _$filteredChoicesComputed;

  @override
  List<ChoicesModel> get filteredChoices => (_$filteredChoicesComputed ??=
          Computed<List<ChoicesModel>>(() => super.filteredChoices,
              name: '_ChoiceStore.filteredChoices'))
      .value;
  Computed<int>? _$totalChoicesComputed;

  @override
  int get totalChoices =>
      (_$totalChoicesComputed ??= Computed<int>(() => super.totalChoices,
              name: '_ChoiceStore.totalChoices'))
          .value;

  late final _$choicesAtom =
      Atom(name: '_ChoiceStore.choices', context: context);

  @override
  ObservableList<ChoicesModel> get choices {
    _$choicesAtom.reportRead();
    return super.choices;
  }

  @override
  set choices(ObservableList<ChoicesModel> value) {
    _$choicesAtom.reportWrite(value, super.choices, () {
      super.choices = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_ChoiceStore.isLoading', context: context);

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
      Atom(name: '_ChoiceStore.errorMessage', context: context);

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
      Atom(name: '_ChoiceStore.searchQuery', context: context);

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

  late final _$loadChoicesAsyncAction =
      AsyncAction('_ChoiceStore.loadChoices', context: context);

  @override
  Future<void> loadChoices() {
    return _$loadChoicesAsyncAction.run(() => super.loadChoices());
  }

  late final _$refreshAsyncAction =
      AsyncAction('_ChoiceStore.refresh', context: context);

  @override
  Future<void> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  late final _$addChoiceAsyncAction =
      AsyncAction('_ChoiceStore.addChoice', context: context);

  @override
  Future<bool> addChoice(ChoicesModel choice) {
    return _$addChoiceAsyncAction.run(() => super.addChoice(choice));
  }

  late final _$getChoiceByIdAsyncAction =
      AsyncAction('_ChoiceStore.getChoiceById', context: context);

  @override
  Future<ChoicesModel?> getChoiceById(String id) {
    return _$getChoiceByIdAsyncAction.run(() => super.getChoiceById(id));
  }

  late final _$updateChoiceAsyncAction =
      AsyncAction('_ChoiceStore.updateChoice', context: context);

  @override
  Future<bool> updateChoice(ChoicesModel updatedChoice) {
    return _$updateChoiceAsyncAction
        .run(() => super.updateChoice(updatedChoice));
  }

  late final _$deleteChoiceAsyncAction =
      AsyncAction('_ChoiceStore.deleteChoice', context: context);

  @override
  Future<bool> deleteChoice(String id) {
    return _$deleteChoiceAsyncAction.run(() => super.deleteChoice(id));
  }

  late final _$addOptionAsyncAction =
      AsyncAction('_ChoiceStore.addOption', context: context);

  @override
  Future<bool> addOption(String choiceId, ChoiceOption option) {
    return _$addOptionAsyncAction.run(() => super.addOption(choiceId, option));
  }

  late final _$removeOptionAsyncAction =
      AsyncAction('_ChoiceStore.removeOption', context: context);

  @override
  Future<bool> removeOption(String choiceId, int optionIndex) {
    return _$removeOptionAsyncAction
        .run(() => super.removeOption(choiceId, optionIndex));
  }

  late final _$updateOptionAsyncAction =
      AsyncAction('_ChoiceStore.updateOption', context: context);

  @override
  Future<bool> updateOption(
      String choiceId, int optionIndex, ChoiceOption updatedOption) {
    return _$updateOptionAsyncAction
        .run(() => super.updateOption(choiceId, optionIndex, updatedOption));
  }

  late final _$_ChoiceStoreActionController =
      ActionController(name: '_ChoiceStore', context: context);

  @override
  void setSearchQuery(String query) {
    final _$actionInfo = _$_ChoiceStoreActionController.startAction(
        name: '_ChoiceStore.setSearchQuery');
    try {
      return super.setSearchQuery(query);
    } finally {
      _$_ChoiceStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearError() {
    final _$actionInfo = _$_ChoiceStoreActionController.startAction(
        name: '_ChoiceStore.clearError');
    try {
      return super.clearError();
    } finally {
      _$_ChoiceStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
choices: ${choices},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
searchQuery: ${searchQuery},
filteredChoices: ${filteredChoices},
totalChoices: ${totalChoices}
    ''';
  }
}
