/// Indian Rupee denominations for cash counting
class CashDenominations {
  // Standard Indian currency denominations (notes and coins)
  static const List<double> notes = [
    2000,
    500,
    200,
    100,
    50,
    20,
    10,
  ];

  static const List<double> coins = [
    10,
    5,
    2,
    1,
  ];

  static const List<double> all = [
    2000,
    500,
    200,
    100,
    50,
    20,
    10,
    5,
    2,
    1,
  ];

  // Get denomination label
  static String getLabel(double denomination) {
    if (denomination >= 10) {
      return '₹${denomination.toInt()} Note';
    } else {
      return '₹${denomination.toInt()} Coin';
    }
  }

  // Get short label
  static String getShortLabel(double denomination) {
    return '₹${denomination.toInt()}';
  }

  // Create empty denomination map
  static Map<String, int> createEmptyMap() {
    return Map.fromIterable(
      all,
      key: (denomination) => denomination.toString(),
      value: (_) => 0,
    );
  }

  // Calculate total from denomination map
  static double calculateTotal(Map<String, int> denominations) {
    double total = 0;
    denominations.forEach((denomination, count) {
      final value = double.tryParse(denomination) ?? 0;
      total += value * count;
    });
    return total;
  }

  // Format denomination map for display
  static String formatDenominations(Map<String, int> denominations) {
    final nonZero = denominations.entries
        .where((entry) => entry.value > 0)
        .map((entry) {
          final denom = double.tryParse(entry.key) ?? 0;
          return '${getShortLabel(denom)} x ${entry.value}';
        })
        .join(', ');
    return nonZero.isEmpty ? 'No denominations' : nonZero;
  }
}

/// Categories for cash transactions
class CashTransactionCategory {
  static const String expense = 'expense';
  static const String pettyCash = 'petty_cash';
  static const String bankDeposit = 'bank_deposit';
  static const String openingBalance = 'opening_balance';
  static const String other = 'other';

  static const List<String> all = [
    expense,
    pettyCash,
    bankDeposit,
    openingBalance,
    other,
  ];

  static String getLabel(String category) {
    switch (category) {
      case expense:
        return 'Expense';
      case pettyCash:
        return 'Petty Cash';
      case bankDeposit:
        return 'Bank Deposit';
      case openingBalance:
        return 'Opening Balance';
      case other:
        return 'Other';
      default:
        return category;
    }
  }
}