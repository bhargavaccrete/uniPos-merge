import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/util/retail/sale_revenue_filter.dart';

/// Header-level sales totals for one period, shared by the Daily and Monthly
/// sales reports.
///
/// No DI, no Hive, no settings — the same shape as [RetailReturnMath], so the
/// money math can be tested without any setup. `ReportService` classifies the
/// window and hands the two lists in; everything below is pure arithmetic over
/// stored `SaleModel` headers.
///
/// **Every key names its own basis.** Daily and Monthly used to emit
/// `totalRevenue` folded over forward sales while `totalDiscount` and
/// `totalTax` were folded over forward sales *and* returns, then render the
/// four as consecutive rows — figures that could not be reconciled against each
/// other on any day with a refund. Gross keys cover forward sales only; `net*`
/// keys include returns.
///
/// **Accrual, unchanged.** `SaleModel.status` is not consulted here either: a
/// `due` credit sale is revenue when it is rung up. Cash actually received is
/// the drawer's and EOD's job.
class RetailSalesTotals {
  RetailSalesTotals._();

  static double _r2(double v) => double.parse(v.toStringAsFixed(2));

  /// Quantities keep a digit more than they are ever displayed with, so folding
  /// weights cannot leave float noise in a figure the identity below depends on.
  static double _r3(double v) => double.parse(v.toStringAsFixed(3));

  /// Totals for a window already split into forward sales and returns.
  ///
  /// [forward] and [returns] must both come from the same classification pass,
  /// with return headers stored negated per the retail convention — see
  /// [RetailSaleFilter].
  static Map<String, dynamic> compute({
    required List<SaleModel> forward,
    required List<SaleModel> returns,
    int skippedRows = 0,
  }) {
    final all = <SaleModel>[...forward, ...returns];

    final grossItems = _r3(forward.fold(0.0, (s, x) => s + x.totalItems));
    final returnedItems = _r3(returns.fold(0.0, (s, x) => s + x.totalItems));
    // Signed, because a return's totalItems is stored positive.
    final netItems =
        _r3(all.fold(0.0, (s, x) => s + RetailSaleFilter.signedItemCount(x)));

    final totalRevenue = _r2(forward.fold(0.0, (s, x) => s + x.totalAmount));
    final totalTax = _r2(forward.fold(0.0, (s, x) => s + x.taxAmount));
    final totalDiscount =
        _r2(forward.fold(0.0, (s, x) => s + x.discountAmount));
    final totalRoundOff =
        _r2(forward.fold(0.0, (s, x) => s + (x.roundOff ?? 0.0)));

    // Taxable value is a RESIDUAL, never the stored `totalTaxableAmount`.
    //
    // `totalTaxableAmount` and `roundOff` are both nullable — the two live
    // checkout factories persist them, but `SaleModel.create`/`createWithGst`
    // accept no roundOff at all — while `totalAmount` and `taxAmount` are not.
    // Deriving the residual makes `taxable + tax + roundOff == revenue` true by
    // construction, in both tax modes and on legacy rows. On a modern row it
    // equals the stored value exactly, because the engine builds the total that
    // way (`retail_billing_service.dart:227-240`).
    //
    // `subtotal` cannot be used for this: in tax-inclusive mode it is the
    // tax-INCLUSIVE line total while `totalTaxableAmount` is the extracted base
    // (`cart_calculation_service.dart:103-110`), so `subtotal - discount + tax`
    // double-counts GST.
    final totalTaxable = _r2(totalRevenue - totalTax - totalRoundOff);

    final totalReturnAmount =
        _r2(returns.fold(0.0, (s, x) => s + x.totalAmount.abs()));

    // Folded directly rather than `totalRevenue - totalReturnAmount`: return
    // headers are already negated, so summing them IS the netting. The
    // subtraction form re-positivised them first and was correct only because
    // `return_service.dart:282` rejects a non-positive refund.
    final netRevenue = _r2(all.fold(0.0, (s, x) => s + x.totalAmount));
    final netTax = _r2(all.fold(0.0, (s, x) => s + x.taxAmount));
    final netDiscount = _r2(all.fold(0.0, (s, x) => s + x.discountAmount));

    // Deliberately absent: `netTaxable` and `netRoundOff`.
    //
    // A return's header carries a prorated share of the original sale's
    // round-off inside `totalAmount` (`return_math.dart:232-241` scales the
    // total by `reconciliationFactor` but leaves taxable and tax unscaled),
    // while `roundOff` is never written on a return header at all. So on a
    // return `totalAmount != totalTaxableAmount + taxAmount`, and the gap is
    // unrecorded. A net-level taxable identity would therefore be off by that
    // residue — the stored data does not support one, so none is offered.

    return {
      // ── Gross: forward sales only ──────────────────────────────────────
      'totalSales': forward.length,
      'grossItems': grossItems,
      'totalRevenue': totalRevenue,
      'totalTaxable': totalTaxable,
      'totalTax': totalTax,
      'totalDiscount': totalDiscount,
      'totalRoundOff': totalRoundOff,

      // ── Returns ────────────────────────────────────────────────────────
      'totalReturns': returns.length,
      'returnedItems': returnedItems,
      'totalReturnAmount': totalReturnAmount,

      // ── Net: forward sales and returns ─────────────────────────────────
      'totalItems': netItems,
      'netRevenue': netRevenue,
      'netTax': netTax,
      'netDiscount': netDiscount,

      // Gross revenue over bills rung up — neither figure counts returns, so
      // this belongs to no block.
      'averageSaleValue':
          forward.isEmpty ? 0.0 : _r2(totalRevenue / forward.length),

      'skippedRows': skippedRows,
    };
  }
}
