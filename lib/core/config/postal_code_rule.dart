import '../di/service_locator.dart';

/// Single source of truth for "what is this country's postal code called, what
/// shape is a valid one, and is it required at all."
///
/// **Deliberately strict only where we actually know the rule.** India's PIN is
/// a fixed 6 digits and is validated exactly. Everywhere else the value is
/// accepted as typed within a generous cap — encoding a regex per country would
/// be 240 chances to reject a real address, and a wrong rejection is far worse
/// here than a lax one. The same judgement [FoodLicenseRule] makes.
///
/// Three things vary, and all three matter:
///  * **Label** — "PIN Code" in India, "ZIP Code" in the US, "Postcode" in the
///    UK. Calling a UK postcode a "Pincode" reads as a bug to a UK merchant.
///  * **Letters** — `SW1A 1AA` and Eircode `D02 AF30` contain letters, so a
///    digits-only input formatter makes the field literally unusable there.
///    See [digitsOnlyFor].
///  * **Existence** — a handful of countries have no postal code system at
///    all. Forcing one is a dead end, so the field is optional there. See
///    [isRequiredFor].
///
/// Two forms, for two callers — same split as [PhoneRule]:
///  * `*For(country, …)` take the country explicitly. Onboarding's Store
///    Details needs these: the country is chosen on that screen and is not
///    persisted until Continue.
///  * The zero-arg getters read the saved `BusinessDetails`, for every screen
///    that runs after setup.
///
/// ```dart
/// AppTextField(
///   label: PostalCodeRule.labelFor(country),
///   hint: PostalCodeRule.hintFor(country),
///   maxLength: PostalCodeRule.maxLengthFor(country),
///   required: PostalCodeRule.isRequiredFor(country),
///   inputFormatters: PostalCodeRule.digitsOnlyFor(country)
///       ? [FilteringTextInputFormatter.digitsOnly]
///       : null,
///   validator: (v) => PostalCodeRule.validateFor(country, v),
/// )
/// ```
class PostalCodeRule {
  PostalCodeRule._();

  /// An Indian PIN is exactly 6 numeric digits.
  static const int indiaDigits = 6;

  /// Cap everywhere else. Comfortably fits the longest real formats — a UK
  /// outward+inward pair with its space (`SW1A 1AA`, 8), a US ZIP+4
  /// (`12345-6789`, 10) and an Eircode (`D02 AF30`, 8).
  static const int genericMaxLength = 12;

  /// Lowercased, trimmed country name → what that country calls it.
  ///
  /// Keys are the exact display names in the bundled `country.json`
  /// (`CountryStateCityData`) — there are no ISO codes to key on. Lookup is
  /// exact-match, never `contains`: the dataset also carries "United States
  /// Minor Outlying Islands", which a substring test would wrongly match.
  static const Map<String, String> _labels = {
    'india': 'PIN Code',
    'united states': 'ZIP Code',
    'united kingdom': 'Postcode',
    'australia': 'Postcode',
    'new zealand': 'Postcode',
    'singapore': 'Postal Code',
    'canada': 'Postal Code',
    'ireland': 'Eircode',
  };

  static const String _defaultLabel = 'Postal Code';

  /// Countries whose postal codes are purely numeric, so the field can safely
  /// keep a digits-only formatter. Anything NOT listed here allows letters —
  /// the safe default, because a wrongly-applied digits-only filter silently
  /// swallows keystrokes and looks like a broken keyboard.
  static const Set<String> _numericOnly = {
    'india',
    'united states',
    'singapore',
    'australia',
    'new zealand',
    'germany',
    'france',
    'spain',
    'italy',
    'switzerland',
    'austria',
    'belgium',
    'denmark',
    'norway',
    'finland',
    'thailand',
    'malaysia',
    'indonesia',
    'philippines',
    'vietnam',
    'china',
    'japan',
    'south korea',
    'bangladesh',
    'nepal',
    'sri lanka',
    'pakistan',
    'mexico',
    'brazil',
    'turkey',
  };

  /// Countries with no postal-code system, where the field must not be
  /// mandatory. NOT exhaustive — the UPU list runs to ~60 entries; these are
  /// the ones this product is most likely to meet. An unlisted country simply
  /// keeps the field required, which is the correct default for most of the
  /// world. Extend as needed.
  static const Set<String> _noPostalCode = {
    'united arab emirates',
    'qatar',
    'hong kong',
    'macau',
    'panama',
    'jamaica',
    'fiji',
    'zimbabwe',
  };

  static String _key(String? country) => (country ?? '').trim().toLowerCase();

  static bool isIndia(String? country) => _key(country) == 'india';

  static String labelFor(String? country) =>
      _labels[_key(country)] ?? _defaultLabel;

  static String hintFor(String? country) {
    if (isIndia(country)) return 'e.g. 382355';
    if (!isRequiredFor(country)) return 'Not used in this country';
    return 'e.g. ${_sampleFor(_key(country))}';
  }

  static String _sampleFor(String key) {
    switch (key) {
      case 'united states':
        return '90210';
      case 'united kingdom':
        return 'SW1A 1AA';
      case 'canada':
        return 'K1A 0B1';
      case 'ireland':
        return 'D02 AF30';
      case 'australia':
      case 'new zealand':
        return '2000';
      case 'singapore':
        return '238823';
      default:
        return '00000';
    }
  }

  static int maxLengthFor(String? country) =>
      isIndia(country) ? indiaDigits : genericMaxLength;

  /// True only where the code is purely numeric. Everywhere else the caller
  /// must NOT apply a digits-only input formatter — see [_numericOnly].
  static bool digitsOnlyFor(String? country) =>
      _numericOnly.contains(_key(country));

  /// False only for the handful of countries with no postal-code system.
  ///
  /// A blank country reads as required: it is the common case, and onboarding
  /// asks for the country anyway before the form can be submitted.
  static bool isRequiredFor(String? country) =>
      !_noPostalCode.contains(_key(country));

  /// Returns an error message, or null when [value] is acceptable.
  static String? validateFor(String? country, String? value) {
    final v = (value ?? '').trim();

    if (v.isEmpty) {
      return isRequiredFor(country)
          ? '${labelFor(country)} is required'
          : null; // country has no postal code — blank is correct
    }

    if (isIndia(country)) {
      return (v.length == indiaDigits && RegExp(r'^[0-9]+$').hasMatch(v))
          ? null
          : 'PIN Code must be exactly $indiaDigits digits';
    }

    // Outside India we only guard the cap. Length and alphabet vary too much
    // to assert anything stricter without rejecting real addresses.
    return v.length > genericMaxLength
        ? '${labelFor(country)} looks too long'
        : null;
  }

  // ── Persisted-record convenience (post-setup screens) ──────────────────────

  static String? get _savedCountry => businessDetailsRepository.get()?.country;

  static String get label => labelFor(_savedCountry);

  static String get hint => hintFor(_savedCountry);

  static int get maxLength => maxLengthFor(_savedCountry);

  static bool get digitsOnly => digitsOnlyFor(_savedCountry);

  static bool get isRequired => isRequiredFor(_savedCountry);

  static String? validate(String? value) => validateFor(_savedCountry, value);
}
