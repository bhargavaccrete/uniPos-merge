/// Canonical catalogue of retail store types — the single source of truth for
/// the setup wizard's retail sub-selection and anything that later reads the
/// stored value back.
///
/// [key] is the stable identifier that gets persisted (`BusinessDetails
/// .retailStoreType`). Display text is presentation only and may be reworded
/// at any time, so never compare against [name] — match on [key].
///
/// Deliberately pure Dart (no Flutter import), matching the other files in
/// this folder. [iconName] is a string the UI maps to an `IconData`, the same
/// convention `SetupWizardStore.businessTypes` already uses.
class RetailStoreType {
  final String key;
  final String name;
  final String description;
  final String iconName;

  /// Attribute names this kind of store STARTS with — seeded into the shared
  /// attribute system and pre-selected as the descriptor fields on a variant.
  ///
  /// A default, never a restriction. The user can add, remove or replace any of
  /// them afterwards (Settings → Product Attributes / Simple Product Fields),
  /// and nothing in the POS branches on store type to honour them: the POS only
  /// ever asks the attribute store what exists.
  ///
  /// Names must exist in `kSeedAttributeValues` (attribute_store.dart) to get
  /// starter values; an unlisted name is still created, just empty.
  final List<String> defaultAttributeNames;

  const RetailStoreType({
    required this.key,
    required this.name,
    required this.description,
    required this.iconName,
    this.defaultAttributeNames = const [],
  });
}

/// The store types retail currently supports.
///
/// Grocery is intentionally absent: it needs decimal quantity, UOM,
/// weight-based selling and batch/expiry, none of which the POS has. Adding it
/// here without those would sell a capability the app cannot deliver.
class RetailStoreTypes {
  const RetailStoreTypes._();

  static const RetailStoreType garment = RetailStoreType(
    key: 'garment',
    name: 'Garment Store',
    description: 'Clothing and apparel',
    iconName: 'apparel',
    defaultAttributeNames: ['Size', 'Color', 'Material', 'Pattern'],
  );

  static const RetailStoreType footwear = RetailStoreType(
    key: 'footwear',
    name: 'Footwear Store',
    description: 'Shoes, sandals and slippers',
    iconName: 'footwear',
    defaultAttributeNames: ['Size', 'Color', 'Material', 'Sole Type'],
  );

  static const RetailStoreType sports = RetailStoreType(
    key: 'sports',
    name: 'Sports Store',
    description: 'Sportswear, equipment and accessories',
    iconName: 'sports',
    defaultAttributeNames: ['Size', 'Color', 'Material', 'Sport Type'],
  );

  static const RetailStoreType cosmeticsBeauty = RetailStoreType(
    key: 'cosmetics_beauty',
    name: 'Cosmetics & Beauty Store',
    description: 'Makeup, skincare and personal care',
    iconName: 'cosmetics',
    defaultAttributeNames: ['Shade', 'Color', 'Skin Type', 'Finish', 'Volume'],
  );

  static const RetailStoreType stationery = RetailStoreType(
    key: 'stationery',
    name: 'Stationery Store',
    description: 'Books, office and school supplies',
    iconName: 'stationery',
    defaultAttributeNames: ['Color', 'Size', 'Paper Type', 'GSM', 'Binding Type'],
  );

  static const RetailStoreType giftGeneral = RetailStoreType(
    key: 'gift_general',
    name: 'Gift & General Store',
    description: 'Gifts, novelty and general merchandise',
    iconName: 'gift',
    defaultAttributeNames: ['Color', 'Size', 'Material', 'Pattern'],
  );

  static const RetailStoreType other = RetailStoreType(
    key: 'other',
    name: 'Other / General Store',
    description: 'Something else — set up your own fields',
    iconName: 'other',
    // Empty, NOT null: this type genuinely wants no attributes, so
    // `defaultAttributeNamesFor` must not fall back to `kBaseAttributeNames`.
    // A shop that fits none of the six above configures its own fields in
    // Settings rather than starting with someone else's.
    defaultAttributeNames: [],
  );

  /// Display order in the setup wizard. `other` sits last — it is the answer for
  /// a shop that recognised itself in none of the above.
  static const List<RetailStoreType> all = [
    garment,
    footwear,
    sports,
    cosmeticsBeauty,
    stationery,
    giftGeneral,
    other,
  ];

  /// Resolve a persisted key back to its entry, or null when the key is
  /// absent/unknown — a store type retired in a later release must not crash
  /// a device that still has it saved.
  static RetailStoreType? byKey(String? key) {
    if (key == null || key.isEmpty) return null;
    for (final type in all) {
      if (type.key == key) return type;
    }
    return null;
  }

  /// True when [key] is one this build still offers. Used to validate a value
  /// restored from storage before treating the selection as made.
  static bool isKnown(String? key) => byKey(key) != null;

  /// Display name for a persisted key, or null when unknown.
  static String? nameFor(String? key) => byKey(key)?.name;

  /// Default attribute names for a persisted key.
  ///
  /// Returns null — not an empty list — when the key is absent or unknown, so
  /// a caller can tell "this business has no store type" apart from "this store
  /// type genuinely wants no attributes" (Other). Returning `null` for Other
  /// instead would silently seed the fallback set onto every product.
  ///
  /// The two cases are handled very differently by
  /// `StoreTypeAttributeDefaultsService.ensureStoreTypeDefaults`: `[]` means
  /// "seed nothing, deliberately", while `null` means "this feature does not
  /// apply — leave the legacy fallback alone".
  static List<String>? defaultAttributeNamesFor(String? key) =>
      byKey(key)?.defaultAttributeNames;
}
