



import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_model_213.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_return_model_174.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_claim_model_176.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_model_211.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/repositories/retail/grn_item_repository.dart';
import 'package:billberrylite/domain/services/retail/stock_adjustment_service.dart';
import 'package:billberrylite/util/restaurant/report_history_window.dart';
import 'package:billberrylite/util/retail/sale_revenue_filter.dart';
import 'package:billberrylite/data/repositories/restaurant/cash_movement_repository.dart';
import 'package:billberrylite/util/retail/cash_drawer_ledger.dart';

import '../../../data/models/retail/hive_model/sale_item_model_204.dart';

/// One window of sales, already classified.
///
/// Every sales report needs the same three things — which sales fall in the
/// window, which of those are returns, and a saleId→sign map for netting their
/// line items. Deriving that once, in one place, is what stops the rules
/// drifting apart between reports.
class _SaleWindow {
  final List<SaleModel> forward;
  final List<SaleModel> returns;

  /// `+1` for a forward sale, `-1` for a return. Line-level aggregation only —
  /// see [RetailSaleFilter.revenueSign].
  final Map<String, int> signBySaleId;

  /// Rows dropped because their date could not be parsed.
  final int skippedRows;

  const _SaleWindow({
    required this.forward,
    required this.returns,
    required this.signBySaleId,
    required this.skippedRows,
  });

  /// Forward sales and returns together, headers already signed.
  Iterable<SaleModel> get all => [...forward, ...returns];
}

/// Service for generating various business reports.
///
/// **Accrual basis.** `SaleModel.status` is deliberately never consulted: a
/// `due` credit sale counts as revenue the moment it is rung up, not when it is
/// collected. There is no cash-basis alternative here — cash actually received
/// is the cash drawer's and EOD's job.
///
/// **Header reports and line reports differ by round-off, and always will.**
/// Daily/Monthly sum the stored `sale.totalAmount`; Product/Variant/Category
/// sum `item.total`. `RetailBillLine.total` is `taxableAmount + gstAmount`
/// (`retail_billing_service.dart:45`) and excludes `roundOff`, which *is* inside
/// the stored grand total. Bill-level discount and loyalty redemption are
/// distributed across lines and do reconcile; round-off is not distributed,
/// because doing so would put a fabricated fraction of a rupee on individual
/// lines and make a reprint disagree with the original receipt. So expect a
/// drift of up to the round-off per sale between the two families of report.
/// That gap is the round-off, not a bug — do not "fix" it by redistributing.
class ReportService {
  /// Inclusive start, **exclusive** end — the single date rule for every report
  /// in this service.
  ///
  /// The original comparisons were `isAfter(start) && isBefore(end)`, strict on
  /// both sides. Because a date picker hands back midnight, that dropped the
  /// whole last day of a range and any record sitting exactly on a boundary.
  /// Callers must therefore pass an end that is the first instant *after* the
  /// window (start of next day / next month), which is what the report kit's
  /// `reportPeriodEndBound` already returns.
  /// How far back this plan may look, captured once per instance so every row
  /// in a single report is judged against the same instant.
  ///
  /// Always `ReportHistoryWindow.cutoff`, never `PlanEnforce.windowCutoff` —
  /// the latter has no `days <= 0 ⇒ unlimited` guard, so a `0` would pin the
  /// cutoff to now and blank every report while the filter buttons stayed
  /// unlocked.
  final DateTime? _historyCutoff = ReportHistoryWindow.cutoff;

  bool _inWindow(DateTime at, DateTime? start, DateTime? end) {
    // Enforced here rather than at each of the 16 report methods, so no report
    // can be added later that quietly reaches past the plan's limit. Null means
    // unlimited, which is what retail resolves to today (licensing is bypassed
    // for retail), making this a no-op until that flips.
    if (_historyCutoff != null && at.isBefore(_historyCutoff)) return false;
    if (start != null && at.isBefore(start)) return false;
    if (end != null && !at.isBefore(end)) return false;
    return true;
  }

  /// Never `DateTime.parse` a stored date in a filter.
  ///
  /// A single malformed string threw straight out of the enclosing `.where`
  /// closure and took the whole report down with it. Restore accepts
  /// `saleMap['date']` unvalidated, so a bad value is reachable. Unparseable
  /// rows are skipped and counted into `skippedRows` instead — silently
  /// dropping a sale is bad, but silently dropping every sale is worse.
  DateTime? _parseDate(String? iso) => DateTime.tryParse(iso ?? '');

  /// The one timestamp every retail report filters and groups on.
  ///
  /// `SaleModel` carries both `date` and `createdAt`, written identically by
  /// every factory — but nothing enforces that, and restore used to default
  /// them independently, so a restored sale could carry two different days.
  /// Reports used `date` while `SaleRepository`, EOD, the cash drawer and the
  /// dashboard all used `createdAt`, which meant the same sale could be counted
  /// by one and not the other. `createdAt` wins because the rest of the app
  /// already agreed on it.
  DateTime? _reportedAt(SaleModel sale) => _parseDate(sale.createdAt);

  /// Classify every sale in a window once: forward sales, returns, and the
  /// per-sale sign its line items carry.
  ///
  /// Both bounds null means "all time" — and note the classification runs
  /// regardless. It used to sit inside `if (start != null || end != null)`,
  /// so an unfiltered report skipped it entirely and counted return lines,
  /// which are stored positive, as extra sales.
  Future<_SaleWindow> _salesInWindow(DateTime? start, DateTime? end) async {
    // Bounded read when we have both ends. `getSalesByDateRange` filters on the
    // same field with the same exclusive-end rule as `_inWindow`, so this is a
    // narrowing, not a different answer — and `_inWindow` below still applies
    // the plan's history cutoff either way.
    final allSales = (start != null && end != null)
        ? await saleStore.getSalesByDateRange(start, end)
        : await saleStore.getAllSales();

    final forward = <SaleModel>[];
    final returns = <SaleModel>[];
    final signBySaleId = <String, int>{};
    var skipped = 0;

    for (final sale in allSales) {
      final at = _reportedAt(sale);
      if (at == null) {
        skipped++;
        continue;
      }
      if (!_inWindow(at, start, end)) continue;
      if (RetailSaleFilter.isExcludedFromRevenue(sale)) continue;

      signBySaleId[sale.saleId] = RetailSaleFilter.revenueSign(sale);
      if (RetailSaleFilter.isReturn(sale)) {
        returns.add(sale);
      } else {
        forward.add(sale);
      }
    }

    return _SaleWindow(
      forward: forward,
      returns: returns,
      signBySaleId: signBySaleId,
      skippedRows: skipped,
    );
  }

  /// Every sale line in a window, paired with the sign its sale contributes.
  ///
  /// Lines belonging to a return come back with `sign: -1` rather than being
  /// dropped, so an item sold 10 and returned 8 reports 2 — which is what makes
  /// the item-level reports reconcile with `netRevenue` on Daily/Monthly.
  Future<List<({SaleItemModel item, int sign})>> _signedLinesInWindow(
      DateTime? start, DateTime? end) async {
    final window = await _salesInWindow(start, end);
    final allItems = await saleItemRepository.getAllSaleItems();

    final signed = <({SaleItemModel item, int sign})>[];
    for (final item in allItems) {
      final sign = window.signBySaleId[item.saleId];
      if (sign == null) continue; // outside the window, or an excluded sale
      signed.add((item: item, sign: sign));
    }
    return signed;
  }

  /// Revenue for a line with the collected tax taken out.
  ///
  /// `item.total` is tax-INCLUSIVE. Profit compares it against an ex-tax cost
  /// price, so leaving the GST in booked the tax you owe the government as
  /// margin — a ₹100 item at 18% costing ₹60 reported ₹58 profit instead of
  /// ₹40, and the overstatement grew with the tax rate.
  double _netRevenueOf(SaleItemModel item) =>
      item.total - (item.gstAmount ?? item.taxAmount ?? 0.0);

  /// variantId → current cost price, read once per report.
  ///
  /// Only a fallback for lines written before cost was snapshotted onto the
  /// sale (see `SaleItemModel.costPrice`); it replaces a `getVariantById` call
  /// per line, which on a miss degraded to a full box scan each time.
  Future<Map<String, double?>> _liveCostByVariantId() async {
    final all = await productStore.getAllVariants();
    return {for (final v in all) v.varianteId: v.costPrice};
  }

  /// Unit cost for a line: frozen-at-sale first, live variant second, and
  /// `null` when it is genuinely unknown.
  ///
  /// Never collapse the unknown case to `0` — that silently turns a line with
  /// no cost data into 100% margin and drags the whole store's margin up.
  double? _unitCostOf(SaleItemModel item, Map<String, double?> liveCost) =>
      item.costPrice ?? liveCost[item.varianteId];

  /// saleId → its lines, indexed in a single pass.
  ///
  /// `saleItemRepository.getItemsBySaleId` has no index and scans the whole
  /// box, so calling it per sale meant a 1,000-sale month cost 1,000 full
  /// scans — and the profit screen did that twice over.
  Future<Map<String, List<SaleItemModel>>> _itemsBySaleId() async {
    final all = await saleItemRepository.getAllSaleItems();
    final bySaleId = <String, List<SaleItemModel>>{};
    for (final item in all) {
      (bySaleId[item.saleId] ??= <SaleItemModel>[]).add(item);
    }
    return bySaleId;
  }

  // ==================== Daily Sales Report ====================

  /// Get daily sales report for a specific date
  Future<Map<String, dynamic>> getDailySalesReport(DateTime date) async {
    // Exclusive end = start of the next day. The old 23:59:59 bound with a
    // strict isAfter/isBefore dropped both a sale at exactly midnight and
    // anything in the final second of the day.
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final window = await _salesInWindow(startOfDay, endOfDay);
    final dailySales = window.forward;
    final dailyReturns = window.returns;

    final totalSales = dailySales.length;
    final totalRevenue = dailySales.fold<double>(0.0, (sum, sale) => sum + sale.totalAmount);
    final totalItems = dailySales.fold<int>(0, (sum, sale) => sum + sale.totalItems);

    // Discount and tax net the credit notes out. Return headers are stored
    // already negated, so folding over forward sales AND returns nets by
    // itself. Without this the GST figure ignored refunds while `netRevenue`
    // right below it did not.
    final totalDiscount =
        window.all.fold<double>(0.0, (sum, sale) => sum + sale.discountAmount);
    final totalTax =
        window.all.fold<double>(0.0, (sum, sale) => sum + sale.taxAmount);

    final totalReturns = dailyReturns.length;
    final totalReturnAmount = dailyReturns.fold<double>(0.0, (sum, sale) => sum + sale.totalAmount.abs());

    return {
      'date': date,
      'totalSales': totalSales,
      'totalRevenue': totalRevenue,
      'totalItems': totalItems,
      'totalDiscount': totalDiscount,
      'totalTax': totalTax,
      'totalReturns': totalReturns,
      'totalReturnAmount': totalReturnAmount,
      'netRevenue': totalRevenue - totalReturnAmount,
      'averageSaleValue': totalSales != 0 ? totalRevenue / totalSales : 0.0,
      'skippedRows': window.skippedRows,
      'sales': dailySales,
    };
  }

  // ==================== Monthly Sales Report ====================

  /// Get monthly sales report
  Future<Map<String, dynamic>> getMonthlySalesReport(int year, int month) async {
    // Exclusive end = first instant of the following month. `DateTime(y, m+1, 1)`
    // rolls the year over correctly for December.
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 1);

    final window = await _salesInWindow(startOfMonth, endOfMonth);
    final monthlySales = window.forward;
    final monthlyReturns = window.returns;

    final totalSales = monthlySales.length;
    final totalRevenue = monthlySales.fold<double>(0.0, (sum, sale) => sum + sale.totalAmount);
    final totalItems = monthlySales.fold<int>(0, (sum, sale) => sum + sale.totalItems);

    // Net of credit notes — see the equivalent note on the daily report.
    final totalDiscount =
        window.all.fold<double>(0.0, (sum, sale) => sum + sale.discountAmount);
    final totalTax =
        window.all.fold<double>(0.0, (sum, sale) => sum + sale.taxAmount);

    final totalReturns = monthlyReturns.length;
    final totalReturnAmount = monthlyReturns.fold<double>(0.0, (sum, sale) => sum + sale.totalAmount.abs());

    // Day-by-day trend, net of returns: a refund pulls its own day down rather
    // than vanishing. Return headers are already negative, so adding them is
    // the netting.
    final dailyBreakdown = <int, double>{};
    for (var sale in window.all) {
      final saleDate = _reportedAt(sale);
      if (saleDate == null) continue;
      final day = saleDate.day;
      dailyBreakdown[day] = (dailyBreakdown[day] ?? 0.0) + sale.totalAmount;
    }

    return {
      'year': year,
      'month': month,
      'totalSales': totalSales,
      'totalRevenue': totalRevenue,
      'totalItems': totalItems,
      'totalDiscount': totalDiscount,
      'totalTax': totalTax,
      'totalReturns': totalReturns,
      'totalReturnAmount': totalReturnAmount,
      'netRevenue': totalRevenue - totalReturnAmount,
      'averageSaleValue': totalSales != 0 ? totalRevenue / totalSales : 0.0,
      'dailyBreakdown': dailyBreakdown,
      'skippedRows': window.skippedRows,
      'sales': monthlySales,
    };
  }

  // ==================== Product-wise Sales Report ====================

  /// Get sales report grouped by products
  Future<List<Map<String, dynamic>>> getProductWiseSalesReport({DateTime? startDate, DateTime? endDate}) async {
    final lines = await _signedLinesInWindow(startDate, endDate);

    // Group by productId
    final Map<String, Map<String, dynamic>> productStats = {};

    for (final (:item, :sign) in lines) {
      if (!productStats.containsKey(item.productId)) {
        productStats[item.productId] = {
          'productId': item.productId,
          // Defaulted here, not at each call site: `SaleItemModel.productName`
          // is nullable and screens cast this straight to `String`.
          'productName': item.productName ?? 'Unknown',
          'totalQuantity': 0,
          'totalRevenue': 0.0,
          'totalDiscount': 0.0,
          'totalTax': 0.0,
        };
      }

      productStats[item.productId]!['totalQuantity'] += item.qty * sign;
      productStats[item.productId]!['totalRevenue'] += item.total * sign;
      productStats[item.productId]!['totalDiscount'] += (item.discountAmount ?? 0.0) * sign;
      productStats[item.productId]!['totalTax'] += (item.taxAmount ?? 0.0) * sign;
    }

    // Convert to list and sort by revenue
    final statsList = productStats.values.toList()
      ..sort((a, b) => (b['totalRevenue'] as double).compareTo(a['totalRevenue'] as double));

    return statsList;
  }

  // ==================== Variant-wise Sales Report ====================

  /// Get sales report grouped by variants
  Future<List<Map<String, dynamic>>> getVariantWiseSalesReport({DateTime? startDate, DateTime? endDate}) async {
    final lines = await _signedLinesInWindow(startDate, endDate);

    // Group by variantId
    final Map<String, Map<String, dynamic>> variantStats = {};

    for (final (:item, :sign) in lines) {
      if (!variantStats.containsKey(item.varianteId)) {
        variantStats[item.varianteId] = {
          'variantId': item.varianteId,
          'productId': item.productId,
          // Defaulted here, not at each call site: `SaleItemModel.productName`
          // is nullable and screens cast this straight to `String`.
          'productName': item.productName ?? 'Unknown',
          'size': item.size,
          'color': item.color,
          // Descriptor resolved from the sale's own record, so reports match
          // the receipt even if the variant was edited afterwards.
          'variantLabel': attributeStore.describeAttributes(item.attributes,
              size: item.size, color: item.color),
          'totalQuantity': 0,
          'totalRevenue': 0.0,
          'totalDiscount': 0.0,
          'totalTax': 0.0,
        };
      }

      variantStats[item.varianteId]!['totalQuantity'] += item.qty * sign;
      variantStats[item.varianteId]!['totalRevenue'] += item.total * sign;
      variantStats[item.varianteId]!['totalDiscount'] += (item.discountAmount ?? 0.0) * sign;
      variantStats[item.varianteId]!['totalTax'] += (item.taxAmount ?? 0.0) * sign;
    }

    // Convert to list and sort by revenue
    final statsList = variantStats.values.toList()
      ..sort((a, b) => (b['totalRevenue'] as double).compareTo(a['totalRevenue'] as double));

    return statsList;
  }

  // ==================== Category-wise Sales Report ====================

  /// Get sales report grouped by categories
  Future<List<Map<String, dynamic>>> getCategoryWiseSalesReport({DateTime? startDate, DateTime? endDate}) async {
    final lines = await _signedLinesInWindow(startDate, endDate);

    // Indexed once — the per-line `products.where(...).firstOrNull` this
    // replaces was a full product scan for every sale line.
    //
    // `ProductModel.category` holds the category **id**, not its name (see
    // `add_product_screen.dart`, which saves `_selectedCategoryModel?.id`).
    // Reporting it directly is why this report showed raw ids.
    final categoryIdByProductId = {
      for (final p in productStore.products) p.productId: p.category,
    };
    final categoryNameById = categoryStore.categoryNameById;

    // Group by category id — names are not guaranteed unique, and grouping on
    // a display string would silently merge two categories that share one.
    final Map<String, Map<String, dynamic>> categoryStats = {};

    for (final (:item, :sign) in lines) {
      final categoryId = categoryIdByProductId[item.productId] ?? '';
      final name = categoryNameById[categoryId];

      // Blank, unknown and deleted-category ids all collapse into a single
      // bucket, so a deleted category can't produce several rows that are all
      // labelled 'Uncategorized'.
      final key = name == null ? '' : categoryId;
      final label = name ?? 'Uncategorized';

      final stat = categoryStats.putIfAbsent(
          key,
          () => {
                'categoryId': key,
                'category': label,
                'totalQuantity': 0,
                'totalRevenue': 0.0,
                'totalDiscount': 0.0,
                'totalTax': 0.0,
                'productCount': <String>{},
              });

      stat['totalQuantity'] += item.qty * sign;
      stat['totalRevenue'] += item.total * sign;
      stat['totalDiscount'] += (item.discountAmount ?? 0.0) * sign;
      stat['totalTax'] += (item.taxAmount ?? 0.0) * sign;
      (stat['productCount'] as Set<String>).add(item.productId);
    }

    // Convert to list and calculate product count
    final statsList = categoryStats.values.map((stat) {
      return {
        'categoryId': stat['categoryId'],
        'category': stat['category'],
        'totalQuantity': stat['totalQuantity'],
        'totalRevenue': stat['totalRevenue'],
        'totalDiscount': stat['totalDiscount'],
        'totalTax': stat['totalTax'],
        'productCount': (stat['productCount'] as Set<String>).length,
      };
    }).toList()
      ..sort((a, b) => (b['totalRevenue'] as double).compareTo(a['totalRevenue'] as double));

    return statsList;
  }

  // ==================== Supplier-wise Purchase Report ====================

  /// Purchases grouped by supplier, measured on what was actually RECEIVED.
  ///
  /// Reads confirmed GRNs, not purchase orders. The previous version summed
  /// `po.estimatedTotal` across every PO regardless of status, so drafts and
  /// cancelled orders inflated it and the figure was an estimate rather than
  /// spend. `GRNModel.totalAmount` is the supplier's invoice value for that
  /// receipt. Credits from returns and settled claims are supplier-ledger
  /// events and are deliberately NOT netted off here — see the damaged columns.
  Future<List<Map<String, dynamic>>> getSupplierWisePurchaseReport(
      {DateTime? startDate, DateTime? endDate}) async {
    final receipts = _confirmedGRNs(startDate: startDate, endDate: endDate);
    final suppliers = supplierStore.suppliers;
    final damagedByGRN = _damagedRecoveryByGRN();

    final stats = <String, Map<String, dynamic>>{};

    for (final grn in receipts) {
      final supplier = suppliers
          .where((s) => s.supplierId == grn.supplierId)
          .firstOrNull;

      final entry = stats.putIfAbsent(
        grn.supplierId,
        () => {
          'supplierId': grn.supplierId,
          'supplierName':
              supplier?.name ?? grn.supplierName ?? 'Unknown Supplier',
          'receiptCount': 0,
          'totalItems': 0,
          'totalAmount': 0.0,
          'damagedAmount': 0.0,
          'damagedRecoverable': 0.0,
          'damagedAbsorbed': 0.0,
        },
      );

      final damaged = damagedByGRN[grn.grnId];

      entry['receiptCount'] = (entry['receiptCount'] as int) + 1;
      entry['totalItems'] = (entry['totalItems'] as int) + grn.totalReceivedQty;
      entry['totalAmount'] =
          (entry['totalAmount'] as double) + (grn.totalAmount ?? 0);
      entry['damagedRecoverable'] =
          (entry['damagedRecoverable'] as double) + (damaged?.recoverable ?? 0);
      entry['damagedAbsorbed'] =
          (entry['damagedAbsorbed'] as double) + (damaged?.absorbed ?? 0);
      // Kept as the combined figure for any reader that only wants one number.
      entry['damagedAmount'] =
          (entry['damagedAmount'] as double) + (damaged?.total ?? 0);
    }

    return stats.values.toList()
      ..sort((a, b) =>
          (b['totalAmount'] as double).compareTo(a['totalAmount'] as double));
  }

  // ==================== Low Stock Report ====================

  /// Get low stock report
  Future<List<Map<String, dynamic>>> getLowStockReport({int threshold = 10}) async {
    final allProducts = productStore.products;
    final lowStockItems = <Map<String, dynamic>>[];

    // One read of the variant box, grouped once. `getVariantsForProduct` is
    // itself a full box scan, so calling it per product was products × variants.
    final variantsByProduct = <String, List<VarianteModel>>{};
    for (final v in await productStore.getAllVariants()) {
      (variantsByProduct[v.productId] ??= <VarianteModel>[]).add(v);
    }

    for (var product in allProducts) {
      final variants =
          variantsByProduct[product.productId] ?? const <VarianteModel>[];
      for (var variant in variants) {
        // A variant's own minStock wins over the global threshold, matching
        // productStore.reorderPointFor — otherwise the Stock Alerts card and
        // the inventory colouring would disagree about the same variant.
        final reorderPoint = variant.minStock ?? threshold;
        if (variant.stockQty <= reorderPoint) {
          lowStockItems.add({
            'productId': product.productId,
            'productName': product.productName,
            'variantId': variant.varianteId,
            'variantLabel':
                attributeStore.describeAttributes(attributeStore.attributesOf(variant)),
            'currentStock': variant.stockQty,
            'reorderPoint': reorderPoint,
            'costPrice': variant.costPrice,
            'mrp': variant.mrp,
            'barcode': variant.barcode,
          });
        }
      }
    }

    // Sort by stock quantity (lowest first)
    lowStockItems.sort((a, b) => (a['currentStock'] as int).compareTo(b['currentStock'] as int));

    return lowStockItems;
  }

  // ==================== Cash Drawer History Report ====================

  /// Every cash movement through the drawer in a period, newest first.
  ///
  /// The live Cash Drawer screen shows the same ledger for today only — once a
  /// day is closed there was no way to look back at it. Both compose it from
  /// the same rules ([CashDrawerLedger]) so they cannot disagree.
  ///
  /// Covers the four things that move till cash: cash sales (the cash leg of a
  /// split bill only), cash refunds, cash expenses, and manual Cash In / Out —
  /// which is also where credit collected in cash arrives.
  Future<List<Map<String, dynamic>>> getCashDrawerReport(
      {DateTime? startDate, DateTime? endDate}) async {
    final rows = <Map<String, dynamic>>[];

    // ---- Sales and refunds -------------------------------------------------
    final window = await _salesInWindow(startDate, endDate);
    for (final sale in window.all) {
      final at = _reportedAt(sale);
      if (at == null) continue;

      final refund = CashDrawerLedger.cashRefundOf(sale);
      if (refund > 0) {
        rows.add({
          'at': at,
          'type': 'Refund',
          'description': 'Cash Refund',
          'amount': -refund,
          'reference': sale.saleId,
        });
        continue;
      }

      final cash = CashDrawerLedger.cashComponentOf(sale);
      if (cash <= 0) continue;
      rows.add({
        'at': at,
        'type': 'Sale',
        'description':
            sale.isSplitPayment == true ? 'Sale (cash portion)' : 'Cash Sale',
        'amount': cash,
        'reference': sale.saleId,
      });
    }

    // ---- Manual Cash In / Out ----------------------------------------------
    for (final m in await CashMovementRepository().getAllMovements()) {
      if (!CashDrawerLedger.isLedgerMovement(m)) continue;
      if (!_inWindow(m.timestamp, startDate, endDate)) continue;
      final isIn = m.type == 'in';
      rows.add({
        'at': m.timestamp,
        'type': isIn ? 'Cash In' : 'Cash Out',
        'description': m.note == null || m.note!.isEmpty
            ? m.reason
            : '${m.reason} — ${m.note}',
        'amount': isIn ? m.amount : -m.amount,
        'reference': m.staffName,
      });
    }

    // ---- Cash expenses ------------------------------------------------------
    await expenseStore.loadExpenses();
    for (final e in expenseStore.expenses) {
      if ((e.paymentType ?? '').toLowerCase().trim() != 'cash') continue;
      if (!_inWindow(e.dateandTime, startDate, endDate)) continue;
      rows.add({
        'at': e.dateandTime,
        'type': 'Expense',
        'description':
            e.reason == null || e.reason!.isEmpty ? 'Expense' : e.reason!,
        'amount': -e.amount,
        'reference': '',
      });
    }

    rows.sort((a, b) => (b['at'] as DateTime).compareTo(a['at'] as DateTime));
    return rows;
  }

  // ==================== GST Summary Report ====================

  /// Output GST for a period, broken down by rate, by product and by rate-band.
  ///
  /// Lifted out of `gst_report_screen.dart`, which computed it inside the
  /// widget and got three things wrong that mattered for a filing-grade report:
  /// it applied no return filter at all (so a credit note ADDED to the GST you
  /// appear to owe), it bounded the range with a `±1 day` fudge on `sale.date`
  /// instead of the window rule every other report uses, and it fetched line
  /// items with a full box scan per sale.
  ///
  /// Returns are netted — a credit note reduces output tax, which is the whole
  /// point of issuing one.
  Future<Map<String, dynamic>> getGstSummaryReport(
      {DateTime? startDate, DateTime? endDate}) async {
    final window = await _salesInWindow(startDate, endDate);
    final lines = <({SaleItemModel item, int sign})>[];
    for (final item in await saleItemRepository.getAllSaleItems()) {
      final sign = window.signBySaleId[item.saleId];
      if (sign == null) continue;
      lines.add((item: item, sign: sign));
    }

    final byRate = <double, Map<String, dynamic>>{};
    final byProduct = <String, Map<String, dynamic>>{};
    final byCategory = <String, Map<String, dynamic>>{};

    double totalTaxable = 0, totalGst = 0, totalCgst = 0, totalSgst = 0;

    for (final (:item, :sign) in lines) {
      final rate = item.gstRate ?? 0;
      final taxable = (item.taxableAmount ?? 0) * sign;
      final gst = (item.gstAmount ?? 0) * sign;
      final cgst = (item.cgstAmount ?? 0) * sign;
      final sgst = (item.sgstAmount ?? 0) * sign;

      totalTaxable += taxable;
      totalGst += gst;
      totalCgst += cgst;
      totalSgst += sgst;

      final rateRow = byRate.putIfAbsent(
          rate,
          () => {
                'rate': rate,
                'itemCount': 0,
                'taxableAmount': 0.0,
                'cgst': 0.0,
                'sgst': 0.0,
                'totalGst': 0.0,
              });
      rateRow['itemCount'] += sign;
      rateRow['taxableAmount'] += taxable;
      rateRow['cgst'] += cgst;
      rateRow['sgst'] += sgst;
      rateRow['totalGst'] += gst;

      final productRow = byProduct.putIfAbsent(
          item.productId,
          () => {
                'productId': item.productId,
                'productName': item.productName ?? 'Unknown',
                'quantity': 0,
                'taxableAmount': 0.0,
                'totalGst': 0.0,
              });
      productRow['quantity'] += item.qty * sign;
      productRow['taxableAmount'] += taxable;
      productRow['totalGst'] += gst;

      // Rate band standing in for a category, as the screen already did.
      final bandKey = '${rate.toInt()}%';
      final categoryRow = byCategory.putIfAbsent(
          bandKey,
          () => {
                'categoryName': 'GST $bandKey Items',
                'gstRate': rate,
                'itemCount': 0,
                'taxableAmount': 0.0,
                'cgst': 0.0,
                'sgst': 0.0,
                'totalGst': 0.0,
              });
      categoryRow['itemCount'] += sign;
      categoryRow['taxableAmount'] += taxable;
      categoryRow['cgst'] += cgst;
      categoryRow['sgst'] += sgst;
      categoryRow['totalGst'] += gst;
    }

    return {
      'saleCount': window.forward.length,
      'returnCount': window.returns.length,
      'lineCount': lines.length,
      'totalTaxableAmount': totalTaxable,
      'totalGstAmount': totalGst,
      'totalCgstAmount': totalCgst,
      'totalSgstAmount': totalSgst,
      'byRate': byRate.values.toList(),
      'byProduct': byProduct.values.map((row) {
        final taxable = row['taxableAmount'] as double;
        final gst = row['totalGst'] as double;
        return {
          ...row,
          // Effective rate, not a mean of the rates seen. Averaging the rates
          // ignores line size, and stays stable once returns can make a
          // line count negative.
          'avgGstRate': taxable != 0 ? (gst / taxable) * 100 : 0.0,
        };
      }).toList(),
      'byCategory': byCategory.values.toList(),
      'skippedRows': window.skippedRows,
    };
  }

  // ==================== Top Selling Products Report ====================

  /// Get top selling products
  Future<List<Map<String, dynamic>>> getTopSellingProductsReport({int limit = 20, DateTime? startDate, DateTime? endDate}) async {
    final productWiseReport = await getProductWiseSalesReport(startDate: startDate, endDate: endDate);
    return productWiseReport.take(limit).toList();
  }

  // ==================== Profit Report ====================

  /// Get profit report (Revenue - Cost)
  Future<Map<String, dynamic>> getProfitReport({DateTime? startDate, DateTime? endDate}) async {
    final lines = await _signedLinesInWindow(startDate, endDate);
    final liveCost = await _liveCostByVariantId();

    double totalRevenue = 0.0;
    double totalCost = 0.0;
    var unknownCostLines = 0;
    double unknownCostRevenue = 0.0;

    for (final (:item, :sign) in lines) {
      final revenue = _netRevenueOf(item) * sign;
      totalRevenue += revenue;

      final unitCost = _unitCostOf(item, liveCost);
      if (unitCost == null) {
        // Counted as revenue but NOT as free profit. The caller surfaces this
        // so "100% margin" can't mean "we never entered a cost price".
        unknownCostLines++;
        unknownCostRevenue += revenue;
        continue;
      }
      totalCost += unitCost * item.qty * sign;
    }

    final profit = totalRevenue - totalCost;
    final profitMargin = totalRevenue != 0 ? (profit / totalRevenue) * 100 : 0.0;

    return {
      'totalRevenue': totalRevenue,
      'totalCost': totalCost,
      'grossProfit': profit,
      'profitMargin': profitMargin,
      // Sale-item LINES in the window, not units sold.
      'itemCount': lines.length,
      'unknownCostLines': unknownCostLines,
      'unknownCostRevenue': unknownCostRevenue,
    };
  }

  // ==================== Profit Per Item Report ====================

  /// Get profit breakdown per item/variant
  Future<List<Map<String, dynamic>>> getProfitPerItemReport({DateTime? startDate, DateTime? endDate}) async {
    final lines = await _signedLinesInWindow(startDate, endDate);
    final liveCost = await _liveCostByVariantId();

    // Group by variant and calculate profit
    final Map<String, Map<String, dynamic>> itemProfits = {};

    for (final (:item, :sign) in lines) {
      final unitCost = _unitCostOf(item, liveCost);

      if (!itemProfits.containsKey(item.varianteId)) {
        itemProfits[item.varianteId] = {
          'variantId': item.varianteId,
          'productId': item.productId,
          // Defaulted here, not at each call site: `SaleItemModel.productName`
          // is nullable and screens cast this straight to `String`.
          'productName': item.productName ?? 'Unknown',
          'size': item.size,
          'color': item.color,
          // Descriptor resolved from the sale's own record, so reports match
          // the receipt even if the variant was edited afterwards.
          'variantLabel': attributeStore.describeAttributes(item.attributes,
              size: item.size, color: item.color),
          'barcode': item.barcode,
          'totalQuantitySold': 0,
          'totalRevenue': 0.0,
          'totalCost': 0.0,
          'totalProfit': 0.0,
          'profitMargin': 0.0,
          'avgSellingPrice': 0.0,
          // Null, not 0.0 — "no cost on record" and "costs nothing" are
          // different facts and the screen needs to be able to tell them apart.
          'costPrice': unitCost,
          'unknownCostLines': 0,
        };
      }

      final revenue = _netRevenueOf(item) * sign;
      final stat = itemProfits[item.varianteId]!;

      stat['totalQuantitySold'] += item.qty * sign;
      stat['totalRevenue'] += revenue;

      if (unitCost == null) {
        stat['unknownCostLines'] += 1;
      } else {
        final cost = unitCost * item.qty * sign;
        stat['totalCost'] += cost;
        stat['totalProfit'] += revenue - cost;
      }
    }

    // Calculate profit margin and average selling price
    final statsList = itemProfits.values.map((stat) {
      final revenue = stat['totalRevenue'] as double;
      final profit = stat['totalProfit'] as double;
      final qty = stat['totalQuantitySold'] as int;

      return {
        ...stat,
        // `!= 0`, not `> 0`: a variant returned more than it sold has negative
        // revenue, and `> 0` rendered that loss as a flat 0% break-even.
        'profitMargin': revenue != 0 ? (profit / revenue) * 100 : 0.0,
        'avgSellingPrice': qty != 0 ? revenue / qty : 0.0,
      };
    }).toList()
      ..sort((a, b) => (b['totalProfit'] as double).compareTo(a['totalProfit'] as double));

    return statsList;
  }

  // ==================== Profit Per Sale Report ====================

  /// Get profit breakdown per individual sale transaction
  Future<List<Map<String, dynamic>>> getProfitPerSaleReport({DateTime? startDate, DateTime? endDate}) async {
    final window = await _salesInWindow(startDate, endDate);
    final itemsBySaleId = await _itemsBySaleId();
    final liveCost = await _liveCostByVariantId();

    final saleProfits = <Map<String, dynamic>>[];

    // Returns are listed too, as negative rows. Excluding them here while the
    // overall profit report netted them made two tabs of the same screen
    // disagree about the same period.
    for (final sale in window.all) {
      final sign = RetailSaleFilter.revenueSign(sale);
      final saleItems = itemsBySaleId[sale.saleId] ?? const <SaleItemModel>[];

      // Header amounts are already negated on a return, so this is signed.
      final totalRevenue = sale.totalAmount - sale.taxAmount;

      double totalCost = 0.0;
      var unknownCostLines = 0;
      for (final item in saleItems) {
        final unitCost = _unitCostOf(item, liveCost);
        if (unitCost == null) {
          unknownCostLines++;
          continue;
        }
        // Lines are stored positive even on a return — hence the sign.
        totalCost += unitCost * item.qty * sign;
      }

      final profit = totalRevenue - totalCost;
      final profitMargin = totalRevenue != 0 ? (profit / totalRevenue) * 100 : 0.0;

      saleProfits.add({
        'saleId': sale.saleId,
        // Same field the row was filtered on, so the listed date can't
        // disagree with the period the report claims to cover.
        'date': sale.createdAt,
        'customerId': sale.customerId,
        'totalItems': sale.totalItems * sign,
        'totalRevenue': totalRevenue,
        'totalCost': totalCost,
        'profit': profit,
        'profitMargin': profitMargin,
        'paymentType': sale.paymentType,
        'discountAmount': sale.discountAmount,
        'taxAmount': sale.taxAmount,
        'isReturn': RetailSaleFilter.isReturn(sale),
        'unknownCostLines': unknownCostLines,
      });
    }

    // Sort by profit (highest first)
    saleProfits.sort((a, b) => (b['profit'] as double).compareTo(a['profit'] as double));

    return saleProfits;
  }

  // ==================== Profit Per Day Report ====================

  /// Get daily profit breakdown over a date range
  Future<List<Map<String, dynamic>>> getProfitPerDayReport({DateTime? startDate, DateTime? endDate}) async {
    final window = await _salesInWindow(startDate, endDate);
    final itemsBySaleId = await _itemsBySaleId();
    final liveCost = await _liveCostByVariantId();

    // Group by day
    final Map<String, Map<String, dynamic>> dailyProfits = {};

    // Returns included, so a refund pulls its own day down instead of vanishing.
    for (final sale in window.all) {
      final sign = RetailSaleFilter.revenueSign(sale);
      final saleDate = _reportedAt(sale);
      if (saleDate == null) continue;
      final dayKey = DateTime(saleDate.year, saleDate.month, saleDate.day).toIso8601String();

      if (!dailyProfits.containsKey(dayKey)) {
        dailyProfits[dayKey] = {
          'date': dayKey,
          'totalSales': 0,
          'totalRevenue': 0.0,
          'totalCost': 0.0,
          'totalProfit': 0.0,
          'profitMargin': 0.0,
          'totalItems': 0,
        };
      }

      final saleItems = itemsBySaleId[sale.saleId] ?? const <SaleItemModel>[];

      double saleCost = 0.0;
      for (final item in saleItems) {
        final unitCost = _unitCostOf(item, liveCost);
        if (unitCost == null) continue;
        saleCost += unitCost * item.qty * sign;
      }

      // Header amounts are already negated on a return; ex-tax so the day's
      // profit doesn't count collected GST as margin.
      final saleRevenue = sale.totalAmount - sale.taxAmount;

      final day = dailyProfits[dayKey]!;
      day['totalSales'] += sign;
      day['totalRevenue'] += saleRevenue;
      day['totalCost'] += saleCost;
      day['totalProfit'] += saleRevenue - saleCost;
      day['totalItems'] += sale.totalItems * sign;
    }

    // Calculate profit margin for each day
    final statsList = dailyProfits.values.map((stat) {
      final revenue = stat['totalRevenue'] as double;
      final profit = stat['totalProfit'] as double;

      return {
        ...stat,
        'profitMargin': revenue != 0 ? (profit / revenue) * 100 : 0.0,
      };
    }).toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    return statsList;
  }

  // ==================== PURCHASING REPORTS (shared helpers) ====================

  /// [_inWindow] for records that store their timestamp as an ISO string.
  /// An unparseable value is treated as outside any explicit window.
  bool _withinRange(String? iso, DateTime? start, DateTime? end) {
    if (start == null && end == null) return true;
    final at = DateTime.tryParse(iso ?? '');
    if (at == null) return false;
    return _inWindow(at, start, end);
  }

  /// Confirmed receipts only — a draft GRN has moved no stock and owes no
  /// money, so it must never reach a report.
  List<GRNModel> _confirmedGRNs({DateTime? startDate, DateTime? endDate}) {
    return purchaseOrderStore.grns
        .where((g) =>
            g.statusEnum == GRNStatus.confirmed &&
            _withinRange(g.receivedDate, startDate, endDate))
        .toList()
      ..sort((a, b) => b.receivedDate.compareTo(a.receivedDate));
  }

  /// Damaged value per GRN. GRN headers only carry accepted value, so the
  /// damaged side has to come from the line items.
  /// Damaged value per GRN, split by whether it can still come back.
  ///
  /// Derived from the damaged-goods DOCUMENTS, not from the GRN line's
  /// `damagedHandling`. Handling is chosen once at receipt, but the outcome is
  /// decided later — a claim can be rejected weeks on. Reading the documents
  /// makes the report self-correct as statuses change; reading the line would
  /// freeze a rejected claim as recoverable forever.
  ///
  /// A rejected claim that has already been written off is counted through its
  /// loss records instead, so the same value never lands in `absorbed` twice.
  Map<String, _DamagedRecovery> _damagedRecoveryByGRN() {
    final byGRN = <String, _DamagedRecovery>{};
    _DamagedRecovery entry(String grnId) =>
        byGRN.putIfAbsent(grnId, () => _DamagedRecovery());

    for (final r in damagedGoodsStore.purchaseReturns) {
      // A cancelled return means the goods never went back, so the value the
      // receipt billed stays with the business.
      if (r.statusEnum == PurchaseReturnStatus.cancelled) {
        entry(r.grnId).absorbed += r.totalAmount;
      } else {
        entry(r.grnId).recoverable += r.totalAmount;
      }
    }

    for (final c in damagedGoodsStore.supplierClaims) {
      if (c.statusEnum != SupplierClaimStatus.rejected) {
        entry(c.grnId).recoverable += c.totalAmount;
      } else if (!c.isLossRecorded) {
        // Written-off rejections are counted via their loss rows below.
        entry(c.grnId).absorbed += c.totalAmount;
      }
    }

    for (final l in damagedGoodsStore.inventoryLosses) {
      final grnId = l.grnId;
      if (grnId == null) continue;
      entry(grnId).absorbed += l.lossValue;
    }

    return byGRN;
  }

  /// Units received against a PO across its confirmed GRNs.
  int _receivedQtyForPO(String poId) {
    return purchaseOrderStore.grns
        .where((g) => g.poId == poId && g.statusEnum == GRNStatus.confirmed)
        .fold<int>(0, (sum, g) => sum + g.totalReceivedQty);
  }

  /// Value billed against a PO across its confirmed GRNs — the supplier's
  /// invoice value, damaged units included.
  double _receivedValueForPO(String poId) {
    return purchaseOrderStore.grns
        .where((g) => g.poId == poId && g.statusEnum == GRNStatus.confirmed)
        .fold<double>(0, (sum, g) => sum + (g.totalAmount ?? 0));
  }

  // ==================== Purchase Summary Report ====================

  /// Headline purchasing numbers for a period: what was ordered, what actually
  /// arrived, and what it cost.
  Future<Map<String, dynamic>> getPurchaseSummaryReport(
      {DateTime? startDate, DateTime? endDate}) async {
    final orders = purchaseOrderStore.purchaseOrders
        .where((po) => _withinRange(po.createdAt, startDate, endDate))
        .toList();

    final receipts = _confirmedGRNs(startDate: startDate, endDate: endDate);
    final damagedByGRN = _damagedRecoveryByGRN();

    // Every status, including draft and cancelled — this breakdown is meant to
    // account for all of them.
    final countByStatus = <String, int>{};
    for (final status in POStatus.values) {
      countByStatus[status.name] =
          orders.where((po) => po.statusEnum == status).length;
    }

    // ...but the ordered aggregates must not. A draft was never placed and a
    // cancelled order was un-placed, so counting either as money ordered made
    // the ordered-vs-received gap look like a supplier failure.
    final placedOrders = orders
        .where((po) =>
            po.statusEnum != POStatus.draft &&
            po.statusEnum != POStatus.cancelled)
        .toList();

    final damagedRecoverable = receipts.fold<double>(
        0, (sum, g) => sum + (damagedByGRN[g.grnId]?.recoverable ?? 0));
    final damagedAbsorbed = receipts.fold<double>(
        0, (sum, g) => sum + (damagedByGRN[g.grnId]?.absorbed ?? 0));

    // Value still expected on orders that are placed but not fully received.
    final outstandingValue = orders
        .where((po) =>
            po.statusEnum == POStatus.sent ||
            po.statusEnum == POStatus.partiallyCompleted)
        .fold<double>(
            0,
            (sum, po) =>
                sum +
                (po.estimatedTotal - _receivedValueForPO(po.poId))
                    .clamp(0, double.infinity))
        .toDouble();

    return {
      'orderCount': placedOrders.length,
      'countByStatus': countByStatus,
      'receiptCount': receipts.length,
      'orderedQty': placedOrders.fold<int>(0, (sum, po) => sum + po.totalItems),
      'receivedQty':
          receipts.fold<int>(0, (sum, g) => sum + g.totalReceivedQty),
      'orderedValue':
          placedOrders.fold<double>(0, (sum, po) => sum + po.estimatedTotal),
      'receivedValue':
          receipts.fold<double>(0, (sum, g) => sum + (g.totalAmount ?? 0)),
      'damagedValue': damagedRecoverable + damagedAbsorbed,
      'damagedRecoverable': damagedRecoverable,
      'damagedAbsorbed': damagedAbsorbed,
      'outstandingValue': outstandingValue,
      'supplierCount': receipts.map((g) => g.supplierId).toSet().length,
    };
  }

  // ==================== Purchase Order Status Report ====================

  /// Purchase orders in one status, with their receiving progress.
  ///
  /// Backs the Pending / Partially Received / Completed reports — same shape,
  /// different [status].
  Future<List<Map<String, dynamic>>> getPurchaseOrderStatusReport(
    POStatus status, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final orders = purchaseOrderStore.purchaseOrders
        .where((po) =>
            po.statusEnum == status &&
            _withinRange(po.createdAt, startDate, endDate))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return orders.map((po) {
      final received = _receivedQtyForPO(po.poId);
      return {
        'poId': po.poId,
        'poNumber': po.poNumber,
        'supplierName': po.supplierName ?? 'Unknown Supplier',
        'createdAt': po.createdAt,
        'expectedDeliveryDate': po.expectedDeliveryDate,
        'orderedQty': po.totalItems,
        'receivedQty': received,
        'remainingQty': (po.totalItems - received).clamp(0, po.totalItems),
        'estimatedTotal': po.estimatedTotal,
        'receivedValue': _receivedValueForPO(po.poId),
        'status': po.status,
      };
    }).toList();
  }

  // ==================== GRN Report ====================

  /// Every confirmed goods receipt in the period.
  Future<List<Map<String, dynamic>>> getGRNReport(
      {DateTime? startDate, DateTime? endDate}) async {
    final receipts = _confirmedGRNs(startDate: startDate, endDate: endDate);
    final items = await GRNItemRepository().getAllGRNItems();

    final acceptedByGRN = <String, int>{};
    final damagedByGRN = <String, int>{};
    for (final item in items) {
      acceptedByGRN[item.grnId] =
          (acceptedByGRN[item.grnId] ?? 0) + item.acceptedQty;
      damagedByGRN[item.grnId] =
          (damagedByGRN[item.grnId] ?? 0) + (item.damagedQty ?? 0);
    }

    return receipts
        .map((grn) => {
              'grnId': grn.grnId,
              'grnNumber': grn.grnNumber,
              'poNumber': grn.poNumber,
              'supplierName': grn.supplierName ?? 'Unknown Supplier',
              'receivedDate': grn.receivedDate,
              'invoiceNumber': grn.invoiceNumber,
              'orderedQty': grn.totalOrderedQty,
              'receivedQty': grn.totalReceivedQty,
              'acceptedQty': acceptedByGRN[grn.grnId] ?? 0,
              'damagedQty': damagedByGRN[grn.grnId] ?? 0,
              'totalAmount': grn.totalAmount ?? 0.0,
            })
        .toList();
  }

  // ==================== Damaged Items Report ====================

  /// Every damaged line across confirmed receipts, with what was decided.
  ///
  /// Supplier and date live on the GRN header, so the lines are joined back to
  /// their receipt.
  Future<List<Map<String, dynamic>>> getDamagedItemsReport(
      {DateTime? startDate, DateTime? endDate}) async {
    final receipts = {
      for (final g in _confirmedGRNs(startDate: startDate, endDate: endDate))
        g.grnId: g
    };
    final items = await GRNItemRepository().getAllGRNItems();

    final rows = <Map<String, dynamic>>[];
    for (final item in items) {
      if ((item.damagedQty ?? 0) <= 0) continue;
      final grn = receipts[item.grnId];
      if (grn == null) continue; // outside the period, or an unconfirmed GRN

      rows.add({
        'grnItemId': item.grnItemId,
        'grnNumber': grn.grnNumber,
        'poNumber': grn.poNumber,
        'supplierName': grn.supplierName ?? 'Unknown Supplier',
        'receivedDate': grn.receivedDate,
        'productName': item.productName ?? 'Unknown Product',
        'variantInfo': item.variantInfo,
        'damagedQty': item.damagedQty ?? 0,
        'costPrice': item.costPrice,
        'damagedAmount': item.damagedAmount ?? 0.0,
        'handling': item.damagedHandlingEnum?.name,
        'handlingDisplay': item.damagedHandlingDisplay,
      });
    }

    rows.sort((a, b) =>
        (b['receivedDate'] as String).compareTo(a['receivedDate'] as String));
    return rows;
  }

  // ==================== Purchase Return Report ====================

  /// Goods sent back to suppliers, and where each credit note stands.
  Future<List<Map<String, dynamic>>> getPurchaseReturnReport(
      {DateTime? startDate, DateTime? endDate}) async {
    final returns = damagedGoodsStore.purchaseReturns
        .where((r) => _withinRange(r.returnDate, startDate, endDate))
        .toList()
      ..sort((a, b) => b.returnDate.compareTo(a.returnDate));

    return returns
        .map((r) => {
              'returnId': r.returnId,
              'returnNumber': r.returnNumber,
              'grnNumber': r.grnNumber,
              'poNumber': r.poNumber,
              'supplierName': r.supplierName ?? 'Unknown Supplier',
              'returnDate': r.returnDate,
              'totalQty': r.totalQty,
              'totalAmount': r.totalAmount,
              'status': r.status,
              'statusDisplay': r.statusDisplay,
              'creditNoteNumber': r.creditNoteNumber,
              'creditNoteAmount': r.creditNoteAmount,
            })
        .toList();
  }

  // ==================== Stock Adjustment Report ====================

  /// Every manual stock adjustment in the window, newest first.
  ///
  /// This is the audit trail for the one stock movement that has no document
  /// behind it. Reads the movement log rather than deriving anything: the log
  /// stores `balanceAfter`, so the before-level is recovered by backing the
  /// signed change out of it — that stays correct even when later movements
  /// have since changed the variant's stock.
  ///
  /// Loss value is intentionally NOT computed here. Whether an adjustment cost
  /// money is decided by its reason at the time it was made, and that decision
  /// is already recorded as an `InventoryLossModel` — see the Damaged Items
  /// report. Recomputing it from today's cost price would disagree with it.
  Future<List<Map<String, dynamic>>> getStockAdjustmentReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final movements = StockAdjustmentService.allAdjustments()
        .where((m) => _inWindow(m.timestamp, startDate, endDate))
        .toList();

    return movements
        .map((m) => {
              'timestamp': m.timestamp.toIso8601String(),
              'itemName': m.itemName,
              'productId': m.itemId,
              'variantId': m.variantId,
              'type': m.type,
              'isIn': m.isIn,
              'quantity': m.quantity.toInt(),
              'signedQuantity': m.signedQuantity.toInt(),
              'balanceAfter': m.balanceAfter.toInt(),
              'balanceBefore': (m.balanceAfter - m.signedQuantity).toInt(),
              'reason': m.reason,
              'note': m.note ?? '',
              'staffName': m.staffName,
            })
        .toList();
  }
}

/// Damaged value for one GRN, split by whether the business can still get it
/// back from the supplier.
///
/// Mutable on purpose — it is accumulated in a single pass over three document
/// lists and never escapes [ReportService].
class _DamagedRecovery {
  /// Open or credited returns, plus claims not yet refused.
  double recoverable = 0;

  /// Write-offs, refused claims and cancelled returns — cost the business keeps.
  double absorbed = 0;

  double get total => recoverable + absorbed;
}
