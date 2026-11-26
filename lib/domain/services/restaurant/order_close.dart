import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../data/models/restaurant/db/pastordermodel_313.dart';
import 'settle_new_order.dart';

/// Moving a finished active order into past orders (SALE-4), and saving an
/// active order whose payment was just recorded (SALE-11) — without ever
/// losing the order or reporting success for a write that failed.
class OrderClose {
  OrderClose._();

  /// Saves [past] (skipped when a record with its id already exists — a retry
  /// after an earlier attempt saved it), THEN removes active order [orderId]
  /// and frees [tableNo]. A failed save throws [OrderSaveFailedException]
  /// and nothing else happens: the order stays active, nothing is lost. A
  /// failed removal also throws; the saved record then makes a retry safe.
  /// No stock moves here — a void goes through `VoidOrderCommit`.
  static Future<void> moveToPast(
    PastOrderModel past, {
    required String orderId,
    String? tableNo,
  }) async {
    final existing = await pastOrderStore.getOrderById(orderId);
    if (existing == null && !await pastOrderStore.addOrder(past)) {
      throw OrderSaveFailedException(pastOrderStore.errorMessage ??
          'The bill could not be saved. The order is still active.');
    }
    if (!await orderStore.deleteOrder(orderId)) {
      throw const OrderSaveFailedException(
          'The bill is saved, but the order could not be removed from '
          'active orders. Try again.');
    }
    if (tableNo != null && tableNo.isNotEmpty) {
      await tableStore.updateTableStatus(tableNo, 'Available');
    }
  }

  /// Saves [order] or throws [OrderSaveFailedException] — the store reports a
  /// failed save as `false`, which callers used to ignore.
  static Future<void> saveActive(OrderModel order) async {
    if (!await orderStore.updateOrder(order)) {
      throw OrderSaveFailedException(orderStore.errorMessage ??
          'The payment could not be saved. Nothing was recorded.');
    }
  }
}
