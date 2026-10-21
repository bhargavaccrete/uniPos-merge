import 'package:hive/hive.dart';
import '../../models/retail/hive_model/credit_payment_model_218.dart';

/// Repository layer for Credit Payment data access
/// Handles all Hive database operations for credit payments
class CreditPaymentRepository {
  late Box<CreditPaymentModel> _paymentBox;

  CreditPaymentRepository() {
    _paymentBox = Hive.box<CreditPaymentModel>('credit_payments');
  }

  /// Initialize the repository (ensure box is open)
  void init() {
    // Box is already opened during app startup in HiveInit
    _paymentBox = Hive.box<CreditPaymentModel>('credit_payments');
  }

  /// Newest first, then the payment id.
  ///
  /// A date is not a total order — two collections recorded in the same second
  /// reordered between loads, because `List.sort` is not stable.
  static int _newestFirst(CreditPaymentModel a, CreditPaymentModel b) {
    final byDate = b.date.compareTo(a.date);
    return byDate != 0 ? byDate : a.paymentId.compareTo(b.paymentId);
  }

  /// Get all credit payments
  Future<List<CreditPaymentModel>> getAllPayments() async {
    return _paymentBox.values.toList()..sort(_newestFirst);
  }

  /// Add a new credit payment
  Future<void> addPayment(CreditPaymentModel payment) async {
    await _paymentBox.put(payment.paymentId, payment);
  }

  /// Get payment by ID
  Future<CreditPaymentModel?> getPaymentById(String paymentId) async {
    return _paymentBox.get(paymentId);
  }

  /// Get payments by customer ID
  Future<List<CreditPaymentModel>> getPaymentsByCustomerId(String customerId) async {
    return _paymentBox.values
        .where((payment) => payment.customerId == customerId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Get payments by sale ID
  Future<List<CreditPaymentModel>> getPaymentsBySaleId(String saleId) async {
    return _paymentBox.values
        .where((payment) => payment.saleId == saleId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Payments in a window: inclusive start, **exclusive** end.
  ///
  /// Matches `ReportService._inWindow` and `SaleRepository.getSalesByDateRange`.
  /// The previous `±1 day` padding widened every range by a day at each end, so
  /// a 1–7 Aug collections report also counted 31 Jul and 8 Aug.
  ///
  /// An unparseable date is skipped rather than thrown.
  Future<List<CreditPaymentModel>> getPaymentsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return _paymentBox.values.where((payment) {
      final paymentDate = DateTime.tryParse(payment.date);
      if (paymentDate == null) return false;
      return !paymentDate.isBefore(startDate) && paymentDate.isBefore(endDate);
    }).toList()
      ..sort(_newestFirst);
  }

  /// Get today's payments
  Future<List<CreditPaymentModel>> getTodayPayments() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    // Start of tomorrow — the range end is exclusive.
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getPaymentsByDateRange(startOfDay, endOfDay);
  }

  /// Get total amount collected today
  Future<double> getTodayTotalCollection() async {
    final todayPayments = await getTodayPayments();
    return todayPayments
        .where((p) => !(p.isWriteOff ?? false))
        .fold<double>(0.0, (sum, payment) => sum + payment.amount);
  }

  /// Get today's collection by payment mode
  Future<Map<String, double>> getTodayCollectionByMode() async {
    final todayPayments = await getTodayPayments();
    final result = <String, double>{
      'cash': 0.0,
      'card': 0.0,
      'upi': 0.0,
    };

    for (var payment in todayPayments) {
      if (!(payment.isWriteOff ?? false)) {
        final mode = payment.paymentMode.toLowerCase();
        if (result.containsKey(mode)) {
          result[mode] = result[mode]! + payment.amount;
        }
      }
    }

    return result;
  }

  /// Bucket key for a collection whose mode is none of cash / card / upi.
  ///
  /// Without it an unknown mode was dropped from the per-mode buckets while
  /// still being added to `total`, so the figures on screen did not add up to
  /// the total printed beside them.
  static const String otherMode = 'other';

  /// The mode buckets, plus `total`. Every displayed bucket is included, so
  /// `cash + card + upi + other == total`, always.
  ///
  /// [payments] is filtered by [CreditPaymentModel.isCollection], which excludes
  /// write-offs AND return adjustments. A return offsetting an unpaid invoice
  /// writes a payment row (`ReturnService`, mode `return_adjustment`) purely so
  /// the customer ledger shows it — no money changed hands, so counting it as
  /// collected overstates the day's takings.
  ///
  /// ONE implementation for the whole report: the all-time summary used to be
  /// computed inline on the screen with the pre-fix rule, so clearing the date
  /// filter silently reverted both behaviours.
  static Map<String, double> bucketCollections(
    Iterable<CreditPaymentModel> payments,
  ) {
    final result = <String, double>{
      'cash': 0.0,
      'card': 0.0,
      'upi': 0.0,
      otherMode: 0.0,
      'total': 0.0,
    };

    for (final payment in payments) {
      if (!payment.isCollection) continue;
      final mode = payment.paymentMode.toLowerCase().trim();
      // `total` is a key of this map, not a mode — a payment recorded under
      // that literal must not clobber the sum.
      final key =
          (mode != 'total' && result.containsKey(mode)) ? mode : otherMode;
      result[key] = result[key]! + payment.amount;
      result['total'] = result['total']! + payment.amount;
    }

    return result;
  }

  /// Get collection by date range grouped by mode
  Future<Map<String, double>> getCollectionByModeInRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return bucketCollections(await getPaymentsByDateRange(startDate, endDate));
  }


  /// Get total amount collected for a customer
  Future<double> getTotalCollectedFromCustomer(String customerId) async {
    final payments = await getPaymentsByCustomerId(customerId);
    return payments
        .where((p) => !(p.isWriteOff ?? false))
        .fold<double>(0.0, (sum, payment) => sum + payment.amount);
  }

  /// Get total write-offs
  Future<double> getTotalWriteOffs() async {
    final allPayments = await getAllPayments();
    return allPayments
        .where((p) => p.isWriteOff ?? false)
        .fold<double>(0.0, (sum, payment) => sum + payment.amount);
  }

  /// Delete a payment
  Future<void> deletePayment(String paymentId) async {
    await _paymentBox.delete(paymentId);
  }

  /// Clear all payments
  Future<void> clearAll() async {
    await _paymentBox.clear();
  }

  /// Get payment count
  int getPaymentCount() {
    return _paymentBox.length;
  }

  /// Get payments summary for a customer (for ledger)
  Future<Map<String, dynamic>> getCustomerPaymentsSummary(String customerId) async {
    final payments = await getPaymentsByCustomerId(customerId);

    double totalPaid = 0.0;
    double totalWriteOff = 0.0;
    int paymentCount = 0;

    for (var payment in payments) {
      if (payment.isWriteOff ?? false) {
        totalWriteOff += payment.amount;
      } else {
        totalPaid += payment.amount;
        paymentCount++;
      }
    }

    return {
      'totalPaid': totalPaid,
      'totalWriteOff': totalWriteOff,
      'paymentCount': paymentCount,
      'payments': payments,
    };
  }
}