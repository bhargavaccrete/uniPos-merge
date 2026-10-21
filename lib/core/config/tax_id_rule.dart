import '../../data/repositories/business_details_repository.dart';
import '../di/service_locator.dart';
import 'tax_label_rule.dart';

/// Single source of truth for "what is this country's tax registration number
/// called, and what shape is a valid one."
///
/// India → GSTIN, a fixed 15-character pattern. Everywhere else the number
/// (VAT / EIN / ABN …) varies too much to format-check, so only the label
/// changes and the value is accepted as typed. Always OPTIONAL — an empty value
/// is valid everywhere.
///
/// Two forms, matching [FoodLicenseRule] and [TaxLabelRule]:
///  * `*For(country)` takes the country explicitly — for onboarding's Store
///    Details step, where nothing is persisted yet.
///  * [label] / [hint] / [maxLength] / [validate] read the saved
///    `BusinessDetails`, for post-setup screens.
///
/// Unlike [TaxLabelRule.isIndiaFor], an UNSET country is not India: Store
/// Details shows the generic field until a country is picked.
class TaxIdRule {
  TaxIdRule._();

  static const int gstinLength = 15;
  static const int genericMaxLength = 20;

  static final RegExp _gstinPattern = RegExp(
    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
    caseSensitive: false,
  );

  static bool isIndiaFor(String? country) =>
      (country ?? '').trim().toLowerCase() == 'india';

  static String labelFor(String? country) =>
      isIndiaFor(country) ? 'GSTIN' : 'Tax Registration Number';

  /// Heading for the Registered / Not Registered question.
  static String registrationTitleFor(String? country) =>
      isIndiaFor(country) ? 'GST Registration' : 'Tax Registration';

  static String hintFor(String? country) => isIndiaFor(country)
      ? 'e.g. 22AAAAA0000A1Z5'
      : 'VAT / EIN / Tax ID (optional)';

  /// Short form for printed bills, where a 32-column thermal line has no room
  /// for "Tax Registration Number": GSTIN, VAT No., Sales Tax No., Tax No.
  static String printLabelFor(String? country) => isIndiaFor(country)
      ? 'GSTIN'
      : '${TaxLabelRule.nameFor(country)} No.';

  static int maxLengthFor(String? country) =>
      isIndiaFor(country) ? gstinLength : genericMaxLength;

  static final RegExp _panPattern = RegExp(
    r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$',
    caseSensitive: false,
  );

  /// India's PAN. Optional; format-checked only when filled.
  static String? validatePan(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    return _panPattern.hasMatch(v) ? null : 'Enter a valid 10-character PAN';
  }

  /// The number to print for a bill: its stamped value, else [live] for bills
  /// written before stamping. Blank reads as none, so no bare "GSTIN:" prints.
  static String? numberForRecord(String? stamped, String? live) {
    final v = (stamped ?? live)?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  /// Returns an error message, or null when [value] is acceptable.
  static String? validateFor(String? country, String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty || !isIndiaFor(country)) return null;
    if (!_gstinPattern.hasMatch(v)) return 'Enter a valid 15-character GSTIN';
    return null;
  }

  // ── Persisted-record convenience (post-setup screens) ─────────────────────

  static String? get _savedCountry =>
      locator.isRegistered<BusinessDetailsRepository>()
          ? businessDetailsRepository.get()?.country
          : null;

  /// Whether the registration-number field is shown at all — the legal-status
  /// flag, not `taxEnabled` (which billing reads). Unset reads as registered,
  /// the model's own default.
  static bool get isRegistered =>
      !locator.isRegistered<BusinessDetailsRepository>() ||
      (businessDetailsRepository.get()?.isRegisteredForTax ?? true);

  static bool get isIndia => isIndiaFor(_savedCountry);

  static String get label => labelFor(_savedCountry);

  static String get registrationTitle => registrationTitleFor(_savedCountry);

  static String get hint => hintFor(_savedCountry);

  static String get printLabel => printLabelFor(_savedCountry);

  static int get maxLength => maxLengthFor(_savedCountry);

  static String? validate(String? value) => validateFor(_savedCountry, value);
}
