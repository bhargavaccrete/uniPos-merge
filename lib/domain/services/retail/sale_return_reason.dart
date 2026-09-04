/// Fixed reason vocabulary for a customer return at the POS.
///
/// A picker rather than free text so "why did this money go back out" always has
/// a machine-readable answer. Refunds are the most abused till operation in
/// retail, and the Sales Refund report is only worth pulling if it can group by
/// reason — free text cannot be grouped.
///
/// Mirrors [LineDiscountReason] and [PriceOverrideReason] deliberately: same
/// shape, same [byCode] / [labelFor] contract, so screens and reports treat all
/// three the same way. Named `SaleReturnReason` rather than `ReturnReason`
/// because the supplier side has its own `PurchaseReturnModel` — an unqualified
/// name would read as either.
class SaleReturnReason {
  /// Stored on the return document's [SaleModel]. Stable — never rename.
  final String code;

  /// Shown in the picker. Free to reword.
  final String label;

  /// Forces the note field before saving. Set on [other], where the reason
  /// alone explains nothing.
  final bool requiresNote;

  const SaleReturnReason({
    required this.code,
    required this.label,
    this.requiresNote = false,
  });

  static const damaged = SaleReturnReason(
    code: 'damaged',
    label: 'Damaged',
  );

  static const defective = SaleReturnReason(
    code: 'defective',
    label: 'Defective / Not Working',
  );

  static const wrongItem = SaleReturnReason(
    code: 'wrong_item',
    label: 'Wrong Item Given',
  );

  static const sizeOrFit = SaleReturnReason(
    code: 'size_or_fit',
    label: 'Size / Fit',
  );

  static const changedMind = SaleReturnReason(
    code: 'changed_mind',
    label: 'Customer Changed Mind',
  );

  static const expired = SaleReturnReason(
    code: 'expired',
    label: 'Expired / Past Date',
  );

  static const other = SaleReturnReason(
    code: 'other',
    label: 'Other',
    requiresNote: true,
  );

  /// Order shown in the picker — most common first.
  static const List<SaleReturnReason> all = [
    damaged,
    defective,
    wrongItem,
    sizeOrFit,
    changedMind,
    expired,
    other,
  ];

  static SaleReturnReason? byCode(String? code) {
    if (code == null) return null;
    for (final reason in all) {
      if (reason.code == code) return reason;
    }
    return null;
  }

  /// Resolves a stored code back to a label, falling back to the raw value so a
  /// reason retired in a later release still renders on old returns.
  static String labelFor(String stored) => byCode(stored)?.label ?? stored;
}
