/// Normalises the descriptor attributes captured on a variant form.
///
/// Retail variants used to carry hardcoded `size` / `color` / `weight` columns
/// alongside a free-form map. Those columns are gone — every descriptor now
/// lives in `VarianteModel.customAttributes` under whatever name the shop
/// configured (Settings → Simple Product Fields), so a grocer records
/// `Volume: 1L` exactly the way a clothing shop records `Size: M`.
///
/// This is the one place that trims, filters and merges those maps, so every
/// form writes them the same way.
library;

/// Merge configured-field values with any ad-hoc one-off rows.
///
/// Blank keys and blank values are dropped; [extraCustomAttributes] wins on a
/// key collision (it is the more specific, per-variant entry). Returns null
/// when nothing survives, matching `VarianteModel.customAttributes` being
/// nullable.
Map<String, String>? mergeVariantAttributes(
  Map<String, String> attributes, {
  Map<String, String>? extraCustomAttributes,
}) {
  final merged = <String, String>{};

  void add(Map<String, String>? source) {
    source?.forEach((key, value) {
      final k = key.trim();
      final v = value.trim();
      if (k.isEmpty || v.isEmpty) return;
      merged[k] = v;
    });
  }

  add(attributes);
  add(extraCustomAttributes);

  return merged.isEmpty ? null : merged;
}
