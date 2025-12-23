import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Order Settings Manager for Restaurant
/// Controls which order types are enabled and their behaviors
class OrderSettings {
  // Private constructor (singleton pattern)
  OrderSettings._();

  /// Storage keys
  static const String _enableTakeAwayKey = 'order_enable_takeaway';
  static const String _enableDineInKey = 'order_enable_dinein';
  static const String _enableDeliveryKey = 'order_enable_delivery';
  static const String _showTakeAwayDialogKey = 'order_takeaway_dialog';
  static const String _showDineInDialogKey = 'order_dinein_dialog';

  /// Default values (all enabled by default for backward compatibility)
  static const bool _defaultEnableTakeAway = true;
  static const bool _defaultEnableDineIn = true;
  static const bool _defaultEnableDelivery = true;
  static const bool _defaultShowTakeAwayDialog = true;
  static const bool _defaultShowDineInDialog = true;

  /// Notifiers for reactive UI updates
  static final ValueNotifier<bool> enableTakeAwayNotifier =
      ValueNotifier(_defaultEnableTakeAway);
  static final ValueNotifier<bool> enableDineInNotifier =
      ValueNotifier(_defaultEnableDineIn);
  static final ValueNotifier<bool> enableDeliveryNotifier =
      ValueNotifier(_defaultEnableDelivery);
  static final ValueNotifier<bool> showTakeAwayDialogNotifier =
      ValueNotifier(_defaultShowTakeAwayDialog);
  static final ValueNotifier<bool> showDineInDialogNotifier =
      ValueNotifier(_defaultShowDineInDialog);

  /// Getters
  static bool get enableTakeAway => enableTakeAwayNotifier.value;
  static bool get enableDineIn => enableDineInNotifier.value;
  static bool get enableDelivery => enableDeliveryNotifier.value;
  static bool get showTakeAwayDialog => showTakeAwayDialogNotifier.value;
  static bool get showDineInDialog => showDineInDialogNotifier.value;

  /// Update individual settings
  static Future<void> setEnableTakeAway(bool value) async {
    enableTakeAwayNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enableTakeAwayKey, value);
    print('📋 Order Setting: Enable Take Away = $value');
  }

  static Future<void> setEnableDineIn(bool value) async {
    enableDineInNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enableDineInKey, value);
    print('📋 Order Setting: Enable Dine In = $value');
  }

  static Future<void> setEnableDelivery(bool value) async {
    enableDeliveryNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enableDeliveryKey, value);
    print('📋 Order Setting: Enable Delivery = $value');
  }

  static Future<void> setShowTakeAwayDialog(bool value) async {
    showTakeAwayDialogNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showTakeAwayDialogKey, value);
    print('📋 Order Setting: Show Take Away Dialog = $value');
  }

  static Future<void> setShowDineInDialog(bool value) async {
    showDineInDialogNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showDineInDialogKey, value);
    print('📋 Order Setting: Show Dine In Dialog = $value');
  }

  /// Load all settings from SharedPreferences
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    enableTakeAwayNotifier.value =
        prefs.getBool(_enableTakeAwayKey) ?? _defaultEnableTakeAway;
    enableDineInNotifier.value =
        prefs.getBool(_enableDineInKey) ?? _defaultEnableDineIn;
    enableDeliveryNotifier.value =
        prefs.getBool(_enableDeliveryKey) ?? _defaultEnableDelivery;
    showTakeAwayDialogNotifier.value =
        prefs.getBool(_showTakeAwayDialogKey) ?? _defaultShowTakeAwayDialog;
    showDineInDialogNotifier.value =
        prefs.getBool(_showDineInDialogKey) ?? _defaultShowDineInDialog;

    print('📋 Order Settings loaded:');
    print('   Take Away: ${enableTakeAwayNotifier.value}');
    print('   Dine In: ${enableDineInNotifier.value}');
    print('   Delivery: ${enableDeliveryNotifier.value}');
    print('   Take Away Dialog: ${showTakeAwayDialogNotifier.value}');
    print('   Dine In Dialog: ${showDineInDialogNotifier.value}');
  }

  /// Reset to default settings
  static Future<void> resetToDefaults() async {
    enableTakeAwayNotifier.value = _defaultEnableTakeAway;
    enableDineInNotifier.value = _defaultEnableDineIn;
    enableDeliveryNotifier.value = _defaultEnableDelivery;
    showTakeAwayDialogNotifier.value = _defaultShowTakeAwayDialog;
    showDineInDialogNotifier.value = _defaultShowDineInDialog;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enableTakeAwayKey, _defaultEnableTakeAway);
    await prefs.setBool(_enableDineInKey, _defaultEnableDineIn);
    await prefs.setBool(_enableDeliveryKey, _defaultEnableDelivery);
    await prefs.setBool(_showTakeAwayDialogKey, _defaultShowTakeAwayDialog);
    await prefs.setBool(_showDineInDialogKey, _defaultShowDineInDialog);

    print('📋 Order Settings reset to defaults');
  }

  /// Check if any order type is enabled
  static bool get hasAnyOrderTypeEnabled =>
      enableTakeAway || enableDineIn || enableDelivery;

  /// Get list of enabled order types
  static List<String> get enabledOrderTypes {
    List<String> enabled = [];
    if (enableTakeAway) enabled.add('Take Away');
    if (enableDineIn) enabled.add('Dine In');
    if (enableDelivery) enabled.add('Delivery');
    return enabled;
  }
}