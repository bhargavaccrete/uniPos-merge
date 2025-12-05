import 'package:mobx/mobx.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/table_Model_311.dart';
import '../../../data/repositories/restaurant/table_repository.dart';

part 'table_store.g.dart';

class TableStore = _TableStore with _$TableStore;

abstract class _TableStore with Store {
  final TableRepository _tableRepository = locator<TableRepository>();

  final ObservableList<TableModel> tables = ObservableList<TableModel>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  _TableStore() {
    _init();
  }

  Future<void> _init() async {
    await loadTables();
  }

  @computed
  List<TableModel> get availableTables {
    return tables.where((t) => t.status == 'Available').toList();
  }

  @computed
  List<TableModel> get occupiedTables {
    return tables.where((t) => t.status != 'Available').toList();
  }

  @computed
  int get totalTableCount => tables.length;

  @computed
  int get availableTableCount => availableTables.length;

  @action
  Future<void> loadTables() async {
    isLoading = true;
    errorMessage = null;
    try {
      final loadedTables = _tableRepository.getAllTables();
      tables.clear();
      tables.addAll(loadedTables);
    } catch (e) {
      errorMessage = 'Failed to load tables: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> addTable(TableModel table) async {
    try {
      await _tableRepository.addTable(table);
      tables.add(table);
    } catch (e) {
      errorMessage = 'Failed to add table: $e';
      rethrow;
    }
  }

  @action
  Future<void> updateTable(TableModel table) async {
    try {
      await _tableRepository.updateTable(table);
      final index = tables.indexWhere((t) => t.id == table.id);
      if (index != -1) {
        tables[index] = table;
      }
    } catch (e) {
      errorMessage = 'Failed to update table: $e';
      rethrow;
    }
  }

  @action
  Future<void> deleteTable(String id) async {
    try {
      await _tableRepository.deleteTable(id);
      tables.removeWhere((table) => table.id == id);
    } catch (e) {
      errorMessage = 'Failed to delete table: $e';
      rethrow;
    }
  }

  @action
  Future<void> updateTableStatus(
    String tableId,
    String newStatus, {
    double? total,
    String? orderId,
    DateTime? orderTime,
  }) async {
    try {
      await _tableRepository.updateTableStatus(
        tableId,
        newStatus,
        total: total,
        orderId: orderId,
        orderTime: orderTime,
      );
      await loadTables(); // Reload to get updated state
    } catch (e) {
      errorMessage = 'Failed to update table status: $e';
      rethrow;
    }
  }

  TableModel? getTableById(String id) {
    try {
      return tables.firstWhere((table) => table.id == id);
    } catch (e) {
      return null;
    }
  }
}