import '../di/service_locator.dart';

/// Single source of truth for "what shape is a valid customer phone number."
///
/// India is fixed at 10 digits; every other country accepts 7–15, the ITU E.164
/// subscriber-number range. Reads `BusinessDetails.country` (set in onboarding's
/// Store Details step) so every form asks one named, greppable helper instead of
/// hardcoding a length — the same reason [TaxFeature] exists.
///
/// Defaults to India when the country hasn't been set yet, matching the app's
/// INR/India defaults elsewhere.
///
/// ```dart
/// AppTextField(
///   maxLength: PhoneRule.maxLength,
///   hint: PhoneRule.hint,
///   validator: (v) => PhoneRule.validate(v),
///   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
/// )
/// ```
class PhoneRule {
  PhoneRule._();

  static const int indiaDigits = 10;
  static const int minDigits = 7;
  static const int maxDigits = 15;

  static bool get isIndia {
    final country = businessDetailsRepository.get()?.country;
    if (country == null || country.trim().isEmpty) return true;
    return country.trim().toLowerCase() == 'india';
  }

  /// Field cap — stops the user typing past the rule in the first place.
  static int get maxLength => isIndia ? indiaDigits : maxDigits;

  static String get hint => isIndia
      ? 'Enter $indiaDigits-digit mobile number'
      : 'Enter $minDigits–$maxDigits digit mobile number';

  /// Returns an error message, or null when [value] is acceptable.
  /// Pass `required: false` for optional phone fields.
  ///
  /// Assumes the field is digits-only (pair it with
  /// `FilteringTextInputFormatter.digitsOnly`) — this checks length, not
  /// character class.
  static String? validate(String? value, {bool required = true}) {
    final digits = (value ?? '').trim();

    if (digits.isEmpty) {
      return required ? 'Please enter phone number' : null;
    }

    if (isIndia) {
      return digits.length == indiaDigits
          ? null
          : 'Phone number must be exactly $indiaDigits digits';
    }

    return (digits.length < minDigits || digits.length > maxDigits)
        ? 'Enter a valid phone number ($minDigits–$maxDigits digits)'
        : null;
  }
}
