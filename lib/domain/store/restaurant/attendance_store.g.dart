// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$AttendanceStore on _AttendanceStore, Store {
  late final _$todayRecordsAtom =
      Atom(name: '_AttendanceStore.todayRecords', context: context);

  @override
  ObservableList<AttendanceModel> get todayRecords {
    _$todayRecordsAtom.reportRead();
    return super.todayRecords;
  }

  @override
  set todayRecords(ObservableList<AttendanceModel> value) {
    _$todayRecordsAtom.reportWrite(value, super.todayRecords, () {
      super.todayRecords = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_AttendanceStore.isLoading', context: context);

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

  late final _$loadTodayRecordsAsyncAction =
      AsyncAction('_AttendanceStore.loadTodayRecords', context: context);

  @override
  Future<void> loadTodayRecords() {
    return _$loadTodayRecordsAsyncAction.run(() => super.loadTodayRecords());
  }

  late final _$clockInAsyncAction =
      AsyncAction('_AttendanceStore.clockIn', context: context);

  @override
  Future<AttendanceModel> clockIn(
      {required String staffName,
      required String staffRole,
      String? sessionId}) {
    return _$clockInAsyncAction.run(() => super.clockIn(
        staffName: staffName, staffRole: staffRole, sessionId: sessionId));
  }

  late final _$clockOutAsyncAction =
      AsyncAction('_AttendanceStore.clockOut', context: context);

  @override
  Future<void> clockOut(String recordId) {
    return _$clockOutAsyncAction.run(() => super.clockOut(recordId));
  }

  late final _$startBreakAsyncAction =
      AsyncAction('_AttendanceStore.startBreak', context: context);

  @override
  Future<void> startBreak(String recordId) {
    return _$startBreakAsyncAction.run(() => super.startBreak(recordId));
  }

  late final _$endBreakAsyncAction =
      AsyncAction('_AttendanceStore.endBreak', context: context);

  @override
  Future<void> endBreak(String recordId) {
    return _$endBreakAsyncAction.run(() => super.endBreak(recordId));
  }

  late final _$addRecordAsyncAction =
      AsyncAction('_AttendanceStore.addRecord', context: context);

  @override
  Future<void> addRecord(AttendanceModel record) {
    return _$addRecordAsyncAction.run(() => super.addRecord(record));
  }

  late final _$deleteRecordAsyncAction =
      AsyncAction('_AttendanceStore.deleteRecord', context: context);

  @override
  Future<void> deleteRecord(String recordId) {
    return _$deleteRecordAsyncAction.run(() => super.deleteRecord(recordId));
  }

  late final _$updateRecordAsyncAction =
      AsyncAction('_AttendanceStore.updateRecord', context: context);

  @override
  Future<void> updateRecord(
      {required String recordId,
      required DateTime newClockIn,
      DateTime? newClockOut}) {
    return _$updateRecordAsyncAction.run(() => super.updateRecord(
        recordId: recordId, newClockIn: newClockIn, newClockOut: newClockOut));
  }

  late final _$autoClockOutIfOpenAsyncAction =
      AsyncAction('_AttendanceStore.autoClockOutIfOpen', context: context);

  @override
  Future<void> autoClockOutIfOpen(String staffName) {
    return _$autoClockOutIfOpenAsyncAction
        .run(() => super.autoClockOutIfOpen(staffName));
  }

  late final _$_AttendanceStoreActionController =
      ActionController(name: '_AttendanceStore', context: context);

  @override
  AttendanceModel? getActiveRecord(String staffName) {
    final _$actionInfo = _$_AttendanceStoreActionController.startAction(
        name: '_AttendanceStore.getActiveRecord');
    try {
      return super.getActiveRecord(staffName);
    } finally {
      _$_AttendanceStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
todayRecords: ${todayRecords},
isLoading: ${isLoading}
    ''';
  }
}
