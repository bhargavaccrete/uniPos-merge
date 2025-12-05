import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';

/// Filters a list of orders based on a given time period string.
/// This function is safe to use with nullable dates.
List<pastOrderModel> filterOrders(List<pastOrderModel> allOrders, String period) {
  final now = DateTime.now();

  switch (period) {
    case 'Today':
    // Filter orders where orderAt is not null AND is on the same day as today.
      return allOrders
          .where((order) => order.orderAt != null && isSameDay(order.orderAt!, now))
          .toList();

    case 'This Week':
    // Assuming the week starts on Monday.
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));

      return allOrders.where((order) {
        // First, ensure the order date is not null.
        if (order.orderAt == null) return false;

        // Normalize dates to ignore the time component for a clean comparison.
        final orderDay = DateTime(order.orderAt!.year, order.orderAt!.month, order.orderAt!.day);
        final startDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        final endDay = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day);

        // Check if the order date is within the week's range (inclusive).
        return (orderDay.isAfter(startDay) || orderDay.isAtSameMomentAs(startDay)) &&
            (orderDay.isBefore(endDay) || orderDay.isAtSameMomentAs(endDay));
      }).toList();

    case 'This Month':
      return allOrders.where((order) =>
      order.orderAt != null &&
          order.orderAt!.year == now.year &&
          order.orderAt!.month == now.month
      ).toList();

    case 'This Year':
      return allOrders
          .where((order) => order.orderAt != null && order.orderAt!.year == now.year)
          .toList();

    default:
    // If the period is unknown, return the original, unfiltered list.
      return allOrders;
  }
}

/// Helper function to check if two DateTime objects are on the same calendar day.
bool isSameDay(DateTime dateA, DateTime dateB) {
  return dateA.year == dateB.year &&
      dateA.month == dateB.month &&
      dateA.day == dateB.day;
}