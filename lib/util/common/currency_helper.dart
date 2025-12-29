import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Currency Helper
///
/// Manages currency symbol selection and formatting throughout the app
///
/// Usage:
/// ```dart
/// // Get current currency symbol
/// String symbol = await CurrencyHelper.getCurrencySymbol();
///
/// // Set currency
/// await CurrencyHelper.setCurrency('USD');
///
/// // Format amount with currency
/// String formatted = await CurrencyHelper.formatAmount(100.50);
/// // Output: "$100.50"
/// ```
class CurrencyHelper {
  static const String _currencyKey = 'selected_currency';

  /// Notifier for currency changes - listen to this for reactive UI updates
  static final ValueNotifier<String> currencyNotifier = ValueNotifier('INR');

  // Available currencies with their symbols
  static const Map<String, CurrencyInfo> currencies = {
    'USD': CurrencyInfo(code: 'USD', symbol: '\$', name: 'US Dollar'),
    'INR': CurrencyInfo(code: 'INR', symbol: '₹', name: 'Indian Rupee'),
    'EUR': CurrencyInfo(code: 'EUR', symbol: '€', name: 'Euro'),
    'GBP': CurrencyInfo(code: 'GBP', symbol: '£', name: 'British Pound'),
    'JPY': CurrencyInfo(code: 'JPY', symbol: '¥', name: 'Japanese Yen'),
    'AUD': CurrencyInfo(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar'),
    'CAD': CurrencyInfo(code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar'),
    'CHF': CurrencyInfo(code: 'CHF', symbol: 'CHF', name: 'Swiss Franc'),
    'CNY': CurrencyInfo(code: 'CNY', symbol: '¥', name: 'Chinese Yuan'),
    'AED': CurrencyInfo(code: 'AED', symbol: 'د.إ', name: 'UAE Dirham'),
    'SAR': CurrencyInfo(code: 'SAR', symbol: '﷼', name: 'Saudi Riyal'),
    'ZAR': CurrencyInfo(code: 'ZAR', symbol: 'R', name: 'South African Rand'),
    'BRL': CurrencyInfo(code: 'BRL', symbol: 'R\$', name: 'Brazilian Real'),
    'MXN': CurrencyInfo(code: 'MXN', symbol: 'Mex\$', name: 'Mexican Peso'),
    'SGD': CurrencyInfo(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar'),
  };

  /// Get the currently selected currency code (default: INR)
  static Future<String> getCurrencyCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currencyKey) ?? 'INR';
  }

  /// Get the currency symbol for the selected currency
  static Future<String> getCurrencySymbol() async {
    final code = await getCurrencyCode();
    return currencies[code]?.symbol ?? '₹';
  }

  /// Get the full currency info for the selected currency
  static Future<CurrencyInfo> getCurrencyInfo() async {
    final code = await getCurrencyCode();
    return currencies[code] ?? currencies['INR']!;
  }

  /// Get current currency code synchronously from notifier
  static String get currentCurrencyCode => currencyNotifier.value;

  /// Get current currency symbol synchronously
  static String get currentSymbol => currencies[currentCurrencyCode]?.symbol ?? '₹';

  /// Get current currency info synchronously
  static CurrencyInfo get currentCurrencyInfo =>
      currencies[currentCurrencyCode] ?? currencies['INR']!;

  /// Load currency from SharedPreferences on app start
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCurrency = prefs.getString(_currencyKey) ?? 'INR';
    currencyNotifier.value = savedCurrency;
    print('💰 Currency loaded: $savedCurrency (${currencies[savedCurrency]?.symbol})');
  }

  /// Set the selected currency
  static Future<void> setCurrency(String currencyCode) async {
    if (!currencies.containsKey(currencyCode)) {
      throw ArgumentError('Invalid currency code: $currencyCode');
    }
    currencyNotifier.value = currencyCode; // Update notifier for reactive UI
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, currencyCode);
    print('💰 Currency changed to: $currencyCode (${currencies[currencyCode]?.symbol})');
  }

  /// Format an amount with the selected currency symbol
  ///
  /// Examples:
  /// - formatAmount(100) => "$100.00"
  /// - formatAmount(100.5) => "$100.50"
  /// - formatAmount(100, showSymbol: false) => "100.00"
  static Future<String> formatAmount(
      num amount, {
        bool showSymbol = true,
        int decimalPlaces = 2,
      }) async {
    final symbol = showSymbol ? await getCurrencySymbol() : '';
    final formatted = amount.toStringAsFixed(decimalPlaces);
    return showSymbol ? '$symbol$formatted' : formatted;
  }

  /// Format amount synchronously with a given symbol
  /// Use this when you already have the symbol to avoid async calls in UI
  static String formatAmountWithSymbol(
      num amount,
      String symbol, {
        int decimalPlaces = 2,
      }) {
    final formatted = amount.toStringAsFixed(decimalPlaces);
    return '$symbol$formatted';
  }

  /// Get list of all available currencies
  static List<CurrencyInfo> getAllCurrencies() {
    return currencies.values.toList();
  }
}

/// Currency Information Model
class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.name,
  });

  @override
  String toString() => '$name ($symbol)';
}