import '../../domain/services/retail/retail_printer_settings_service.dart';
import '../../util/common/currency_helper.dart';
import '../../util/common/decimal_settings.dart';
import '../../util/restaurant/staticswitch.dart';

/// Settings Retail reads from the first bill onward.
///
/// `AppSettings` is shared: Retail's round-off and its refund lock and window
/// live there, so without this load they fell back to defaults on every
/// restart (WF-2).
Future<void> loadRetailStartupSettings() async {
  await Future.wait([
    AppSettings.load(),
    RetailPrinterSettingsService().initialize(),
    DecimalSettings.load(),
    CurrencyHelper.load(),
  ]);
}
