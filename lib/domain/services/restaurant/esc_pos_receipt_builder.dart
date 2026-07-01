import 'package:intl/intl.dart';
import 'package:billberrylite/domain/services/retail/receipt_pdf_service.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/util/restaurant/print_settings.dart';
import 'package:billberrylite/domain/services/restaurant/tax_breakdown.dart';
import 'package:billberrylite/core/di/service_locator.dart' show taxStore;

/// Builds raw ESC/POS byte arrays for thermal printers.
///
/// This is the ESC/POS equivalent of [ReceiptPdfService]. It takes the same
/// [ReceiptData] object but produces [List<int>] (raw printer bytes) instead
/// of a PDF document. The bytes are sent directly to the printer via
/// [PrinterStore.sendBytes()] — no OS print dialog involved.
///
/// Respects the same [PrintSettings] toggles as the PDF receipt
/// (showOrderId, showTax, showSubtotal, etc.)
class EscPosReceiptBuilder {
  // ════════════════════════════════════════════════════════════════════════
  // ESC/POS COMMAND CONSTANTS
  // These are the printer's "machine language" — byte sequences that
  // control formatting, alignment, and hardware actions.
  // ════════════════════════════════════════════════════════════════════════

  /// ESC @ — Initialize/reset printer to default state
  /// Always send this first to clear any leftover formatting
  static const List<int> _init = [0x1B, 0x40];

  /// ESC a 0/1/2 — Text alignment: left, center, right
  static const List<int> _alignLeft = [0x1B, 0x61, 0x00];
  static const List<int> _alignCenter = [0x1B, 0x61, 0x01];
  /// ESC E 0/1 — Bold off/on
  static const List<int> _boldOn = [0x1B, 0x45, 0x01];
  static const List<int> _boldOff = [0x1B, 0x45, 0x00];

  /// ESC ! n — Select print mode (combines font size flags)
  /// 0x00 = normal, 0x10 = double height, 0x20 = double width, 0x30 = both
  static const List<int> _sizeNormal = [0x1B, 0x21, 0x00];
  static const List<int> _sizeDouble = [0x1B, 0x21, 0x30];
  static const List<int> _sizeDoubleHeight = [0x1B, 0x21, 0x10];

  /// GS V 1 — Partial paper cut (leaves a small strip connecting the paper)
  static const List<int> _cut = [0x1D, 0x56, 0x01];

  /// LF — Line feed (newline)
  static const List<int> _newline = [0x0A];

  // ════════════════════════════════════════════════════════════════════════
  // PUBLIC API — Three build methods matching the three print types
  // ════════════════════════════════════════════════════════════════════════

  /// Build KOT (Kitchen Order Ticket) — items only, NO prices.
  /// The kitchen needs to know WHAT to make, not how much it costs.
  ///
  /// Layout:
  /// ```
  ///      RESTAURANT NAME
  ///      KOT #12 (ADD-ON)
  ///   Table: T3  |  Dine In
  ///   Order #7   |  14:30
  ///   ─────────────────────
  ///   2x Chicken Biryani (Large)
  ///      Extras: Cheese, Raita
  ///      NOTE: No onions
  ///   1x Butter Naan
  ///   ─────────────────────
  ///   Items: 2   Qty: 3
  /// ```
  static List<int> buildKotTicket({
    required ReceiptData receiptData,
    required int paperWidth, // 58 or 80
  }) {
    final cols = _columnsForPaper(paperWidth);
    final bytes = <int>[];

    // Initialize printer — clears any previous formatting
    bytes.addAll(_init);

    if (receiptData.kotStatus?.toUpperCase() == 'CANCEL') {
      bytes.addAll(_alignCenter);
      bytes.addAll(_boldOn);
      bytes.addAll(_sizeDouble);
      bytes.addAll(_text('******** CANCEL KOT ********'));
      bytes.addAll(_sizeNormal);
      bytes.addAll(_boldOff);
      bytes.addAll(_text('\n'));
    }

    // ── HEADER: Store name + KOT number ──
    bytes.addAll(_alignCenter);
    if (PrintSettings.showRestaurantName && receiptData.storeName != null) {
      bytes.addAll(_boldOn);
      bytes.addAll(_sizeDouble);
      bytes.addAll(_text(receiptData.storeName!));
      bytes.addAll(_sizeNormal);
      bytes.addAll(_boldOff);
    }

    // KOT number — always shown (critical for kitchen)
    bytes.addAll(_boldOn);
    bytes.addAll(_sizeDoubleHeight);
    String kotLabel = 'KOT #${receiptData.kotNumber ?? 0}';
    if (receiptData.isAddonKot == true && receiptData.kotStatus?.toUpperCase() != 'CANCEL') {
      kotLabel += ' (ADD-ON)'; // Tells kitchen this isn't the first KOT
    }
    bytes.addAll(_text(kotLabel));
    bytes.addAll(_sizeNormal);
    bytes.addAll(_boldOff);

    // Reference KOT
    if (receiptData.cancelReference != null && receiptData.kotStatus?.toUpperCase() == 'CANCEL') {
      bytes.addAll(_alignCenter);
      bytes.addAll(_text('Reference: ${receiptData.cancelReference}'));
    }

    // ── ORDER INFO: Table, type, order#, time ──
    bytes.addAll(_alignLeft);
    bytes.addAll(_divider(cols));

    // Table + Order Type on one line
    String infoLine = '';
    if (receiptData.tableNo != null && receiptData.tableNo!.isNotEmpty) {
      infoLine += 'Table: ${receiptData.tableNo}';
    }
    if (PrintSettings.showOrderType && receiptData.orderType != null) {
      if (infoLine.isNotEmpty) infoLine += '  |  ';
      infoLine += receiptData.orderType!;
    }
    if (infoLine.isNotEmpty) bytes.addAll(_text(infoLine));

    // Order # + Time on one line
    String orderLine = '';
    if (PrintSettings.showOrderId && receiptData.orderNo != null) {
      orderLine += 'Order #${receiptData.orderNo}';
    }
    if (PrintSettings.showOrderedTime && receiptData.orderTimestamp != null) {
      if (orderLine.isNotEmpty) orderLine += '  |  ';
      orderLine += DateFormat('HH:mm').format(receiptData.orderTimestamp!);
    }
    if (orderLine.isNotEmpty) bytes.addAll(_text(orderLine));

    // Order-level kitchen note (e.g. "No onions") — printed in bold so the
    // kitchen can't miss it. KOT only.
    final kotRemark = receiptData.kotRemark?.trim() ?? '';
    if (kotRemark.isNotEmpty) {
      bytes.addAll(_boldOn);
      bytes.addAll(_text('Note: $kotRemark'));
      bytes.addAll(_boldOff);
    }

    bytes.addAll(_divider(cols));

    // ── ITEMS: Name + qty, choices, extras, instructions ──
    // This is the core of the KOT — what the kitchen reads
    int totalQty = 0;
    for (final item in receiptData.items) {
      final qty = item.qty;
      totalQty += qty;

      // Item name with variant: "2x Chicken Biryani (Large)"
      String itemName = item.productName ?? 'Item';
      if (item.size != null && item.size!.isNotEmpty) {
        // size field contains variant name for KOT
        itemName += ' (${item.size})';
      }
      
      String prefix = '${qty}x ';
      if (receiptData.kotStatus?.toUpperCase() == 'CANCEL') {
        prefix = 'CANCEL ${qty}x '; // plain text — no glyph fonts on thermal
      }
      
      bytes.addAll(_boldOn);
      bytes.addAll(_text('$prefix$itemName'));
      bytes.addAll(_boldOff);

      // Additional info (choices, extras, instructions) stored in weight field
      // by RestaurantPrintHelper — printed as sub-lines in smaller context
      if (item.weight != null && item.weight!.isNotEmpty) {
        // Split by ' | ' to put each info type on its own line
        for (final part in item.weight!.split(' | ')) {
          bytes.addAll(_text('   $part'));
        }
      }
    }

    // ── FOOTER: Item count + total quantity ──
    bytes.addAll(_divider(cols));
    bytes.addAll(_text('Items: ${receiptData.items.length}   Qty: $totalQty'));

    // Feed paper + cut
    bytes.addAll(_feed(4));
    bytes.addAll(_cut);

    return bytes;
  }

  /// Build customer receipt/bill — full financial breakdown.
  ///
  /// Layout:
  /// ```
  ///      RESTAURANT NAME
  ///      Address, Phone, GST
  ///   ─────────────────────────
  ///   Bill#: INV-1042  KOT: #12,#15
  ///   Date: 19 Mar 2026  14:30
  ///   Type: Dine In  Table: T3
  ///   Customer: Rahul
  ///   ─────────────────────────
  ///   Item          Qty  Amount
  ///   ─────────────────────────
  ///   Biryani (L)     2  500.00
  ///     Extras: Cheese(₹30)
  ///   Naan            1  60.00
  ///   ─────────────────────────
  ///   Sub Total          560.00
  ///   Discount           -50.00
  ///   GST                 25.50
  ///   ═════════════════════════
  ///   TOTAL              535.50
  ///   ─────────────────────────
  ///   Paid by Cash       535.50
  ///   ─────────────────────────
  ///   Thank you! Visit again.
  /// ```
  static List<int> buildReceiptTicket({
    required ReceiptData receiptData,
    required int paperWidth,
  }) {
    final cols = _columnsForPaper(paperWidth);
    final bytes = <int>[];
    final sale = receiptData.sale;
    final currency = CurrencyHelper.currentSymbol;

    // Initialize printer
    bytes.addAll(_init);

    // ── STORE HEADER ──
    bytes.addAll(_alignCenter);

    // Store name in large bold text
    if (PrintSettings.showRestaurantName && receiptData.storeName != null) {
      bytes.addAll(_boldOn);
      bytes.addAll(_sizeDouble);
      bytes.addAll(_text(receiptData.storeName!));
      bytes.addAll(_sizeNormal);
      bytes.addAll(_boldOff);
    }

    // Address, phone, GST — smaller text below store name
    if (PrintSettings.showRestaurantAddress &&
        receiptData.storeAddress != null &&
        receiptData.storeAddress!.isNotEmpty) {
      bytes.addAll(_text(receiptData.storeAddress!));
    }
    if (PrintSettings.showRestaurantMobile &&
        receiptData.storePhone != null &&
        receiptData.storePhone!.isNotEmpty) {
      bytes.addAll(_text('Tel: ${receiptData.storePhone}'));
    }
    if (receiptData.gstNumber != null && receiptData.gstNumber!.isNotEmpty) {
      bytes.addAll(_text('GSTIN: ${receiptData.gstNumber}'));
    }

    bytes.addAll(_alignLeft);
    bytes.addAll(_divider(cols));

    // ── ORDER INFO ──

    // Bill# only — KOT numbers are internal kitchen info, not for the customer
    if (receiptData.billNumber != null) {
      bytes.addAll(_text('Bill No: INV-${receiptData.billNumber}'));
    }

    // Date and time
    if (PrintSettings.showOrderedTime) {
      final now = receiptData.orderTimestamp ?? DateTime.now();
      bytes.addAll(_text(
          'Date: ${DateFormat('dd MMM yyyy  HH:mm').format(now)}'));
    }

    // Order type + table
    if (PrintSettings.showOrderType && receiptData.orderType != null) {
      String typeLine = 'Type: ${receiptData.orderType}';
      if (receiptData.tableNo != null && receiptData.tableNo!.isNotEmpty) {
        typeLine += '  Table: ${receiptData.tableNo}';
      }
      bytes.addAll(_text(typeLine));
    }

    // Payment type
    if (PrintSettings.showPaymentType) {
      bytes.addAll(_text('Payment: ${sale.paymentType}'));
    }

    // Customer name
    if (PrintSettings.showCustomerName &&
        receiptData.customer != null &&
        receiptData.customer!.name.isNotEmpty) {
      bytes.addAll(_text('Customer: ${receiptData.customer!.name}'));
    }

    bytes.addAll(_divider(cols));

    // ── ITEM TABLE HEADER ──
    // Right-align "Amount" while left-aligning "Item" and "Qty"
    bytes.addAll(_boldOn);
    bytes.addAll(_text(_formatRow('Item', 'Qty', 'Amount', cols)));
    bytes.addAll(_boldOff);
    bytes.addAll(_divider(cols));

    // ── ITEM ROWS ──
    for (final item in receiptData.items) {
      // Item name (truncated to fit) + variant
      String name = item.productName ?? 'Item';
      if (item.size != null && item.size!.isNotEmpty) {
        name += ' (${item.size})';
      }

      // Truncate name to fit columns (leave room for qty + amount)
      final maxNameLen = cols - 18; // Reserve 18 chars for qty + amount
      if (name.length > maxNameLen) {
        name = '${name.substring(0, maxNameLen - 2)}..';
      }

      final amount = _fmt(item.price * item.qty);
      bytes.addAll(_text(
          _formatRow(name, '${item.qty}', amount, cols)));

      // Extras/choices info (indented, stored in weight field)
      if (item.weight != null && item.weight!.isNotEmpty) {
        for (final part in item.weight!.split(' | ')) {
          bytes.addAll(_text('  $part'));
        }
      }
    }

    bytes.addAll(_divider(cols));

    // ── TOTALS SECTION ──
    // This mirrors the bill summary from customerdetails.dart

    // Per-rate base for the GST table. item.price is mode-adjusted (divided by
    // 1+rate for exclusive display), so use item.total — which restores the true
    // base and sums to Sub Total.
    // Derive the tax mode from the order totals (stored flag can be stale).
    // Fall back to the receipt's own line gross so the detector never has to
    // rely on the stale inclusive flag (which mis-classified exclusive bills).
    final double itemsGross =
        receiptData.items.fold<double>(0, (s, it) => s + it.total);
    final double grossTotal = receiptData.itemTotal ?? itemsGross;
    final isTaxInclusive = (grossTotal > 0)
        ? TaxBreakdown.isInclusiveFromTotals(
            grossBeforeDiscount: grossTotal,
            discount: sale.discountAmount ?? 0,
            taxAmount: sale.totalGstAmount ?? 0,
            grandTotal: sale.grandTotal ?? 0,
            serviceCharge: receiptData.serviceCharge ?? 0,
            loyaltyDiscount:
                (receiptData.loyaltyPointsDiscount ?? 0).toDouble(),
            fallback: receiptData.isTaxInclusive ?? false,
          )
        : (receiptData.isTaxInclusive ?? false);

    // Sub Total
    if (PrintSettings.showSubtotal) {
      final subValue = receiptData.itemTotal ?? sale.subtotal ?? 0;
      bytes.addAll(_text(_formatTotalRow('Sub Total', _fmt(subValue), cols)));
    }

    // Discount (only show if > 0)
    if ((sale.discountAmount ?? 0) > 0.009) {
      bytes.addAll(_text(
          _formatTotalRow('Discount', '-$currency${_fmt(sale.discountAmount ?? 0)}', cols)));
    }

    // Loyalty points redeemed (only show if > 0)
    if (receiptData.loyaltyPointsDiscount != null &&
        receiptData.loyaltyPointsDiscount! > 0) {
      bytes.addAll(_text(_formatTotalRow(
          'Points Redeemed',
          '-$currency${receiptData.loyaltyPointsDiscount}',
          cols)));
    }

    // Tax block — per-rate GST summary, shown in BOTH modes when GST applies.
    // (0% bills produce no lines and skip the whole block.)
    final taxLines = TaxBreakdown.compute(
      items: receiptData.items
          .map((it) => (gross: it.total, ratePercent: it.gstRate ?? 0))
          .toList(),
      billDiscount: sale.discountAmount ?? 0,
      isTaxInclusive: isTaxInclusive,
      reconcileToGst: sale.totalGstAmount ?? 0, // lines must sum to the order's GST
    );
    if (PrintSettings.showTax && taxLines.isNotEmpty) {
      final totalGst = sale.totalGstAmount ?? 0; // authoritative — matches order
      bytes.addAll(_divider(cols));
      bytes.addAll(
          _text(_formatRow4('Tax', 'Taxable', 'GST', 'Total', cols)));
      for (final l in taxLines) {
        bytes.addAll(_text(_formatRow4(_taxLabel(l.ratePercent),
            _fmt(l.taxable), _fmt(l.gst), _fmt(l.taxable + l.gst), cols)));
      }
      bytes.addAll(_divider(cols));
      bytes.addAll(_text(_formatTotalRow(
          isTaxInclusive ? 'Total GST (Incl)' : 'Total GST:',
          _fmt(totalGst),
          cols)));
    }

    // Service / Delivery Charge (only show if > 0)
    if ((receiptData.serviceCharge ?? 0) > 0.009) {
      final chargeLabel = (receiptData.isDeliveryOrder ?? false)
          ? 'Delivery Charge'
          : 'Service Charge';
      bytes.addAll(_text(
          _formatTotalRow(chargeLabel, _fmt(receiptData.serviceCharge!), cols)));
    }

    // Round Off (only show if a rounding adjustment was applied)
    if ((receiptData.roundOff ?? 0).abs() > 0.009) {
      final ro = receiptData.roundOff!;
      bytes.addAll(_text(_formatTotalRow(
          'Round Off',
          '${ro >= 0 ? '+' : '-'}$currency${_fmt(ro.abs())}',
          cols)));
    }

    // ── GRAND TOTAL ──
    // Double-line divider above total for emphasis
    bytes.addAll(_doubleDivider(cols));
    bytes.addAll(_boldOn);
    bytes.addAll(_sizeDoubleHeight);
    bytes.addAll(_text(_formatTotalRow('TOTAL', '$currency${_fmt(sale.grandTotal ?? 0)}', cols)));
    bytes.addAll(_sizeNormal);
    bytes.addAll(_boldOff);
    bytes.addAll(_divider(cols));

    // ── PAYMENT INFO ──
    if (PrintSettings.showPaymentPaid) {
      // Split payment — show each method on its own line
      if (receiptData.paymentBreakdown != null && receiptData.paymentBreakdown!.isNotEmpty) {
        // Split payment — show each method on its own line
        // Format: "cash: ₹500, card: ₹300" → separate lines
        final parts = receiptData.paymentBreakdown!.split(', ');
        for (final part in parts) {
          bytes.addAll(_text(part.padRight(cols)));
        }
      } else {
        bytes.addAll(
            _text(_formatTotalRow('Paid by ${sale.paymentType ?? 'Cash'}', _fmt(sale.grandTotal ?? 0), cols)));
      }
    }

    bytes.addAll(_divider(cols));

    // ── FOOTER ──
    bytes.addAll(_alignCenter);
    if (isTaxInclusive) {
      bytes.addAll(_text('All prices include GST'));
    }
    // Order-type-aware thank you message
    final orderType = receiptData.orderType?.toLowerCase() ?? '';
    if (orderType.contains('dine')) {
      bytes.addAll(_text('Thank you for dining with us!'));
    } else if (orderType.contains('delivery')) {
      bytes.addAll(_text('Thank you for your order!'));
    } else {
      bytes.addAll(_text('Thank you! Enjoy your meal!'));
    }
    bytes.addAll(_text('Visit us again!'));
    if (PrintSettings.showPoweredBy) {
      bytes.addAll(_text('Powered by Bill Berry Lite'));
    }

    // Feed paper and cut
    bytes.addAll(_feed(4));
    bytes.addAll(_cut);

    return bytes;
  }

  /// Build the End-of-Day SETTLEMENT receipt.
  ///
  /// All values are passed in pre-computed by the caller (endday.dart) so this
  /// stays a pure formatter. Untracked lines (round off, credit, cancelled
  /// bills/products, etc.) are passed as 0 and still printed, matching the
  /// store's expected settlement template.
  static List<int> buildEodSettlementTicket({
    required int paperWidth,
    required String storeName,
    String? storeSubtitle,
    required String currencySymbol,
    required String shiftUser,
    required DateTime shiftStart,
    required DateTime shiftEnd,
    required List<({String name, double amount})> orderTypes,
    required double totalSale,
    required double discount,
    required double netSale,
    required double tax,
    required double roundOff,
    required double grossSale,
    required double cash,
    required double totalCredit,
    required double openingBalance,
    required double cashExpense,
    required double totalExpense,
    required double drawerBalance,
    required double withdrawalCash,
    required double cashDifference,
    required List<({String name, double amount})> paymentMethods,
    required int noOfBill,
    required int reprintBill,
    required int cancelledBill,
    required double cancelledBillAmount,
    required int cancelledProducts,
    required double cancelledProductsAmount,
    required double saleReturnAmount,
    required double finalAmount,
  }) {
    final cols = _columnsForPaper(paperWidth);
    final b = <int>[];
    final df = DateFormat('dd-MM-yyyy hh:mm:ss a');

    b.addAll(_init);

    // ── HEADER ──
    b.addAll(_alignCenter);
    b.addAll(_boldOn);
    b.addAll(_sizeDouble);
    b.addAll(_text(storeName));
    b.addAll(_sizeNormal);
    if (storeSubtitle != null && storeSubtitle.isNotEmpty) {
      b.addAll(_text(storeSubtitle));
    }
    b.addAll(_text('SETTLEMENT RECEIPT'));
    b.addAll(_boldOff);
    b.addAll(_alignLeft);
    b.addAll(_divider(cols));

    // ── SHIFT INFO ──
    b.addAll(_text('SHIFT USER: $shiftUser'));
    b.addAll(_text('SHIFT START: ${df.format(shiftStart)}'));
    b.addAll(_text('SHIFT END: ${df.format(shiftEnd)}'));
    b.addAll(_text('DURATION: ${_fmtDuration(shiftEnd.difference(shiftStart))}'));
    b.addAll(_divider(cols));

    // ── ORDER TYPES ──
    for (final o in orderTypes) {
      b.addAll(_text(_formatTotalRow(o.name.toUpperCase(), _fmt(o.amount), cols)));
    }
    final orderTypeTotal = orderTypes.fold<double>(0, (s, o) => s + o.amount);
    b.addAll(_text(_formatTotalRow('TOTAL (ORDER TYPE)', _fmt(orderTypeTotal), cols)));
    b.addAll(_divider(cols));

    // ── SALES ──
    b.addAll(_text(_formatTotalRow('TOTAL SALE:', _fmt(totalSale), cols)));
    b.addAll(_text(_formatTotalRow('DISCOUNT:', _fmt(discount), cols)));
    b.addAll(_text(_formatTotalRow('NET SALE:', _fmt(netSale), cols)));
    b.addAll(_text(_formatTotalRow('TAX:', _fmt(tax), cols)));
    b.addAll(_text(_formatTotalRow('ROUND OFF:', _fmt(roundOff), cols)));
    b.addAll(_boldOn);
    b.addAll(_text(_formatTotalRow('GROSS SALE:', _fmt(grossSale), cols)));
    b.addAll(_boldOff);
    b.addAll(_divider(cols));

    // ── CASH / DRAWER ──
    b.addAll(_text(_formatTotalRow('CASH', _fmt(cash), cols)));
    b.addAll(_text(_formatTotalRow('TOTAL CREDIT:', _fmt(totalCredit), cols)));
    b.addAll(_text(_formatTotalRow('OPENING BALANCE:', _fmt(openingBalance), cols)));
    b.addAll(_text(_formatTotalRow('CASH EXPENSE:', _fmt(cashExpense), cols)));
    b.addAll(_text(_formatTotalRow('TOTAL EXPENSE:', _fmt(totalExpense), cols)));
    b.addAll(_text(_formatTotalRow('DRAWER BALANCE:', _fmt(drawerBalance), cols)));
    b.addAll(_text(_formatTotalRow('WITHDRAWAL CASH:', _fmt(withdrawalCash), cols)));
    b.addAll(_text(_formatTotalRow('CASH DIFFERENCE:', _fmt(cashDifference), cols)));
    b.addAll(_divider(cols));

    // ── PAYMENT METHODS ──
    for (final p in paymentMethods) {
      b.addAll(_text(_formatTotalRow(p.name.toUpperCase(), _fmt(p.amount), cols)));
    }
    if (paymentMethods.isNotEmpty) b.addAll(_divider(cols));

    // ── BILL COUNTS ──
    b.addAll(_text(_formatTotalRow('NO OF BILL:', '$noOfBill', cols)));
    b.addAll(_text(_formatTotalRow('REPRINT BILL:', '$reprintBill', cols)));
    b.addAll(_text(_formatTotalRow('CANCELLED BILL:', '$cancelledBill', cols)));
    b.addAll(_text(_formatTotalRow('CANCELLED BILL AMOUNT:', _fmt(cancelledBillAmount), cols)));
    b.addAll(_text(_formatTotalRow('CANCELLED PRODUCTS:', '$cancelledProducts', cols)));
    b.addAll(_text(_formatTotalRow('CANCELLED PRODUCTS AMOUNT:', _fmt(cancelledProductsAmount), cols)));
    b.addAll(_text(_formatTotalRow('SALE RETURN AMOUNT:', _fmt(saleReturnAmount), cols)));
    b.addAll(_doubleDivider(cols));

    // ── FINAL AMOUNT ──
    b.addAll(_boldOn);
    b.addAll(_sizeDoubleHeight);
    b.addAll(_text(_formatTotalRow('FINAL AMOUNT:', '$currencySymbol ${_fmt(finalAmount)}', cols)));
    b.addAll(_sizeNormal);
    b.addAll(_boldOff);
    b.addAll(_divider(cols));

    // ── FOOTER ──
    b.addAll(_alignCenter);
    b.addAll(_text('THANK YOU...!'));
    b.addAll(_feed(4));
    b.addAll(_cut);

    return b;
  }

  /// Format a duration as HH:mm:ss (e.g. shift length 04:22:56).
  static String _fmtDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  /// Build a simple test ticket to verify printer connection.
  /// No ReceiptData needed — just sends a formatted test page.
  static List<int> buildTestTicket(int paperWidth) {
    final cols = _columnsForPaper(paperWidth);
    final bytes = <int>[];

    bytes.addAll(_init);
    bytes.addAll(_alignCenter);
    bytes.addAll(_sizeDouble);
    bytes.addAll(_text('Bill Berry Lite'));
    bytes.addAll(_sizeNormal);
    bytes.addAll(_text('Printer Test'));
    bytes.addAll(_alignLeft);
    bytes.addAll(_divider(cols));
    bytes.addAll(_text('Paper: ${paperWidth}mm ($cols chars/line)'));
    bytes.addAll(_text('Time: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}'));
    bytes.addAll(_text('Status: Connected OK'));
    bytes.addAll(_divider(cols));
    bytes.addAll(_alignCenter);
    bytes.addAll(_text('If you can read this,'));
    bytes.addAll(_text('your printer is working!'));
    bytes.addAll(_feed(4));
    bytes.addAll(_cut);

    return bytes;
  }

  // ════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS — byte-level utilities
  // ════════════════════════════════════════════════════════════════════════

  /// Convert a string to bytes + newline.
  /// ESC/POS printers expect raw ASCII bytes terminated by LF (0x0A).
  static List<int> _text(String text) {
    return [...text.codeUnits, ..._newline];
  }

  /// Print N blank lines (paper feed)
  static List<int> _feed(int lines) {
    return List.filled(lines, 0x0A);
  }

  /// Single-line divider: ─────────────
  static List<int> _divider(int cols) {
    return _text('-'.padRight(cols, '-'));
  }

  /// Double-line divider for emphasis: ═══════════════
  static List<int> _doubleDivider(int cols) {
    return _text('='.padRight(cols, '='));
  }

  /// Number of printable characters per line based on paper width.
  /// 80mm paper ≈ 48 chars, 58mm paper ≈ 32 chars.
  /// These are standard values for most thermal printers using the
  /// default 12x24 dot font.
  static int _columnsForPaper(int paperWidth) {
    return paperWidth >= 80 ? 48 : 32;
  }

  /// Format a number as a price string using app's decimal settings.
  /// e.g., 1234.5 → "1234.50" (with 2 decimal places)
  static String _fmt(double value) {
    return DecimalSettings.formatAmount(value);
  }

  /// Format an item row: "Biryani (L)       2   500.00"
  /// Pads the name, centers qty, and right-aligns amount.
  static String _formatRow(
      String name, String qty, String amount, int cols) {
    // Reserve: 6 chars for qty column, 10 chars for amount column
    final qtyWidth = 5;
    final amountWidth = 10;
    final nameWidth = cols - qtyWidth - amountWidth;

    // Truncate name if needed
    final truncatedName =
        name.length > nameWidth ? name.substring(0, nameWidth) : name;

    return truncatedName.padRight(nameWidth) +
        qty.padLeft(qtyWidth) +
        amount.padLeft(amountWidth);
  }

  /// 4-column row for the GST table (Tax | Taxable | GST | Total).
  /// First column (tax name) left-aligned; the 3 amounts right-aligned.
  static String _formatRow4(
      String c1, String c2, String c3, String c4, int cols) {
    final wNum = (cols ~/ 5).clamp(6, 12);
    final w1 = (cols - wNum * 3) < 6 ? 6 : (cols - wNum * 3);
    String padR(String s, int width) =>
        s.length > width ? s.substring(0, width) : s.padLeft(width);
    final first = c1.length > w1 ? c1.substring(0, w1) : c1.padRight(w1);
    return first + padR(c2, wNum) + padR(c3, wNum) + padR(c4, wNum);
  }

  /// Label for a GST rate, e.g. "GST1 (5%)". Uses the configured tax name when a
  /// single tax matches the rate; falls back to "GST (rate%)".
  static String _taxLabel(double ratePercent) {
    final rateStr = ratePercent % 1 == 0
        ? ratePercent.toStringAsFixed(0)
        : ratePercent.toStringAsFixed(2);
    String name = 'GST';
    for (final t in taxStore.taxes) {
      if (((t.taxperecentage ?? 0) - ratePercent).abs() < 0.001 &&
          t.taxname.trim().isNotEmpty) {
        name = t.taxname.trim();
        break;
      }
    }
    return '$name ($rateStr%)';
  }

  /// Format a totals row: "Sub Total              560.00"
  /// Label on left, amount on right, padded to fill the line.
  static String _formatTotalRow(String label, String amount, int cols) {
    final amountWidth = amount.length;
    final labelWidth = cols - amountWidth;

    final truncatedLabel =
        label.length > labelWidth ? label.substring(0, labelWidth) : label;

    return truncatedLabel.padRight(labelWidth) + amount;
  }
}
