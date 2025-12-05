// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'choice_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ChoiceStore on _ChoiceStore, Store {
  Computed<int>? _$choiceCountComputed;

  @override
  int get choiceCount =>
      (_$choiceCountComputed ??= Computed<int>(() => super.choiceCount,
              name: '_ChoiceStore.choiceCount'))
          .value;

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

  late final _$loadChoicesAsyncAction =
      AsyncAction('_ChoiceStore.loadChoices', context: context);

  @override
  Future<void> loadChoices() {
    return _$loadChoicesAsyncAction.run(() => super.loadChoices());
  }

  late final _$addChoiceAsyncAction =
      AsyncAction('_ChoiceStore.addChoice', context: context);

  @override
  Future<void> addChoice(ChoicesModel choice) {
    return _$addChoiceAsyncAction.run(() => super.addChoice(choice));
  }

  late final _$updateChoiceAsyncAction =
      AsyncAction('_ChoiceStore.updateChoice', context: context);

  @override
  Future<void> updateChoice(ChoicesModel choice) {
    return _$updateChoiceAsyncAction.run(() => super.updateChoice(choice));
  }

  late final _$deleteChoiceAsyncAction =
      AsyncAction('_ChoiceStore.deleteChoice', context: context);

  @override
  Future<void> deleteChoice(String id) {
    return _$deleteChoiceAsyncAction.run(() => super.deleteChoice(id));
  }

  late final _$addOptionAsyncAction =
      AsyncAction('_ChoiceStore.addOption', context: context);

  @override
  Future<void> addOption(String choiceId, ChoiceOption option) {
    return _$addOptionAsyncAction.run(() => super.addOption(choiceId, option));
  }

  late final _$removeOptionAsyncAction =
      AsyncAction('_ChoiceStore.removeOption', context: context);

  @override
  Future<void> removeOption(String choiceId, int optionIndex) {
    return _$removeOptionAsyncAction
        .run(() => super.removeOption(choiceId, optionIndex));
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
errorMessage: ${errorMessage},
choiceCount: ${choiceCount}
    ''';
  }
}
