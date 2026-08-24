

import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import '../../../core/di/service_locator.dart';

/// Cash-refund helpers for the retail End of Day.
///
/// This used to be a SECOND, parallel EOD engine: a `generateEODReport` that
/// built a transient `EODReport` for `EODReportScreen`, which nothing ever
/// navigated to. It bucketed payments differently from the live path and
/// hardcoded `openingBalance` to zero, so the two could disagree about the same
/// day. The live, persisted path is `EODService.generateRetailEODReport`
/// (`domain/services/restaurant/eod_service.dart`) — the only EOD engine.
///
/// What survives here is the cash-refund definition, which the EOD screen and
/// the Cash Drawer both depend on.
class EODReportService {

  /// Cash handed back to customers as refunds, from the return sales in [sales].
  ///
  /// The single definition of "cash refund" — the Cash Drawer and the EOD
  /// screen both route through this so the figure can never drift between them.
  ///
  /// Derived from the return sales, NOT from the audit cash movement
  /// `ReturnService` writes. That movement carries a distinct `'refund'` type
  /// which no total sums, so a refund is counted exactly once — and deriving it
  /// also corrects refunds recorded before the audit trail existed.
  ///
  /// Positively matches `'cash'`, so card, UPI and any refund method added
  /// later are excluded automatically rather than needing a deny-list.
  /// EXCHANGE returns are excluded: their cash leg already appears in the
  /// payment summaries as a signed movement, so counting it here as well would
  /// subtract the same refund from expected cash twice. Their header is also
  /// the whole returned value, not the cash that actually left the till.
  static double cashRefundsIn(List<SaleModel> sales) => sales
      .where((sale) =>
          sale.isReturn == true &&
          sale.exchangeGroupId == null &&
          sale.paymentType.toLowerCase().trim() == 'cash')
      .fold<double>(0.0, (sum, sale) => sum + sale.totalAmount.abs());

  /// Cash refunds for a date window — for callers that don't already hold the
  /// day's sales (e.g. the EOD screen, which builds its report via EODService).
  static Future<double> cashRefundsForRange(
      DateTime start, DateTime end) async {
    final sales = await saleStore.getSalesByDateRange(start, end);
    return cashRefundsIn(sales);
  }
}
