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
    "Powered By": true,
    "Custom Field": false,
    "Extra Info": false,
  };

  /// ---- Notifiers ----
  static final ValueNotifier<Map<String, bool>> settingsNotifier =
      ValueNotifier(Map.from(_defaultPrintSettings));

  /// ---- Public Getters ----
  static Map<String, bool> get values => settingsNotifier.value;

  static bool getSetting(String key) => values[key] ?? false;

  // Individual getters for easy access in code
  static bool get showOrderId => getSetting("Order ID");
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
  static bool get showPoweredBy => getSetting("Powered By");
  static bool get showCustomField => getSetting("Custom Field");
  static bool get showExtraInfo => getSetting("Extra Info");

  /// ---- Update Methods ----
  static Future<void> updateSetting(String key, bool newValue) async {
    final updated = Map<String, bool>.from(values);
    updated[key] = newValue;
    settingsNotifier.value = updated;
    await _save();
    print('🖨️  PrintSettings: $key = $newValue (saved)');
  }

  static Future<void> resetToDefaults() async {
    settingsNotifier.value = Map.from(_defaultPrintSettings);
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
  }
}