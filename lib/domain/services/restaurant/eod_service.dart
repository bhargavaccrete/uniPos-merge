
import 'package:billberrylite/core/config/tax_label_rule.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/eodmodel_317.dart';
import '../../../data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/domain/services/restaurant/day_management_service.dart';
import '../../../core/constants/hive_box_names.dart';
import '../../../data/models/restaurant/db/cash_movement_model.dart';
import 'package:hive/hive.dart';
import 'package:billberrylite/util/restaurant/order_status_filter.dart';
import 'package:billberrylite/util/restaurant/payment_mode_summary.dart';
import 'package:billberrylite/util/retail/payment_mode_summary.dart';
import 'package:billberrylite/util/retail/retail_cash_expectation.dart';
import 'package:billberrylite/domain/services/retail/eod_report_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';

/// Below this, a cash difference is float noise rather than a real shortage or
/// overage — half a paisa, under anything a drawer can be counted to.
///
/// Shared so the EOD History card judges a stored difference by exactly the
/// rule that decided its status.
const double kCashReconciliationTolerance = 0.005;

class EODService {
  static const _uuid = Uuid();

  /// Returns true if the order should be completely excluded from all EOD totals.
  /// VOID/VOIDED = never paid, CANCELLED = abandoned, FULLY_REFUNDED = all money returned.
  static bool _isExcluded(String status) =>
      OrderStatusFilter.isExcludedFromRevenue(status);

  static Future<EndOfDayReport> generateEODReport({
    required DateTime date,
    required double openingBalance,
    required double actualCash,
    String? remarks,
    String? sessionId,
  }) async {
    // If sessionId is not provided, try to get current active session
    final targetSessionId = sessionId ?? await DayManagementService.getCurrentSessionId();
    final dayStartTimestamp = await DayManagementService.getDayStartTimestamp();
    final startTime = dayStartTimestamp ?? DateTime(date.year, date.month, date.day);
    final endTime = DateTime.now();


    // Fetch all past orders
    await pastOrderStore.loadPastOrders();
    final pastOrders = pastOrderStore.pastOrders.toList();

    // Filter orders by sessionId
    final allDayOrders = pastOrders.where((order) {
      if (targetSessionId != null) {
        if (order.sessionId == targetSessionId) return true;
        // Legacy fallback: null sessionId orders attributed by calendar day, not session timestamps.
        // Using exact session timestamps caused old-data orders to be permanently dropped because
        // their orderAt predates the current session's startTime.
        if (order.sessionId == null) {
          if (order.orderAt == null) return false;
          final d = order.orderAt!;
          return d.year == date.year && d.month == date.month && d.day == date.day;
        }
        return false;
      }
      // Fallback to date range if no target session exists (for legacy data)
      return order.orderAt != null &&
          (order.orderAt!.isAfter(startTime) || order.orderAt!.isAtSameMomentAs(startTime)) &&
          (order.orderAt!.isBefore(endTime) || order.orderAt!.isAtSameMomentAs(endTime));
    }).toList();


    // Exclude voided, cancelled, and fully refunded orders from count-based stats
    final activeDayOrders = allDayOrders.where((order) {
      final status = order.orderStatus?.toUpperCase() ?? '';
      return !_isExcluded(status);
    }).toList();

    // Use activeDayOrders for count-based statistics (excludes fully refunded orders)
    final orderSummaries = _calculateOrderTypeSummaries(activeDayOrders);
    final categorySales = _calculateCategorySales(activeDayOrders);
    final paymentSummaries = PaymentModeSummary.summarize(activeDayOrders);
    final taxSummaries = _calculateTaxSummaries(activeDayOrders);

    // 1. Identify all orders refunded within this session's time range [startTime, endTime]
    final sessionRefundedOrders = pastOrders.where((order) {
      if (order.refundedAt == null) return false;
      final status = order.orderStatus?.toUpperCase() ?? '';
      if (status == 'CANCELLED') return false;
      return (order.refundedAt!.isAfter(startTime) || order.refundedAt!.isAtSameMomentAs(startTime)) &&
             (order.refundedAt!.isBefore(endTime) || order.refundedAt!.isAtSameMomentAs(endTime));
    }).toList();

    // 2. Identify external refunded orders (refunded in this session but created before this session)
    final externalRefundedOrders = sessionRefundedOrders.where((order) {
      if (targetSessionId != null) {
        return order.sessionId != targetSessionId;
      }
      return order.orderAt == null || (order.orderAt!.isBefore(startTime));
    }).toList();

    // 3. Compute EOD totalRefunds as sum of refundAmount for all orders refunded in this session's period
    final totalRefunds = sessionRefundedOrders.fold<double>(0.0, (sum, order) => sum + (order.refundAmount ?? 0.0));

    final totalSalesBase = allDayOrders.fold<double>(0.0, (sum, order) {
      final status = order.orderStatus?.toUpperCase() ?? '';
      if (_isExcluded(status)) return sum;
      return sum + (order.totalPrice - (order.refundAmount ?? 0.0));
    });
    // Deduct external refunds from today's net sales
    final totalSales = totalSalesBase - externalRefundedOrders.fold<double>(0.0, (sum, order) => sum + (order.refundAmount ?? 0.0));

    final totalDiscount = allDayOrders.fold<double>(0.0, (sum, order) {
      final status = order.orderStatus?.toUpperCase() ?? '';
      if (_isExcluded(status)) return sum;
      return sum + (order.Discount ?? 0.0);
    });

    final totalTaxBase = allDayOrders.fold<double>(0.0, (sum, order) {
      final status = order.orderStatus?.toUpperCase() ?? '';
      if (_isExcluded(status)) return sum;
      final refundRatio = order.totalPrice > 0
          ? ((order.totalPrice - (order.refundAmount ?? 0.0)) / order.totalPrice)
          : 1.0;
      return sum + (order.gstAmount ?? 0.0) * refundRatio;
    });
    // Deduct external refund tax portions from today's net tax liability
    final double externalRefundedTax = externalRefundedOrders.fold<double>(0.0, (sum, order) {
      final refund = order.refundAmount ?? 0.0;
      if (refund > 0 && order.totalPrice > 0) {
        return sum + (refund * ((order.gstAmount ?? 0.0) / order.totalPrice));
      }
      return sum;
    });
    final totalTax = totalTaxBase - externalRefundedTax;

    // Subtract external refunds from paymentSummaries
    for (final order in externalRefundedOrders) {
      final refund = order.refundAmount ?? 0.0;
      if (refund <= 0) continue;

      if (order.isSplitPayment == true && order.paymentListJson != null && order.paymentListJson!.isNotEmpty) {
        final ratio = order.totalPrice > 0 ? refund / order.totalPrice : 0.0;
        for (final p in order.paymentList) {
          final method = (p['method'] as String? ?? '').toLowerCase().trim();
          final amt = ((p['amount'] as num?)?.toDouble() ?? 0.0) * ratio;
          _subtractFromSummary(paymentSummaries, method, amt);
        }
      } else {
        final method = (order.paymentmode ?? '').toLowerCase().trim();
        _subtractFromSummary(paymentSummaries, method, refund);
      }
    }

    // Recompute percentages for paymentSummaries
    final newGrandTotal = paymentSummaries.fold<double>(0.0, (sum, p) => sum + p.totalAmount);
    for (int i = 0; i < paymentSummaries.length; i++) {
      final p = paymentSummaries[i];
      paymentSummaries[i] = PaymentSummary(
        paymentType: p.paymentType,
        totalAmount: p.totalAmount,
        transactionCount: p.transactionCount,
        percentage: newGrandTotal > 0 ? (p.totalAmount / newGrandTotal) * 100 : 0.0,
      );
    }

    final totalOrderCount = activeDayOrders.length; // Count only active orders

    // Calculate expenses for the day using expense store
    await expenseStore.loadExpenses();
    final allExpenses = expenseStore.expenses;

    final dayExpenses = allExpenses.where((expense) {
      if (targetSessionId != null) {
        if (expense.sessionId == targetSessionId) return true;
        // Fallback for expenses that might have failed to save sessionId (e.g., hot reload issues)
        if (expense.sessionId == null) {
          return (expense.dateandTime.isAfter(startTime) || expense.dateandTime.isAtSameMomentAs(startTime)) &&
                 (expense.dateandTime.isBefore(endTime) || expense.dateandTime.isAtSameMomentAs(endTime));
        }
        return false;
      }
      // Fallback to date range for legacy
      return (expense.dateandTime.isAfter(startTime) || expense.dateandTime.isAtSameMomentAs(startTime)) &&
          (expense.dateandTime.isBefore(endTime) || expense.dateandTime.isAtSameMomentAs(endTime));
    }).toList();


    // Calculate total expenses (all payment types) for P&L reporting
    final totalExpenses = dayExpenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);

    // Calculate ONLY cash expenses for cash drawer reconciliation
    final cashExpenses = dayExpenses.where((expense) {
      final paymentType = expense.paymentType?.toLowerCase().trim() ?? '';
      return paymentType == 'cash';
    }).fold<double>(0.0, (sum, expense) => sum + expense.amount);


    // Load manual Cash In / Cash Out movements recorded during the day
    double totalCashIn = 0.0;
    double totalCashOut = 0.0;
    if (Hive.isBoxOpen(HiveBoxNames.restaurantCashMovements)) {
      final cashMovBox = Hive.box<CashMovementModel>(HiveBoxNames.restaurantCashMovements);
      final todayMoves = cashMovBox.values.where((m) {
        if (targetSessionId != null) {
          if (m.sessionId == targetSessionId) return true;
          // Fallback for legacy compatibility
          final isOpeningFromSession = m.type == 'opening' && (m.note?.contains(targetSessionId) ?? false);
          if (m.sessionId == null) {
             return m.timestamp.isAfter(startTime) && m.timestamp.isBefore(endTime) || isOpeningFromSession;
          }
          return false;
        }
        return m.timestamp.isAfter(startTime) && m.timestamp.isBefore(endTime);
      }).toList();
      totalCashIn  = todayMoves.where((m) => m.type == 'in' ).fold(0.0, (s, m) => s + m.amount);
      totalCashOut = todayMoves.where((m) => m.type == 'out').fold(0.0, (s, m) => s + m.amount);
    }

    final expectedCash = paymentSummaries
        .where((payment) => payment.paymentType.toLowerCase().trim() == 'cash')
        .fold<double>(0.0, (sum, payment) => sum + payment.totalAmount);

    // Full formula: Opening + Cash Sales + Cash In − Cash Out − Cash Expenses
    final closingBalance = openingBalance + expectedCash + totalCashIn - totalCashOut - cashExpenses;
    final cashDifference = actualCash - closingBalance;

    String reconciliationStatus;
    if (cashDifference == 0) {
      reconciliationStatus = 'Balanced';
    } else if (cashDifference > 0) {
      reconciliationStatus = 'Overage';
    } else {
      reconciliationStatus = 'Shortage';
    }

    final cashReconciliation = CashReconciliation(
      systemExpectedCash: expectedCash,
      actualCash: actualCash,
      difference: cashDifference,
      reconciliationStatus: reconciliationStatus,
      remarks: remarks,
    );

    // Cancelled/voided orders (excluded from sales) — count + value for the receipt.
    final cancelledOrders = allDayOrders
        .where((o) => _isExcluded(o.orderStatus?.toUpperCase() ?? ''))
        .toList();
    final cancelledOrderCount = cancelledOrders.length;
    final cancelledOrderAmount =
        cancelledOrders.fold<double>(0.0, (s, o) => s + o.totalPrice);

    // Round-off: per-order rounding delta = final total − (taxable + tax − discount + service).
    // subTotal is stored as the pre-tax taxable base in both tax modes, so this is mode-independent.
    double roundOffSum = 0.0;
    for (final o in activeDayOrders) {
      if (o.subTotal == null) continue;
      final raw = o.subTotal! +
          (o.gstAmount ?? 0) -
          (o.Discount ?? 0) +
          (o.serviceCharge ?? 0);
      final delta = o.totalPrice - raw;
      if (delta.abs() >= 0.005) roundOffSum += double.parse(delta.toStringAsFixed(2));
    }

    final reportId = _uuid.v4();

    return EndOfDayReport(
      reportId: reportId,
      date: date,
      openingBalance: openingBalance,
      orderSummaries: orderSummaries,
      totalDiscount: totalDiscount,
      totalTax: totalTax,
      categorySales: categorySales,
      paymentSummaries: paymentSummaries,
      cashReconciliation: cashReconciliation,
      totalSales: totalSales,
      closingBalance: closingBalance,
      taxSummaries: taxSummaries,
      totalOrderCount: totalOrderCount,
      totalRefunds: totalRefunds,
      totalExpenses: totalExpenses,
      cashExpenses: cashExpenses,
      roundOff: double.parse(roundOffSum.toStringAsFixed(2)),
      cancelledOrderCount: cancelledOrderCount,
      cancelledOrderAmount: cancelledOrderAmount,
      sessionId: targetSessionId,
    );
  }

  static List<OrderTypeSummary> _calculateOrderTypeSummaries(List<PastOrderModel> orders) {
    final Map<String, List<PastOrderModel>> groupedOrders = {};

    for (final order in orders) {
      final orderType = order.orderType ?? 'Unknown';
      groupedOrders.putIfAbsent(orderType, () => []).add(order);
    }

    return groupedOrders.entries.map((entry) {
      final orderType = entry.key;
      final typeOrders = entry.value;
      final totalAmount = typeOrders.fold<double>(0.0, (sum, order) => sum + (order.totalPrice - (order.refundAmount ?? 0.0)));
      final orderCount = typeOrders.length;
      final averageOrderValue = orderCount > 0 ? totalAmount / orderCount : 0.0;

      return OrderTypeSummary(
        orderType: orderType,
        orderCount: orderCount,
        totalAmount: totalAmount,
        averageOrderValue: averageOrderValue,
      );
    }).toList();
  }

  static List<CategorySales> _calculateCategorySales(List<PastOrderModel> orders) {
    final Map<String, double> categoryTotals = {};
    final Map<String, int> categoryItemCounts = {};

    double grandTotal = 0.0;

    for (final order in orders) {
      final status = order.orderStatus?.toUpperCase() ?? '';
      if (_isExcluded(status)) continue;

      final netOrderAmount = order.totalPrice - (order.refundAmount ?? 0.0);
      grandTotal += netOrderAmount;

      // For partially refunded orders, calculate proportional category amounts
      final refundRatio = order.totalPrice > 0 ? (netOrderAmount / order.totalPrice) : 1.0;

      for (final item in order.items) {
        final category = item.categoryName ?? 'Uncategorized';
        // Apply proportional reduction for refunds
        final itemTotal = item.totalPrice * refundRatio;
        // Only count non-refunded quantities
        final effectiveQuantity = (item.quantity - (item.refundedQuantity ?? 0));

        categoryTotals[category] = (categoryTotals[category] ?? 0.0) + itemTotal;
        categoryItemCounts[category] = (categoryItemCounts[category] ?? 0) + effectiveQuantity;
      }
    }

    return categoryTotals.entries.map((entry) {
      final categoryName = entry.key;
      final totalAmount = entry.value;
      final itemsSold = categoryItemCounts[categoryName] ?? 0;
      final percentage = grandTotal > 0 ? (totalAmount / grandTotal) * 100 : 0.0;

      return CategorySales(
        categoryName: categoryName,
        totalAmount: totalAmount,
        itemsSold: itemsSold,
        percentage: percentage,
      );
    }).toList()..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  }

  static List<TaxSummary> _calculateTaxSummaries(List<PastOrderModel> orders) {
    final Map<String, TaxInfo> taxData = {};

    for (final order in orders) {
      final status = order.orderStatus?.toUpperCase() ?? '';
      if (_isExcluded(status)) continue;

      if (order.gstRate != null && order.gstAmount != null && order.gstRate! > 0) {
        final taxKey = 'GST ${(order.gstRate! * 100).toStringAsFixed(1)}%';

        // Calculate proportional tax amount for partially refunded orders
        final orderRefundRatio = order.totalPrice > 0
            ? ((order.totalPrice - (order.refundAmount ?? 0.0)) / order.totalPrice)
            : 1.0;

        final effectiveTaxAmount = order.gstAmount! * orderRefundRatio;
        final taxableAmount = (order.subTotal ?? (order.totalPrice - (order.gstAmount ?? 0.0))) * orderRefundRatio;

        if (taxData.containsKey(taxKey)) {
          taxData[taxKey]!.taxAmount += effectiveTaxAmount;
          taxData[taxKey]!.taxableAmount += taxableAmount;
        } else {
          taxData[taxKey] = TaxInfo(
            taxName: taxKey,
            taxRate: order.gstRate!,
            taxAmount: effectiveTaxAmount,
            taxableAmount: taxableAmount,
          );
        }
      }
    }

    return taxData.values.map((taxInfo) {
      return TaxSummary(
        taxName: taxInfo.taxName,
        taxRate: taxInfo.taxRate,
        taxAmount: taxInfo.taxAmount,
        taxableAmount: taxInfo.taxableAmount,
      );
    }).toList();
  }

  static Future<void> saveEODReport(EndOfDayReport report) async {
    // De-duplicate by SESSION, not date: a retry of the same close reuses the
    // same session, so replace only that session's report. Genuinely different
    // sessions on the same date are each kept.
    //
    // Both verticals stamp a sessionId now. The date fallback survives only for
    // records written before retail did — without a session there is no way to
    // tell a retry from a second close, and replacing is the safer of the two.
    final existing = report.sessionId != null
        ? await eodStore.getEODBySession(report.sessionId!)
        : await eodStore.getEODByDate(report.date);
    if (existing != null) {
      await eodStore.deleteEODReport(existing.reportId);
    }
    await eodStore.addEODReport(report);
  }

  static Future<List<EndOfDayReport>> getAllEODReports() async {
    await eodStore.loadEODReports();
    return eodStore.eodReports.toList();
  }

  static Future<EndOfDayReport?> getTodaysEOD() async {
    final today = DateTime.now();
    return await eodStore.getEODByDate(today);
  }

  static Future<double> getLastClosingBalance() async {
    final latestEOD = await eodStore.getLatestEOD();
    return latestEOD?.closingBalance ?? 0.0;
  }

  // ==================== RETAIL EOD GENERATION ====================

  static Future<EndOfDayReport> generateRetailEODReport({
    required DateTime date,
    required double openingBalance,
    required double actualCash,
    String? remarks,
    /// Safe drop — cash taken out of the drawer at close. Stored on the record
    /// so the settlement slip can be reprinted with the real figure.
    double cashWithdrawn = 0,
    /// The session being closed. Defaults to the open one, exactly as
    /// [generateEODReport] resolves it; passed explicitly only by tests.
    String? sessionId,
  }) async {
    // Retail DOES have sessions — it shares DayManagementService, and the EOD
    // screen already gates itself on `getCurrentSession()`. This was simply
    // never stamped, so every retail report carried a null sessionId and
    // `saveEODReport` fell back to de-duplicating by DATE: closing a second
    // session on the same calendar day DELETED the first day's report.
    //
    // Resolved before the session is closed — `_completeEndOfDay` generates and
    // saves the report before calling `markDayEnded`, which clears the pointer.
    final targetSessionId =
        sessionId ?? await DayManagementService.getCurrentSessionId();
    // Get the day start timestamp - CRITICAL for filtering sales after "Start Day" was clicked
    final dayStartTimestamp = await DayManagementService.getDayStartTimestamp();

    // Determine the start time for filtering:
    // - If day was started with a timestamp, use that exact time
    // - Otherwise, fall back to start of day (00:00:00)
    final startTime = dayStartTimestamp ?? DateTime(date.year, date.month, date.day);
    // Use current time as end — handles midnight crossing (EOD run after midnight for yesterday's session)
    final endTime = DateTime.now();

    // TRADING DAY: the report is dated when the session OPENED, not when the
    // close was run — the same rule restaurant applies (endday.dart sets
    // `selectedDate = currentSession.startTime`). A shop that opens 11 PM and
    // closes at 2 AM belongs entirely to the day it opened, and its after-
    // midnight sales are already inside [startTime]..[endTime]. Dating the
    // record `DateTime.now()` filed those closes under the NEXT day, so the
    // report's own date disagreed with the sales window it was built from.
    //
    // Falls back to the caller's [date] when there is no session.
    final reportDate = dayStartTimestamp ?? date;


    // Get all sales for the day using SaleStore
    final allSales = await saleStore.getSalesByDateRange(startTime, endTime);


    // Filter out returns for count-based stats, but include them in financial calculations
    final activeSales = allSales.where((sale) => sale.isReturn != true).toList();

    // Calculate payment summaries (Cash, Card, UPI, Credit, Split).
    //
    // Forward sales PLUS exchange returns. An exchange return carries signed
    // money legs describing what actually went back to the customer, so
    // including it makes the buckets show the real difference rather than the
    // whole value of the goods swapped. Its exchange-credit leg is suppressed
    // by the summariser. Plain returns stay excluded, keeping the long-standing
    // gross-of-refunds convention and the separate `cashRefunds` term that
    // already accounts for them.
    final exchangeReturns = allSales
        .where((s) => s.isReturn == true && s.exchangeGroupId != null)
        .toList();
    final paymentSummaries = _calculateRetailPaymentSummaries(
      [...activeSales, ...exchangeReturns],
    );

    // Calculate totals.
    //
    // A return header is ALREADY stored negated (`return_service.dart`), so it
    // nets by simply being summed. Negating it here made `-(-1000)` positive
    // and ADDED every refund to the day's sales — a double swing on the figure
    // the shop closes its day against. The invariant is documented in
    // `util/retail/sale_revenue_filter.dart`, which `ReportService` follows;
    // this is the line that used to disagree with it.
    final totalSales =
        allSales.fold<double>(0.0, (sum, sale) => sum + sale.totalAmount);

    final totalDiscount = allSales.fold<double>(0.0, (sum, sale) => sum + sale.discountAmount);
    final totalTax = allSales.fold<double>(0.0, (sum, sale) => sum + (sale.totalGstAmount ?? sale.taxAmount));

    // Calculate tax summaries (CGST/SGST breakdown)
    final taxSummaries = _calculateRetailTaxSummaries(allSales);

    // Calculate total returns.
    //
    // POSITIVE, matching the field's contract on the restaurant side (`:96`)
    // and what every consumer expects — `eod_report_detail_screen` renders the
    // Refunds row behind `if (report.totalRefunds > 0)`, so the raw negative
    // sum meant the row never appeared at all.
    final totalRefunds = allSales
        .where((sale) => sale.isReturn == true)
        .fold<double>(0.0, (sum, sale) => sum + sale.totalAmount.abs());

    final totalSaleCount = activeSales.length;

    // Calculate expenses for the day (reuse restaurant expense system)
    // Use the same start time as sales filtering for consistency
    await expenseStore.loadExpenses();
    final allExpenses = expenseStore.expenses;

    final dayExpenses = allExpenses.where((expense) {
      return (expense.dateandTime.isAfter(startTime) || expense.dateandTime.isAtSameMomentAs(startTime)) &&
          (expense.dateandTime.isBefore(endTime) || expense.dateandTime.isAtSameMomentAs(endTime));
    }).toList();


    final totalExpenses = dayExpenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
    final cashExpenses = dayExpenses
        .where((expense) => expense.paymentType?.toLowerCase().trim() == 'cash')
        .fold<double>(0.0, (sum, expense) => sum + expense.amount);

    // Calculate expected cash
    final expectedCash = paymentSummaries
        .where((payment) => payment.paymentType.toLowerCase().trim() == 'cash')
        .fold<double>(0.0, (sum, payment) => sum + payment.totalAmount);

    // Load manual Cash In / Cash Out movements recorded during the retail day
    double totalCashIn = 0.0;
    double totalCashOut = 0.0;
    if (Hive.isBoxOpen(HiveBoxNames.restaurantCashMovements)) {
      final cashMovBox = Hive.box<CashMovementModel>(HiveBoxNames.restaurantCashMovements);
      final todayMoves = cashMovBox.values.where(
        (m) => m.timestamp.isAfter(startTime) && m.timestamp.isBefore(endTime),
      ).toList();
      totalCashIn  = todayMoves.where((m) => m.type == 'in' ).fold(0.0, (s, m) => s + m.amount);
      totalCashOut = todayMoves.where((m) => m.type == 'out').fold(0.0, (s, m) => s + m.amount);
    }

    // Cash handed back on returns leaves the drawer, so it must come off the
    // expectation. This term was missing here while the EOD screen subtracted
    // it — so the variance the cashier signed off on never matched the variance
    // stored in the archived close.
    //
    // Retail only: restaurant nets refunds per-order via `refundAmount`, which
    // is already inside its totals, so adding a term there would double-count.
    final cashRefunds = EODReportService.cashRefundsIn(allSales);

    // One definition, shared with the EOD screen — see RetailCashExpectation.
    final closingBalance = RetailCashExpectation.expected(
      openingBalance: openingBalance,
      cashSales: expectedCash,
      cashIn: totalCashIn,
      cashOut: totalCashOut,
      cashExpenses: cashExpenses,
      cashRefunds: cashRefunds,
    );
    final cashDifference = actualCash - closingBalance;

    String reconciliationStatus;
    // Tolerance, not `== 0`. `closingBalance` accumulates opening + cash sales
    // + cash in - cash out - expenses - refunds, so a perfectly counted drawer
    // routinely lands a residual like 1e-13 away from it. The exact comparison
    // branded such a day 'Shortage', and the status is STORED — so it stayed
    // wrong forever. Half a paisa is below anything a drawer can be counted to.
    //
    // Only the STATUS decision changes; `difference` keeps the real number.
    if (cashDifference.abs() < kCashReconciliationTolerance) {
      reconciliationStatus = 'Balanced';
    } else if (cashDifference > 0) {
      reconciliationStatus = 'Overage';
    } else {
      reconciliationStatus = 'Shortage';
    }

    final cashReconciliation = CashReconciliation(
      // `closingBalance`, not `expectedCash`. The latter is CASH SALES ONLY,
      // while `difference` is measured against the full expectation — so every
      // screen and export showing both made `actual − expected` disagree with
      // `difference` whenever there was a float, an expense, a refund or a
      // manual movement. The EOD screen already reads `closingBalance`.
      systemExpectedCash: closingBalance,
      actualCash: actualCash,
      difference: cashDifference,
      reconciliationStatus: reconciliationStatus,
      remarks: remarks,
    );

    // ==================== CREDIT COLLECTIONS ====================
    // Repayments against credit sold on earlier days. Not revenue — adding them
    // to `totalSales` would book the same goods twice — but the cash leg is
    // real money that has to be in the drawer.
    final collections = await creditPaymentRepository.getCollectionByModeInRange(
        startTime, endTime);

    // ==================== PROFIT ====================
    // Through ReportService rather than recomputed here, so the day close and
    // the Profit report can never disagree. It nets returns, reads the cost
    // frozen on each sale line, and takes GST out of revenue — the engine this
    // replaces did none of those and force-unwrapped `costPrice!`.
    final profit = await ReportService()
        .getProfitReport(startDate: startTime, endDate: endTime);
    final totalCost = (profit['totalCost'] as num).toDouble();
    final grossProfit = (profit['grossProfit'] as num).toDouble();

    // ==================== CUSTOMER OUTSTANDING ====================
    // A position at close, not a movement during the day.
    final customersWithCredit = await customerStore.getCustomersWithCredit();
    final totalOutstanding = await saleStore.getTotalDueAmount();

    final reportId = _uuid.v4();

    return EndOfDayReport(
      reportId: reportId,
      date: reportDate,
      openingBalance: openingBalance,
      orderSummaries: [], // Empty for retail - not applicable
      totalDiscount: totalDiscount,
      totalTax: totalTax,
      categorySales: [], // Empty for retail - can be added later if needed
      paymentSummaries: paymentSummaries,
      cashReconciliation: cashReconciliation,
      totalSales: totalSales,
      closingBalance: closingBalance,
      taxSummaries: taxSummaries,
      totalOrderCount: totalSaleCount,
      totalRefunds: totalRefunds,
      totalExpenses: totalExpenses,
      cashExpenses: cashExpenses,
      mode: 'retail', // Mark as retail EOD
      cashCollections: collections['cash'] ?? 0.0,
      cardCollections: collections['card'] ?? 0.0,
      upiCollections: collections['upi'] ?? 0.0,
      totalCost: totalCost,
      grossProfit: grossProfit,
      customersWithDue: customersWithCredit.length,
      totalOutstanding: totalOutstanding,
      cashWithdrawn: cashWithdrawn,
      sessionId: targetSessionId,
    );
  }

  /// Delegates to the shared retail summariser so EOD and any payment-mode
  /// report can never disagree — the same reason restaurant's EOD goes through
  /// `PaymentModeSummary.summarize`.
  ///
  /// The list handed in is still `activeSales` (returns excluded), which keeps
  /// expected-cash gross of refunds; refunds are accounted for separately by
  /// the drawer's own cash-refund figure.
  static List<PaymentSummary> _calculateRetailPaymentSummaries(
          List<SaleModel> sales) =>
      RetailPaymentModeSummary.summarize(sales);

  static List<TaxSummary> _calculateRetailTaxSummaries(List sales) {
    double totalCgst = 0.0;
    double totalSgst = 0.0;
    double totalTaxableAmount = 0.0;

    for (final sale in sales) {
      // Returns are NETTED, not skipped. Their CGST/SGST/taxable are stored
      // already negated, so summing them straight nets the credit note out.
      // Skipping them left CGST + SGST unable to reconcile with `totalTax`
      // above, which does net returns — the two disagreed on any day with a
      // refund.
      if (sale.totalCgstAmount != null && sale.totalSgstAmount != null) {
        totalCgst += sale.totalCgstAmount!;
        totalSgst += sale.totalSgstAmount!;
        totalTaxableAmount += (sale.totalTaxableAmount ?? 0.0);
      }
    }

    List<TaxSummary> summaries = [];

    // CGST/SGST is an INDIAN intra-state concept. Storing those names for a UK
    // or US shop put Indian tax rows into its permanent close records — and
    // unlike a screen label, a stored name cannot be re-rendered later.
    // `TaxLabelRule` is the same rule the GST report and Checkout already use.
    if (!TaxLabelRule.splitsIntoComponents) {
      final totalTax = totalCgst + totalSgst;
      if (totalTax > 0) {
        summaries.add(TaxSummary(
          // "VAT" / "Sales Tax" / "Tax" — whatever this country calls it.
          taxName: TaxLabelRule.name,
          taxRate: 0.0, // Rate varies by product, so we'll show 0 for overall
          taxAmount: totalTax,
          // The WHOLE base, not a half: there is nothing to halve it between.
          taxableAmount: totalTaxableAmount,
        ));
      }
      return summaries;
    }

    // Add CGST summary if present
    if (totalCgst > 0) {
      summaries.add(TaxSummary(
        taxName: 'CGST',
        taxRate: 0.0, // Rate varies by product, so we'll show 0 for overall
        taxAmount: totalCgst,
        taxableAmount: totalTaxableAmount / 2, // Half for CGST
      ));
    }

    // Add SGST summary if present
    if (totalSgst > 0) {
      summaries.add(TaxSummary(
        taxName: 'SGST',
        taxRate: 0.0,
        taxAmount: totalSgst,
        taxableAmount: totalTaxableAmount / 2, // Half for SGST
      ));
    }

    return summaries;
  }

  static void _subtractFromSummary(List<PaymentSummary> list, String method, double amount) {
    final normMethod = PaymentModeSummary.normalizeMethod(method);
    final idx = list.indexWhere((s) => s.paymentType.toLowerCase().trim() == normMethod.toLowerCase().trim());
    if (idx != -1) {
      final old = list[idx];
      list[idx] = PaymentSummary(
        paymentType: old.paymentType,
        totalAmount: old.totalAmount - amount,
        transactionCount: old.transactionCount,
        percentage: 0.0,
      );
    } else {
      list.add(PaymentSummary(
        paymentType: normMethod,
        totalAmount: -amount,
        transactionCount: 1,
        percentage: 0.0,
      ));
    }
  }
}

class TaxInfo {
  final String taxName;
  final double taxRate;
  double taxAmount;
  double taxableAmount;

  TaxInfo({
    required this.taxName,
    required this.taxRate,
    required this.taxAmount,
    required this.taxableAmount,
  });
}