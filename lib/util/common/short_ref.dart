/// Short, human-readable reference for a long generated id.
///
/// Sale, return and GRN ids are UUID v4 — 36 characters of noise on a receipt
/// card. This trims them to a readable prefix.
///
/// **Guarded.** The hand-rolled `id.substring(0, 8)` this replaces threw a
/// `RangeError` whenever an id was shorter than the cut length, which is easy
/// to hit once ids stop being UUIDs (retail customers now use `CUST-000042`).
/// An id shorter than [length] is returned whole instead.
///
/// ```dart
/// shortRef(sale.saleId)                      // '3F2A1B4C'
/// shortRef(sale.saleId, length: 13)          // '3F2A1B4C-5D6E'
/// shortRef(customer.customerId, minLength: 16, ellipsis: true)
/// ```
String shortRef(
  String? id, {
  int length = 8,
  bool ellipsis = false,

  /// Leave ids at or below this length untouched. Defaults to [length]; raise
  /// it when short human ids (`CUST-000042`) should never be trimmed.
  int? minLength,
}) {
  final value = (id ?? '').trim();
  if (value.isEmpty) return '—';

  final keepWhole = minLength ?? length;
  if (value.length <= keepWhole) return value.toUpperCase();

  final cut = value.substring(0, length).toUpperCase();
  return ellipsis ? '$cut…' : cut;
}
