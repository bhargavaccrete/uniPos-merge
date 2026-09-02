



import 'package:billberrylite/core/config/tax_label_rule.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/credit_payment_model_218.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_model_213.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_return_model_174.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_claim_model_176.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_model_211.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_item_model_214.dart';
import 'package:billberrylite/data/repositories/retail/credit_payment_repository.dart';
import 'package:billberrylite/data/repositories/retail/grn_item_repository.dart';
import 'package:billberrylite/domain/services/retail/gst_service.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart' show kInactiveVariantStatus;
import 'package:billberrylite/domain/services/retail/inventory_service.dart';
import 'package:billberrylite/domain/services/retail/sales_totals.dart';
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
///
/// **Gross and net are named, never implied.** On the totals reports every key
/// declares its own basis: bare keys (`totalRevenue`, `totalTax`,
/// `totalDiscount`) cover forward sales only, `net*` keys include returns. They
/// used to be mixed — revenue folded over forward sales while tax and discount
/// folded over both — and were then rendered as consecutive rows that could not
/// be reconciled. See [RetailSalesTotals], which owns that arithmetic for both
/// the daily and the monthly report.
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

  /// Money lands on paise; quantities keep a digit more than they are ever
  /// displayed with.
  ///
  /// Applied at EMIT time, never per line: rounding each line first would move
  /// a group's total by up to half a paisa per row. Line figures are already
  /// 2dp from the billing engine, so this only strips float noise — the reason
  /// a quantity could surface as `0.30000000000000004`.
  static double _r2(double v) => double.parse(v.toStringAsFixed(2));

  /// The CGST/SGST components of an authoritative [totalGst], reconciled so the
  /// two ALWAYS add back to it exactly at two decimals.
  ///
  /// Every write path stores the halves as two INDEPENDENTLY rounded copies of
  /// `gst / 2` (`SaleItemModel:260`, `GstService:60`,
  /// `RetailBillingService:209`). On an odd paisa those two roundings do not
  /// close: ₹18.05 stores 9.03 and 9.03, which display as ₹18.06 beside a Total
  /// GST of ₹18.05. Summed over a month of lines the gap reaches rupees, and it
  /// is visible on the one report that gets filed.
  ///
  /// Total GST is the authoritative figure — it is what the customer was
  /// charged and what `sale.taxAmount` and the receipt carry. The components
  /// are a presentation split of it, so they are DERIVED here rather than
  /// summed: the first is the ordinary half, the second is whatever is left.
  /// The adjustment is at most ₹0.01 and lands on SGST, deterministically.
  ///
  /// Sign is preserved — a credit note's negative GST yields two negative
  /// components that still sum to it.
  static ({double cgst, double sgst}) _splitGst(double totalGst) {
    final cgst = _r2(totalGst / 2);
    return (cgst: cgst, sgst: _r2(totalGst - cgst));
  }
  static double _r3(double v) => double.parse(v.toStringAsFixed(3));

  /// Deterministic order for a line-level report row: revenue desc, then
  /// quantity desc, then the group's own id ascending.
  ///
  /// Revenue alone is not enough. `List.sort` is NOT stable in Dart, so two rows
  /// on the same revenue fell in whatever order `getAllSaleItems()` happened to
  /// return their lines — which meant Top Selling's rank could change between
  /// two loads of one period, and could even change which product made the cut.
  /// Quantity, then the id, break the tie on values that do not move.
  ///
  /// [idKey] is the report's own grouping key: `productId`, `variantId` or
  /// `categoryId`. Ordering only — no figure is altered.
  static int _byRevenueDesc(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
    String idKey,
  ) {
    final byRevenue =
        (b['totalRevenue'] as num).compareTo(a['totalRevenue'] as num);
    if (byRevenue != 0) return byRevenue;
    final byQuantity =
        (b['totalQuantity'] as num).compareTo(a['totalQuantity'] as num);
    if (byQuantity != 0) return byQuantity;
    return (a[idKey] as String).compareTo(b[idKey] as String);
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

    return {
      'date': date,
      ...RetailSalesTotals.compute(
        forward: window.forward,
        returns: window.returns,
        skippedRows: window.skippedRows,
      ),
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

    // Day-by-day trend, net of returns: a refund pulls its own day down rather
    // than vanishing. Return headers are already negative, so adding them is
    // the netting.
    //
    // Nothing renders this yet — it is kept as the ready-made series for a
    // monthly trend chart, which is the only reason it is still computed.
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
      // Same builder as the daily report, so the two can never drift apart
      // again — they were copies of one another, bugs included.
      ...RetailSalesTotals.compute(
        forward: window.forward,
        returns: window.returns,
        skippedRows: window.skippedRows,
      ),
      'dailyBreakdown': dailyBreakdown,
    };
  }

  // ==================== Product-wise Sales Report ====================

  /// The line-level contract shared by the product, variant and category
  /// reports. All three run it; only the grouping key and the row's descriptive
  /// fields differ.
  ///
  /// - **line**      — every `SaleItemModel` whose sale falls in the window
  /// - **sign**      — `RetailSaleFilter.revenueSign`; return LINES are stored
  ///                   positive, so the sign is what nets them
  /// - **quantity**  — `Σ qty × sign`, a double: retail sells by weight
  /// - **revenue**   — `Σ total × sign`. `total` is `taxable + gst`, so it is
  ///                   tax-INCLUSIVE and discount-applied, and it EXCLUDES
  ///                   round-off, which lives only on the sale header. That is
  ///                   the whole of the gap against Daily/Monthly revenue, and
  ///                   it must not be allocated down to lines.
  /// - **discount**  — `Σ discountAmount × sign`; already the line's own share
  ///                   plus its portion of the bill discount, allocated by the
  ///                   billing engine. Nothing to re-derive.
  /// - **tax**       — `Σ taxAmount × sign`; `fromCalculated` writes
  ///                   `taxAmount = gstAmount` on forward AND return lines, so
  ///                   refunds net correctly.
  ///
  /// Deliberately three functions rather than one for now: the sharing question
  /// is open until these reports are corrected and covered.

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
          'totalQuantity': 0.0,
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

    // Rounded here, then sorted, so the order matches the figures shown.
    final statsList = productStats.values.map(_rounded).toList()
      ..sort((a, b) => _byRevenueDesc(a, b, 'productId'));

    return statsList;
  }

  /// Emit-time rounding for a line-level row. Leaves every other key alone.
  /// A breakdown row with its `cgst`/`sgst` replaced by the reconciled split of
  /// its own `totalGst`. Each By Rate and By Category card prints its two
  /// components above its own total, so each row has to close on its own.
  static Map<String, dynamic> _reconciledSplit(Map<String, dynamic> row) {
    final parts = _splitGst(row['totalGst'] as double);
    return {...row, 'cgst': parts.cgst, 'sgst': parts.sgst};
  }

  static Map<String, dynamic> _rounded(Map<String, dynamic> row) => {
        ...row,
        'totalQuantity': _r3(row['totalQuantity'] as double),
        'totalRevenue': _r2(row['totalRevenue'] as double),
        'totalDiscount': _r2(row['totalDiscount'] as double),
        'totalTax': _r2(row['totalTax'] as double),
      };

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
          'totalQuantity': 0.0,
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

    // Rounded here, then sorted, so the order matches the figures shown.
    final statsList = variantStats.values.map(_rounded).toList()
      ..sort((a, b) => _byRevenueDesc(a, b, 'variantId'));

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
                'totalQuantity': 0.0,
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
      return _rounded({
        'categoryId': stat['categoryId'],
        'category': stat['category'],
        'totalQuantity': stat['totalQuantity'],
        'totalRevenue': stat['totalRevenue'],
        'totalDiscount': stat['totalDiscount'],
        'totalTax': stat['totalTax'],
        'productCount': (stat['productCount'] as Set<String>).length,
      });
    }).toList()
      ..sort((a, b) => _byRevenueDesc(a, b, 'categoryId'));

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
    final recovery = _damagedRecoveryInWindow(startDate, endDate);

    final stats = <String, Map<String, dynamic>>{};

    for (final grn in receipts) {
      final supplier = suppliers
          .where((s) => s.supplierId == grn.supplierId)
          .firstOrNull;

      // Historical identity: the receipt's OWN snapshot wins, so renaming a
      // supplier today cannot rename last year's purchases. `supplierName` is
      // denormalized onto the GRN for exactly this reason. Falls back to the
      // live record (a GRN restored without the field), then to a placeholder.
      //
      // Blank counts as absent: `??` alone passes an empty or whitespace-only
      // name straight through and renders an empty cell.
      final snapshot = (grn.supplierName ?? '').trim();
      final current = (supplier?.name ?? '').trim();
      final resolvedName = snapshot.isNotEmpty
          ? snapshot
          : (current.isNotEmpty ? current : 'Unknown Supplier');

      final entry = stats.putIfAbsent(
        // Grouping stays on the ID: two suppliers sharing a name must never
        // merge, and one supplier's receipts must never split on a rename.
        grn.supplierId,
        () => {
          'supplierId': grn.supplierId,
          'supplierName': resolvedName,
          'receiptCount': 0,
          'totalItems': 0.0,
          'totalAmount': 0.0,
          'damagedAmount': 0.0,
          'damagedExpected': 0.0,
          'damagedRecovered': 0.0,
          'damagedAbsorbed': 0.0,
        },
      );

      entry['receiptCount'] = (entry['receiptCount'] as int) + 1;
      entry['totalItems'] =
          (entry['totalItems'] as num).toDouble() + grn.totalReceivedQty;
      entry['totalAmount'] =
          (entry['totalAmount'] as double) + (grn.totalAmount ?? 0);
    }

    // Recovery is merged by SUPPLIER on its own event date, not by receipt. A
    // supplier can therefore appear in this window purely because a return was
    // raised or a credit landed, with no goods received — which is the point:
    // a January receipt credited in March belongs to March.
    for (final e in recovery.entries) {
      final row = stats.putIfAbsent(
        e.key,
        () => {
          'supplierId': e.key,
          'supplierName': e.value.supplierName ?? 'Unknown Supplier',
          'receiptCount': 0,
          'totalItems': 0.0,
          'totalAmount': 0.0,
          'damagedAmount': 0.0,
          'damagedExpected': 0.0,
          'damagedRecovered': 0.0,
          'damagedAbsorbed': 0.0,
        },
      );
      row['damagedExpected'] =
          (row['damagedExpected'] as double) + e.value.expected;
      row['damagedRecovered'] =
          (row['damagedRecovered'] as double) + e.value.recovered;
      row['damagedAbsorbed'] =
          (row['damagedAbsorbed'] as double) + e.value.absorbed;
      row['damagedAmount'] = (row['damagedAmount'] as double) + e.value.total;
    }

    // Amount alone is not a total order: `List.sort` is not stable in Dart, so
    // two suppliers on the same spend fell in whatever order the GRN box
    // happened to yield, and the screen and its export could disagree between
    // loads. Units, then the supplier id, break the tie on values that do not
    // move.
    return stats.values.toList()
      ..sort((a, b) {
        final byAmount =
            (b['totalAmount'] as num).compareTo(a['totalAmount'] as num);
        if (byAmount != 0) return byAmount;
        final byUnits =
            (b['totalItems'] as num).compareTo(a['totalItems'] as num);
        if (byUnits != 0) return byUnits;
        return (a['supplierId'] as String).compareTo(b['supplierId'] as String);
      });
  }

  // ==================== Low Stock Report ====================

  /// Get low stock report
  Future<List<Map<String, dynamic>>> getLowStockReport({int threshold = 10}) async {
    // The catalogue hydrates asynchronously from ProductStore's constructor,
    // and `products` below is the OBSERVABLE while the variants are read from
    // the repository. Without this await a cold open could see every variant
    // and zero products, produce no rows, and render the success state — "All
    // products are well stocked" — over a catalogue that had simply not loaded.
    // Same guard, same reason, as `RetailNotificationSyncService`.
    await productStore.ensureLoaded();

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
        // A DEACTIVATED variant is not actionable: it has been withdrawn, so it
        // will sit at zero forever and can never be reordered. It used to be
        // flagged here and — because `StockAlertService` reads these same rows —
        // raised as a low-stock NOTIFICATION for the life of the store, with no
        // way to clear it short of deleting the variant.
        //
        // Excluding rather than filtering to `isSellable`, deliberately:
        // `isSellable` is `status == 'active'`, and `VarianteModel` documents
        // `out_of_stock` as a third value. Keeping only 'active' would drop the
        // out-of-stock rows, which are the most urgent ones this report exists
        // to show. Only an explicit 'inactive' is withdrawn.
        if (variant.status == kInactiveVariantStatus) continue;

        // A variant's own minStock wins over the global threshold, matching
        // productStore.reorderPointFor — otherwise the Stock Alerts card and
        // the inventory colouring would disagree about the same variant.
        // Always a `double`. `minStock` is a double and `threshold` an int, so
        // this used to emit a double for a variant-level reorder point and an
        // int for the global fallback — two runtime types in one column, which
        // rendered as "5.0" beside "10" and would throw on any `as int`.
        final reorderPoint = variant.minStock ?? threshold.toDouble();
        // Bundle-type variants have no stock of their own — `variant.stockQty`
        // is meaningless for them. "How many can actually be sold" (bounded by
        // component stock) is what the reorder threshold should compare
        // against instead. See docs/retail_inventory_system_plan.md §3.3.
        final isBundle = product.isBundle;
        final effectiveStock = isBundle
            ? RetailInventoryService.calculateAvailableToSell(product, variant)
            : variant.stockQty;
        if (effectiveStock <= reorderPoint) {
          lowStockItems.add({
            'productId': product.productId,
            'productName': product.productName,
            'variantId': variant.varianteId,
            'variantLabel':
                attributeStore.describeAttributes(attributeStore.attributesOf(variant)),
            'currentStock': effectiveStock,
            'isBundle': isBundle,
            'reorderPoint': reorderPoint,
            'costPrice': variant.costPrice,
            'mrp': variant.mrp,
            'barcode': variant.barcode,
          });
        }
      }
    }

    // Lowest stock first, then the variant id. Stock alone is not a total
    // order and `List.sort` is not stable, so a catalogue with many
    // zero-stock variants reordered between loads — and between the screen and
    // its own export, which reads this same list.
    lowStockItems.sort((a, b) {
      final byStock =
          (a['currentStock'] as num).compareTo(b['currentStock'] as num);
      if (byStock != 0) return byStock;
      return (a['variantId'] as String).compareTo(b['variantId'] as String);
    });

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
          // Source-prefixed unique key, for the tie-break below. `reference`
          // cannot serve: it holds a staff NAME on a manual movement.
          'id': 'sale:${sale.saleId}',
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
        'id': 'sale:${sale.saleId}',
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
        'id': 'movement:${m.id}',
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
        'id': 'expense:${e.id}',
        'at': e.dateandTime,
        'type': 'Expense',
        'description':
            e.reason == null || e.reason!.isEmpty ? 'Expense' : e.reason!,
        'amount': -e.amount,
        'reference': '',
      });
    }

    // Newest first, then the row's own id. A timestamp is not a total order —
    // two cash sales in the same second, or a sale and a movement sharing one,
    // reordered between loads because `List.sort` is not stable. The screen and
    // the export read this same list, so both are pinned by one decision.
    rows.sort((a, b) {
      final byTime = (b['at'] as DateTime).compareTo(a['at'] as DateTime);
      if (byTime != 0) return byTime;
      return (a['id'] as String).compareTo(b['id'] as String);
    });
    return rows;
  }

  // ==================== Credit Reports ====================

  /// Credit sales for a period — the Credit Sales tab.
  ///
  /// Exists so the credit tabs go through the SAME window rule as every other
  /// retail report: [_withinRange] applies the caller's bounds AND the plan's
  /// `reports.history_limit_days` cutoff. Reading `SaleRepository` directly, as
  /// the screen used to, skipped the cutoff entirely — a plan limited to 30
  /// days of history still showed every credit sale ever made.
  ///
  /// Filtered on `createdAt`, the basis every other report uses. The repository
  /// still owns the ORDER (newest first, sale id as the tie-break).
  Future<List<SaleModel>> getCreditSalesReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final all = await saleStore.getCreditSales();
    return all
        .where((sale) => _withinRange(sale.createdAt, startDate, endDate))
        .toList();
  }

  /// Credit collections for a period — the Collections tab.
  ///
  /// Same window rule as [getCreditSalesReport]. Payments carry a single date,
  /// so that is what is judged. Write-off and return-adjustment rows are kept
  /// here — the tab LISTS them — and excluded from the money totals by
  /// `CreditPaymentRepository.bucketCollections`, which is the one place that
  /// decides what counts as collected.
  Future<List<CreditPaymentModel>> getCreditCollectionsReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final all = await CreditPaymentRepository().getAllPayments();
    return all
        .where((payment) => _withinRange(payment.date, startDate, endDate))
        .toList();
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
    // Keyed on the RATE, not on a formatted label. Keying on `rate.toInt()`
    // merged 12% and 12.5% into one "12%" band whose badge then showed
    // whichever rate arrived first, while `byRate` kept them apart — the same
    // screen gave two different answers.
    final byCategory = <double, Map<String, dynamic>>{};

    // No cgst/sgst accumulators: the components are derived from the totals
    // below, not summed from the per-line halves. See `_splitGst`.
    double totalTaxable = 0, totalGst = 0;
    // B-4: signed UNITS, so a credit note subtracts. `lineCount` below counts
    // rows and cannot do that.
    double totalQuantity = 0;

    for (final (:item, :sign) in lines) {
      final rate = item.gstRate ?? 0;
      final taxable = (item.taxableAmount ?? 0) * sign;
      final gst = (item.gstAmount ?? 0) * sign;

      totalTaxable += taxable;
      totalGst += gst;
      totalQuantity += item.qty * sign;

      final rateRow = byRate.putIfAbsent(
          rate,
          () => {
                'rate': rate,
                'itemCount': 0,
                'taxableAmount': 0.0,
                // Placeholders. Filled by `_reconciledSplit` at emit time from
                // this row's own `totalGst`, never accumulated.
                'cgst': 0.0,
                'sgst': 0.0,
                'totalGst': 0.0,
              });
      rateRow['itemCount'] += sign;
      rateRow['taxableAmount'] += taxable;
      rateRow['totalGst'] += gst;

      final productRow = byProduct.putIfAbsent(
          item.productId,
          () => {
                'productId': item.productId,
                'productName': item.productName ?? 'Unknown',
                // A `double`: retail sells by weight, and seeding an `int`
                // made the field's runtime type depend on whether any line had
                // been added yet.
                'quantity': 0.0,
                'taxableAmount': 0.0,
                'totalGst': 0.0,
              });
      productRow['quantity'] += item.qty * sign;
      productRow['taxableAmount'] += taxable;
      productRow['totalGst'] += gst;

      // Rate band standing in for a category, as the screen already did.
      final categoryRow = byCategory.putIfAbsent(
          rate,
          () => {
                // Country-aware NAME only — the grouping, the rate and every
                // amount below are identical everywhere. The rate is formatted,
                // not floored, so 12.5% reads "12.5%" and stays its own band.
                'categoryName':
                    '${TaxLabelRule.name} ${GstService.formatGstRate(rate)} Items',
                'gstRate': rate,
                'itemCount': 0,
                'taxableAmount': 0.0,
                // Placeholders — see the byRate seed above.
                'cgst': 0.0,
                'sgst': 0.0,
                'totalGst': 0.0,
              });
      categoryRow['itemCount'] += sign;
      categoryRow['taxableAmount'] += taxable;
      categoryRow['totalGst'] += gst;
    }

    return {
      'saleCount': window.forward.length,
      'returnCount': window.returns.length,
      'lineCount': lines.length,
      'totalTaxableAmount': totalTaxable,
      'totalGstAmount': totalGst,
      // Derived from the total, so the three figures the Summary card prints
      // under one divider actually add up.
      'totalCgstAmount': _splitGst(totalGst).cgst,
      'totalSgstAmount': _splitGst(totalGst).sgst,
      'totalQuantity': totalQuantity,
      // Ascending, decided HERE. Returned in map-insertion order, the Summary
      // tab listed rates in whatever order their first line happened to appear
      // in the box while the By Rate tab sorted them — two orders for one list,
      // and the Summary one shifted as new sales arrived.
      'byRate': (byRate.values.map(_reconciledSplit).toList()
        ..sort((a, b) => (a['rate'] as double).compareTo(b['rate'] as double))),
      // ORDER IS DECIDED HERE, for all three breakdowns, so the screen just
      // renders what it is handed and no two surfaces can disagree.
      'byProduct': (byProduct.values.map((row) {
        final taxable = row['taxableAmount'] as double;
        final gst = row['totalGst'] as double;
        return {
          ...row,
          // Effective rate, not a mean of the rates seen. Averaging the rates
          // ignores line size, and stays stable once returns can make a
          // line count negative.
          'avgGstRate': taxable != 0 ? (gst / taxable) * 100 : 0.0,
        };
      }).toList()
        // Most tax first, then the product id. Tax alone is not a total order
        // and `List.sort` is not stable, so tied products reordered between
        // loads.
        ..sort((a, b) {
          final byTax =
              (b['totalGst'] as double).compareTo(a['totalGst'] as double);
          if (byTax != 0) return byTax;
          return (a['productId'] as String).compareTo(b['productId'] as String);
        })),
      // Same rule as byProduct; the rate is the tie-break because a band's
      // name is derived from it.
      'byCategory': (byCategory.values.map(_reconciledSplit).toList()
        ..sort((a, b) {
          final byTax =
              (b['totalGst'] as double).compareTo(a['totalGst'] as double);
          if (byTax != 0) return byTax;
          return (a['gstRate'] as double).compareTo(b['gstRate'] as double);
        })),
      'skippedRows': window.skippedRows,
    };
  }

  // ==================== Top Selling Products Report ====================

  /// Get top selling products
  Future<List<Map<String, dynamic>>> getTopSellingProductsReport({int limit = 20, DateTime? startDate, DateTime? endDate}) async {
    final productWiseReport = await getProductWiseSalesReport(startDate: startDate, endDate: endDate);
    // Eligibility: a product that was returned as much as it sold, or more, has
    // not sold on balance and is not a top seller.
    //
    // Filtered BEFORE `take`: reversing these lets an excluded row consume one
    // of the N slots, so a "top 20" would come back holding fewer than 20
    // eligible products. Rows are already rounded here, so a residual fraction
    // of a paisa correctly reads as zero.
    //
    // Top Selling only. Product-wise still reports every product, these
    // included.
    return productWiseReport
        .where((row) => (row['totalRevenue'] as num) > 0)
        .take(limit)
        .toList();
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
          'totalQuantitySold': 0.0,
          'totalRevenue': 0.0,
          'totalCost': 0.0,
          'totalProfit': 0.0,
          'profitMargin': 0.0,
          'avgSellingPrice': 0.0,
          // Null, not 0.0 — "no cost on record" and "costs nothing" are
          // different facts and the screen needs to be able to tell them apart.
          'costPrice': unitCost,
          'unknownCostLines': 0,
          'unknownCostRevenue': 0.0,
        };
      }

      final revenue = _netRevenueOf(item) * sign;
      final stat = itemProfits[item.varianteId]!;

      stat['totalQuantitySold'] += item.qty * sign;
      stat['totalRevenue'] += revenue;

      // Cost only when it is known; profit is derived at the end from the two
      // totals. Accumulating profit HERE, inside the else, meant revenue
      // counted every line while profit counted only the costed ones — so a
      // variant with a mix failed its own `profit == revenue - cost`, and its
      // margin was understated by the whole un-costed amount.
      if (unitCost == null) {
        stat['unknownCostLines'] += 1;
        stat['unknownCostRevenue'] += revenue;
      } else {
        stat['totalCost'] += unitCost * item.qty * sign;
      }
    }

    // Calculate profit margin and average selling price
    final statsList = itemProfits.values.map((stat) {
      final revenue = stat['totalRevenue'] as double;
      final qty = (stat['totalQuantitySold'] as num).toDouble();
      // Derived from the two totals, never accumulated alongside them.
      final profit = revenue - (stat['totalCost'] as double);

      return {
        ...stat,
        // Derived, so the row always satisfies profit == revenue - cost.
        'totalProfit': profit,
        // `!= 0`, not `> 0`: a variant returned more than it sold has negative
        // revenue, and `> 0` rendered that loss as a flat 0% break-even.
        'profitMargin': revenue != 0 ? (profit / revenue) * 100 : 0.0,
        'avgSellingPrice': qty != 0 ? revenue / qty : 0.0,
      };
    }).toList()
      // Highest profit first, then the variant id — profit alone is not a
      // total order and `List.sort` is not stable.
      ..sort((a, b) {
        final byProfit =
            (b['totalProfit'] as double).compareTo(a['totalProfit'] as double);
        if (byProfit != 0) return byProfit;
        return (a['variantId'] as String).compareTo(b['variantId'] as String);
      });

    return statsList;
  }

  // ==================== Bundle Margin Report ====================

  /// Margin for each bundle/repack product: its effective selling price
  /// against the summed cost of its components. Unlike the other profit
  /// reports this is NOT tied to a sales window — a bundle's margin is a
  /// pricing question about the current catalogue, not a sales-history one
  /// (mirrors how [getLowStockReport] is also window-less). See
  /// docs/retail_inventory_system_plan.md §3.3.
  Future<List<Map<String, dynamic>>> getBundleMarginReport() async {
    final costByVariantId = <String, double>{
      for (final v in productStore.variants) v.varianteId: v.costPrice ?? 0.0,
    };

    final rows = <Map<String, dynamic>>[];
    for (final product in productStore.products) {
      if (!product.needsBundleComponents) continue;
      final variant = productStore.primaryVariantFor(product.productId);
      if (variant == null) continue;
      final bundle = bundleRepository.getBundleForVariant(variant.varianteId);
      if (bundle == null || !bundle.hasComponents) continue;

      final componentCost =
          bundle.estimatedCost((id) => costByVariantId[id] ?? 0.0);
      final sellingPrice = variant.sellingPrice ?? variant.mrp ?? 0.0;
      final margin = sellingPrice - componentCost;
      final marginPercent =
          sellingPrice != 0 ? (margin / sellingPrice) * 100 : 0.0;

      rows.add({
        'productId': product.productId,
        'productName': product.productName,
        'variantId': variant.varianteId,
        'isRepack': product.isRepack,
        'sellingPrice': sellingPrice,
        'componentCost': componentCost,
        'margin': margin,
        'marginPercent': marginPercent,
        'componentCount': bundle.components.length,
      });
    }

    rows.sort((a, b) =>
        (a['marginPercent'] as double).compareTo(b['marginPercent'] as double));
    return rows;
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

      // LINE basis, matching every other profit tab. This used to read
      // `sale.totalAmount - sale.taxAmount`, which is `taxable + roundOff` —
      // so this tab and the Daily one carried the sale's round-off into profit
      // while Overview and By-Item did not, and the same period showed a
      // different profit depending on which tab you were looking at.
      //
      // Round-off is an adjustment to the customer's payable, attributable to
      // no line and no product's margin, so it stays out of profit. Cost is a
      // pure line figure; revenue has to be on the same footing.
      double totalRevenue = 0.0;
      double totalCost = 0.0;
      var unknownCostLines = 0;
      double unknownCostRevenue = 0.0;
      for (final item in saleItems) {
        // Lines are stored positive even on a return — hence the sign.
        final revenue = _netRevenueOf(item) * sign;
        totalRevenue += revenue;

        final unitCost = _unitCostOf(item, liveCost);
        if (unitCost == null) {
          // Revenue is kept; only the cost is unknown. Surfaced below so a
          // margin built on it can't be mistaken for fully-costed profit.
          unknownCostLines++;
          unknownCostRevenue += revenue;
          continue;
        }
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
        'totalItems': RetailSaleFilter.signedItemCount(sale),
        'totalRevenue': totalRevenue,
        'totalCost': totalCost,
        'profit': profit,
        'profitMargin': profitMargin,
        'paymentType': sale.paymentType,
        'discountAmount': sale.discountAmount,
        'taxAmount': sale.taxAmount,
        'isReturn': RetailSaleFilter.isReturn(sale),
        'unknownCostLines': unknownCostLines,
        'unknownCostRevenue': unknownCostRevenue,
      });
    }

    // Highest profit first, then the sale id. Profit alone is not a total
    // order and `List.sort` is not stable, so tied rows could reorder between
    // loads.
    saleProfits.sort((a, b) {
      final byProfit = (b['profit'] as double).compareTo(a['profit'] as double);
      if (byProfit != 0) return byProfit;
      return (a['saleId'] as String).compareTo(b['saleId'] as String);
    });

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
          'totalItems': 0.0,
          // A day of un-costed sales used to read as 100% margin with nothing
          // said about it — the exact failure `_unitCostOf` exists to prevent.
          'unknownCostLines': 0,
          'unknownCostRevenue': 0.0,
        };
      }

      final saleItems = itemsBySaleId[sale.saleId] ?? const <SaleItemModel>[];

      // LINE basis, matching every other profit tab — see the note in
      // `getProfitPerSaleReport`. The header figure this replaces carried the
      // sale's round-off into the day's profit.
      double saleRevenue = 0.0;
      double saleCost = 0.0;
      var unknownLines = 0;
      double unknownRevenue = 0.0;
      for (final item in saleItems) {
        final revenue = _netRevenueOf(item) * sign;
        saleRevenue += revenue;

        final unitCost = _unitCostOf(item, liveCost);
        if (unitCost == null) {
          unknownLines++;
          unknownRevenue += revenue;
          continue;
        }
        saleCost += unitCost * item.qty * sign;
      }

      final day = dailyProfits[dayKey]!;
      day['totalSales'] += sign;
      day['totalRevenue'] += saleRevenue;
      day['totalCost'] += saleCost;
      day['totalProfit'] += saleRevenue - saleCost;
      day['totalItems'] += RetailSaleFilter.signedItemCount(sale);
      day['unknownCostLines'] += unknownLines;
      day['unknownCostRevenue'] += unknownRevenue;
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
  /// The date rule for every PURCHASE report — POs, GRNs and returns.
  ///
  /// Parse FIRST, always. This used to open with
  /// `if (start == null && end == null) return true;`, which skipped
  /// [_inWindow] entirely — so an all-time query ignored the plan's history
  /// cutoff, and admitted rows whose date could not be read while a bounded
  /// query rejected the very same rows. [_inWindow] already null-guards both
  /// bounds, so it is the whole rule in both cases.
  ///
  /// The sales side had the same defect and it is documented there
  /// (`_salesInWindow`, "it used to sit inside `if (start != null || end !=
  /// null)`"). This is the purchase counterpart.
  bool _withinRange(String? iso, DateTime? start, DateTime? end) {
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
      // Newest first, then the GRN id. `receivedDate` alone is not a total
      // order and `List.sort` is not stable in Dart, so two receipts confirmed
      // in the same instant could swap between loads.
      //
      // Only the GRN Report inherits this order: Supplier-wise re-aggregates
      // and sorts on its own, Purchase Summary only folds, and Damaged Items
      // builds a map from it and sorts its own rows.
      ..sort((a, b) {
        final byDate = b.receivedDate.compareTo(a.receivedDate);
        if (byDate != 0) return byDate;
        return a.grnId.compareTo(b.grnId);
      });
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
  /// A received line with no usable cost price.
  ///
  /// **Zero is the live case, not null.** `ReceivingItemData.costPrice` is a
  /// non-nullable double seeded `estimatedPrice ?? variant.costPrice ?? 0`
  /// (`material_receiving_screen.dart:88`) and the price field parses
  /// `tryParse(text) ?? 0` (`:150`), so a blank price becomes 0 — which then
  /// values the line, the receipt, the supplier accrual and any return raised
  /// from it at nothing. Null only reaches here from legacy or restored rows.
  ///
  /// Both mean the same thing — the cost was never captured — so both are
  /// flagged. Nothing is reconstructed: substituting the variant's current cost
  /// would price a receipt at a figure no invoice supports, and the supplier
  /// ledger has already accrued the zero.
  ///
  /// Lines that received nothing are ignored; an unpriced line only matters
  /// once goods have actually arrived against it.
  static bool _lineUnpriced(GRNItemModel i) =>
      i.receivedQty > 0 && (i.costPrice == null || i.costPrice! <= 0);

  /// GRN ids with at least one unpriced received line.
  ///
  /// Derived once from the item list so every report that surfaces this reads
  /// the same answer — a receipt cannot be flagged on one screen and clean on
  /// another.
  static Set<String> _grnIdsWithUnpricedLines(List<GRNItemModel> items) => {
        for (final i in items)
          if (_lineUnpriced(i)) i.grnId,
      };

  /// A confirmed receipt whose invoice value was never recorded.
  ///
  /// **Null is not zero.** `GRNModel.totalAmount` and the supplier's `purchase`
  /// ledger movement are written from ONE value in ONE block
  /// (`material_receiving_screen.dart:547` and `:753`), so a GRN with no amount
  /// also has no payable — the two absences are the same event. Every report
  /// reads it as `?? 0`, which is honest against the ledger but silently
  /// understates spend, so the condition is surfaced rather than patched.
  ///
  /// Deliberately NOT reconstructed. `Σ item.totalAmount` uses `acceptedQty`
  /// (`grn_item_model_214.dart:135`) while the header bills `receivedQty`, so
  /// it drops the damaged value; and recomputing from `costPrice` would invent
  /// a payable the supplier balance has never seen.
  ///
  /// A stored `0.0` is a legitimate value — a free or sample receipt — and is
  /// never flagged.
  static bool _grnAmountMissing(GRNModel g) => g.totalAmount == null;

  /// Damage recovery for a window, grouped by SUPPLIER, with every document
  /// judged on ITS OWN event date.
  ///
  /// This replaces a per-GRN lookup that attributed every return, claim and
  /// write-off to the date its GRN was RECEIVED, and applied no date filter at
  /// all. Two things were wrong with that: recovery appeared in a period before
  /// it had happened, and a closed period changed retroactively every time a
  /// later credit note arrived.
  ///
  /// The app already dates these events correctly in the supplier ledger —
  /// `recordCreditNote` posts with `creditNoteDate` and `updateClaimStatus`
  /// posts with `resolvedAt` (`damaged_goods_store.dart:313, :45`). This makes
  /// the reports agree with the ledger.
  ///
  /// **Expected is not Recovered.** A raised return or claim is value the
  /// supplier owes; only a credit note or a settled claim is value actually
  /// received — and a credit note may be for LESS than the return's face value,
  /// so `creditNoteAmount` is what counts as recovered, never `totalAmount`.
  ///
  /// Iterates the DOCUMENTS, not the window's GRNs: February's recovery belongs
  /// to a January receipt that is not in February's window at all.
  ///
  /// Cancelled returns are excluded from all three buckets. The goods never went
  /// back, nothing was credited, and there is no reliable cancellation date to
  /// post against — `updatedAt` moves on any edit, so using it would invent an
  /// accounting event.
  Map<String, _DamagedRecovery> _damagedRecoveryInWindow(
      DateTime? start, DateTime? end) {
    final bySupplier = <String, _DamagedRecovery>{};
    _DamagedRecovery entry(String supplierId, String? name) {
      final e = bySupplier.putIfAbsent(supplierId, () => _DamagedRecovery());
      final trimmed = (name ?? '').trim();
      if (e.supplierName == null && trimmed.isNotEmpty) {
        e.supplierName = trimmed;
      }
      return e;
    }

    for (final r in damagedGoodsStore.purchaseReturns) {
      switch (r.statusEnum) {
        case PurchaseReturnStatus.cancelled:
          break; // never returned, never credited, no dependable date
        case PurchaseReturnStatus.pending:
          if (_withinRange(r.returnDate, start, end)) {
            entry(r.supplierId, r.supplierName).expected += r.totalAmount;
          }
        case PurchaseReturnStatus.creditReceived:
          // The note's face value, which may be less than the return total.
          // A legacy row with no credit date cannot be placed in a period.
          if (_withinRange(r.creditNoteDate, start, end)) {
            entry(r.supplierId, r.supplierName).recovered +=
                r.creditNoteAmount ?? 0;
          }
      }
    }

    for (final c in damagedGoodsStore.supplierClaims) {
      switch (c.statusEnum) {
        case SupplierClaimStatus.pending:
        case SupplierClaimStatus.approved:
          // Approved means the supplier agreed, not that they paid.
          if (_withinRange(c.claimDate, start, end)) {
            entry(c.supplierId, c.supplierName).expected += c.totalAmount;
          }
        case SupplierClaimStatus.settled:
          if (_withinRange(c.resolvedAt, start, end)) {
            entry(c.supplierId, c.supplierName).recovered += c.totalAmount;
          }
        case SupplierClaimStatus.rejected:
          // A written-off rejection is counted through its loss row instead, so
          // the same value never lands in `absorbed` twice.
          if (!c.isLossRecorded && _withinRange(c.resolvedAt, start, end)) {
            entry(c.supplierId, c.supplierName).absorbed += c.totalAmount;
          }
      }
    }

    for (final l in damagedGoodsStore.inventoryLosses) {
      // Only losses raised from a receipt are purchase damage; a stock
      // adjustment loss has no GRN and belongs to inventory, not purchasing.
      if (l.grnId == null) continue;
      final supplierId = l.supplierId;
      if (supplierId == null) continue;
      if (!_withinRange(l.recordedAt, start, end)) continue;
      entry(supplierId, l.supplierName).absorbed += l.lossValue;
    }

    return bySupplier;
  }

  /// Units received against a PO across its confirmed GRNs.
  double _receivedQtyForPO(String poId) {
    return purchaseOrderStore.grns
        .where((g) => g.poId == poId && g.statusEnum == GRNStatus.confirmed)
        .fold<double>(0.0, (sum, g) => sum + g.totalReceivedQty);
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
    final recovery = _damagedRecoveryInWindow(startDate, endDate);
    // One item read so this figure is line-accurate. A receipt with SOME
    // unpriced lines still has a non-zero header total, so a header-only check
    // would miss it — and would then disagree with the GRN Report, which is
    // line-aware.
    final unpricedGRNs =
        _grnIdsWithUnpricedLines(await GRNItemRepository().getAllGRNItems());

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

    // Recovery is judged on each document's OWN event date, so these cover
    // recovery that HAPPENED in this period — not recovery attached to this
    // period's receipts. A January receipt credited in March contributes to
    // March, and January never changes afterwards.
    final damagedExpected =
        recovery.values.fold<double>(0, (sum, r) => sum + r.expected);
    final damagedRecovered =
        recovery.values.fold<double>(0, (sum, r) => sum + r.recovered);
    final damagedAbsorbed =
        recovery.values.fold<double>(0, (sum, r) => sum + r.absorbed);

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
      'orderedQty': placedOrders.fold<double>(0.0, (sum, po) => sum + po.totalItems),
      'receivedQty':
          receipts.fold<double>(0.0, (sum, g) => sum + g.totalReceivedQty),
      'orderedValue':
          placedOrders.fold<double>(0, (sum, po) => sum + po.estimatedTotal),
      'receivedValue':
          receipts.fold<double>(0, (sum, g) => sum + (g.totalAmount ?? 0)),
      'damagedValue': damagedExpected + damagedRecovered + damagedAbsorbed,
      // Expected is owed, not received — never present them as one number.
      'damagedExpected': damagedExpected,
      'damagedRecovered': damagedRecovered,
      'damagedAbsorbed': damagedAbsorbed,
      'outstandingValue': outstandingValue,
      'supplierCount': receipts.map((g) => g.supplierId).toSet().length,
      // Same window and same confirmed-only rule as every figure above it —
      // it counts the very list they were folded from.
      'grnsMissingAmount': receipts.where(_grnAmountMissing).length,
      // Receipts in this window carrying at least one line with no cost price.
      // Their value — and any recovery raised from them — is understated.
      'grnsWithUnpricedLines':
          receipts.where((g) => unpricedGRNs.contains(g.grnId)).length,
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
      // Newest first, then the PO id. `createdAt` alone is not a total order,
      // and `List.sort` is not stable in Dart, so two orders stamped the same
      // instant fell in whatever order the box yielded and could swap between
      // loads — on screen and in the export.
      ..sort((a, b) {
        final byDate = b.createdAt.compareTo(a.createdAt);
        if (byDate != 0) return byDate;
        return a.poId.compareTo(b.poId);
      });

    return orders.map((po) {
      final received = _receivedQtyForPO(po.poId);
      // The PO's own snapshot is the source of truth for the name — a renamed
      // supplier must not relabel historical orders. Blank counts as absent:
      // `??` alone passes a whitespace-only name through and renders an empty
      // cell.
      final snapshot = (po.supplierName ?? '').trim();
      return {
        'poId': po.poId,
        'poNumber': po.poNumber,
        'supplierName': snapshot.isNotEmpty ? snapshot : 'Unknown Supplier',
        'createdAt': po.createdAt,
        'expectedDeliveryDate': po.expectedDeliveryDate,
        'orderedQty': po.totalItems,
        'receivedQty': received,
        // `.toDouble()` is load-bearing: `num.clamp` returns whichever operand
        // it picked, so on an over-receipt this handed back the int literal `0`
        // while every other row was a double. The column carried two runtime
        // types and the screen's `as int` threw on the double ones.
        'remainingQty':
            (po.totalItems - received).clamp(0, po.totalItems).toDouble(),
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

    final unpricedGRNs = _grnIdsWithUnpricedLines(items);

    final acceptedByGRN = <String, double>{};
    final damagedByGRN = <String, double>{};
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
              // `?? 0` handed back the int literal for a GRN with no items
              // while every other row was a double, so the column carried two
              // runtime types and the screen's `as int` threw on the doubles.
              'acceptedQty': acceptedByGRN[grn.grnId] ?? 0.0,
              'damagedQty': damagedByGRN[grn.grnId] ?? 0.0,
              'totalAmount': grn.totalAmount ?? 0.0,
              // At least one received line has no cost price, so this receipt's
              // Value is understated by whatever those units were worth.
              'hasUnpricedLine': unpricedGRNs.contains(grn.grnId),
              // The `?? 0` above is lossy: it makes "never recorded" and
              // "genuinely free" look identical. This keeps them apart so the
              // row report can name the receipt rather than just count it.
              'amountMissing': _grnAmountMissing(grn),
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
        // The GRN's own snapshot names the supplier — a rename must not
        // relabel historical receipts. Blank counts as absent: `??` alone
        // passes a whitespace-only name through and renders an empty cell.
        'supplierName': (grn.supplierName ?? '').trim().isEmpty
            ? 'Unknown Supplier'
            : grn.supplierName!.trim(),
        'receivedDate': grn.receivedDate,
        'productName': item.productName ?? 'Unknown Product',
        'variantInfo': item.variantInfo,
        // Always a double. Rows are filtered to `damagedQty > 0`, so this is
        // never the `?? 0` int literal in practice — but the fallback matches
        // the type anyway, so the column can never carry two runtime types.
        'damagedQty': (item.damagedQty ?? 0).toDouble(),
        'costPrice': item.costPrice,
        // No usable cost, so `damagedAmount` below is 0 and any return or claim
        // raised from this line was created at zero value too.
        'costMissing': _lineUnpriced(item),
        'damagedAmount': item.damagedAmount ?? 0.0,
        'handling': item.damagedHandlingEnum?.name,
        'handlingDisplay': item.damagedHandlingDisplay,
      });
    }

    // Newest first, then the line id. Several damaged lines from ONE receipt
    // share an identical `receivedDate`, so ties are the norm here rather than
    // the exception — and `List.sort` is not stable in Dart.
    //
    // This is the report's OWN sort: `_confirmedGRNs` is consumed as a map
    // above, so its ordering never reaches these rows.
    rows.sort((a, b) {
      final byDate =
          (b['receivedDate'] as String).compareTo(a['receivedDate'] as String);
      if (byDate != 0) return byDate;
      return (a['grnItemId'] as String).compareTo(b['grnItemId'] as String);
    });
    return rows;
  }

  // ==================== Purchase Return Report ====================

  /// Goods sent back to suppliers, and where each credit note stands.
  Future<List<Map<String, dynamic>>> getPurchaseReturnReport(
      {DateTime? startDate, DateTime? endDate}) async {
    final returns = damagedGoodsStore.purchaseReturns
        .where((r) => _withinRange(r.returnDate, startDate, endDate))
        .toList()
      // Newest first, then the return id. `returnDate` alone is not a total
      // order — one receipt can raise several returns in the same instant — and
      // `List.sort` is not stable in Dart, so tied rows could swap between
      // loads, on screen and in the export.
      ..sort((a, b) {
        final byDate = b.returnDate.compareTo(a.returnDate);
        if (byDate != 0) return byDate;
        return a.returnId.compareTo(b.returnId);
      });

    return returns
        .map((r) => {
              'returnId': r.returnId,
              'returnNumber': r.returnNumber,
              'grnNumber': r.grnNumber,
              'poNumber': r.poNumber,
              // The return document's own snapshot names the supplier — a
              // rename must not relabel history. Blank counts as absent: `??`
              // alone passes a whitespace-only name through as an empty cell.
              'supplierName': (r.supplierName ?? '').trim().isEmpty
                  ? 'Unknown Supplier'
                  : r.supplierName!.trim(),
              'returnDate': r.returnDate,
              // Explicitly a double, matching every other quantity the reports
              // emit — goods go back by weight as readily as by the piece.
              'totalQty': r.totalQty.toDouble(),
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
              // Doubles, deliberately. `StockMovementModel.quantity` and
              // `balanceAfter` are `double` and the adjustment dialog lets a
              // loose-goods variant type a fractional amount
              // (`stock_adjustment_dialog.dart:159`), so `.toInt()` here turned
              // a 2.5 kg correction into 2 — silently, with no error to notice.
              //
              // It also broke the row's own arithmetic: `balanceBefore` is
              // derived from the two doubles, so truncating all three
              // separately let Before + Change disagree with After.
              'quantity': m.quantity,
              'signedQuantity': m.signedQuantity,
              'balanceAfter': m.balanceAfter,
              'balanceBefore': m.balanceAfter - m.signedQuantity,
              // Carried from the movement so a weighed correction can read
              // "2.5 kg" rather than a bare number that looks like pieces.
              'unit': m.unit,
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
/// Damage recovery for one supplier in one window, split by what actually
/// happened rather than by what might.
class _DamagedRecovery {
  /// Snapshot name from whichever document was seen first, so a supplier that
  /// appears only through a recovery event can still be labelled.
  String? supplierName;

  /// Raised and owed: an open return, or a claim not yet settled or refused.
  /// **Not money received.**
  double expected = 0;

  /// Actually credited or settled — a credit note's face value, or a settled
  /// claim's total.
  double recovered = 0;

  /// Write-offs and refused claims: cost the business keeps.
  double absorbed = 0;

  double get total => expected + recovered + absorbed;
}
