// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'extra_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ExtraStore on _ExtraStore, Store {
  Computed<int>? _$extraCountComputed;

  @override
  int get extraCount => (_$extraCountComputed ??=
          Computed<int>(() => super.extraCount, name: '_ExtraStore.extraCount'))
      .value;

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

  late final _$loadExtrasAsyncAction =
      AsyncAction('_ExtraStore.loadExtras', context: context);

  @override
  Future<void> loadExtras() {
    return _$loadExtrasAsyncAction.run(() => super.loadExtras());
  }

  late final _$addExtraAsyncAction =
      AsyncAction('_ExtraStore.addExtra', context: context);

  @override
  Future<void> addExtra(Extramodel extra) {
    return _$addExtraAsyncAction.run(() => super.addExtra(extra));
  }

  late final _$updateExtraAsyncAction =
      AsyncAction('_ExtraStore.updateExtra', context: context);

  @override
  Future<void> updateExtra(Extramodel extra) {
    return _$updateExtraAsyncAction.run(() => super.updateExtra(extra));
  }

  late final _$deleteExtraAsyncAction =
      AsyncAction('_ExtraStore.deleteExtra', context: context);

  @override
  Future<void> deleteExtra(String id) {
    return _$deleteExtraAsyncAction.run(() => super.deleteExtra(id));
  }

  late final _$addToppingToExtraAsyncAction =
      AsyncAction('_ExtraStore.addToppingToExtra', context: context);

  @override
  Future<void> addToppingToExtra(String extraId, Topping topping) {
    return _$addToppingToExtraAsyncAction
        .run(() => super.addToppingToExtra(extraId, topping));
  }

  late final _$removeToppingFromExtraAsyncAction =
      AsyncAction('_ExtraStore.removeToppingFromExtra', context: context);

  @override
  Future<void> removeToppingFromExtra(String extraId, int toppingIndex) {
    return _$removeToppingFromExtraAsyncAction
        .run(() => super.removeToppingFromExtra(extraId, toppingIndex));
  }

  late final _$updateToppingInExtraAsyncAction =
      AsyncAction('_ExtraStore.updateToppingInExtra', context: context);

  @override
  Future<void> updateToppingInExtra(
      String extraId, int toppingIndex, Topping updatedTopping) {
    return _$updateToppingInExtraAsyncAction.run(() =>
        super.updateToppingInExtra(extraId, toppingIndex, updatedTopping));
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
errorMessage: ${errorMessage},
extraCount: ${extraCount}
    ''';
  }
}
