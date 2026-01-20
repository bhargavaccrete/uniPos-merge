// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'eod_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$EodStore on _EodStore, Store {
  Computed<List<EndOfDayReport>>? _$filteredReportsComputed;

  @override
  List<EndOfDayReport> get filteredReports => (_$filteredReportsComputed ??=
          Computed<List<EndOfDayReport>>(() => super.filteredReports,
              name: '_EodStore.filteredReports'))
      .value;
  Computed<int>? _$totalReportsComputed;

  @override
  int get totalReports =>
      (_$totalReportsComputed ??= Computed<int>(() => super.totalReports,
              name: '_EodStore.totalReports'))
          .value;
  Computed<double>? _$totalRevenueComputed;

  @override
  double get totalRevenue =>
      (_$totalRevenueComputed ??= Computed<double>(() => super.totalRevenue,
              name: '_EodStore.totalRevenue'))
          .value;

  late final _$eodReportsAtom =
      Atom(name: '_EodStore.eodReports', context: context);

  @override
  ObservableList<EndOfDayReport> get eodReports {
    _$eodReportsAtom.reportRead();
    return super.eodReports;
  }

  @override
  set eodReports(ObservableList<EndOfDayReport> value) {
    _$eodReportsAtom.reportWrite(value, super.eodReports, () {
      super.eodReports = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_EodStore.isLoading', context: context);

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
      Atom(name: '_EodStore.errorMessage', context: context);

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

  late final _$startDateAtom =
      Atom(name: '_EodStore.startDate', context: context);

  @override
  DateTime? get startDate {
    _$startDateAtom.reportRead();
    return super.startDate;
  }

  @override
  set startDate(DateTime? value) {
    _$startDateAtom.reportWrite(value, super.startDate, () {
      super.startDate = value;
    });
  }

  late final _$endDateAtom = Atom(name: '_EodStore.endDate', context: context);

  @override
  DateTime? get endDate {
    _$endDateAtom.reportRead();
    return super.endDate;
  }

  @override
  set endDate(DateTime? value) {
    _$endDateAtom.reportWrite(value, super.endDate, () {
      super.endDate = value;
    });
  }

  late final _$loadEODReportsAsyncAction =
      AsyncAction('_EodStore.loadEODReports', context: context);

  @override
  Future<void> loadEODReports() {
    return _$loadEODReportsAsyncAction.run(() => super.loadEODReports());
  }

  late final _$refreshAsyncAction =
      AsyncAction('_EodStore.refresh', context: context);

  @override
  Future<void> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  late final _$addEODReportAsyncAction =
      AsyncAction('_EodStore.addEODReport', context: context);

  @override
  Future<bool> addEODReport(EndOfDayReport report) {
    return _$addEODReportAsyncAction.run(() => super.addEODReport(report));
  }

  late final _$getEODByDateAsyncAction =
      AsyncAction('_EodStore.getEODByDate', context: context);

  @override
  Future<EndOfDayReport?> getEODByDate(DateTime date) {
    return _$getEODByDateAsyncAction.run(() => super.getEODByDate(date));
  }

  late final _$getLatestEODAsyncAction =
      AsyncAction('_EodStore.getLatestEOD', context: context);

  @override
  Future<EndOfDayReport?> getLatestEOD() {
    return _$getLatestEODAsyncAction.run(() => super.getLatestEOD());
  }

  late final _$updateEODReportAsyncAction =
      AsyncAction('_EodStore.updateEODReport', context: context);

  @override
  Future<bool> updateEODReport(EndOfDayReport updatedReport) {
    return _$updateEODReportAsyncAction
        .run(() => super.updateEODReport(updatedReport));
  }

  late final _$deleteEODReportAsyncAction =
      AsyncAction('_EodStore.deleteEODReport', context: context);

  @override
  Future<bool> deleteEODReport(String reportId) {
    return _$deleteEODReportAsyncAction
        .run(() => super.deleteEODReport(reportId));
  }

  late final _$_EodStoreActionController =
      ActionController(name: '_EodStore', context: context);

  @override
  void setDateRange(DateTime? start, DateTime? end) {
    final _$actionInfo =
        _$_EodStoreActionController.startAction(name: '_EodStore.setDateRange');
    try {
      return super.setDateRange(start, end);
    } finally {
      _$_EodStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearFilters() {
    final _$actionInfo =
        _$_EodStoreActionController.startAction(name: '_EodStore.clearFilters');
    try {
      return super.clearFilters();
    } finally {
      _$_EodStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearError() {
    final _$actionInfo =
        _$_EodStoreActionController.startAction(name: '_EodStore.clearError');
    try {
      return super.clearError();
    } finally {
      _$_EodStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
eodReports: ${eodReports},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
startDate: ${startDate},
endDate: ${endDate},
filteredReports: ${filteredReports},
totalReports: ${totalReports},
totalRevenue: ${totalRevenue}
    ''';
  }
}
