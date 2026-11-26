import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../data/models/restaurant/db/pastordermodel_313.dart';
import 'stock_gate.dart';

/// The order record could not be saved — nothing was deducted.
class OrderSaveFailedException implements Exception {
  final String message;
  const OrderSaveFailedException(this.message);
  @override
  String toString() => message;
}

/// Outcome of [SettleNewOrder.commit].
class SettleNewOrderResult {
  final GatedSale sale;

  /// Set when the sale went through.
  final PastOrderModel? order;
  final int? kotNumber;
  final int? billNumber;

  const SettleNewOrderResult._(
      this.sale, this.order, this.kotNumber, this.billNumber);

  bool get refused => sale.refused;
}

/// Settle & Print / Delivery on a NEW order (customerdetails `_placeOrder`,
/// `isSettle`): the bill is saved straight to past orders and stock leaves
/// at once.
class SettleNewOrder {
  SettleNewOrder._();

  /// Inside the app-wide [StockGate] as ONE operation: check stock with
  /// `InventoryService.stockShortfalls` — refused → nothing written, no KOT
  /// or bill number taken — then the KOT and bill numbers, [build] the bill
  /// from the plan's stamped lines, save it, and deduct the stock.
  ///
  /// Throws [OrderSaveFailedException] when the save fails; no stock is
  /// deducted then. [build] must not open dialogs or print.
  static Future<SettleNewOrderResult> commit({
    required List<CartItem> items,
    required Future<PastOrderModel> Function(
            List<CartItem> stampedLines, int kotNumber, int billNumber)
        build,
  }) async {
    PastOrderModel? order;
    int? kot;
    int? bill;
    final sale = await StockGate.sell(items, write: (plan) async {
      kot = await orderStore.getNextKotNumber();
      bill = await orderStore.getNextBillNumber();
      final built = await build(plan.lines, kot!, bill!);
      if (!await pastOrderStore.addOrder(built)) {
        throw OrderSaveFailedException(
            pastOrderStore.errorMessage ?? 'The order could not be saved.');
      }
      order = built;
    });
    return SettleNewOrderResult._(sale, order, kot, bill);
  }
}
