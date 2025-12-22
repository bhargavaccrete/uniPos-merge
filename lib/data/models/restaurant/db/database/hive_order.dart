
import 'package:hive/hive.dart';

import '../ordermodel_309.dart';

class HiveOrders {
  static const String _boxName = 'orderBox';
  static const String _counterBoxName = 'appCounters';

  // static const String _boxName = 'orderBox';

  // Keep a static reference to the box instance
  static Box<OrderModel>? _box;

  static Future<Box<OrderModel>> _getOrderBox() async {
    // If the box is already open, return it immediately.
    if (_box != null && _box!.isOpen) {
      return _box!;
    }
    // Otherwise, open it and store the instance for future use.
    _box = await Hive.openBox<OrderModel>(_boxName);
    return _box!;
  }


// Add an Order to the Box
static Future<void> addOrder(OrderModel order) async{
  final box = await _getOrderBox();
  await box.put(order.id, order);
}

// Get All saved Orders
static Future<List<OrderModel>> getAllOrder()async {
  final box = await _getOrderBox();
  return box.values.toList();
}

// delete Box
static Future<void> deleteOrder (String id )async{
  final box = await _getOrderBox();
  await box.delete(id);
}


  static Future<int> getNextKotNumber() async {
    final counterBox = await Hive.openBox(_counterBoxName);
    // Get the last number, defaulting to 0 if it doesn't exist
    int lastNumber = await counterBox.get('lastKotNumber', defaultValue: 0);
    int newNumber = lastNumber + 1;
    // Save the new number back to the box for the next order
    await counterBox.put('lastKotNumber', newNumber);
    return newNumber;
  }

  /// Get next daily bill number (resets every day)
  /// This is separate from KOT numbers and only for completed bills
  static Future<int> getNextBillNumber() async {
    final counterBox = await Hive.openBox(_counterBoxName);

    // Check if it's a new day
    final lastBillDate = await counterBox.get('lastBillDate');
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // If it's a new day, reset the counter
    if (lastBillDate != todayStr) {
      await counterBox.put('lastBillNumber', 0);
      await counterBox.put('lastBillDate', todayStr);
    }

    // Get and increment the bill number
    int lastNumber = await counterBox.get('lastBillNumber', defaultValue: 0);
    int newNumber = lastNumber + 1;
    await counterBox.put('lastBillNumber', newNumber);

    return newNumber;
  }

  /// Reset daily bill number (called at end of day)
  static Future<void> resetDailyBillNumber() async {
    final counterBox = await Hive.openBox(_counterBoxName);
    await counterBox.put('lastBillNumber', 0);
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await counterBox.put('lastBillDate', todayStr);
    print('✅ Daily bill number reset to 0');
  }

  static Future<OrderModel?> getActiveOrderByTableId(String tableId) async{
    final box = await _getOrderBox();
    final allOrder = box.values.toList();

    try{
      final Order = allOrder.firstWhere(
          (order)=>
              order.tableNo == tableId &&
                  (order.status == 'Processing'|| order.status == 'Cooking'),
      );
      return Order;
    }catch(e){

      return null;
    }


  }


  // ... inside your HiveOrders class

  /// Updates an existing order in the database.
  /// Finds the order by its unique ID and replaces it with the updated version.
  static Future<void> updateOrder(OrderModel updatedOrder) async {
    final box = await _getOrderBox(); // Your function to open the order box
    dynamic orderKey;

    print('🔍 Looking for order with ID: ${updatedOrder.id}');
    print('📦 Total orders in box: ${box.length}');

    // Loop through the box to find the key of the order with a matching ID
    for (var key in box.keys) {
      final order = box.get(key) as OrderModel?;
      print('   Checking key: $key, Order ID: ${order?.id}, TableNo: ${order?.tableNo}');
      if (order?.id == updatedOrder.id) {
        orderKey = key;
        print('   ✅ Found matching order!');
        break; // Found the key, no need to continue looping
      }
    }

    if (orderKey != null) {
      // Use the found key to overwrite the old order with the updated one
      final oldOrder = box.get(orderKey) as OrderModel?;
      print('📝 Updating order: Old TableNo=${oldOrder?.tableNo}, New TableNo=${updatedOrder.tableNo}');
      await box.put(orderKey, updatedOrder);
      print('✅ Order updated successfully with key: $orderKey');

      // Verify the update
      final verifyOrder = box.get(orderKey) as OrderModel?;
      print('🔍 Verification - Updated TableNo: ${verifyOrder?.tableNo}');
    } else {
      // This can happen if the order was deleted elsewhere
      print("❌ Error: Could not find order with ID ${updatedOrder.id} to update.");
    }
  }


}

