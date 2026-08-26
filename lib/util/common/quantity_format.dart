/// Quantity rendering, in one place.
///
/// Retail quantities are `double` so loose goods can be sold by weight, but a
/// piece product must still read "3", never "3.0". Every screen that prints a
/// quantity goes through here so the two never diverge.
///
/// This is DISPLAY ONLY — never parse the result back into arithmetic.
library;

/// Renders [qty] without a trailing `.0`, trimming trailing zeros on a
/// fractional value: `3` → "3", `10.5` → "10.5", `1.250` → "1.25".
String formatQty(double qty) {
  if (qty == qty.roundToDouble()) return qty.toInt().toString();
  return qty
      .toStringAsFixed(2)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '');
}

/// [formatQty] with the unit appended when there is one, e.g. "10.5 kg".
String formatQtyWithUnit(double qty, String? unit) {
  final u = (unit ?? '').trim();
  return u.isEmpty ? formatQty(qty) : '${formatQty(qty)} $u';
}
