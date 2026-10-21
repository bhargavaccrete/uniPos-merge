import '../di/service_locator.dart';

/// Single source of truth for "what shape is a valid phone number."
///
/// India is fixed at 10 digits; every other country accepts 7–15, the ITU E.164
/// subscriber-number range.
///
/// **Two APIs, and the difference matters.**
///
/// * The `*For(country, …)` methods take the country explicitly. Use these on a
///   screen where the country is still being *chosen* — onboarding's Store
///   Details, where the dropdown sits below the phone box. There, a blank
///   country means "the user hasn't told us yet", so the rule stays permissive
///   (7–15) rather than guessing India and rejecting a perfectly good 9-digit
///   number before the question has even been asked.
///
/// * The plain getters (`maxLength`, `hint`, `validate`) read the SAVED country
///   from `BusinessDetails`. Use these everywhere else. There a blank country
///   means "not configured", which the app treats as India — matching its
///   INR/India defaults. Behaviour is unchanged from before this split.
///
/// Both assume the field is digits-only (pair with
/// `FilteringTextInputFormatter.digitsOnly`) — this checks length, not
/// character class.
///
/// ```dart
/// // On the screen that chooses the country:
/// AppTextField(
///   maxLength: PhoneRule.maxLengthFor(_countryController.text),
///   hint: PhoneRule.hintFor(_countryController.text),
///   validator: (v) => PhoneRule.validateFor(_countryController.text, v),
///   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
/// )
///
/// // Everywhere else:
/// AppTextField(
///   maxLength: PhoneRule.maxLength,
///   hint: PhoneRule.hint,
///   validator: (v) => PhoneRule.validate(v),
/// )
/// ```
class PhoneRule {
  PhoneRule._();

  static const int indiaDigits = 10;
  static const int minDigits = 7;
  static const int maxDigits = 15;

  // ── Country-passing API ────────────────────────────────────────────────────

  static bool isIndiaFor(String? country) =>
      (country ?? '').trim().toLowerCase() == 'india';

  /// "Not chosen yet" — deliberately NOT treated as India. See the class doc.
  static bool _isUnchosen(String? country) => (country ?? '').trim().isEmpty;

  /// Field cap. While the country is unchosen this is the widest rule, so the
  /// box never stops someone typing a number that will turn out to be valid.
  static int maxLengthFor(String? country) {
    if (_isUnchosen(country)) return maxDigits;
    return isIndiaFor(country) ? indiaDigits : maxDigits;
  }

  static String hintFor(String? country) {
    if (_isUnchosen(country)) return 'Enter mobile number';
    return isIndiaFor(country)
        ? 'Enter $indiaDigits-digit mobile number'
        : 'Enter $minDigits–$maxDigits digit mobile number';
  }

  /// Just the length portion — "10 digits" / "7–15 digits" — for callers that
  /// compose their own hint, e.g. an optional field reading
  /// "Optional, ${PhoneRule.lengthLabel}".
  static String lengthLabelFor(String? country) {
    if (_isUnchosen(country)) return 'digits';
    return isIndiaFor(country)
        ? '$indiaDigits digits'
        : '$minDigits–$maxDigits digits';
  }

  /// Returns an error message, or null when [value] is acceptable for
  /// [country]. Pass `required: false` for optional phone fields.
  static String? validateFor(
    String? country,
    String? value, {
    bool required = true,
  }) {
    final digits = (value ?? '').trim();

    if (digits.isEmpty) {
      return required ? 'Please enter phone number' : null;
    }

    // Country unchosen, or a country with no special rule → the permissive
    // E.164 range. Only India narrows it further.
    if (_isUnchosen(country) || !isIndiaFor(country)) {
      return _outOfRange(digits)
          ? 'Enter a valid phone number ($minDigits–$maxDigits digits)'
          : null;
    }

    return digits.length == indiaDigits
        ? null
        : 'Phone number must be exactly $indiaDigits digits';
  }

  static bool _outOfRange(String digits) =>
      digits.length < minDigits || digits.length > maxDigits;

  // ── Saved-country API (unchanged behaviour) ────────────────────────────────

  /// The configured country, or India when none is set. Collapsing blank to
  /// India *here* is what keeps the getters below behaving exactly as they did
  /// before the country-passing API existed.
  static String get _savedCountry {
    final country = businessDetailsRepository.get()?.country;
    return (country == null || country.trim().isEmpty) ? 'India' : country;
  }

  static bool get isIndia => isIndiaFor(_savedCountry);

  static int get maxLength => maxLengthFor(_savedCountry);

  static String get hint => hintFor(_savedCountry);

  static String get lengthLabel => lengthLabelFor(_savedCountry);

  static String? validate(String? value, {bool required = true}) =>
      validateFor(_savedCountry, value, required: required);
}
