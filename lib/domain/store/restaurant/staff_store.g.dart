// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staff_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$StaffStore on _StaffStore, Store {
  Computed<List<StaffModel>>? _$filteredStaffComputed;

  @override
  List<StaffModel> get filteredStaff => (_$filteredStaffComputed ??=
          Computed<List<StaffModel>>(() => super.filteredStaff,
              name: '_StaffStore.filteredStaff'))
      .value;
  Computed<List<StaffModel>>? _$activeStaffComputed;

  @override
  List<StaffModel> get activeStaff => (_$activeStaffComputed ??=
          Computed<List<StaffModel>>(() => super.activeStaff,
              name: '_StaffStore.activeStaff'))
      .value;
  Computed<int>? _$totalStaffComputed;

  @override
  int get totalStaff => (_$totalStaffComputed ??=
          Computed<int>(() => super.totalStaff, name: '_StaffStore.totalStaff'))
      .value;
  Computed<int>? _$activeStaffCountComputed;

  @override
  int get activeStaffCount => (_$activeStaffCountComputed ??= Computed<int>(
          () => super.activeStaffCount,
          name: '_StaffStore.activeStaffCount'))
      .value;

  late final _$staffAtom = Atom(name: '_StaffStore.staff', context: context);

  @override
  ObservableList<StaffModel> get staff {
    _$staffAtom.reportRead();
    return super.staff;
  }

  @override
  set staff(ObservableList<StaffModel> value) {
    _$staffAtom.reportWrite(value, super.staff, () {
      super.staff = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_StaffStore.isLoading', context: context);

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
      Atom(name: '_StaffStore.errorMessage', context: context);

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
      Atom(name: '_StaffStore.searchQuery', context: context);

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

  late final _$selectedCashierStatusAtom =
      Atom(name: '_StaffStore.selectedCashierStatus', context: context);

  @override
  String? get selectedCashierStatus {
    _$selectedCashierStatusAtom.reportRead();
    return super.selectedCashierStatus;
  }

  @override
  set selectedCashierStatus(String? value) {
    _$selectedCashierStatusAtom.reportWrite(value, super.selectedCashierStatus,
        () {
      super.selectedCashierStatus = value;
    });
  }

  late final _$showActiveOnlyAtom =
      Atom(name: '_StaffStore.showActiveOnly', context: context);

  @override
  bool get showActiveOnly {
    _$showActiveOnlyAtom.reportRead();
    return super.showActiveOnly;
  }

  @override
  set showActiveOnly(bool value) {
    _$showActiveOnlyAtom.reportWrite(value, super.showActiveOnly, () {
      super.showActiveOnly = value;
    });
  }

  late final _$loadStaffAsyncAction =
      AsyncAction('_StaffStore.loadStaff', context: context);

  @override
  Future<void> loadStaff() {
    return _$loadStaffAsyncAction.run(() => super.loadStaff());
  }

  late final _$refreshAsyncAction =
      AsyncAction('_StaffStore.refresh', context: context);

  @override
  Future<void> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  late final _$addStaffAsyncAction =
      AsyncAction('_StaffStore.addStaff', context: context);

  @override
  Future<bool> addStaff(StaffModel newStaff) {
    return _$addStaffAsyncAction.run(() => super.addStaff(newStaff));
  }

  late final _$getStaffByIdAsyncAction =
      AsyncAction('_StaffStore.getStaffById', context: context);

  @override
  Future<StaffModel?> getStaffById(String id) {
    return _$getStaffByIdAsyncAction.run(() => super.getStaffById(id));
  }

  late final _$updateStaffAsyncAction =
      AsyncAction('_StaffStore.updateStaff', context: context);

  @override
  Future<bool> updateStaff(StaffModel updatedStaff) {
    return _$updateStaffAsyncAction.run(() => super.updateStaff(updatedStaff));
  }

  late final _$deleteStaffAsyncAction =
      AsyncAction('_StaffStore.deleteStaff', context: context);

  @override
  Future<bool> deleteStaff(String id) {
    return _$deleteStaffAsyncAction.run(() => super.deleteStaff(id));
  }

  late final _$searchStaffAsyncAction =
      AsyncAction('_StaffStore.searchStaff', context: context);

  @override
  Future<List<StaffModel>> searchStaff(String query) {
    return _$searchStaffAsyncAction.run(() => super.searchStaff(query));
  }

  late final _$getStaffByCashierStatusAsyncAction =
      AsyncAction('_StaffStore.getStaffByCashierStatus', context: context);

  @override
  Future<List<StaffModel>> getStaffByCashierStatus(String isCashier) {
    return _$getStaffByCashierStatusAsyncAction
        .run(() => super.getStaffByCashierStatus(isCashier));
  }

  late final _$_StaffStoreActionController =
      ActionController(name: '_StaffStore', context: context);

  @override
  void setSearchQuery(String query) {
    final _$actionInfo = _$_StaffStoreActionController.startAction(
        name: '_StaffStore.setSearchQuery');
    try {
      return super.setSearchQuery(query);
    } finally {
      _$_StaffStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setCashierStatusFilter(String? status) {
    final _$actionInfo = _$_StaffStoreActionController.startAction(
        name: '_StaffStore.setCashierStatusFilter');
    try {
      return super.setCashierStatusFilter(status);
    } finally {
      _$_StaffStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setShowActiveOnly(bool value) {
    final _$actionInfo = _$_StaffStoreActionController.startAction(
        name: '_StaffStore.setShowActiveOnly');
    try {
      return super.setShowActiveOnly(value);
    } finally {
      _$_StaffStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearFilters() {
    final _$actionInfo = _$_StaffStoreActionController.startAction(
        name: '_StaffStore.clearFilters');
    try {
      return super.clearFilters();
    } finally {
      _$_StaffStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearError() {
    final _$actionInfo = _$_StaffStoreActionController.startAction(
        name: '_StaffStore.clearError');
    try {
      return super.clearError();
    } finally {
      _$_StaffStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
staff: ${staff},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
searchQuery: ${searchQuery},
selectedCashierStatus: ${selectedCashierStatus},
showActiveOnly: ${showActiveOnly},
filteredStaff: ${filteredStaff},
activeStaff: ${activeStaff},
totalStaff: ${totalStaff},
activeStaffCount: ${activeStaffCount}
    ''';
  }
}
