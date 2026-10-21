/// The one definition of how much cash should be in a retail drawer at close.
///
/// There used to be two, and they disagreed: the EOD screen computed
/// `opening + cashSales - cashExpenses - cashRefunds` while the service stored
/// `opening + cashSales + cashIn - cashOut - cashExpenses`. The screen ignored
/// manual drawer movements, the service ignored refunds — so the variance a
/// cashier signed off on was not the variance kept in the archived close.
class RetailCashExpectation {
  const RetailCashExpectation._();

  /// Cash the drawer should hold.
  ///
  /// - [openingBalance] — float the day started with.
  /// - [cashSales] — the cash leg of the day's sales.
  /// - [cashIn] / [cashOut] — manual drawer movements. **Credit collections
  ///   arrive here**, not as a term of their own: settling credit in cash
  ///   writes a Cash In movement (`CreditStore.settleCustomerDue`). Adding a
  ///   separate collections term on top would count that money twice.
  /// - [cashExpenses] — money paid out of the drawer.
  /// - [cashRefunds] — cash handed back to customers on returns.
  static double expected({
    required double openingBalance,
    required double cashSales,
    required double cashIn,
    required double cashOut,
    required double cashExpenses,
    required double cashRefunds,
  }) =>
      openingBalance +
      cashSales +
      cashIn -
      cashOut -
      cashExpenses -
      cashRefunds;
}
