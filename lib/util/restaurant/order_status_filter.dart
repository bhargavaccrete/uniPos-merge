/// Canonical order-status filters for restaurant reports.
///
/// These exist so the VOID / refund exclusion rules live in ONE place instead
/// of being re-typed as `status == 'VOID' || status == 'VOIDED' || ...` lists
/// that silently drift out of sync (e.g. one file forgetting 'VOID' vs
/// 'VOIDED'). Always uses `contains('VOID')` so BOTH kinds of void are caught:
///   - 'VOID'   — unpaid, deleted before payment
///   - 'VOIDED' — paid, then cancelled (still refundable)
class OrderStatusFilter {
  OrderStatusFilter._();

  /// A voided order (either 'VOID' or 'VOIDED'). Never counts as revenue.
  static bool isVoided(String? status) =>
      (status ?? '').toUpperCase().contains('VOID');

  /// Orders that must NOT be counted as sales/revenue: voided, cancelled, or
  /// fully refunded. Partially-refunded orders are NOT excluded here — callers
  /// net the returned amount out via `refundAmount`.
  static bool isExcludedFromRevenue(String? status) {
    final s = (status ?? '').toUpperCase();
    return s.contains('VOID') || s == 'CANCELLED' || s == 'FULLY_REFUNDED';
  }

  /// Stricter exclusion for item-quantity comparisons, which additionally drop
  /// partially-refunded orders (their per-line quantities are ambiguous).
  static bool isExcludedFromItemCounts(String? status) {
    final s = (status ?? '').toUpperCase();
    return isExcludedFromRevenue(s) || s == 'PARTIALLY_REFUNDED';
  }
}
