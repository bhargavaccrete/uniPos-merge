/// Fixed reason vocabulary for a per-line discount at the POS.
///
/// A dropdown rather than free text so "why did this line sell below list" always
/// has a machine-readable answer. A line discount squeezes margin on a sale that
/// has already been settled; without a stored reason the profit report shows a
/// dip nobody can explain.
///
/// Mirrors `PriceOverrideReason` deliberately: same shape, same [byCode] /
/// [labelFor] contract, so screens and reports treat both the same way. Kept as a
/// separate vocabulary because the *reasons* differ — an override is a price
/// decision, a discount is usually a promotion or a negotiation.
class LineDiscountReason {
  /// Stored on the cart line and the sale line. Stable — never rename.
  final String code;

  /// Shown in the dropdown. Free to reword.
  final String label;

  /// Forces the note field before saving. Set on [other], where the reason alone
  /// explains nothing.
  final bool requiresNote;

  const LineDiscountReason({
    required this.code,
    required this.label,
    this.requiresNote = false,
  });

  static const customerNegotiation = LineDiscountReason(
    code: 'customer_negotiation',
    label: 'Customer Negotiation',
  );

  static const promotionalDiscount = LineDiscountReason(
    code: 'promotional_discount',
    label: 'Promotional Discount',
  );

  static const clearance = LineDiscountReason(
    code: 'clearance',
    label: 'Clearance',
  );

  static const managerApproved = LineDiscountReason(
    code: 'manager_approved',
    label: 'Manager Approved',
  );

  static const damagedPackaging = LineDiscountReason(
    code: 'damaged_packaging',
    label: 'Damaged Packaging',
  );

  static const other = LineDiscountReason(
    code: 'other',
    label: 'Other',
    requiresNote: true,
  );

  /// Order shown in the dropdown — most common first.
  static const List<LineDiscountReason> all = [
    customerNegotiation,
    promotionalDiscount,
    clearance,
    managerApproved,
    damagedPackaging,
    other,
  ];

  static LineDiscountReason? byCode(String? code) {
    if (code == null) return null;
    for (final reason in all) {
      if (reason.code == code) return reason;
    }
    return null;
  }

  /// Resolves a stored code back to a label, falling back to the raw value so a
  /// reason retired in a later release still renders on old sales.
  static String labelFor(String stored) => byCode(stored)?.label ?? stored;
}
