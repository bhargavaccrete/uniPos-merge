import '../../data/repositories/business_details_repository.dart';
import '../di/service_locator.dart';

/// Single source of truth for "what does this country call the product's
/// customs/tariff classification code."
///
/// The value is stored everywhere as `hsnCode` — that field name is India's
/// wording, frozen into Hive and never renamed (a rename would be a breaking
/// schema change for zero user benefit). Only the LABEL varies, so a US shop
/// sees "HTS Code" over the same field an Indian shop sees "HSN Code" over.
///
/// Two forms, for two callers — the same split [FoodLicenseRule] uses:
///  * `labelFor(country)` takes the country explicitly, for onboarding, where
///    nothing is persisted yet while Store Details is still being filled.
///  * [label] / [shortLabel] read the saved `BusinessDetails`, for post-setup
///    screens, receipts and labels.
///
/// ```dart
/// AppTextField(label: TariffCodeRule.label)          // "HTS Code"
/// pw.Text(TariffCodeRule.shortLabel)                 // "HTS"  (receipt column)
/// ```
class TariffCodeRule {
  TariffCodeRule._();

  /// Lowercased, trimmed country name → full field label.
  ///
  /// Keys are the exact display names in the bundled `country.json`
  /// (`CountryStateCityData`), which has some non-obvious spellings —
  /// `Netherlands The`, `Croatia (Hrvatska)`, `Czech Republic`. Lookup is
  /// exact-match, never `contains`: the dataset also carries "United States
  /// Minor Outlying Islands" and "Netherlands Antilles", both of which a
  /// substring test would wrongly fold into their parent entry.
  static const Map<String, String> _labels = {
    'india': 'HSN Code',
    'united states': 'HTS Code',
    'united kingdom': 'Commodity Code',
    'canada': 'HS / Tariff Code',
    'australia': 'HS / Tariff Code',
    'new zealand': 'HS / Tariff Code',
    'singapore': 'HS / AHTN Code',
    'united arab emirates': 'HS / Customs Code',
    // ── EU-27: the union shares one CN/TARIC nomenclature, but country.json
    // has no "European Union" entry to key on, so each member is listed.
    'austria': _eu,
    'belgium': _eu,
    'bulgaria': _eu,
    'croatia (hrvatska)': _eu,
    'cyprus': _eu,
    'czech republic': _eu,
    'denmark': _eu,
    'estonia': _eu,
    'finland': _eu,
    'france': _eu,
    'germany': _eu,
    'greece': _eu,
    'hungary': _eu,
    'ireland': _eu,
    'italy': _eu,
    'latvia': _eu,
    'lithuania': _eu,
    'luxembourg': _eu,
    'malta': _eu,
    'netherlands the': _eu,
    'poland': _eu,
    'portugal': _eu,
    'romania': _eu,
    'slovakia': _eu,
    'slovenia': _eu,
    'spain': _eu,
    'sweden': _eu,
  };

  static const String _eu = 'CN / TARIC Code';

  /// Used for the ~215 countries without a specific entry above. HS is the WCO
  /// nomenclature every one of them derives its own tariff code from.
  static const String _defaultLabel = 'HS Code';

  /// Space-constrained form, for receipt and label columns where the full
  /// label will not fit. Keyed off the full label so the two can't drift.
  static const Map<String, String> _shortLabels = {
    'HSN Code': 'HSN',
    'HTS Code': 'HTS',
    'Commodity Code': 'Comm.',
    'HS / Tariff Code': 'HS',
    'HS / AHTN Code': 'HS',
    'HS / Customs Code': 'HS',
    _eu: 'CN',
    _defaultLabel: 'HS',
  };

  static String _key(String? country) => (country ?? '').trim().toLowerCase();

  /// An UNSET country reads as India, matching [PhoneRule] and the app's
  /// India-first defaults — a shop that hasn't reached Store Details yet still
  /// sees "HSN Code" rather than a generic label. A country that IS set but
  /// isn't listed above falls back to plain HS; the two cases are deliberately
  /// different.
  static String labelFor(String? country) {
    final key = _key(country);
    if (key.isEmpty) return _labels['india']!;
    return _labels[key] ?? _defaultLabel;
  }

  static String shortLabelFor(String? country) =>
      _shortLabels[labelFor(country)] ?? 'HS';

  // ── Persisted-record convenience (post-setup screens, receipts, labels) ────

  /// Never throws. This is a label helper, and it gets reached before the
  /// service locator is wired — early boot, and every widget/unit test that
  /// renders a product field without standing up DI. Unregistered reads as
  /// unset, which [labelFor] treats as India.
  static String? get _savedCountry =>
      locator.isRegistered<BusinessDetailsRepository>()
          ? businessDetailsRepository.get()?.country
          : null;

  /// Full label for the business's saved country, e.g. "HTS Code".
  static String get label => labelFor(_savedCountry);

  /// Short label for the saved country, e.g. "HTS" — receipt/label columns.
  static String get shortLabel => shortLabelFor(_savedCountry);
}
