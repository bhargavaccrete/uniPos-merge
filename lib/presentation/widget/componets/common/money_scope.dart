import 'package:flutter/material.dart';

import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';

/// Money string honouring the store's currency symbol and decimal-precision
/// settings. Callers must sit under a [MoneyScope] for it to stay live.
String formatMoney(double amount) => CurrencyHelper.formatAmountWithSymbol(
      amount,
      CurrencyHelper.currentSymbol,
      decimalPlaces: DecimalSettings.precision,
    );

/// Rebuilds [child] when the currency or decimal precision changes.
///
/// Wrap a whole screen or dialog in one of these rather than nesting a
/// `ValueListenableBuilder` pair around every individual price — one
/// subscription per surface instead of one per label.
class MoneyScope extends StatelessWidget {
  final Widget child;

  const MoneyScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: CurrencyHelper.currencyNotifier,
      builder: (context, currency, _) => ValueListenableBuilder<int>(
        valueListenable: DecimalSettings.precisionNotifier,
        builder: (context, precision, _) => child,
      ),
    );
  }
}
