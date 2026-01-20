import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_box_names.dart';
import '../../models/restaurant/db/table_Model_311.dart';

/// Repository layer for Table data access (Restaurant)
/// Handles all Hive database operations for tables
class TableRepository {
  late Box<TableModel> _tableBox;

  TableRepository() {
    _tableBox = Hive.box<TableModel>(HiveBoxNames.restaurantTables);
  }

  /// Get all tables
  Future<List<TableModel>> getAllTables() async {
    return _tableBox.values.toList();
  }

  /// Add a new table
  Future<void> addTable(TableModel table) async {
    await _tableBox.put(table.id, table);
  }

  /// Get table by ID
  Future<TableModel?> getTableById(String tableId) async {
    return _tableBox.get(tableId);
  }

  /// Update table status
  Future<void> updateTableStatus(
    String tableId,
    String newStatus, {
    double? total,
    String? orderId,
    DateTime? orderTime,
  }) async {
    final table = _tableBox.get(tableId);

    if (table != null) {
      table.status = newStatus;
      if (newStatus == 'Available') {
        table.currentOrderTotal = null;
        table.currentOrderId = null;
        table.timeStamp = null;
      } else {
        table.currentOrderTotal = total;
        table.currentOrderId = orderId;
        // Set timestamp when order is placed on table
        if (orderTime != null) {
          table.timeStamp = orderTime.toIso8601String();
        }
      }
      await table.save();
    }
  }

  /// Delete table
  Future<void> deleteTable(String tableId) async {
    await _tableBox.delete(tableId);
  }

  /// Get tables by status
  Future<List<TableModel>> getTablesByStatus(String status) async {
    return _tableBox.values.where((table) => table.status == status).toList();
  }

  /// Check if table exists
  Future<bool> tableExists(String tableId) async {
    return _tableBox.containsKey(tableId);
  }
}