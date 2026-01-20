
import 'package:hive/hive.dart';
import 'package:unipos/server/websocket.dart' as ws;

import '../ordermodel_309.dart';
import '../cartmodel_308.dart';


class HiveOrders {
  static const String _boxName = 'orderBox';
  static const String _counterBoxName = 'appCounters';

  // static const String _boxName = 'orderBox';

  // Keep a static reference to the box instance
  static Box<OrderModel>? _box;

  static Box<OrderModel> _getOrderBox() {
    // Box is already opened during app startup in HiveInit
    if (_box == null || !_box!.isOpen) {
      _box = Hive.box<OrderModel>(_boxName);
    }
    return _box!;
  }


// Add an Order to the Box
static Future<void> addOrder(OrderModel order) async{
  final box = _getOrderBox();
  await box.put(order.id, order);
}

// Get All saved Orders
static Future<List<OrderModel>> getAllOrder()async {
  final box = _getOrderBox();
  return box.values.toList();
}

// delete Box
static Future<void> deleteOrder (String id )async{
  final box = _getOrderBox();
  await box.delete(id);
}


  static Future<int> getNextKotNumber() async {
    // Box is already opened during app startup in HiveInit
    final counterBox = Hive.box(_counterBoxName);
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
    // Box is already opened during app startup in HiveInit
    final counterBox = Hive.box(_counterBoxName);

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
    // Box is already opened during app startup in HiveInit
    final counterBox = Hive.box(_counterBoxName);
    await counterBox.put('lastBillNumber', 0);
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await counterBox.put('lastBillDate', todayStr);
    print('✅ Daily bill number reset to 0');
  }

  /// Get next daily order number (resets every day)
  /// This is assigned when order is PLACED (not when paid like bill number)
  static Future<int> getNextOrderNumber() async {
    // Box is already opened during app startup in HiveInit
    final counterBox = Hive.box(_counterBoxName);

    // Check if it's a new day
    final lastOrderDate = await counterBox.get('lastOrderDate');
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // If it's a new day, reset the counter
    if (lastOrderDate != todayStr) {
      await counterBox.put('lastOrderNumber', 0);
      await counterBox.put('lastOrderDate', todayStr);
      print('🔄 New day detected - Order number reset to 0');
    }

    // Get and increment the order number
    int lastNumber = await counterBox.get('lastOrderNumber', defaultValue: 0);
    int newNumber = lastNumber + 1;
    await counterBox.put('lastOrderNumber', newNumber);

    print('📋 Order Number Generated: #$newNumber');
    return newNumber;
  }

  /// Reset daily order number (called at end of day)
  static Future<void> resetDailyOrderNumber() async {
    // Box is already opened during app startup in HiveInit
    final counterBox = Hive.box(_counterBoxName);
    await counterBox.put('lastOrderNumber', 0);
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await counterBox.put('lastOrderDate', todayStr);
    print('✅ Daily order number reset to 0');
  }

  static Future<OrderModel?> getActiveOrderByTableId(String tableId) async{
    final box = _getOrderBox();
    final allOrder = box.values.toList();

    try{
      final Order = allOrder.firstWhere(
          (order)=>
              order.tableNo == tableId &&
                  (order.status == 'Processing' ||
                   order.status == 'Cooking' ||
                   order.status == 'Ready' ||
                   order.status == 'Running' ||
                   order.status == 'Reserved' ||
                   order.status == 'Served'),
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
    final box = _getOrderBox(); // Your function to open the order box
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

  /// Updates order with new items added (e.g., when adding items to existing order)
  /// Automatically handles:
  /// - Resetting status to "Processing" if it was "Ready" or "Served"
  /// - Generating new KOT number for additional items
  /// - Updating KOT boundaries
  /// - Broadcasting WebSocket event for real-time updates
  static Future<OrderModel> updateOrderWithNewItems({
    required OrderModel existingOrder,
    required List<CartItem> newItems,
    bool broadcastUpdate = true,
  }) async {
    // Check if we need to reset status (order was Ready or Served)
    bool needsStatusReset = existingOrder.status == 'Ready' || existingOrder.status == 'Served';

    // Generate new KOT number for the additional items
    final newKotNumber = await getNextKotNumber();

    // Combine existing and new items
    final combinedItems = [...existingOrder.items, ...newItems];

    // Update KOT tracking
    final updatedKotNumbers = [...existingOrder.kotNumbers, newKotNumber];
    final updatedBoundaries = [...existingOrder.kotBoundaries, combinedItems.length];

    // Create updated order
    final updatedOrder = existingOrder.copyWith(
      items: combinedItems,
      status: needsStatusReset ? 'Processing' : existingOrder.status,
      kotNumbers: updatedKotNumbers,
      itemCountAtLastKot: combinedItems.length,
      kotBoundaries: updatedBoundaries,
    );

    // Save to database
    await updateOrder(updatedOrder);

    print('✅ Order ${existingOrder.id} updated with ${newItems.length} new items');
    print('   New KOT #$newKotNumber generated');
    print('   Status: ${existingOrder.status} → ${updatedOrder.status}');

    // Broadcast update via WebSocket if requested
    if (broadcastUpdate) {
      try {

        ws.broadcastEvent({
          'type': needsStatusReset ? 'ORDER_UPDATED' : 'NEW_ITEMS_ADDED',
          'orderId': updatedOrder.id,
          'status': updatedOrder.status,
          'tableNo': updatedOrder.tableNo,
          'kotNumber': newKotNumber,
          'newItemCount': newItems.length,
          'allKotNumbers': updatedKotNumbers,
        });
        print('📡 WebSocket event broadcast: ${needsStatusReset ? "ORDER_UPDATED" : "NEW_ITEMS_ADDED"}');
      } catch (e) {
        print('⚠️ Failed to broadcast WebSocket event: $e');
      }
    }

    return updatedOrder;
  }


}

