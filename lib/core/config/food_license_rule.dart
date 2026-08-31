import '../di/service_locator.dart';

/// Single source of truth for "what is this country's food-business licence
/// called, and what shape is a valid number."
///
/// India's FSSAI number is a fixed 14 numeric digits; every other country's
/// equivalent registration varies by state/emirate/council, so only the label
/// changes and the value is accepted as typed. Always OPTIONAL — an empty value
/// is valid everywhere.
///
/// Two forms, for two callers:
///  * `labelFor(country)` / `validateFor(country, value)` take the country
///    explicitly — onboarding needs these, because nothing is persisted yet
///    while the user is still filling the Store Details step.
///  * [label] / [number] read the saved `BusinessDetails` — for post-setup
///    screens and the receipt builders, the same way [PhoneRule] and
///    [TaxFeature] do.
///
/// ```dart
/// AppTextField(
///   label: FoodLicenseRule.labelFor(country),
///   maxLength: FoodLicenseRule.maxLengthFor(country),
///   validator: (v) => FoodLicenseRule.validateFor(country, v),
/// )
/// ```
class FoodLicenseRule {
  FoodLicenseRule._();

  /// FSSAI licence/registration numbers are exactly 14 numeric digits.
  static const int indiaDigits = 14;

  /// Field cap everywhere else — long enough for the longest permit formats
  /// seen across US states and UAE emirates.
  static const int genericMaxLength = 30;

  /// Lowercased, trimmed country name → licence label.
  ///
  /// Keys are the exact display names in the bundled `country.json`
  /// (`CountryStateCityData`) — there are no ISO codes to key on. Lookup is
  /// exact-match, never `contains`: that dataset also carries
  /// "United States Minor Outlying Islands", which a substring test would
  /// wrongly label as the USA.
  static const Map<String, String> _labels = {
    'india': 'FSSAI License No.',
    'united kingdom': 'Food Business Registration Ref. No.',
    'united states': 'Food Establishment Permit No.',
    'canada': 'SFC Licence No.',
    'australia': 'Food Business Registration No.',
    'new zealand': 'Food Business Registration No.',
    'singapore': 'SFA Food Licence No.',
    'united arab emirates': 'Food Establishment Permit No.',
  };

  /// Used for the 242 countries without a specific entry above.
  static const String _defaultLabel = 'Food Licence No.';

  static String _key(String? country) => (country ?? '').trim().toLowerCase();

  static bool isIndia(String? country) => _key(country) == 'india';

  static String labelFor(String? country) =>
      _labels[_key(country)] ?? _defaultLabel;

  static String hintFor(String? country) =>
      isIndia(country) ? 'e.g. 12345678901234' : 'Optional';

  static int maxLengthFor(String? country) =>
      isIndia(country) ? indiaDigits : genericMaxLength;

  /// True only for India — everywhere else the number may contain letters.
  static bool digitsOnlyFor(String? country) => isIndia(country);

  /// Returns an error message, or null when [value] is acceptable.
  /// Empty is always acceptable: the field is optional in every country.
  static String? validateFor(String? country, String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    if (!isIndia(country)) return null;
    if (v.length != indiaDigits || !RegExp(r'^[0-9]+$').hasMatch(v)) {
      return 'FSSAI number must be exactly $indiaDigits digits';
    }
    return null;
  }

  // ── Persisted-record convenience (post-setup screens, receipt builders) ────

  static String? get _savedCountry => businessDetailsRepository.get()?.country;

  /// Label for the business's saved country.
  static String get label => labelFor(_savedCountry);

  static String get hint => hintFor(_savedCountry);

  static int get maxLength => maxLengthFor(_savedCountry);

  static bool get digitsOnly => digitsOnlyFor(_savedCountry);

  static String? validate(String? value) => validateFor(_savedCountry, value);

  /// The saved licence number, or null when never entered.
  static String? get number {
    final n = businessDetailsRepository.get()?.foodLicenseNo?.trim();
    return (n == null || n.isEmpty) ? null : n;
  }
}
