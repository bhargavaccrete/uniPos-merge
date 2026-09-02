import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/eodmodel_317.dart';
import 'package:billberrylite/domain/services/restaurant/esc_pos_receipt_builder.dart';
import 'package:billberrylite/domain/services/retail/store_settings_service.dart';
import 'package:billberrylite/util/common/currency_helper.dart';

/// Why a reprint failed, when it did.
enum EodReprintOutcome {
  printed,

  /// No thermal printer is paired — nothing to send to.
  noPrinter,

  /// The printer was reached but rejected or dropped the job.
  sendFailed,
}

/// Reprinting a PAST settlement from its stored close record.
///
/// The close flow prints a settlement once and then the ticket is gone; EOD
/// History could show a record but never produce that slip again, which is the
/// document a shop most often needs a second copy of.
///
/// This maps a stored [EndOfDayReport] onto the existing
/// [EscPosReceiptBuilder.buildEodSettlementTicket] — the same formatter the
/// close flow uses, so a reprint is the same document, not a lookalike.
///
/// **Thermal only.** The close flow also has a PDF fallback, but that layout is
/// ~150 lines inside `endday.dart` (a restaurant screen); lifting it out is a
/// refactor of its own. A reprint with no printer paired reports
/// [EodReprintOutcome.noPrinter] rather than silently doing nothing.
class EodSettlementPrint {
  EodSettlementPrint._();

  /// The arguments a stored record contributes to the settlement ticket.
  ///
  /// Split out from [reprint] so the mapping is testable without a printer:
  /// everything here is derived from the record, nothing is invented.
  static ({
    List<({String name, double amount})> orderTypes,
    List<({String name, double amount})> paymentMethods,
    double totalCredit,
    double netSale,
    double grossSale,
  }) figuresFor(EndOfDayReport report) {
    final orderTypes = report.orderSummaries
        .map((o) => (name: o.orderType, amount: o.totalAmount))
        .toList();
    final paymentMethods = report.paymentSummaries
        .map((p) => (name: p.paymentType, amount: p.totalAmount))
        .toList();

    // Same definition the close flow uses: the 'Credit' payment bucket.
    final totalCredit = paymentMethods
        .where((p) => p.name.toLowerCase().trim() == 'credit')
        .fold<double>(0, (s, p) => s + p.amount);

    // `totalSales` is the authoritative figure on the record; gross adds back
    // the tax it is stated net of on the ticket's own layout.
    final netSale = report.totalSales - report.totalTax;

    return (
      orderTypes: orderTypes,
      paymentMethods: paymentMethods,
      totalCredit: totalCredit,
      netSale: netSale,
      grossSale: report.totalSales,
    );
  }

  /// Sends [report] to the paired receipt printer (KOT printer as fallback,
  /// matching the close flow's own preference order).
  static Future<EodReprintOutcome> reprint(EndOfDayReport report) async {
    final printer =
        printerStore.defaultReceiptPrinter ?? printerStore.defaultKotPrinter;
    if (printer == null) return EodReprintOutcome.noPrinter;

    final storeName =
        await StoreSettingsService().getStoreName() ?? 'Store';
    final symbol = await CurrencyHelper.getCurrencySymbol();
    final figures = figuresFor(report);
    final recon = report.cashReconciliation;

    final bytes = EscPosReceiptBuilder.buildEodSettlementTicket(
      paperWidth: printer.paperSize,
      storeName: storeName,
      currencySymbol: symbol,
      // The record does not store who closed the day, so the ticket says what
      // it truthfully knows: this is a reprint of a stored close.
      shiftUser: 'Reprint',
      shiftStart: report.date,
      shiftEnd: report.date,
      orderTypes: figures.orderTypes,
      totalSale: figures.netSale,
      discount: report.totalDiscount,
      netSale: figures.netSale,
      tax: report.totalTax,
      roundOff: report.roundOff,
      grossSale: figures.grossSale,
      cash: recon.actualCash,
      totalCredit: figures.totalCredit,
      openingBalance: report.openingBalance,
      cashExpense: report.cashExpenses,
      totalExpense: report.totalExpenses,
      drawerBalance: report.closingBalance,
      // Not stored on the record — the close flow computes it live from the
      // safe-drop entry. Passed as 0 rather than guessed.
      withdrawalCash: 0,
      cashDifference: recon.difference,
      paymentMethods: figures.paymentMethods,
      noOfBill: report.totalOrderCount,
      reprintBill: 0,
      cancelledBill: report.cancelledOrderCount,
      cancelledBillAmount: report.cancelledOrderAmount,
      cancelledProducts: 0,
      cancelledProductsAmount: 0,
      saleReturnAmount: report.totalRefunds,
      finalAmount: figures.grossSale,
    );

    final sent = await printerStore.sendBytes(bytes, printer);
    return sent ? EodReprintOutcome.printed : EodReprintOutcome.sendFailed;
  }
}
