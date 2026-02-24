import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  // Private constructor (no instance creation)
  AppSettings._();

  /// ---- Default Values ----
  static const String _roundOffPrefKey = 'selectedRoundOffValue';
  static const String _roundOffDefault = '1.00';

  static final Map<String, bool> _defaultSettingValues = {
    // Layout Settings
    "Item Image": true,
    "Item Price": true,
    "Fix Item Card": false,
    "All Items Category": false,
    "Round Off": false,

    // Input & Interaction
    "Visual Keyboard": false,
    "Addresss Suggestion": true,
    // "Separate Quantity": false, // ❌ NOT IMPLEMENTED - Commented out

    // Order Processing
    // "Auto Print KOT On Delete Item": false, // ❌ NOT IMPLEMENTED - Commented out
    // "Estimate": false, // ✅ WORKING
    "Generate KOT": false, // ✅ WORKING
    // "Show Payment Method": false, // ❌ NOT IMPLEMENTED - Commented out
    "Tax Is Inclusive": false, // ✅ WORKING
    "Discount On Items": false, // ✅ WORKING
    "Decimal Precision": true, // 🔢 Decimal places control



    // Printing
    // "Label Printer": false, // ❌ NOT IMPLEMENTED - Commented out
    // "Section Wise Print": false, // ❌ NOT IMPLEMENTED - Commented out
    // "auto Print End Day Summary": false, // ❌ NOT IMPLEMENTED - Commented out
    // "Print End Day Extra Details": false,
    // "Print Qr Code For E-Incoice": false, // ❌ NOT IMPLEMENTED - Commented out
    // "Show Payment Method (Quick Settle)": false, // ❌ NOT IMPLEMENTED - Commented out
    // "Auto Print Kot of New Local Other": false, // ❌ NOT IMPLEMENTED - Commented out

    // // Online Order Settings
    // "Online Order Notification": false,
    // "Online Order Bill Auto Print": false,
    // "Online Order Auto Kot Print": false,
  };

  /// ---- Grouped Settings for UI ----
  static final Map<String, List<String>> groupedSettings = {
    "Layout Settings": [
      "Item Image",
      "Item Price",
      "Fix Item Card",
      "All Items Category",
      "Round Off",
    ],
    "Input & Interaction": [
      "Visual Keyboard",
      "Addresss Suggestion",
      // "Separate Quantity", // ❌ NOT IMPLEMENTED - Commented out
    ],
    "Order Processing": [
      // "Auto Print KOT On Delete Item", // ❌ NOT IMPLEMENTED - Commented out
      // "Estimate", // ✅ WORKING
      "Generate KOT", // ✅ WORKING
      // "Show Payment Method", // ❌ NOT IMPLEMENTED - Commented out
      "Tax Is Inclusive", // ✅ WORKING
      "Discount On Items", // ✅ WORKING
    ],
    // "Printing": [
    //   // "Label Printer", // ❌ NOT IMPLEMENTED - Commented out
    //   // "Section Wise Print", // ❌ NOT IMPLEMENTED - Commented out
    //   // "auto Print End Day Summary", // ❌ NOT IMPLEMENTED - Commented out
    //   "Print End Day Extra Details",
    //   // "Print Qr Code For E-Incoice", // ❌ NOT IMPLEMENTED - Commented out
    //   // "Show Payment Method (Quick Settle)", // ❌ NOT IMPLEMENTED - Commented out
    //   // "Auto Print Kot of New Local Other", // ❌ NOT IMPLEMENTED - Commented out
    // ],
    // "Online Order Settings": [
    //   "Online Order Notification",
    //   "Online Order Bill Auto Print",
    //   "Online Order Auto Kot Print",
    // ],
  };

  /// ---- Notifiers ----
  static final ValueNotifier<Map<String, bool>> settingsNotifier =
  ValueNotifier(Map.from(_defaultSettingValues));

  static final ValueNotifier<String> roundOffNotifier =
  ValueNotifier(_roundOffDefault);

  static const String _refundWindowKey = 'refundWindowMinutes';
  static const int _refundWindowDefault = 60;
  static final ValueNotifier<int> refundWindowNotifier =
      ValueNotifier(_refundWindowDefault);

  /// ---- Public Getters ----
  static Map<String, bool> get values => settingsNotifier.value;
  static String get selectedRoundOffValue => roundOffNotifier.value;
  static int get refundWindowMinutes => refundWindowNotifier.value;

  static bool getSetting(String key) => values[key] ?? false;

  /// ---- Update Methods ----
  static Future<void> updateSetting(String key, bool newValue) async {
    final updated = Map<String, bool>.from(values);
    updated[key] = newValue;
    settingsNotifier.value = updated;
    await _save();
  }

  static Future<void> updateRoundOffValue(String newValue) async {
    roundOffNotifier.value = newValue;
    await _save();
  }

  static Future<void> updateRefundWindow(int minutes) async {
    refundWindowNotifier.value = minutes;
    await _save();
  }

  static Future<void> resetToDefaults() async {
    settingsNotifier.value = Map.from(_defaultSettingValues);
    roundOffNotifier.value = _roundOffDefault;
    refundWindowNotifier.value = _refundWindowDefault;
    await _save();
  }

  /// ---- Persistence ----
  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    values.forEach((key, value) => prefs.setBool(key, value));
    await prefs.setString(_roundOffPrefKey, selectedRoundOffValue);
    await prefs.setInt(_refundWindowKey, refundWindowMinutes);
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = Map<String, bool>.from(_defaultSettingValues);

    for (var key in loaded.keys) {
      loaded[key] = prefs.getBool(key) ?? loaded[key]!;
    }

    settingsNotifier.value = loaded;
    roundOffNotifier.value =
        prefs.getString(_roundOffPrefKey) ?? _roundOffDefault;
    refundWindowNotifier.value =
        prefs.getInt(_refundWindowKey) ?? _refundWindowDefault;
  }


// -------- Optional: Individual Getters --------
  static bool get showItemImage => values["Item Image"] ?? true;
  static bool get showItemPrice => values["Item Price"] ?? true;
  // static bool get showDefaultItemImage => values["Item Default Image"] ?? false;
  static bool get fixItemCard => values["Fix Item Card"] ?? false;
  static bool get allItemsCategory => values["All Items Category"] ?? false;
  static bool get roundOff => values["Round Off"] ?? true;

  static bool get visualKeyboard => values["Visual Keyboard"] ?? false;
  static bool get addressSuggestion => values["Addresss Suggestion"] ?? true;

  // static bool get  sepratedQuantity => values["Separate Quantity"] ?? false;
  // static bool get autoPrintKotOnDelete => values["Auto Print KOT On Delete Item"] ?? false;
  // static bool get  estimate=> values["Estimate"] ?? false;
  static bool get generateKOT => values["Generate KOT"] ?? false;

  static bool get showPaymentMethod => values["Show Payment Method"] ?? false;
  static bool get isTaxInclusive => values["Tax Is Inclusive"] ?? false;
  static bool get discountOnItems => values["Discount On Items"] ?? false;




 //  static bool get  labelPrinter => values["Label Printer"] ?? false;
 //  static bool get sectionWisePrint => values["Section Wise Print"] ?? false;
 //  static bool get  autoPrintEndDaySummary=> values["auto Print End Day Summary"] ?? false;
 //  static bool get printEndDayExtraDetails => values["Print End Day Extra Details"] ?? false;
 //  static bool get printQrCodeForEIncoice => values["Print Qr Code For E-Incoice"] ?? false;
 // static bool get showPaymentMethodQuickSettle => values["Show Payment Method (Quick Settle)"] ?? false;
 //  static bool get  printKotofNewLocalOther => values["Auto Print Kot of New Local Other"] ?? false;



  // static bool get onlineOrderNotification =>
  //     values["Online Order Notification"] ?? false;
  // static bool get onlineOrderAutoPrint =>
  //     values["Online Order Bill Auto Print"] ?? true;
  // static bool get onlineOrderKotPrint =>
  //     values["Online Order Auto Kot Print"] ?? true;
  //

}
