import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';

/// One returned line, prorated from the STORED figures of the sale line it
/// reverses.
class ReturnLineFigures {
  /// The original sale line this reverses.
  final SaleItemModel source;

  final double qty;

  /// The charged unit price, carried across unchanged.
  final double price;

  /// TOTAL discount attributable to the returned quantity — the line's own plus
  /// its share of the order's. Mirrors `SaleItemModel.discountAmount`.
  final double discountAmount;

  /// The line's OWN share, a SUBSET of [discountAmount]. Never add the two.
  final double? lineDiscountAmount;

  final double taxableAmount;
  final double gstAmount;

  /// Net amount actually charged for [qty] units. Correct in BOTH tax modes,
  /// because it is prorated from the engine-computed original rather than
  /// rebuilt from price and rate.
  final double total;

  const ReturnLineFigures({
    required this.source,
    required this.qty,
    required this.price,
    required this.discountAmount,
    required this.lineDiscountAmount,
    required this.taxableAmount,
    required this.gstAmount,
    required this.total,
  });
}

/// The complete money position of a return, ready to persist.
///
/// Every amount here is POSITIVE. The caller negates the header when building
/// the return `SaleModel`, per the retail convention that return headers are
/// stored negated while return lines are stored positive.
class ReturnFigures {
  final List<ReturnLineFigures> lines;
  final double totalItems;

  /// Gross of the returned quantities, before discount.
  final double subtotal;

  final double discountAmount;
  final double taxAmount;
  final double totalTaxableAmount;

  /// What the customer is owed. Reconciled against the sale's stored
  /// `totalAmount`, so returning every line equals what was charged exactly.
  final double totalAmount;

  const ReturnFigures({
    required this.lines,
    required this.totalItems,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.totalTaxableAmount,
    required this.totalAmount,
  });

  bool get isEmpty => lines.isEmpty;

  static const ReturnFigures empty = ReturnFigures(
    lines: [],
    totalItems: 0,
    subtotal: 0,
    discountAmount: 0,
    taxAmount: 0,
    totalTaxableAmount: 0,
    totalAmount: 0,
  );
}

/// Pure money math for retail sale returns.
///
/// No DI, no Hive, no settings — the same shape as `TaxBreakdown`, so it can be
/// tested without any setup.
///
/// **The rule this exists to enforce: a refund is PRORATED from what was
/// charged, never recomputed.** Rebuilding a return from `price`, `qty` and
/// `gstRate` re-applies tax to a price that may already contain it, which
/// over-refunds by the whole tax amount in tax-inclusive mode. Every figure
/// below comes from the stored line, scaled by the returned quantity.
class RetailReturnMath {
  RetailReturnMath._();

  static double _r2(double v) => double.parse(v.toStringAsFixed(2));

  /// How many units of each variant a set of return lines gave back.
  ///
  /// Return lines store `qty` POSITIVE (kept that way for stock restoration),
  /// so these are summed as-is.
  static Map<String, double> returnedQtyByVariant(
    List<SaleItemModel> returnLines,
  ) {
    final out = <String, double>{};
    for (final line in returnLines) {
      out[line.varianteId] = (out[line.varianteId] ?? 0) + line.qty;
    }
    return out;
  }

  /// How many units of each variant may still be returned.
  ///
  /// This is the protection against refunding the same goods twice. It is
  /// DERIVED from the return documents rather than stored on the sale line, so
  /// there is no counter to keep in sync and no schema change — the same
  /// approach `PurchaseReturnRepository.returnedQtyForGRNItem` takes on the
  /// supplier side.
  ///
  /// Safe because the retail cart merges by `variantId` at every mutation site,
  /// so one sale can never hold two lines for the same variant.
  static Map<String, double> remainingByVariant({
    required List<SaleItemModel> soldLines,
    required List<SaleItemModel> returnedLines,
  }) {
    final alreadyReturned = returnedQtyByVariant(returnedLines);
    final out = <String, double>{};
    for (final line in soldLines) {
      final remaining = line.qty - (alreadyReturned[line.varianteId] ?? 0);
      out[line.varianteId] = remaining > 0 ? remaining : 0;
    }
    return out;
  }

  /// Scales the sum of line totals onto the sale's authoritative `totalAmount`.
  ///
  /// `SaleItemModel.total` excludes round-off; `SaleModel.totalAmount` includes
  /// it (loyalty is already inside both — the engine scales the per-line figures
  /// at `cart_calculation_service.dart:357`). Without this factor, returning
  /// every line would refund a rupee less or more than was taken, and repeated
  /// partial returns could sum past the bill.
  ///
  /// Returns 1.0 when it cannot be computed, so a malformed sale prorates
  /// plainly rather than producing a wild figure.
  static double reconciliationFactor(
    SaleModel sale,
    List<SaleItemModel> soldLines,
  ) {
    final lineSum = soldLines.fold<double>(0.0, (s, l) => s + l.total);
    if (lineSum <= 0) return 1.0;
    final factor = sale.totalAmount / lineSum;
    // Round-off can only ever move the total by a rupee or two. Anything
    // outside this band means the stored data disagrees with itself, and
    // trusting it would mis-refund; prorate plainly instead.
    if (factor < 0.9 || factor > 1.1) return 1.0;
    return factor;
  }

  /// Compute a return from the original sale's stored values.
  ///
  /// [returnQtyByVariantId] maps a variant to the units coming back. Entries
  /// with a non-positive quantity, or naming a variant absent from [soldLines],
  /// are ignored — validation of what MAY be returned belongs to the caller,
  /// which has the prior return documents.
  static ReturnFigures compute({
    required SaleModel sale,
    required List<SaleItemModel> soldLines,
    required Map<String, double> returnQtyByVariantId,
  }) {
    if (returnQtyByVariantId.isEmpty || soldLines.isEmpty) {
      return ReturnFigures.empty;
    }

    final byVariant = <String, SaleItemModel>{
      for (final l in soldLines) l.varianteId: l,
    };

    final lines = <ReturnLineFigures>[];
    var totalItems = 0.0;
    var subtotal = 0.0;
    var discountAmount = 0.0;
    var taxAmount = 0.0;
    var taxableAmount = 0.0;
    var netSum = 0.0;

    for (final entry in returnQtyByVariantId.entries) {
      final qty = entry.value;
      if (qty <= 0) continue;

      final source = byVariant[entry.key];
      if (source == null || source.qty <= 0) continue;

      // The one ratio every figure below is scaled by.
      final ratio = qty / source.qty;

      final lineSubtotal = _r2(source.price * qty);
      final lineDiscountTotal = _r2((source.discountAmount ?? 0) * ratio);
      final lineTaxable = _r2((source.taxableAmount ?? 0) * ratio);
      final lineGst = _r2((source.gstAmount ?? source.taxAmount ?? 0) * ratio);
      // Prorated from the stored net, so it is right in both tax modes.
      final lineTotal = _r2(source.total * ratio);

      lines.add(ReturnLineFigures(
        source: source,
        qty: qty,
        price: source.price,
        discountAmount: lineDiscountTotal,
        lineDiscountAmount: source.lineDiscountAmount == null
            ? null
            : _r2(source.lineDiscountAmount! * ratio),
        taxableAmount: lineTaxable,
        gstAmount: lineGst,
        total: lineTotal,
      ));

      totalItems += qty;
      subtotal += lineSubtotal;
      discountAmount += lineDiscountTotal;
      taxAmount += lineGst;
      taxableAmount += lineTaxable;
      netSum += lineTotal;
    }

    if (lines.isEmpty) return ReturnFigures.empty;

    // Header carries the reconciled refund; lines keep their exact historical
    // figures. That is the same relationship a FORWARD sale has — lines exclude
    // round-off, the header includes it — and reports already document the gap
    // (`report_service.dart:56-65`).
    final factor = reconciliationFactor(sale, soldLines);

    return ReturnFigures(
      lines: lines,
      totalItems: totalItems,
      subtotal: _r2(subtotal),
      discountAmount: _r2(discountAmount),
      taxAmount: _r2(taxAmount),
      totalTaxableAmount: _r2(taxableAmount),
      totalAmount: _r2(netSum * factor),
    );
  }
}
