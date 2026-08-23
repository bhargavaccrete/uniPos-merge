/// Fixed reason vocabulary for a POS price override.
///
/// A dropdown rather than free text so "why did this line sell below list"
/// always has a machine-readable answer. An override squeezes margin on a sale
/// that has already been settled; without a stored reason the profit report
/// shows a dip nobody can explain — the same argument that makes
/// [StockAdjustmentReason] mandatory for stock.
///
/// Mirrors `StockAdjustmentReason` deliberately: same shape, same [byCode] /
/// [labelFor] contract, so screens and reports treat both the same way.
class PriceOverrideReason {
  /// Stored on the cart line and the sale line. Stable — never rename.
  final String code;

  /// Shown in the dropdown. Free to reword.
  final String label;

  /// Forces the note field before saving. Set on [other], where the reason
  /// alone explains nothing.
  final bool requiresNote;

  const PriceOverrideReason({
    required this.code,
    required this.label,
    this.requiresNote = false,
  });

  static const customerNegotiation = PriceOverrideReason(
    code: 'customer_negotiation',
    label: 'Customer Negotiation',
  );

  static const specialCustomerPrice = PriceOverrideReason(
    code: 'special_customer_price',
    label: 'Special Customer Price',
  );

  static const clearance = PriceOverrideReason(
    code: 'clearance',
    label: 'Clearance',
  );

  static const damagedPackaging = PriceOverrideReason(
    code: 'damaged_packaging',
    label: 'Damaged Packaging',
  );

  static const managerApproved = PriceOverrideReason(
    code: 'manager_approved',
    label: 'Manager Approved',
  );

  static const pricingCorrection = PriceOverrideReason(
    code: 'pricing_correction',
    label: 'Pricing Correction',
  );

  static const other = PriceOverrideReason(
    code: 'other',
    label: 'Other',
    requiresNote: true,
  );

  /// Order shown in the dropdown — most common first.
  static const List<PriceOverrideReason> all = [
    customerNegotiation,
    specialCustomerPrice,
    clearance,
    damagedPackaging,
    managerApproved,
    pricingCorrection,
    other,
  ];

  static PriceOverrideReason? byCode(String? code) {
    if (code == null) return null;
    for (final reason in all) {
      if (reason.code == code) return reason;
    }
    return null;
  }

  /// Resolves a stored code back to a label, falling back to the raw value so
  /// a reason retired in a later release still renders on old sales.
  static String labelFor(String stored) => byCode(stored)?.label ?? stored;
}
