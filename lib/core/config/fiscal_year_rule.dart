import '../../data/repositories/business_details_repository.dart';
import '../di/service_locator.dart';

/// Single source of truth for "when does this country's financial year turn
/// over" — the moment every document series restarts at 1.
///
/// India runs 1 April – 31 March, which is what makes an invoice number like
/// `INV-00001` legal even though it repeats every year: CGST Rule 46(b) demands
/// a consecutive serial "unique for a financial year", not unique forever. Get
/// the boundary wrong and a series either resets mid-year or never resets, and
/// both are audit findings.
///
/// Two forms, matching the split [TariffCodeRule] and [FoodLicenseRule] use:
///  * `startMonthFor(country)` / `keyFor(country, date)` take the country
///    explicitly, for onboarding, where nothing is persisted yet.
///  * [currentKey] / [resetLabel] read the saved `BusinessDetails`, for the
///    numbering services and settings screens that run after setup.
class FiscalYearRule {
  FiscalYearRule._();

  /// Lowercased, trimmed country name → month the financial year begins in.
  ///
  /// Keys are the exact display names in the bundled `country.json`
  /// (`CountryStateCityData`). Only countries whose year does NOT start in
  /// January are listed; everything else falls through to [_calendarStart],
  /// which covers the EU, UAE, Singapore, Canada and the US.
  ///
  /// The UK is the awkward one: 6 April for individuals, 1 April for
  /// corporation tax. April is right either way for a business's own document
  /// series, and the day-of-month never matters here — only the month does.
  static const Map<String, int> _startMonths = {
    'india': 4,
    'united kingdom': 4,
    'australia': 7,
    'new zealand': 7,
    'japan': 4,
    'south africa': 3,
    'pakistan': 7,
    'bangladesh': 7,
  };

  static const int _calendarStart = 1;

  static String _key(String? country) => (country ?? '').trim().toLowerCase();

  /// An UNSET country reads as India, matching [PhoneRule] and the app's
  /// primary market — a shop that hasn't finished Store Details still gets the
  /// April boundary rather than a silent calendar-year default.
  static int startMonthFor(String? country) {
    final key = _key(country);
    if (key.isEmpty) return _startMonths['india']!;
    return _startMonths[key] ?? _calendarStart;
  }

  /// The date [date]'s financial year began on.
  static DateTime startOfFor(String? country, DateTime date) {
    final month = startMonthFor(country);
    final year = date.month >= month ? date.year : date.year - 1;
    return DateTime(year, month, 1);
  }

  /// A stable token identifying the financial year [date] falls in — the value
  /// stored beside each counter so a mint can tell "same year, keep counting"
  /// from "new year, restart at 1".
  ///
  /// `2026-27` where the year straddles, plain `2026` where it does not, so a
  /// calendar-year country never sees a misleading hyphenated span.
  static String keyFor(String? country, DateTime date) {
    final start = startOfFor(country, date);
    if (startMonthFor(country) == _calendarStart) return '${start.year}';
    final endShort = ((start.year + 1) % 100).toString().padLeft(2, '0');
    return '${start.year}-$endShort';
  }

  /// Human wording for the turnover date, e.g. "1 April" — shown on the
  /// numbering settings screen so the reset is never a surprise.
  static String resetLabelFor(String? country) =>
      '1 ${_monthNames[startMonthFor(country) - 1]}';

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  // ── Persisted-record convenience ──────────────────────────────────────────

  /// Never throws. Reached before the service locator is wired — early boot,
  /// and every unit test that mints a number without standing up DI.
  /// Unregistered reads as unset, which [startMonthFor] treats as India.
  static String? get _savedCountry =>
      locator.isRegistered<BusinessDetailsRepository>()
          ? businessDetailsRepository.get()?.country
          : null;

  /// Month the saved country's financial year begins in.
  static int get startMonth => startMonthFor(_savedCountry);

  /// The financial year token for today, e.g. `2026-27`.
  static String get currentKey => keyFor(_savedCountry, DateTime.now());

  /// The financial year token for [date] under the saved country.
  static String keyOf(DateTime date) => keyFor(_savedCountry, date);

  /// The date the current financial year began.
  static DateTime get startOfCurrent => startOfFor(_savedCountry, DateTime.now());

  /// e.g. "1 April".
  static String get resetLabel => resetLabelFor(_savedCountry);
}
