/// One revenue transaction, normalised across the two verticals.
///
/// Shift reporting asks the same four questions in both modes — when did this
/// happen, which shift owned it, what did it net, and what was discounted or
/// refunded — but the underlying rows could hardly be less alike:
///
/// * Restaurant keeps a `PastOrderModel` whose status flips on a refund and
///   whose `refundAmount` is netted off the same row.
/// * Retail writes a whole second `SaleModel` with `isReturn: true` and
///   **negated header amounts**, so a plain sum already nets.
///
/// Rather than teach `ShiftStore` and Staff Performance both shapes, the
/// repository — the only layer that touches Hive — flattens each into this.
/// Revenue-eligibility is applied there too, so anything that reaches a
/// consumer already counts.
class ShiftTxn {
  /// Order id / sale id. Only needs to be unique within a mode.
  final String id;

  /// When it happened. Restaurant: `orderAt`. Retail: parsed `createdAt`, the
  /// timestamp every other retail report already agrees on.
  final DateTime at;

  /// The shift that owned it, or null for rows written before shifts existed —
  /// those fall back to time-window matching.
  final String? shiftId;

  /// Net revenue contributed. Restaurant nets `refundAmount` off here; retail's
  /// return headers arrive already negated.
  final double amount;

  final double discount;

  /// Positive magnitude of what was refunded, for the "Refunds" figure.
  final double refund;

  /// Restaurant order type (Dine In / Takeaway / …). **Null in retail**, which
  /// has no such concept — Staff Performance hides the breakdown when every
  /// txn comes back null.
  final String? typeLabel;

  const ShiftTxn({
    required this.id,
    required this.at,
    required this.shiftId,
    required this.amount,
    required this.discount,
    required this.refund,
    this.typeLabel,
  });
}
