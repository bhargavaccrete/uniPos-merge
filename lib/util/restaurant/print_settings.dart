import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Print Settings Manager for Restaurant Bills/KOT
/// Controls what information appears on printed receipts
class PrintSettings {
  // Private constructor (singleton pattern)
  PrintSettings._();

  /// ---- Default Values ----
  static const Map<String, bool> _defaultPrintSettings = {
    "Order ID": true,
    // Logo prints on PDF/A4 receipts only — the raw ESC/POS builder has no
    // image support, so a directly-connected thermal printer ignores this.
    "Restaurant Logo": true,
    "Restaurant Name": true,
    "Restaurant Address": false,
    "Restaurant Mobile No": false,
    "Website Name": true,
    "Ordered Time": true,
    "Customer Name": true,
    "Order Type": true,
    "Payment Type": true,
    "Tax": true,
    "Subtotal": true,
    "Payment Paid": true,
    "UPI QR": true,
    "Powered By": true,
    "Custom Field": false,
    "Extra Info": false,
  };

  /// ---- Notifiers ----
  static final ValueNotifier<Map<String, bool>> settingsNotifier =
      ValueNotifier(Map.from(_defaultPrintSettings));

  /// Bill format used for printing bills — 'thermal' (80mm) or 'a4'.
  /// Stored separately from the boolean map (string value).
  static const String _billFormatKey = 'print_bill_format';
  static const String _billFormatDefault = 'thermal';
  static final ValueNotifier<String> billFormatNotifier =
      ValueNotifier(_billFormatDefault);

  static String get billFormat => billFormatNotifier.value;
  static bool get isBillFormatA4 => billFormat == 'a4';

  static Future<void> setBillFormat(String value) async {
    billFormatNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_billFormatKey, value);
  }

  /// Owner-editable footer / "Thank You" message printed at the bottom of bills.
  /// Supports multiple lines (split on \n). Blank prints no footer message.
  static const String _footerMessageKey = 'print_footer_message';
  static const String _footerMessageDefault = 'Thank you! Visit us again!';
  static final ValueNotifier<String> footerMessageNotifier =
      ValueNotifier(_footerMessageDefault);

  static String get footerMessage => footerMessageNotifier.value;

  static Future<void> setFooterMessage(String value) async {
    footerMessageNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_footerMessageKey, value);
  }

  /// Bill template: 'simple' or 'paper_saver'
  static const String _billTemplateKey = 'print_bill_template';
  static const String _billTemplateDefault = 'simple';
  static final ValueNotifier<String> billTemplateNotifier =
      ValueNotifier(_billTemplateDefault);

  static String get billTemplate => billTemplateNotifier.value;
  static bool get isBillTemplatePaperSaver => billTemplate == 'paper_saver';

  static Future<void> setBillTemplate(String value) async {
    billTemplateNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_billTemplateKey, value);
  }

  /// KOT template: 'standard' or 'paper_saver'
  static const String _kotTemplateKey = 'print_kot_template';
  static const String _kotTemplateDefault = 'standard';
  static final ValueNotifier<String> kotTemplateNotifier =
      ValueNotifier(_kotTemplateDefault);

  static String get kotTemplate => kotTemplateNotifier.value;
  static bool get isKotTemplatePaperSaver => kotTemplate == 'paper_saver';

  static Future<void> setKotTemplate(String value) async {
    kotTemplateNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kotTemplateKey, value);
  }

  /// ---- Public Getters ----
  static Map<String, bool> get values => settingsNotifier.value;

  static bool getSetting(String key) => values[key] ?? false;

  // Individual getters for easy access in code
  static bool get showOrderId => getSetting("Order ID");
  static bool get showRestaurantLogo => getSetting("Restaurant Logo");
  static bool get showRestaurantName => getSetting("Restaurant Name");
  static bool get showRestaurantAddress => getSetting("Restaurant Address");
  static bool get showRestaurantMobile => getSetting("Restaurant Mobile No");
  static bool get showWebsiteName => getSetting("Website Name");
  static bool get showOrderedTime => getSetting("Ordered Time");
  static bool get showCustomerName => getSetting("Customer Name");
  static bool get showOrderType => getSetting("Order Type");
  static bool get showPaymentType => getSetting("Payment Type");
  static bool get showTax => getSetting("Tax");
  static bool get showSubtotal => getSetting("Subtotal");
  static bool get showPaymentPaid => getSetting("Payment Paid");
  static bool get showUpiQr => getSetting("UPI QR");
  static bool get showPoweredBy => getSetting("Powered By");
  static bool get showCustomField => getSetting("Custom Field");
  static bool get showExtraInfo => getSetting("Extra Info");

  /// ---- Update Methods ----
  static Future<void> updateSetting(String key, bool newValue) async {
    final updated = Map<String, bool>.from(values);
    updated[key] = newValue;
    settingsNotifier.value = updated;
    await _save();
  }

  static Future<void> resetToDefaults() async {
    settingsNotifier.value = Map.from(_defaultPrintSettings);
    await setBillFormat(_billFormatDefault);
    await setFooterMessage(_footerMessageDefault);
    await setBillTemplate(_billTemplateDefault);
    await setKotTemplate(_kotTemplateDefault);
    await _save();
  }

  /// ---- Persistence ----
  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    values.forEach((key, value) {
      prefs.setBool('print_$key', value);
    });
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = Map<String, bool>.from(_defaultPrintSettings);

    for (var key in loaded.keys) {
      loaded[key] = prefs.getBool('print_$key') ?? loaded[key]!;
    }

    settingsNotifier.value = loaded;
    billFormatNotifier.value =
        prefs.getString(_billFormatKey) ?? _billFormatDefault;
    footerMessageNotifier.value =
        prefs.getString(_footerMessageKey) ?? _footerMessageDefault;
    billTemplateNotifier.value =
        prefs.getString(_billTemplateKey) ?? _billTemplateDefault;
    kotTemplateNotifier.value =
        prefs.getString(_kotTemplateKey) ?? _kotTemplateDefault;
  }
}