// lib/database/hive_tables.dart

import 'package:hive/hive.dart';
import 'package:unipos/data/models/restaurant/db/table_Model_311.dart';

class HiveTables {
  static const String _boxName = 'tablesBox';

  static Box<TableModel> _getBox() {
    return Hive.box<TableModel>(_boxName);
  }

  static Future<void> addTable(TableModel table) async {
    final box = _getBox();
    await box.put(table.id, table);
  }

  // MODIFIED FUNCTION TO CATCH THE ERROR
  static Future<List<TableModel>> getAllTables() async {
    try {
      final box = _getBox();
      return box.values.toList();
    } catch (e, stacktrace) {
      // This will print the real, specific error to your debug console
      print('!!!!!!!!!! HIVE DATABASE ERROR !!!!!!!!!!');
      print('Error: $e');
      print('Stacktrace: $stacktrace');
      rethrow; // This makes sure your UI still shows an error message
    }
  }

  static Future<void> updateTableStatus(String tableId, String newStatus, {double? total, String? orderId, DateTime? orderTime}) async {
    final box = _getBox();
    final table = box.get(tableId);

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
}
