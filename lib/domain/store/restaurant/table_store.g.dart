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
  Computed<int>? _$totalTableCountComputed;

  @override
  int get totalTableCount =>
      (_$totalTableCountComputed ??= Computed<int>(() => super.totalTableCount,
              name: '_TableStore.totalTableCount'))
          .value;
  Computed<int>? _$availableTableCountComputed;

  @override
  int get availableTableCount => (_$availableTableCountComputed ??=
          Computed<int>(() => super.availableTableCount,
              name: '_TableStore.availableTableCount'))
      .value;

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

  late final _$loadTablesAsyncAction =
      AsyncAction('_TableStore.loadTables', context: context);

  @override
  Future<void> loadTables() {
    return _$loadTablesAsyncAction.run(() => super.loadTables());
  }

  late final _$addTableAsyncAction =
      AsyncAction('_TableStore.addTable', context: context);

  @override
  Future<void> addTable(TableModel table) {
    return _$addTableAsyncAction.run(() => super.addTable(table));
  }

  late final _$updateTableAsyncAction =
      AsyncAction('_TableStore.updateTable', context: context);

  @override
  Future<void> updateTable(TableModel table) {
    return _$updateTableAsyncAction.run(() => super.updateTable(table));
  }

  late final _$deleteTableAsyncAction =
      AsyncAction('_TableStore.deleteTable', context: context);

  @override
  Future<void> deleteTable(String id) {
    return _$deleteTableAsyncAction.run(() => super.deleteTable(id));
  }

  late final _$updateTableStatusAsyncAction =
      AsyncAction('_TableStore.updateTableStatus', context: context);

  @override
  Future<void> updateTableStatus(String tableId, String newStatus,
      {double? total, String? orderId, DateTime? orderTime}) {
    return _$updateTableStatusAsyncAction.run(() => super.updateTableStatus(
        tableId, newStatus,
        total: total, orderId: orderId, orderTime: orderTime));
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
errorMessage: ${errorMessage},
availableTables: ${availableTables},
occupiedTables: ${occupiedTables},
totalTableCount: ${totalTableCount},
availableTableCount: ${availableTableCount}
    ''';
  }
}
