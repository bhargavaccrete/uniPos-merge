import 'package:hive/hive.dart';

import '../../models/restaurant/db/table_Model_311.dart';

/// Repository layer for Table data access
class TableRepository {
  static const String _boxName = 'tablesBox';
  late Box<TableModel> _tableBox;

  TableRepository() {
    _tableBox = Hive.box<TableModel>(_boxName);
  }

  List<TableModel> getAllTables() {
    return _tableBox.values.toList();
  }

  Future<void> addTable(TableModel table) async {
    await _tableBox.put(table.id, table);
  }

  Future<void> updateTable(TableModel table) async {
    await _tableBox.put(table.id, table);
  }

  Future<void> deleteTable(String id) async {
    await _tableBox.delete(id);
  }

  TableModel? getTableById(String id) {
    return _tableBox.get(id);
  }

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
        if (orderTime != null) {
          table.timeStamp = orderTime.toIso8601String();
        }
      }
      await table.save();
    }
  }

  List<TableModel> getAvailableTables() {
    return _tableBox.values.where((t) => t.status == 'Available').toList();
  }

  List<TableModel> getOccupiedTables() {
    return _tableBox.values.where((t) => t.status != 'Available').toList();
  }

  int getTableCount() {
    return _tableBox.length;
  }

  Future<void> clearAll() async {
    await _tableBox.clear();
  }
}