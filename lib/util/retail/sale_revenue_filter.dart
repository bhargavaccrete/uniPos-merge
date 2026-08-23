import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';

/// Canonical revenue rules for retail reports — the counterpart of
/// [OrderStatusFilter] on the restaurant side.
///
/// This exists because `!(sale.isReturn ?? false)` used to be re-typed at
/// eleven separate sites inside `report_service.dart`, and five of them ended
/// up nested inside a date-conditional block — so with no date filter the
/// return rows were counted as *positive* sales. One seam, one rule.
///
/// **Retail models a refund differently from restaurant.** Restaurant flips the
/// order's status and nets `refundAmount` off the same row; retail writes a
/// whole new [SaleModel] with `isReturn: true` and negated header amounts,
/// while its *line items* carry positive qty and total. So a report can never
/// just sum the lines — it must apply [revenueSign] per sale.
class RetailSaleFilter {
  RetailSaleFilter._();

  /// The single reading of the nullable return flag.
  static bool isReturn(SaleModel sale) => sale.isReturn ?? false;

  /// Multiplier a sale's **line items** contribute to any total: `-1` for a
  /// return, `+1` otherwise.
  ///
  /// Only for line-level aggregation. A return's *header* amounts are already
  /// stored negated (`return_service.dart:49-52`), so summing `totalAmount`
  /// across sales nets by itself — applying this on top would double-negate.
  /// Its *lines* are stored positive (`:73`, kept that way for stock
  /// restoration), which is why they need the sign and headers don't.
  ///
  /// Returns are **netted, not dropped**. Dropping them made item-level reports
  /// disagree with the net figure on Daily/Monthly — a product sold 10 and
  /// returned 8 read as 10 sold at full revenue.
  static int revenueSign(SaleModel sale) => isReturn(sale) ? -1 : 1;

  /// Sales that must not contribute to revenue *at all*, in either direction.
  ///
  /// Nothing qualifies today: retail has no void or cancel state — [SaleStatus]
  /// offers only paid / partially_paid / due — and refunds are netted rather
  /// than excluded. This is the seam a future void flow plugs into, so the
  /// rule lands in one place instead of eleven.
  static bool isExcludedFromRevenue(SaleModel sale) => false;

  /// Sales counted by the returns figures on the Daily/Monthly reports.
  static bool isReturnInRevenue(SaleModel sale) =>
      isReturn(sale) && !isExcludedFromRevenue(sale);

  /// Sales counted as forward (non-return) revenue.
  static bool isForwardSale(SaleModel sale) =>
      !isReturn(sale) && !isExcludedFromRevenue(sale);
}
