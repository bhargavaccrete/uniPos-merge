
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';

import '../filterOrders.dart';

class ItemReportData{
  final String itemName;
  int totalQuantity;
  double totalRevenue;



  ItemReportData({
    required this.itemName,
    required this.totalQuantity,
    required this.totalRevenue,
  });
}


// The updated main function
List<ItemReportData> generateItemWiseReport(List<pastOrderModel> allOrders, String period) {
  // Step 1: Filter orders by date (this function doesn't change)
  final filteredOrders = filterOrders(allOrders, period);

  // Step 2: Create a Map to group items and calculate totals
  final Map<String, ItemReportData> itemSummary = {};

  // Step 3 & 4: Loop through all orders and their items
  for (final order in filteredOrders) {
    // Debug prints to check refund data
    if ((order.refundAmount ?? 0.0) > 0 || order.orderStatus == 'FULLY_REFUNDED' || order.orderStatus == 'PARTIALLY_REFUNDED') {
      print('DEBUG ItemReport: Order ${order.id}');
      print('  orderStatus: ${order.orderStatus}');
      print('  totalPrice: ${order.totalPrice}');
      print('  refundAmount: ${order.refundAmount}');
      for (var item in order.items) {
        print('  Item ${item.title}: qty=${item.quantity}, refundedQty=${item.refundedQuantity}');
      }
    }

    // Skip fully refunded orders
    if (order.orderStatus == 'FULLY_REFUNDED') continue;

    for (final cartItem in order.items) {
      // Calculate effective quantity (exclude refunded quantities)
      final originalQuantity = cartItem.quantity;
      final refundedQuantity = cartItem.refundedQuantity ?? 0;
      final effectiveQuantity = originalQuantity - refundedQuantity;

      // Skip items that are fully refunded
      if (effectiveQuantity <= 0) continue;

      // Calculate proportional revenue for partially refunded orders
      final orderRefundRatio = order.totalPrice > 0
          ? ((order.totalPrice - (order.refundAmount ?? 0.0)) / order.totalPrice)
          : 1.0;
      final effectiveRevenue = cartItem.totalPrice * orderRefundRatio;

      // Use cartItem.title as the unique key for grouping
      if (itemSummary.containsKey(cartItem.title)) {
        // If this item already exists in our summary, update its totals
        final existingItem = itemSummary[cartItem.title]!;
        existingItem.totalQuantity += effectiveQuantity;
        existingItem.totalRevenue += effectiveRevenue;
      } else {
        // If it's a new item, add it to the summary map
        itemSummary[cartItem.title] = ItemReportData(
          itemName: cartItem.title,
          totalQuantity: effectiveQuantity,
          totalRevenue: effectiveRevenue,
        );
      }
    }
  }

  // Step 5: Convert to a list and sort by the highest revenue
  final reportList = itemSummary.values.toList()
    ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

  return reportList;
}