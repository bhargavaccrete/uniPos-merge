import 'package:mobx/mobx.dart';
import '../../../data/models/restaurant/db/table_Model_311.dart';
import '../../../data/repositories/restaurant/table_repository.dart';

part 'table_store.g.dart';

class TableStore = _TableStore with _$TableStore;

abstract class _TableStore with Store {
  final TableRepository _repository;

  _TableStore(this._repository);

  @observable
  ObservableList<TableModel> tables = ObservableList<TableModel>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  String searchQuery = '';

  @observable
  String? selectedStatus;

  // Computed properties
  @computed
  List<TableModel> get availableTables =>
      tables.where((table) => table.status == 'Available').toList();

  @computed
  List<TableModel> get occupiedTables =>
      tables.where((table) => table.status == 'Cooking' || table.status == 'Running' || table.status == 'Reserved').toList();

  @computed
  List<TableModel> get filteredTables {
    var result = tables.toList();

    if (searchQuery.isNotEmpty) {
      final lowercaseQuery = searchQuery.toLowerCase();
      result = result.where((table) => table.id.toLowerCase().contains(lowercaseQuery)).toList();
    }

    if (selectedStatus != null && selectedStatus!.isNotEmpty) {
      result = result.where((table) => table.status == selectedStatus).toList();
    }

    return result;
  }

  @computed
  int get totalTables => tables.length;

  @computed
  int get availableCount => availableTables.length;

  @computed
  int get occupiedCount => occupiedTables.length;

  // Actions
  @action
  Future<void> loadTables() async {
    try {
      isLoading = true;
      errorMessage = null;
      final loadedTables = await _repository.getAllTables();
      tables = ObservableList.of(loadedTables);
    } catch (e) {
      errorMessage = 'Failed to load tables: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> refresh() async {
    await loadTables();
  }

  @action
  Future<bool> addTable(TableModel table) async {
    try {
      await _repository.addTable(table);
      tables.add(table);
      return true;
    } catch (e) {
      errorMessage = 'Failed to add table: $e';
      return false;
    }
  }

  @action
  Future<TableModel?> getTableById(String tableId) async {
    try {
      return await _repository.getTableById(tableId);
    } catch (e) {
      errorMessage = 'Failed to get table: $e';
      return null;
    }
  }

  @action
  Future<bool> updateTableStatus(
    String tableId,
    String newStatus, {
    double? total,
    String? orderId,
    DateTime? orderTime,
  }) async {
    try {
      await _repository.updateTableStatus(
        tableId,
        newStatus,
        total: total,
        orderId: orderId,
        orderTime: orderTime,
      );

      // Update local state
      final index = tables.indexWhere((t) => t.id == tableId);
      if (index != -1) {
        final table = tables[index];
        table.status = newStatus;
        if (newStatus == 'Available') {
          table.currentOrderTotal = null;
          table.currentOrderId = null;
          table.timeStamp = null;
        } else {
          table.currentOrderTotal = total;
          table.currentOrderId = orderId;
          if (orderTime != null) {
            table.timeStamp = orderTime.toIso8601String();
          }
        }
        tables[index] = table;
      }

      return true;
    } catch (e) {
      errorMessage = 'Failed to update table status: $e';
      return false;
    }
  }

  @action
  Future<bool> deleteTable(String tableId) async {
    try {
      await _repository.deleteTable(tableId);
      tables.removeWhere((table) => table.id == tableId);
      return true;
    } catch (e) {
      errorMessage = 'Failed to delete table: $e';
      return false;
    }
  }

  @action
  Future<List<TableModel>> getTablesByStatus(String status) async {
    try {
      return await _repository.getTablesByStatus(status);
    } catch (e) {
      errorMessage = 'Failed to get tables by status: $e';
      return [];
    }
  }

  @action
  Future<bool> tableExists(String tableId) async {
    try {
      return await _repository.tableExists(tableId);
    } catch (e) {
      errorMessage = 'Failed to check table existence: $e';
      return false;
    }
  }

  @action
  void setSearchQuery(String query) {
    searchQuery = query;
  }

  @action
  void setStatusFilter(String? status) {
    selectedStatus = status;
  }

  @action
  void clearFilters() {
    searchQuery = '';
    selectedStatus = null;
  }

  @action
  void clearError() {
    errorMessage = null;
  }
}