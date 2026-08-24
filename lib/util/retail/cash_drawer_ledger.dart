import 'package:billberrylite/data/models/restaurant/db/cash_movement_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/domain/services/retail/return_service.dart';

/// What counts as cash moving through a retail drawer.
///
/// Extracted so the live Cash Drawer screen and the Cash Drawer History report
/// answer these questions identically. They are subtle enough that a second
/// implementation would drift: a split bill contributes only its cash leg, and
/// refunds must come from the return SALE rather than from the audit movement
/// `ReturnService` writes, or every refund is counted twice.
class CashDrawerLedger {
  const CashDrawerLedger._();

  /// The part of a sale that physically entered the till.
  ///
  /// A split bill contributes only its cash leg; a card/UPI bill contributes
  /// nothing even though it is revenue.
  static double cashComponentOf(SaleModel sale) {
    // Keyed off the stored legs, not `isSplitPayment` — an exchange writes
    // legs while remaining a single-method sale, and its cash leg is only the
    // difference, never the whole replacement value.
    if (sale.paymentListJson != null && sale.paymentListJson!.isNotEmpty) {
      return sale.paymentList
          .where((p) => (p['method'] as String? ?? '').toLowerCase() == 'cash')
          .fold(0.0, (a, p) => a + ((p['amount'] as num?)?.toDouble() ?? 0.0));
    }
    if (sale.paymentType.toLowerCase().trim() == 'cash') {
      return sale.totalAmount;
    }
    return 0.0;
  }

  /// Cash handed back on a return, or 0 when the refund never touched the till.
  ///
  /// Return headers store a negative `totalAmount`, hence the `abs()`.
  static double cashRefundOf(SaleModel sale) {
    if (sale.isReturn != true) return 0.0;

    // An exchange return's header is the whole value of the goods handed back,
    // most of which went across to the replacement rather than into anyone's
    // hand. Only its cash leg left the till. Legs are stored negative to match
    // the negated header, hence the `abs()`.
    if (sale.paymentListJson != null && sale.paymentListJson!.isNotEmpty) {
      return sale.paymentList
          .where((p) => (p['method'] as String? ?? '').toLowerCase() == 'cash')
          .fold(0.0, (a, p) => a + ((p['amount'] as num?)?.toDouble() ?? 0.0))
          .abs();
    }

    if (sale.paymentType.toLowerCase().trim() != 'cash') return 0.0;
    return sale.totalAmount.abs();
  }

  /// Manual movements that belong in the ledger.
  ///
  /// - `opening` is the day's float, shown as its own opening line rather than
  ///   a movement.
  /// - `adjustment` is audit-only and deliberately excluded from cash totals.
  /// - `refund` movements are audit-only too — the spendable figure comes from
  ///   [cashRefundOf], so counting these as well would double it.
  static bool isLedgerMovement(CashMovementModel m) =>
      m.type != 'opening' &&
      m.type != 'adjustment' &&
      m.type != ReturnService.refundMovementType;
}
