// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'table_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$TableStore on _TableStore, Store {
  Computed<List<TableModel>>? _$availableTablesComputed;

  @override
  List<TableModel> get availableTables => (_$availableTablesComputed ??=
          Computed<List<TableModel>>(() => super.availableTables,
              name: '_TableStore.availableTables'))
      .value;
  Computed<List<TableModel>>? _$occupiedTablesComputed;

  @override
  List<TableModel> get occupiedTables => (_$occupiedTablesComputed ??=
          Computed<List<TableModel>>(() => super.occupiedTables,
              name: '_TableStore.occupiedTables'))
      .value;
  Computed<List<TableModel>>? _$filteredTablesComputed;

  @override
  List<TableModel> get filteredTables => (_$filteredTablesComputed ??=
          Computed<List<TableModel>>(() => super.filteredTables,
              name: '_TableStore.filteredTables'))
      .value;
  Computed<int>? _$totalTablesComputed;

  @override
  int get totalTables =>
      (_$totalTablesComputed ??= Computed<int>(() => super.totalTables,
              name: '_TableStore.totalTables'))
          .value;
  Computed<int>? _$availableCountComputed;

  @override
  int get availableCount =>
      (_$availableCountComputed ??= Computed<int>(() => super.availableCount,
              name: '_TableStore.availableCount'))
          .value;
  Computed<int>? _$occupiedCountComputed;

  @override
  int get occupiedCount =>
      (_$occupiedCountComputed ??= Computed<int>(() => super.occupiedCount,
              name: '_TableStore.occupiedCount'))
          .value;

  late final _$tablesAtom = Atom(name: '_TableStore.tables', context: context);

  @override
  ObservableList<TableModel> get tables {
    _$tablesAtom.reportRead();
    return super.tables;
  }

  @override
  set tables(ObservableList<TableModel> value) {
    _$tablesAtom.reportWrite(value, super.tables, () {
      super.tables = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_TableStore.isLoading', context: context);

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
      Atom(name: '_TableStore.errorMessage', context: context);

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
      Atom(name: '_TableStore.searchQuery', context: context);

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

  late final _$selectedStatusAtom =
      Atom(name: '_TableStore.selectedStatus', context: context);

  @override
  String? get selectedStatus {
    _$selectedStatusAtom.reportRead();
    return super.selectedStatus;
  }

  @override
  set selectedStatus(String? value) {
    _$selectedStatusAtom.reportWrite(value, super.selectedStatus, () {
      super.selectedStatus = value;
    });
  }

  late final _$loadTablesAsyncAction =
      AsyncAction('_TableStore.loadTables', context: context);

  @override
  Future<void> loadTables() {
    return _$loadTablesAsyncAction.run(() => super.loadTables());
  }

  late final _$refreshAsyncAction =
      AsyncAction('_TableStore.refresh', context: context);

  @override
  Future<void> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  late final _$addTableAsyncAction =
      AsyncAction('_TableStore.addTable', context: context);

  @override
  Future<bool> addTable(TableModel table) {
    return _$addTableAsyncAction.run(() => super.addTable(table));
  }

  late final _$getTableByIdAsyncAction =
      AsyncAction('_TableStore.getTableById', context: context);

  @override
  Future<TableModel?> getTableById(String tableId) {
    return _$getTableByIdAsyncAction.run(() => super.getTableById(tableId));
  }

  late final _$updateTableStatusAsyncAction =
      AsyncAction('_TableStore.updateTableStatus', context: context);

  @override
  Future<bool> updateTableStatus(String tableId, String newStatus,
      {double? total, String? orderId, DateTime? orderTime}) {
    return _$updateTableStatusAsyncAction.run(() => super.updateTableStatus(
        tableId, newStatus,
        total: total, orderId: orderId, orderTime: orderTime));
  }

  late final _$deleteTableAsyncAction =
      AsyncAction('_TableStore.deleteTable', context: context);

  @override
  Future<bool> deleteTable(String tableId) {
    return _$deleteTableAsyncAction.run(() => super.deleteTable(tableId));
  }

  late final _$getTablesByStatusAsyncAction =
      AsyncAction('_TableStore.getTablesByStatus', context: context);

  @override
  Future<List<TableModel>> getTablesByStatus(String status) {
    return _$getTablesByStatusAsyncAction
        .run(() => super.getTablesByStatus(status));
  }

  late final _$tableExistsAsyncAction =
      AsyncAction('_TableStore.tableExists', context: context);

  @override
  Future<bool> tableExists(String tableId) {
    return _$tableExistsAsyncAction.run(() => super.tableExists(tableId));
  }

  late final _$_TableStoreActionController =
      ActionController(name: '_TableStore', context: context);

  @override
  void setSearchQuery(String query) {
    final _$actionInfo = _$_TableStoreActionController.startAction(
        name: '_TableStore.setSearchQuery');
    try {
      return super.setSearchQuery(query);
    } finally {
      _$_TableStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setStatusFilter(String? status) {
    final _$actionInfo = _$_TableStoreActionController.startAction(
        name: '_TableStore.setStatusFilter');
    try {
      return super.setStatusFilter(status);
    } finally {
      _$_TableStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearFilters() {
    final _$actionInfo = _$_TableStoreActionController.startAction(
        name: '_TableStore.clearFilters');
    try {
      return super.clearFilters();
    } finally {
      _$_TableStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearError() {
    final _$actionInfo = _$_TableStoreActionController.startAction(
        name: '_TableStore.clearError');
    try {
      return super.clearError();
    } finally {
      _$_TableStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
tables: ${tables},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
searchQuery: ${searchQuery},
selectedStatus: ${selectedStatus},
availableTables: ${availableTables},
occupiedTables: ${occupiedTables},
filteredTables: ${filteredTables},
totalTables: ${totalTables},
availableCount: ${availableCount},
occupiedCount: ${occupiedCount}
    ''';
  }
}
