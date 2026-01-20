// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'company_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CompanyStore on _CompanyStore, Store {
  Computed<bool>? _$hasCompanyComputed;

  @override
  bool get hasCompany =>
      (_$hasCompanyComputed ??= Computed<bool>(() => super.hasCompany,
              name: '_CompanyStore.hasCompany'))
          .value;

  late final _$companyAtom =
      Atom(name: '_CompanyStore.company', context: context);

  @override
  Company? get company {
    _$companyAtom.reportRead();
    return super.company;
  }

  @override
  set company(Company? value) {
    _$companyAtom.reportWrite(value, super.company, () {
      super.company = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_CompanyStore.isLoading', context: context);

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
      Atom(name: '_CompanyStore.errorMessage', context: context);

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

  late final _$loadCompanyAsyncAction =
      AsyncAction('_CompanyStore.loadCompany', context: context);

  @override
  Future<void> loadCompany() {
    return _$loadCompanyAsyncAction.run(() => super.loadCompany());
  }

  late final _$refreshAsyncAction =
      AsyncAction('_CompanyStore.refresh', context: context);

  @override
  Future<void> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  late final _$saveCompanyAsyncAction =
      AsyncAction('_CompanyStore.saveCompany', context: context);

  @override
  Future<bool> saveCompany(Company newCompany) {
    return _$saveCompanyAsyncAction.run(() => super.saveCompany(newCompany));
  }

  late final _$updateCompanyAsyncAction =
      AsyncAction('_CompanyStore.updateCompany', context: context);

  @override
  Future<bool> updateCompany(Company updatedCompany) {
    return _$updateCompanyAsyncAction
        .run(() => super.updateCompany(updatedCompany));
  }

  late final _$deleteCompanyAsyncAction =
      AsyncAction('_CompanyStore.deleteCompany', context: context);

  @override
  Future<bool> deleteCompany() {
    return _$deleteCompanyAsyncAction.run(() => super.deleteCompany());
  }

  late final _$_CompanyStoreActionController =
      ActionController(name: '_CompanyStore', context: context);

  @override
  void clearError() {
    final _$actionInfo = _$_CompanyStoreActionController.startAction(
        name: '_CompanyStore.clearError');
    try {
      return super.clearError();
    } finally {
      _$_CompanyStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
company: ${company},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
hasCompany: ${hasCompany}
    ''';
  }
}
