/*
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';

/// Retail Price Formatter
/// Uses shared currency and decimal settings to format prices
class PriceFormatter {
  /// Format a price with the current currency symbol and decimal precision
  static String format(num amount) {
    final symbol = CurrencyHelper.currentSymbol;
    final formatted = amount.toStringAsFixed(DecimalSettings.precision);
    return '$symbol$formatted';
  }

  /// Get just the currency symbol (for prefix in text fields)
  static String get currencySymbol => '${CurrencyHelper.currentSymbol} ';
}*/
