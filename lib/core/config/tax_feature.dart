import '../di/service_locator.dart';

/// Single source of truth for "does this business use tax features right now."
/// Wraps BusinessDetails.taxEnabled (set during onboarding's tax-registration
/// question) so every call site — UI, import, billing, print, reports — reads
/// one named, greppable helper instead of reaching into the repository directly.
class TaxFeature {
  TaxFeature._();

  static bool get enabled => businessDetailsRepository.isTaxEnabled;

  /// The flag a SAVED bill was made under. Bills stamp [enabled] when created,
  /// so a reprint after the business changes its tax registration renders the
  /// tax the bill actually carried. Records written before the stamp existed
  /// read null and fall back to the live flag.
  static bool forRecord(bool? stamped) => stamped ?? enabled;
}
