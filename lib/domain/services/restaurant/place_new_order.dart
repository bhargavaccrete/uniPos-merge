import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../data/models/restaurant/db/ordermodel_309.dart';
import 'settle_new_order.dart';
import 'stock_gate.dart';

/// Place Order on a NEW order (Takeaway `_placeOrder`): check stock, write
/// the active order and deduct, as ONE operation in the app-wide
/// [StockGate] — the same shape as [SettleNewOrder].
class PlaceNewOrder {
  PlaceNewOrder._();

  /// [build] makes the order from the plan's stamped lines. When the order
  /// cannot be saved, throws [OrderSaveFailedException] and deducts nothing
  /// (SALE-3): the caller must not print a KOT or report success.
  static Future<GatedSale> commit({
    required List<CartItem> items,
    required Future<OrderModel> Function(List<CartItem> stampedLines) build,
  }) =>
      StockGate.sell(items, write: (plan) async {
        final order = await build(plan.lines);
        if (!await orderStore.addOrder(order)) {
          throw OrderSaveFailedException(
              orderStore.errorMessage ?? 'The order could not be saved.');
        }
      });
}
