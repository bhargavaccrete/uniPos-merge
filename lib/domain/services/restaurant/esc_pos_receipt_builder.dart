import 'package:intl/intl.dart';
import 'package:unipos/domain/services/retail/receipt_pdf_service.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/util/restaurant/print_settings.dart';

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
    if (receiptData.isAddonKot == true) {
      kotLabel += ' (ADD-ON)'; // Tells kitchen this isn't the first KOT
    }
    bytes.addAll(_text(kotLabel));
    bytes.addAll(_sizeNormal);
    bytes.addAll(_boldOff);

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
      bytes.addAll(_boldOn);
      bytes.addAll(_text('${qty}x $itemName'));
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

    // Bill# and KOT numbers
    if (receiptData.billNumber != null) {
      bytes.addAll(_text('Bill No: INV-${receiptData.billNumber}'));
    }
    if (receiptData.kotNumbers != null && receiptData.kotNumbers!.isNotEmpty) {
      final kotStr = receiptData.kotNumbers!.map((k) => '#$k').join(', ');
      bytes.addAll(_text('KOT: $kotStr'));
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

    final isTaxInclusive = receiptData.isTaxInclusive ?? false;

    // Sub Total
    if (PrintSettings.showSubtotal) {
      final subLabel = isTaxInclusive ? 'Sub Total (Incl. Tax)' : 'Sub Total';
      // Use itemTotal if available (pre-calculated), otherwise use sale.subtotal
      final subValue = receiptData.itemTotal ?? sale.subtotal ?? 0;
      bytes.addAll(_text(_formatTotalRow(subLabel, _fmt(subValue), cols)));
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

    // Tax (GST)
    if (PrintSettings.showTax && (sale.totalGstAmount ?? 0) > 0.009) {
      final taxLabel = isTaxInclusive ? 'GST (Included)' : 'GST';
      bytes.addAll(
          _text(_formatTotalRow(taxLabel, _fmt(sale.totalGstAmount ?? 0), cols)));
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
      bytes.addAll(
          _text(_formatTotalRow('Paid by ${sale.paymentType ?? 'Cash'}', _fmt(sale.grandTotal ?? 0), cols)));
    }

    // Split payment breakdown (if applicable)
    // The paymentBreakdown string is passed via sale.remark or separately
    // For now, we show the basic payment info. Split payment detail
    // will be enhanced in Phase 5 integration.

    bytes.addAll(_divider(cols));

    // ── FOOTER ──
    bytes.addAll(_alignCenter);
    bytes.addAll(_text('Thank you for dining with us!'));
    bytes.addAll(_text('Visit us again!'));
    if (PrintSettings.showPoweredBy) {
      bytes.addAll(_text('Powered by UniPOS'));
    }

    // Feed paper and cut
    bytes.addAll(_feed(4));
    bytes.addAll(_cut);

    return bytes;
  }

  /// Build a simple test ticket to verify printer connection.
  /// No ReceiptData needed — just sends a formatted test page.
  static List<int> buildTestTicket(int paperWidth) {
    final cols = _columnsForPaper(paperWidth);
    final bytes = <int>[];

    bytes.addAll(_init);
    bytes.addAll(_alignCenter);
    bytes.addAll(_sizeDouble);
    bytes.addAll(_text('UniPOS'));
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
