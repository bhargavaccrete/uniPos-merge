import '../../data/repositories/business_details_repository.dart';
import '../di/service_locator.dart';

/// Single source of truth for "what does this country call its sales tax, and
/// does that tax present as two components."
///
/// PRESENTATION ONLY. Nothing here calculates, stores or validates tax — the
/// rate a line was charged at, its `gstAmount`, and the `cgstAmount`/
/// `sgstAmount` halves are written by `SaleItemModel` and `GstService` exactly
/// as before, in every country. This rule decides only what a screen is allowed
/// to *call* those figures and which of them it may show.
///
/// The reason it has to exist: the retail tax surfaces were written India-first
/// and hard-code "GST", "CGST" and "SGST". A UK shop selling at 20% VAT was
/// shown two invented sub-taxes of 10% each under Indian names. The 50/50 split
/// stored on every line is meaningful **only** for Indian intra-state supply;
/// VAT and US sales tax have no such components, so outside India the combined
/// figure is the only honest one to print.
///
/// Two forms, matching [TariffCodeRule] and [FoodLicenseRule]:
///  * `*For(country)` takes the country explicitly — for onboarding, where
///    nothing is persisted yet.
///  * [name] / [splitsIntoComponents] / [components] / [reportTitle] read the
///    saved `BusinessDetails`, for post-setup screens.
///
/// ```dart
/// Text('${TaxLabelRule.name} Breakdown')            // "VAT Breakdown"
/// if (TaxLabelRule.splitsIntoComponents) ...[ cgstRow, sgstRow ]
/// ```
class TaxLabelRule {
  TaxLabelRule._();

  static const String _gst = 'GST';
  static const String _vat = 'VAT';
  static const String _salesTax = 'Sales Tax';

  /// Used for every country without an entry below. Deliberately generic — a
  /// wrong-but-specific name ("GST" over a Brazilian bill) is worse than a
  /// correct-but-plain one.
  static const String _defaultName = 'Tax';

  /// Lowercased, trimmed country name → what that country calls the tax.
  ///
  /// Keys are the exact display names in the bundled `country.json`
  /// (`CountryStateCityData`) — the same key space [TariffCodeRule] uses, with
  /// its non-obvious spellings (`Netherlands The`, `Croatia (Hrvatska)`).
  /// Lookup is exact-match, never `contains`: the dataset also carries
  /// "United States Minor Outlying Islands", which a substring test would
  /// wrongly fold into "United States".
  static const Map<String, String> _names = {
    'india': _gst,
    'united states': _salesTax,
    'united kingdom': _vat,
    // ── EU-27: every member levies VAT under that name. `country.json` has no
    // "European Union" entry to key on, so each member is listed — same list
    // and same spellings as `TariffCodeRule`.
    'austria': _vat,
    'belgium': _vat,
    'bulgaria': _vat,
    'croatia (hrvatska)': _vat,
    'cyprus': _vat,
    'czech republic': _vat,
    'denmark': _vat,
    'estonia': _vat,
    'finland': _vat,
    'france': _vat,
    'germany': _vat,
    'greece': _vat,
    'hungary': _vat,
    'ireland': _vat,
    'italy': _vat,
    'latvia': _vat,
    'lithuania': _vat,
    'luxembourg': _vat,
    'malta': _vat,
    'netherlands the': _vat,
    'poland': _vat,
    'romania': _vat,
    'slovakia': _vat,
    'slovenia': _vat,
    'spain': _vat,
    'sweden': _vat,
  };

  static String _key(String? country) => (country ?? '').trim().toLowerCase();

  /// True for India, and for an UNSET country.
  ///
  /// India-first, matching [PhoneRule] and [TariffCodeRule]: a shop that has not
  /// reached Store Details yet keeps the behaviour it has always had rather than
  /// silently losing its CGST/SGST rows mid-setup. A country that IS set but
  /// isn't listed is a different case and reads as non-India.
  static bool isIndiaFor(String? country) {
    final key = _key(country);
    return key.isEmpty || key == 'india';
  }

  /// What this country calls the tax: "GST", "VAT", "Sales Tax" or "Tax".
  static String nameFor(String? country) {
    final key = _key(country);
    if (key.isEmpty) return _gst;
    return _names[key] ?? _defaultName;
  }

  /// Whether the tax presents as two components on screen.
  ///
  /// India only — CGST + SGST on an intra-state supply. Everywhere else the
  /// stored halves are an artefact of the write path, not a real division, and
  /// must not be shown.
  static bool splitsIntoComponentsFor(String? country) => isIndiaFor(country);

  /// The two component names, or **null** when this country's tax does not
  /// split. Returning null rather than a pair is deliberate: a caller cannot
  /// render the components without first handling the non-splitting case.
  static ({String first, String second})? componentsFor(String? country) =>
      splitsIntoComponentsFor(country)
          ? (first: 'CGST', second: 'SGST')
          : null;

  /// Screen and hub-tile title, e.g. "VAT Report".
  static String reportTitleFor(String? country) => '${nameFor(country)} Report';

  // ── Persisted-record convenience (post-setup screens) ─────────────────────

  /// Never throws. Like [TariffCodeRule], this is reached before the service
  /// locator is wired — early boot, and widget tests that render a tax label
  /// without standing up DI. Unregistered reads as unset, i.e. India.
  static String? get _savedCountry =>
      locator.isRegistered<BusinessDetailsRepository>()
          ? businessDetailsRepository.get()?.country
          : null;

  static bool get isIndia => isIndiaFor(_savedCountry);

  static String get name => nameFor(_savedCountry);

  static bool get splitsIntoComponents =>
      splitsIntoComponentsFor(_savedCountry);

  static ({String first, String second})? get components =>
      componentsFor(_savedCountry);

  static String get reportTitle => reportTitleFor(_savedCountry);
}
