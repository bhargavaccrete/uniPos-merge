// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shift_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ShiftStore on _ShiftStore, Store {
  Computed<bool>? _$hasOpenShiftComputed;

  @override
  bool get hasOpenShift =>
      (_$hasOpenShiftComputed ??= Computed<bool>(() => super.hasOpenShift,
              name: '_ShiftStore.hasOpenShift'))
          .value;
  Computed<List<ShiftModel>>? _$closedShiftsComputed;

  @override
  List<ShiftModel> get closedShifts => (_$closedShiftsComputed ??=
          Computed<List<ShiftModel>>(() => super.closedShifts,
              name: '_ShiftStore.closedShifts'))
      .value;
  Computed<List<ShiftModel>>? _$filteredShiftsComputed;

  @override
  List<ShiftModel> get filteredShifts => (_$filteredShiftsComputed ??=
          Computed<List<ShiftModel>>(() => super.filteredShifts,
              name: '_ShiftStore.filteredShifts'))
      .value;

  late final _$shiftsAtom = Atom(name: '_ShiftStore.shifts', context: context);

  @override
  ObservableList<ShiftModel> get shifts {
    _$shiftsAtom.reportRead();
    return super.shifts;
  }

  @override
  set shifts(ObservableList<ShiftModel> value) {
    _$shiftsAtom.reportWrite(value, super.shifts, () {
      super.shifts = value;
    });
  }

  late final _$activeShiftAtom =
      Atom(name: '_ShiftStore.activeShift', context: context);

  @override
  ShiftModel? get activeShift {
    _$activeShiftAtom.reportRead();
    return super.activeShift;
  }

  @override
  set activeShift(ShiftModel? value) {
    _$activeShiftAtom.reportWrite(value, super.activeShift, () {
      super.activeShift = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_ShiftStore.isLoading', context: context);

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
      Atom(name: '_ShiftStore.errorMessage', context: context);

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

  late final _$filterPeriodAtom =
      Atom(name: '_ShiftStore.filterPeriod', context: context);

  @override
  String get filterPeriod {
    _$filterPeriodAtom.reportRead();
    return super.filterPeriod;
  }

  @override
  set filterPeriod(String value) {
    _$filterPeriodAtom.reportWrite(value, super.filterPeriod, () {
      super.filterPeriod = value;
    });
  }

  late final _$searchQueryAtom =
      Atom(name: '_ShiftStore.searchQuery', context: context);

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

  late final _$customStartAtom =
      Atom(name: '_ShiftStore.customStart', context: context);

  @override
  DateTime? get customStart {
    _$customStartAtom.reportRead();
    return super.customStart;
  }

  @override
  set customStart(DateTime? value) {
    _$customStartAtom.reportWrite(value, super.customStart, () {
      super.customStart = value;
    });
  }

  late final _$customEndAtom =
      Atom(name: '_ShiftStore.customEnd', context: context);

  @override
  DateTime? get customEnd {
    _$customEndAtom.reportRead();
    return super.customEnd;
  }

  @override
  set customEnd(DateTime? value) {
    _$customEndAtom.reportWrite(value, super.customEnd, () {
      super.customEnd = value;
    });
  }

  late final _$loadShiftsAsyncAction =
      AsyncAction('_ShiftStore.loadShifts', context: context);

  @override
  Future<void> loadShifts() {
    return _$loadShiftsAsyncAction.run(() => super.loadShifts());
  }

  late final _$loadActiveShiftForStaffAsyncAction =
      AsyncAction('_ShiftStore.loadActiveShiftForStaff', context: context);

  @override
  Future<void> loadActiveShiftForStaff(String staffId) {
    return _$loadActiveShiftForStaffAsyncAction
        .run(() => super.loadActiveShiftForStaff(staffId));
  }

  late final _$startShiftAsyncAction =
      AsyncAction('_ShiftStore.startShift', context: context);

  @override
  Future<bool> startShift(
      {required String staffId, required String staffName}) {
    return _$startShiftAsyncAction
        .run(() => super.startShift(staffId: staffId, staffName: staffName));
  }

  late final _$closeShiftAsyncAction =
      AsyncAction('_ShiftStore.closeShift', context: context);

  @override
  Future<ShiftModel?> closeShift(String shiftId) {
    return _$closeShiftAsyncAction.run(() => super.closeShift(shiftId));
  }

  late final _$refreshAsyncAction =
      AsyncAction('_ShiftStore.refresh', context: context);

  @override
  Future<void> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  late final _$_ShiftStoreActionController =
      ActionController(name: '_ShiftStore', context: context);

  @override
  void clearError() {
    final _$actionInfo = _$_ShiftStoreActionController.startAction(
        name: '_ShiftStore.clearError');
    try {
      return super.clearError();
    } finally {
      _$_ShiftStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setFilter(String period, {DateTime? start, DateTime? end}) {
    final _$actionInfo = _$_ShiftStoreActionController.startAction(
        name: '_ShiftStore.setFilter');
    try {
      return super.setFilter(period, start: start, end: end);
    } finally {
      _$_ShiftStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setSearch(String query) {
    final _$actionInfo = _$_ShiftStoreActionController.startAction(
        name: '_ShiftStore.setSearch');
    try {
      return super.setSearch(query);
    } finally {
      _$_ShiftStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
shifts: ${shifts},
activeShift: ${activeShift},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
filterPeriod: ${filterPeriod},
searchQuery: ${searchQuery},
customStart: ${customStart},
customEnd: ${customEnd},
hasOpenShift: ${hasOpenShift},
closedShifts: ${closedShifts},
filteredShifts: ${filteredShifts}
    ''';
  }
}
