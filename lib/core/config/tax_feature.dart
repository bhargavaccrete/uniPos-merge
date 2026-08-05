import '../di/service_locator.dart';

/// Single source of truth for "does this business use tax features right now."
/// Wraps BusinessDetails.taxEnabled (set during onboarding's tax-registration
/// question) so every call site — UI, import, billing, print, reports — reads
/// one named, greppable helper instead of reaching into the repository directly.
class TaxFeature {
  TaxFeature._();

  static bool get enabled => businessDetailsRepository.isTaxEnabled;
}
