/// Fixed reason vocabulary for a manual stock adjustment.
///
/// A dropdown rather than free text so the adjustment report can group, and so
/// "why is stock different" always has a machine-readable answer. The optional
/// note carries the detail.
///
/// **[isLoss] is what makes a reason cost money.** A shortage caused by theft
/// or breakage is a real expense and must reach the loss report and profit
/// figures; a miscount corrected downwards is a bookkeeping fix and must not.
/// Both remove the same units — only the accounting differs, which is exactly
/// why the reason is mandatory.
class StockAdjustmentReason {
  final String code;
  final String label;

  /// True when a downward adjustment for this reason is a genuine business
  /// loss, and should therefore also write an `InventoryLossModel`.
  ///
  /// Only meaningful on a decrease: finding extra stock is never a loss.
  final bool isLoss;

  /// Forces the note field to be filled before saving. Used where the reason
  /// alone explains nothing — "Data entry error" needs to say which entry.
  final bool requiresNote;

  const StockAdjustmentReason({
    required this.code,
    required this.label,
    this.isLoss = false,
    this.requiresNote = false,
  });

  static const stockCount = StockAdjustmentReason(
    code: 'stock_count',
    label: 'Stock count correction',
  );

  static const damaged = StockAdjustmentReason(
    code: 'damaged',
    label: 'Damaged / Broken',
    isLoss: true,
  );

  static const expired = StockAdjustmentReason(
    code: 'expired',
    label: 'Expired',
    isLoss: true,
  );

  static const theft = StockAdjustmentReason(
    code: 'theft',
    label: 'Theft / Shrinkage',
    isLoss: true,
  );

  static const internalUse = StockAdjustmentReason(
    code: 'internal_use',
    label: 'Internal use',
    isLoss: true,
  );

  static const sample = StockAdjustmentReason(
    code: 'sample',
    label: 'Sample / Gift',
    isLoss: true,
  );

  static const foundExtra = StockAdjustmentReason(
    code: 'found_extra',
    label: 'Found extra stock',
  );

  static const dataEntryError = StockAdjustmentReason(
    code: 'data_entry_error',
    label: 'Data entry error',
    requiresNote: true,
  );

  /// Order shown in the dropdown — most common first.
  static const List<StockAdjustmentReason> all = [
    stockCount,
    damaged,
    expired,
    theft,
    internalUse,
    sample,
    foundExtra,
    dataEntryError,
  ];

  /// Reasons that only make sense when stock goes down.
  static List<StockAdjustmentReason> get decreaseReasons =>
      all.where((r) => r.code != foundExtra.code).toList();

  /// Reasons that only make sense when stock goes up. Nothing is lost by
  /// gaining units, so the loss-bearing reasons are excluded.
  static List<StockAdjustmentReason> get increaseReasons =>
      all.where((r) => !r.isLoss).toList();

  static StockAdjustmentReason? byCode(String code) {
    for (final reason in all) {
      if (reason.code == code) return reason;
    }
    return null;
  }

  /// Resolves a stored `reason` string back to a label. History rows persist
  /// the label, so this falls back to the raw value rather than 'Unknown'.
  static String labelFor(String stored) => byCode(stored)?.label ?? stored;
}
