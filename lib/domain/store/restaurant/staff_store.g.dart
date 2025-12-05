// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staff_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$StaffStore on _StaffStore, Store {
  Computed<List<StaffModel>>? _$activeStaffComputed;

  @override
  List<StaffModel> get activeStaff => (_$activeStaffComputed ??=
          Computed<List<StaffModel>>(() => super.activeStaff,
              name: '_StaffStore.activeStaff'))
      .value;
  Computed<int>? _$totalStaffCountComputed;

  @override
  int get totalStaffCount =>
      (_$totalStaffCountComputed ??= Computed<int>(() => super.totalStaffCount,
              name: '_StaffStore.totalStaffCount'))
          .value;

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

  late final _$currentLoggedInStaffAtom =
      Atom(name: '_StaffStore.currentLoggedInStaff', context: context);

  @override
  StaffModel? get currentLoggedInStaff {
    _$currentLoggedInStaffAtom.reportRead();
    return super.currentLoggedInStaff;
  }

  @override
  set currentLoggedInStaff(StaffModel? value) {
    _$currentLoggedInStaffAtom.reportWrite(value, super.currentLoggedInStaff,
        () {
      super.currentLoggedInStaff = value;
    });
  }

  late final _$loadStaffAsyncAction =
      AsyncAction('_StaffStore.loadStaff', context: context);

  @override
  Future<void> loadStaff() {
    return _$loadStaffAsyncAction.run(() => super.loadStaff());
  }

  late final _$addStaffAsyncAction =
      AsyncAction('_StaffStore.addStaff', context: context);

  @override
  Future<void> addStaff(StaffModel staff) {
    return _$addStaffAsyncAction.run(() => super.addStaff(staff));
  }

  late final _$updateStaffAsyncAction =
      AsyncAction('_StaffStore.updateStaff', context: context);

  @override
  Future<void> updateStaff(StaffModel staff) {
    return _$updateStaffAsyncAction.run(() => super.updateStaff(staff));
  }

  late final _$deleteStaffAsyncAction =
      AsyncAction('_StaffStore.deleteStaff', context: context);

  @override
  Future<void> deleteStaff(String id) {
    return _$deleteStaffAsyncAction.run(() => super.deleteStaff(id));
  }

  late final _$_StaffStoreActionController =
      ActionController(name: '_StaffStore', context: context);

  @override
  bool loginWithPin(String pin) {
    final _$actionInfo = _$_StaffStoreActionController.startAction(
        name: '_StaffStore.loginWithPin');
    try {
      return super.loginWithPin(pin);
    } finally {
      _$_StaffStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void logout() {
    final _$actionInfo =
        _$_StaffStoreActionController.startAction(name: '_StaffStore.logout');
    try {
      return super.logout();
    } finally {
      _$_StaffStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
errorMessage: ${errorMessage},
currentLoggedInStaff: ${currentLoggedInStaff},
activeStaff: ${activeStaff},
totalStaffCount: ${totalStaffCount}
    ''';
  }
}
