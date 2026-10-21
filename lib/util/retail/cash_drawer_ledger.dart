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
  static double cashComponentOf(SaleModel sale) => settledLegsOf(sale)['cash'] ?? 0.0;

  /// Every method a sale settled against, and how much reached the business
  /// through each — the one decomposition the drawer balance and the payment
  /// method summary both read, so they cannot disagree.
  ///
  /// Keyed off the stored legs, not `isSplitPayment` — an exchange writes legs
  /// while remaining a single-method sale, and its cash leg is only the
  /// difference, never the whole replacement value.
  static Map<String, double> settledLegsOf(SaleModel sale) {
    final legs = <String, double>{};
    void add(String? method, double value) {
      final key = (method ?? '').toLowerCase().trim();
      if (key.isEmpty || value == 0) return;
      legs[key] = (legs[key] ?? 0) + value;
    }

    if (sale.paymentListJson != null && sale.paymentListJson!.isNotEmpty) {
      for (final p in sale.paymentList) {
        add(p['method'] as String?, (p['amount'] as num?)?.toDouble() ?? 0.0);
      }
    } else {
      add(sale.paymentType, sale.totalAmount);
    }

    // Fully settled bill: the legs are the whole story.
    //
    // Gated on `dueAmount`, never on `paidAmount` alone: sales written before
    // that field existed decode as `paidAmount == 0` (adapter default), and
    // trimming those would erase every legacy cash sale from the drawer.
    if (sale.dueAmount <= 0.009) return legs;

    // Short-paid bill. Legs written before partial payment stored the tendered
    // amount carried the full bill ALLOCATION, so trim the collected side down
    // to what was actually taken. Proportional, because a split bill can be
    // short on any leg and nothing records which one.
    final collected = legs.entries
        .where((e) => e.key != 'credit')
        .fold(0.0, (sum, e) => sum + e.value);
    if (collected > sale.paidAmount + 0.009 && collected > 0) {
      final factor = sale.paidAmount / collected;
      for (final key in legs.keys.toList()) {
        if (key == 'credit') continue;
        legs[key] =
            double.parse((legs[key]! * factor).toStringAsFixed(2));
      }
    }

    // The unpaid balance went onto the customer's account at checkout
    // (`updateAfterCreditSale`), so it belongs to credit — billed, not
    // collected — rather than going missing from the summary.
    if (sale.dueAmount > (legs['credit'] ?? 0)) {
      legs['credit'] = sale.dueAmount;
    }
    return legs;
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
