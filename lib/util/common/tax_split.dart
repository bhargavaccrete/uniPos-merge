/// Splits a tax figure into its two components (CGST/SGST) so they always add
/// back to the whole.
///
/// Rounding each half independently — `_r2(gst / 2)` twice — loses a paisa
/// whenever the tax lands on an odd one. That is ~50% of bills at every common
/// slab: ₹1.81 of GST printed as CGST 0.91 + SGST 0.91 = 1.82, one paisa more
/// than the customer paid. The first component takes the rounded half and the
/// second takes the remainder.
///
/// Sign is preserved, so a credit note's negative GST yields two negative
/// components that still sum to it.
///
/// This is the ONE place the 50/50 split is computed. Every writer of a
/// cgst/sgst pair — the billing engine, `GstService`, and the Hive factories on
/// `CartItemModel`, `SaleItemModel` and `SaleModel` — routes through it, or the
/// stored figures disagree with the receipt that prints them.
///
/// PRESENTATION of these halves is a separate question: they are meaningful
/// only for Indian intra-state supply, and `TaxLabelRule.splitsIntoComponents`
/// decides whether a screen may show them at all.
class TaxSplit {
  TaxSplit._();

  static double _r2(double v) => double.parse(v.toStringAsFixed(2));

  static ({double cgst, double sgst}) halves(double totalTax) {
    final cgst = _r2(totalTax / 2);
    return (cgst: cgst, sgst: _r2(totalTax - cgst));
  }
}
