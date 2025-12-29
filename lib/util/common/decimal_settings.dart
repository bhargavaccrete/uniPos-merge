import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Decimal Precision Settings Manager for Restaurant
/// Controls decimal places for prices and amounts
class DecimalSettings {
  // Private constructor (singleton pattern)
  DecimalSettings._();

  /// Storage key
  static const String _storageKey = 'restaurant_decimal_precision';

  /// Default decimal places (2 for currency)
  static const int _defaultPrecision = 2;

  /// Current decimal precision notifier
  static final ValueNotifier<int> precisionNotifier =
      ValueNotifier(_defaultPrecision);

  /// Get current precision value
  static int get precision => precisionNotifier.value;

  /// Update decimal precision
  static Future<void> updatePrecision(int newPrecision) async {
    if (newPrecision < 0 || newPrecision > 3) {
      throw ArgumentError('Precision must be between 0 and 3');
    }

    precisionNotifier.value = newPrecision;
    await _save();
    print('💰 Decimal precision updated to: $newPrecision places');
  }

  /// Reset to default precision
  static Future<void> resetToDefault() async {
    precisionNotifier.value = _defaultPrecision;
    await _save();
  }

  /// Save to SharedPreferences
  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_storageKey, precisionNotifier.value);
  }

  /// Load from SharedPreferences
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPrecision = prefs.getInt(_storageKey) ?? _defaultPrecision;
    precisionNotifier.value = savedPrecision;
    print('💰 Decimal precision loaded: $savedPrecision places');
  }

  /// Format amount according to current precision
  static String formatAmount(double amount) {
    return amount.toStringAsFixed(precision);
  }

  /// Format currency with symbol
  static String formatCurrency(double amount, {String symbol = '₹'}) {
    return '$symbol${formatAmount(amount)}';
  }

  /// Get precision description for UI
  static String getPrecisionLabel(int precision) {
    switch (precision) {
      case 0:
        return 'No decimals (₹100)';
      case 1:
        return '1 decimal place (₹100.5)';
      case 2:
        return '2 decimal places (₹100.50)';
      case 3:
        return '3 decimal places (₹100.500)';
      default:
        return '2 decimal places (₹100.50)';
    }
  }
}