import 'package:billberrylite/data/models/restaurant/db/eodmodel_317.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';

/// Aggregates retail sales into one [PaymentSummary] per payment method.
///
/// The retail counterpart of `util/restaurant/payment_mode_summary.dart`, and
/// for the same reason: EOD and any payment-mode report must read identical
/// numbers, which they can't if each re-implements the bucketing. Retail had
/// two separate implementations that disagreed — one decomposed split bills,
/// the other dropped every split into an opaque `'split'` bucket so you could
/// not see how much of a split bill was cash.
///
/// Nets nothing by itself: it summarises exactly the list it is handed. Pass
/// forward sales only for a gross view, or include returns (whose header
/// amounts are stored negative) to net refunds out.
class RetailPaymentModeSummary {
  RetailPaymentModeSummary._();

  /// One [PaymentSummary] per method, sorted by amount descending.
  static List<PaymentSummary> summarize(List<SaleModel> sales) {
    final paymentTotals = <String, double>{};
    final paymentCounts = <String, int>{};
    double grandTotal = 0.0;

    for (final sale in sales) {
      // Keyed off the JSON, not `isSplitPayment` — that flag is null on older
      // rows, and the stored legs are the source of truth either way.
      final hasLegs =
          sale.paymentListJson != null && sale.paymentListJson!.isNotEmpty;

      if (hasLegs) {
        for (final leg in sale.paymentList) {
          final method = normalizeMethod(leg['method'] as String?);
          // `as double` used to be a live crash: jsonDecode returns an int for
          // a whole-rupee leg, and an int is not a double.
          final amount = (leg['amount'] as num?)?.toDouble() ?? 0.0;

          paymentTotals[method] = (paymentTotals[method] ?? 0.0) + amount;
          paymentCounts[method] = (paymentCounts[method] ?? 0) + 1;
          grandTotal += amount;
        }
      } else {
        final method = normalizeMethod(sale.paymentType);
        paymentTotals[method] = (paymentTotals[method] ?? 0.0) + sale.totalAmount;
        paymentCounts[method] = (paymentCounts[method] ?? 0) + 1;
        grandTotal += sale.totalAmount;
      }
    }

    return paymentTotals.entries.map((entry) {
      final totalAmount = entry.value;
      return PaymentSummary(
        paymentType: entry.key,
        totalAmount: totalAmount,
        transactionCount: paymentCounts[entry.key] ?? 0,
        // `!= 0`: a period whose refunds exceed its takings has a negative
        // grand total, and `> 0` would report every share as a flat 0%.
        percentage: grandTotal != 0 ? (totalAmount / grandTotal) * 100 : 0.0,
      );
    }).toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  }

  /// Canonical label so case and spacing variants ('Cash', 'cash', 'CASH ')
  /// collapse into one bucket instead of showing up as separate rows.
  static String normalizeMethod(String? raw) {
    final m = (raw ?? '').trim().toLowerCase();
    if (m.isEmpty) return 'Unknown';
    switch (m) {
      case 'cash':
        return 'Cash';
      case 'upi':
        return 'UPI';
      case 'card':
        return 'Card';
      case 'wallet':
        return 'Wallet';
      case 'credit':
        return 'Credit';
      case 'split':
      case 'split payment':
        return 'Split Payment';
      default:
        return m[0].toUpperCase() + m.substring(1);
    }
  }

  /// Per-sale display label: the legs of a split bill joined ("Cash + UPI"), or
  /// the single normalised method.
  static String methodLabel(SaleModel sale) {
    if (sale.paymentListJson != null && sale.paymentListJson!.isNotEmpty) {
      final legs = sale.paymentList
          .map((e) => normalizeMethod(e['method'] as String?))
          .toSet()
          .toList();
      if (legs.isNotEmpty) return legs.join(' + ');
    }
    return normalizeMethod(sale.paymentType);
  }
}
