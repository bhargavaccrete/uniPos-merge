import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../../data/models/common/customer_model_125.dart';
import '../../../data/models/retail/hive_model/sale_item_model_204.dart';
import '../../../data/models/retail/hive_model/sale_model_203.dart';
import '../../../data/models/retail/printer_settings_model.dart';
import '../../../util/restaurant/print_settings.dart';
import '../../../core/config/app_config.dart';
import '../../../core/plan/plan_enforcement.dart';
import '../../../core/plan/mode_keys.dart';
import '../../../core/di/service_locator.dart' show taxStore;
// This service is shared: restaurant's bill/KOT print reuses it. Import
// describeAttributeMap only — resolving AttributeStore from GetIt throws in
// restaurant mode, where it is never registered.
import '../../store/retail/attribute_store.dart' show describeAttributeMap;
import '../../../util/restaurant/staticswitch.dart';
import '../restaurant/tax_breakdown.dart';
import 'package:billberrylite/core/config/food_license_rule.dart';
import 'package:billberrylite/core/config/tariff_code_rule.dart';
import 'package:billberrylite/core/config/tax_label_rule.dart';
import 'package:billberrylite/core/config/tax_id_rule.dart';
import 'package:billberrylite/util/common/short_ref.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/util/common/loyalty_points.dart';
import 'retail_printer_settings_service.dart';

/// What one receipt line contributes to Sub Total — the single definition every
/// renderer must print in its Amount column and feed to the tax table.
///
/// The two modes build `SaleItemModel` from opposite ends:
/// - **Restaurant** divides the gross menu price down to a base before calling
///   `SaleItemModel.create` (`restaurant_print_helper.dart`), so `total` lands
///   back on the original gross — which is what `CartCalculationService
///   .itemTotal` (the Sub Total) sums.
/// - **Retail** passes an already-base price, so `total` comes out
///   tax-INCLUSIVE while its Sub Total (`bill.itemTotal`) is the ex-tax gross.
///
/// Printing raw `item.total` in both modes is what made a retail bill show a
/// ₹118 line above a ₹100 Sub Total. Item-level discount is deliberately not
/// subtracted here: retail's Sub Total is "before any discount" and the bill
/// shows Discount as its own row.
double receiptLineGross(SaleItemModel it) =>
    AppConfig.isRestaurant ? it.total : it.price * it.qty;

/// The line's OWN discount, or 0. Distinct from `SaleItemModel.discountAmount`,
/// which is the total including this line's share of the order-level discount.
double receiptLineDiscount(SaleItemModel it) => it.lineDiscountAmount ?? 0;

/// Sum of the per-line discounts on a bill.
///
/// Folded over the very items the receipt renders, so the "Item Discounts" total
/// can never disagree with the sub-rows printed above it. Deliberately NOT read
/// from `SaleModel.lineDiscountTotal` for that reason (that field exists for
/// reporting, and is absent on returns and on pre-feature sales).
double receiptLineDiscountTotal(List<SaleItemModel> items) =>
    items.fold<double>(0, (s, it) => s + receiptLineDiscount(it));

/// The order-level part of a bill's discount: the stored total minus everything
/// attributable to individual lines.
///
/// Clamped at zero — the per-line and total figures are rounded independently,
/// so the residual can land a paisa negative.
double receiptBillDiscountRemainder(SaleModel sale, List<SaleItemModel> items) {
  // Compared as MAGNITUDES so a credit note keeps its Bill Discount row.
  // A return stores its header negated while its lines stay positive, so the
  // raw subtraction was always negative there and the clamp below silently
  // deleted the row from every credit note. Stored signs are untouched — this
  // is a PRINTING concern only.
  final remainder =
      sale.discountAmount.abs() - receiptLineDiscountTotal(items).abs();
  return remainder > 0 ? remainder : 0;
}

/// "Discount 10%" / "Discount 90.00" label for a line's own discount.
String receiptLineDiscountLabel(SaleItemModel it) {
  final value = it.lineDiscountValue;
  if (it.lineDiscountType == 'percentage' && value != null && value > 0) {
    final pct = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
    return 'Discount $pct%';
  }
  return 'Discount';
}

/// Data class to hold all receipt information
class ReceiptData {
  final SaleModel sale;
  final List<SaleItemModel> items;
  final Customer? customer;
  final String? storeName;
  final String? storeAddress;
  final String? storePhone;
  final String? storeEmail;
  final String? gstNumber;

  // Restaurant-specific fields
  final String? orderType; // e.g., "Dine In", "Takeaway", "Delivery"
  final String? tableNo; // Table number for dine-in orders
  final int? kotNumber; // KOT number for kitchen orders (single KOT prints)
  final String? kotStatus; // Status of this KOT (e.g. "CANCEL")
  final String? cancelReference; // Reference to original KOT (e.g. "KOT #013")
  final List<int>? kotNumbers; // All KOT numbers for this order (customer bill)
  final DateTime? orderTimestamp; // Order timestamp for KOT
  final String? orderNo; // Order number/ID for KOT
  final bool? isAddonKot; // True if this is an additional KOT for existing order
  final String? kotRemark; // Order-level kitchen note (e.g. "No onions") — KOT only
  final int? billNumber; // Daily bill number for completed orders (resets every day)

  // Store logo
  final Uint8List? logoBytes; // Store logo image

  // Restaurant-specific: Pre-calculated item total (before discount)
  // This should come from CartCalculationService.itemTotal
  final double? itemTotal;

  // Loyalty points redeemed as discount (shown as a separate line on bill)
  final int? loyaltyPointsDiscount;

  // Tax mode stored at order creation time (use this instead of live AppSettings)
  final bool? isTaxInclusive;

  // Does this business use tax features at all (TaxFeature.enabled at the time
  // this receipt was built)? Gates GSTIN, tax summary rows, and the "includes
  // GST" footer across every renderer — authoritative, unlike per-item gstRate/
  // taxRate which can be stale on old records.
  final bool taxEnabled;

  // Service / Delivery charge (pre-calculated by CartCalculationService)
  final double? serviceCharge;
  final bool? isDeliveryOrder;

  // Rounding adjustment applied to reach grandTotal (+/-), pre-calculated by
  // CartCalculationService. Shown as a separate "Round Off" line on the bill.
  final double? roundOff;

  // Split payment breakdown (e.g., "cash: ₹500, card: ₹300")
  final String? paymentBreakdown;

  // Offline UPI "scan & pay" — printed on UNPAID bills only.
  final String? upiId; // merchant VPA, e.g. "merchant@okhdfc"
  final String? upiPayeeName; // payee name for the UPI link
  final Uint8List? upiQrImageBytes; // merchant's own static QR (printed as-is)

  ReceiptData({
    required this.sale,
    required this.items,
    this.customer,
    this.storeName,
    this.storeAddress,
    this.storePhone,
    this.storeEmail,
    this.gstNumber,
    this.orderType,
    this.tableNo,
    this.kotNumber,
    this.kotStatus,
    this.cancelReference,
    this.kotNumbers,
    this.orderTimestamp,
    this.orderNo,
    this.isAddonKot,
    this.kotRemark,
    this.billNumber,
    this.logoBytes,
    this.itemTotal,
    this.loyaltyPointsDiscount,
    this.isTaxInclusive,
    this.taxEnabled = true,
    this.serviceCharge,
    this.isDeliveryOrder,
    this.roundOff,
    this.paymentBreakdown,
    this.upiId,
    this.upiPayeeName,
    this.upiQrImageBytes,
  });
}

/// Service for generating PDF receipts and invoices
class ReceiptPdfService {
  /// Default store info - can be customized via settings
  static const String defaultStoreName = 'My Store';
  static const String defaultStoreAddress = 'Your Store Address';
  static const String defaultStorePhone = '+91 1234567890';

  // Static font cache to prevent reloading from assets on every single print
  static pw.Font? _cachedBaseFont;
  static pw.Font? _cachedBoldFont;
  static List<pw.Font>? _cachedFallbackFonts;

  /// Get retail printer settings if in retail mode
  RetailPrinterSettings? _getRetailSettings() {
    if (AppConfig.isRetail) {
      return RetailPrinterSettingsService().settings;
    }
    return null;
  }

  /// Get paper format based on retail settings or default
  PdfPageFormat _getPaperFormat() {
    final retailSettings = _getRetailSettings();
    if (retailSettings != null) {
      switch (retailSettings.paperSize) {
        case PaperSize.mm58:
        // Note: Using roll80 as PDF package doesn't have roll58, can be customized
          return const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 8);
        case PaperSize.mm80:
          return PdfPageFormat.roll80;
        case PaperSize.a4:
          return PdfPageFormat.a4;
      }
    }
    // Default to 80mm for restaurant/undefined
    return PdfPageFormat.roll80;
  }

  /// Generate a thermal receipt style PDF (narrow, suitable for 80mm printers)
  /// Extra fonts so non-Latin scripts (Gujarati, Hindi/Devanagari) render on
  /// receipts. Used as `fontFallback`: Poppins covers Latin, these cover the
  /// rest. Best-effort — a missing file just leaves boxes for that script.
  Future<List<pw.Font>> _indicFallbackFonts() async {
    if (_cachedFallbackFonts != null) {
      return _cachedFallbackFonts!;
    }
    final fonts = <pw.Font>[];
    for (final path in const [
      'assets/fonts/NotoSansGujarati-Regular.ttf',
      'assets/fonts/NotoSansDevanagari-Regular.ttf',
    ]) {
      try {
        fonts.add(pw.Font.ttf(await rootBundle.load(path)));
      } catch (e, s) {
        print('Error loading fallback font $path: $e\n$s');
      }
    }
    _cachedFallbackFonts = fonts;
    return fonts;
  }

  Future<pw.Document> generateThermalReceipt(ReceiptData data, {int paperWidth = 80}) async {
    final pdf = pw.Document();
    
    // Natively layout the page size based on target printer width
    final bool isSmallMedia = paperWidth <= 58;
    final bool isKot = data.kotNumber != null;
    final bool isPaperSaver = isKot
        ? PrintSettings.isKotTemplatePaperSaver
        : PrintSettings.isBillTemplatePaperSaver;

    // Define format with 0 default margins so we control margins cleanly inside pw.Page
    final pageFormat = isSmallMedia
        ? const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 0)
        : const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 0);

    // Dynamic margins to eliminate outer spaces and top spacing
    final double hMargin = isPaperSaver
        ? (isSmallMedia ? 1.5 : 2.5)
        : (isSmallMedia ? 3.0 : 5.0);
    final double vMargin = 0.0;

    // Load fonts with fallback
    pw.Font ttf;
    pw.Font boldTtf;
    try {
      if (_cachedBaseFont != null && _cachedBoldFont != null) {
        ttf = _cachedBaseFont!;
        boldTtf = _cachedBoldFont!;
      } else {
        final fontData = await rootBundle.load("assets/fonts/Poppins-Regular.ttf");
        ttf = pw.Font.ttf(fontData);
        final boldFontData = await rootBundle.load("assets/fonts/Poppins-Bold.ttf");
        boldTtf = pw.Font.ttf(boldFontData);
        _cachedBaseFont = ttf;
        _cachedBoldFont = boldTtf;
      }
    } catch (e, s) {
      print('Error loading fonts: $e\n$s');
      ttf = pw.Font.helvetica();
      boldTtf = pw.Font.helveticaBold();
    }

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.symmetric(horizontal: hMargin, vertical: vMargin),
        theme: pw.ThemeData.withFont(
          base: ttf,
          bold: boldTtf,
          fontFallback: await _indicFallbackFonts(),
        ),
        build: (context) => _buildThermalReceiptContent(data, paperWidth: paperWidth),
      ),
    );

    return pdf;
  }

  /// Generate a full A4 invoice PDF
  Future<pw.Document> generateInvoice(ReceiptData data) async {
    final pdf = pw.Document();

    // Load fonts with fallback
    pw.Font ttf;
    pw.Font boldTtf;
    try {
      final fontData = await rootBundle.load("assets/fonts/Poppins-Regular.ttf");
      ttf = pw.Font.ttf(fontData);
      final boldFontData = await rootBundle.load("assets/fonts/Poppins-Bold.ttf");
      boldTtf = pw.Font.ttf(boldFontData);
    } catch (e) {
      print('Error loading fonts: $e');
      ttf = pw.Font.helvetica();
      boldTtf = pw.Font.helveticaBold();
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(
          base: ttf,
          bold: boldTtf,
          fontFallback: await _indicFallbackFonts(),
        ),
        build: (context) => _buildInvoiceContent(data),
      ),
    );

    return pdf;
  }

  /// Build thermal receipt content (80mm width)
  pw.Widget _buildThermalReceiptContent(ReceiptData data, {int paperWidth = 80}) {
    final storeName = data.storeName ?? defaultStoreName;
    final storeAddress = data.storeAddress ?? defaultStoreAddress;
    final storePhone = data.storePhone ?? defaultStorePhone;

    final bool isSmallMedia = paperWidth <= 58;
    final isRetail = AppConfig.isRetail;
    final retailSettings = _getRetailSettings();

    final isKot = data.kotNumber != null;
    // The compact layout was already built here, but the flag came only from
    // restaurant's PrintSettings — which retail's settings screen never exposed,
    // so a retail user could not reach it. In retail mode the choice now comes
    // from RetailPrinterSettings; restaurant keeps its own (and KOT is
    // restaurant-only, so that branch is unchanged).
    final bool isPaperSaver = isKot
        ? PrintSettings.isKotTemplatePaperSaver
        : (isRetail && retailSettings != null
            ? retailSettings.billTemplate == BillTemplate.paperSaver
            : PrintSettings.isBillTemplatePaperSaver);

    // Font size baseline calculations based on template choice
    final double storeNameSize = isPaperSaver
        ? (isSmallMedia ? 8.5 : 10.0)
        : (isSmallMedia ? 11.0 : 13.0);

    final double headerBadgeSize = isKot
        ? (isPaperSaver
            ? (isSmallMedia ? 7.0 : 8.5)
            : (isSmallMedia ? 9.0 : 11.0))
        : (isPaperSaver
            ? (isSmallMedia ? 7.0 : 8.5)
            : (isSmallMedia ? 8.5 : 10.5));

    final double labelSize = isKot
        ? (isPaperSaver
            ? (isSmallMedia ? 6.5 : 7.5)
            : (isSmallMedia ? 8.0 : 9.5))
        : (isPaperSaver
            ? (isSmallMedia ? 6.5 : 7.5)
            : (isSmallMedia ? 8.0 : 9.5));

    final double tableHeaderSize = isPaperSaver
        ? (isSmallMedia ? 6.5 : 7.5)
        : (isSmallMedia ? 8.0 : 9.5);
    final double bodySize = isPaperSaver
        ? (isSmallMedia ? 6.0 : 7.0)
        : (isSmallMedia ? 7.5 : 9.0);
    final double totalRowSize = isPaperSaver
        ? (isSmallMedia ? 6.5 : 7.5)
        : (isSmallMedia ? 8.0 : 9.5);
    final double grandTotalSize = isPaperSaver
        ? (isSmallMedia ? 7.5 : 9.0)
        : (isSmallMedia ? 9.5 : 11.5);
    final double footerSize = isPaperSaver
        ? (isSmallMedia ? 6.0 : 7.0)
        : (isSmallMedia ? 8.0 : 9.0);

    // Component Sizes
    final double logoW = isPaperSaver
        ? (isSmallMedia ? 120.0 : 160.0)
        : (isSmallMedia ? 150.0 : 200.0);
    final double logoH = isPaperSaver
        ? (isSmallMedia ? 120.0 : 160.0)
        : (isSmallMedia ? 150.0 : 200.0);
    final double qrS = isPaperSaver
        ? (isSmallMedia ? 55.0 : 65.0)
        : (isSmallMedia ? 75.0 : 90.0);

    final double lineSpacing = isPaperSaver ? 1.0 : 3.0;

    final showLogo = isKot ? false : (isRetail ? (retailSettings?.showLogo ?? true) : PrintSettings.showRestaurantLogo);
    final showStoreName = isKot ? false : (isRetail ? (retailSettings?.showStoreName ?? true) : PrintSettings.showRestaurantName);
    final showStoreAddress = isKot ? false : (isRetail ? (retailSettings?.showStoreAddress ?? true) : PrintSettings.showRestaurantAddress);
    final showStorePhone = isKot ? false : (isRetail ? (retailSettings?.showStorePhone ?? true) : PrintSettings.showRestaurantMobile);
    final showGST = data.taxEnabled &&
        (isKot ? false : (isRetail ? (retailSettings?.showGSTNumber ?? true) : true));
    // Food licence (FSSAI in India) — read live, not threaded through
    // ReceiptData: it is a standing business identifier, not a per-order value.
    // NOT gated on taxEnabled; a food licence is not a tax registration.
    final foodLicense = isKot ? null : FoodLicenseRule.number;

    final bool hasHeaderDetails = (showLogo && data.logoBytes != null) ||
        showStoreName ||
        showStoreAddress ||
        showStorePhone ||
        (showGST && data.gstNumber != null) ||
        foodLicense != null;

    final showInvoiceNumber = isRetail ? (retailSettings?.showInvoiceNumber ?? true) : PrintSettings.showOrderId;
    final showInvoiceDate = isRetail ? (retailSettings?.showInvoiceDate ?? true) : PrintSettings.showOrderedTime;
    final showPaymentMethod = isRetail ? (retailSettings?.showPaymentMethod ?? true) : PrintSettings.showPaymentType;
    final showCustomer = isRetail ? (retailSettings?.showCustomerDetails ?? true) : PrintSettings.showCustomerName;
    final showSubtotal = isRetail ? (retailSettings?.showSubtotal ?? true) : PrintSettings.showSubtotal;
    final showTax = data.taxEnabled && (isRetail ? (retailSettings?.showTax ?? true) : PrintSettings.showTax);
    final showPaymentPaid = isRetail ? (retailSettings?.showSplitPayment ?? true) : PrintSettings.showPaymentPaid;
    // Retail-only: per-line discounts printed under their item. Restaurant
    // receipts are unchanged — they have no line-discount concept, and their
    // per-item Discount column on the A4 invoice already covers the case.
    // `showItemDiscount` has existed on the retail printer settings model since
    // it was written; this is its first consumer.
    final showItemDiscount =
        isRetail && (retailSettings?.showItemDiscount ?? true);
    final showFooter = isRetail ? (retailSettings?.showFooter ?? true) : PrintSettings.showPoweredBy;

    // Custom text for retail
    final headerText = isRetail ? (retailSettings?.headerText ?? '') : '';
    final footerText = isRetail ? (retailSettings?.footerText ?? 'Visit Again!') : '';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Store Logo
        if (showLogo && data.logoBytes != null) ...[
          pw.Container(
            width: logoW,
            child: pw.Image(
              pw.MemoryImage(data.logoBytes!),
              fit: pw.BoxFit.contain,
            ),
          ),
          pw.SizedBox(height: isPaperSaver ? 0.5 : 1.0),
        ],

        // Custom Header Text (Retail only)
        if (isRetail && headerText.isNotEmpty) ...[
          pw.Text(
            headerText,
            style: pw.TextStyle(fontSize: bodySize),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
        ],

        // Store Header
        if (showStoreName) ...[
          pw.Text(
            storeName,
            style: pw.TextStyle(
              fontSize: storeNameSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          // INVOICE heading (only for bills, not KOTs). A return prints as a
          // CREDIT NOTE — the A4 invoice already did this; thermal did not, so
          // a refund slip was indistinguishable from a sale.
          if (data.kotNumber == null) ...[
            pw.Text(
              data.sale.isReturn == true ? 'CREDIT NOTE' : 'INVOICE',
              style: pw.TextStyle(
                fontSize: headerBadgeSize,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 2),
            // Both halves of an exchange print their shared reference, so a
            // customer holding one slip can be tied to the other.
            if (data.sale.exchangeGroupId != null) ...[
              pw.Text(
                'EXCHANGE ${data.sale.exchangeGroupId}',
                style: pw.TextStyle(fontSize: bodySize),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
            ],
          ],
        ],
        if (showStoreAddress) ...[
          pw.Text(
            storeAddress,
            style: pw.TextStyle(fontSize: bodySize),
            textAlign: pw.TextAlign.center,
          ),
        ],
        if (showStorePhone) ...[
          pw.Text(
            'Tel: $storePhone',
            style: pw.TextStyle(fontSize: bodySize),
          ),
        ],
        if (showGST && data.gstNumber != null) ...[
          pw.Text(
            '${TaxIdRule.printLabel}: ${data.gstNumber}',
            style: pw.TextStyle(fontSize: bodySize),
          ),
        ],
        if (foodLicense != null) ...[
          pw.Text(
            '${FoodLicenseRule.label}: $foodLicense',
            style: pw.TextStyle(fontSize: bodySize),
          ),
        ],
        if (data.kotNumber == null && hasHeaderDetails) ...[
          pw.SizedBox(height: lineSpacing * 2),
          _buildDashedLine(isSmallMedia: isSmallMedia),
          pw.SizedBox(height: lineSpacing),
        ],

        // Receipt Info / KOT Info
        if (data.kotNumber != null) ...[
          // KOT Format (simplified for kitchen)
          if (data.kotStatus?.toUpperCase() == 'CANCEL') ...[
            pw.Center(
              child: pw.Text(
                'CANCEL KOT',
                style: pw.TextStyle(fontSize: storeNameSize, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 4),
            _buildDashedLine(isSmallMedia: isSmallMedia),
            pw.SizedBox(height: 6),
          ],
          pw.Text(
            'KOT #: ${data.kotNumber.toString().padLeft(3, '0')}',
            style: pw.TextStyle(fontSize: headerBadgeSize, fontWeight: pw.FontWeight.bold),
          ),
          if (data.cancelReference != null && data.kotStatus?.toUpperCase() == 'CANCEL') ...[
            pw.Text(
              'Reference: ${data.cancelReference}',
              style: pw.TextStyle(fontSize: headerBadgeSize, fontWeight: pw.FontWeight.bold),
            ),
          ],
          if (data.tableNo != null && data.tableNo!.isNotEmpty) ...[
            pw.Text(
              'Table: ${data.tableNo}',
              style: pw.TextStyle(fontSize: labelSize, fontWeight: pw.FontWeight.bold),
            ),
          ],
          if (data.orderNo != null && data.orderNo!.isNotEmpty) ...[
            pw.Text(
              'Order No: ${data.orderNo}',
              style: pw.TextStyle(fontSize: headerBadgeSize, fontWeight: pw.FontWeight.bold),
            ),
          ],
          if (PrintSettings.showOrderType && data.orderType != null) ...[
            pw.Text(
              'Type: ${data.orderType!.toUpperCase()}${(data.isAddonKot == true && data.kotStatus?.toUpperCase() != 'CANCEL') ? ' (ADD-ON)' : ''}',
              style: pw.TextStyle(fontSize: headerBadgeSize, fontWeight: pw.FontWeight.bold),
            ),
          ],
          if (data.orderTimestamp != null) ...[
            pw.Text(
              _formatDateTime(data.orderTimestamp!.toIso8601String()),
              style: pw.TextStyle(fontSize: labelSize, fontWeight: pw.FontWeight.bold),
            ),
          ],
          // Order-level kitchen note (e.g. "No onions") — KOT only.
          if (data.kotRemark != null && data.kotRemark!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            _buildDashedLine(isSmallMedia: isSmallMedia),
            pw.SizedBox(height: 2),
            pw.Text(
              'Note: ${data.kotRemark!.trim()}',
              style: pw.TextStyle(fontSize: headerBadgeSize, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ] else ...[
          // Regular Receipt Info - Show Bill Number for completed orders
          if (showInvoiceNumber) ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(data.billNumber != null ? 'Bill No:' : 'Receipt #:', style: pw.TextStyle(fontSize: labelSize, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  data.billNumber != null
                      ? 'INV${data.billNumber}'
                      : data.sale.displayNumber,
                  style: pw.TextStyle(fontSize: labelSize, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ],
          // KOT numbers are internal kitchen info — never shown on the customer bill
          if (showInvoiceDate) ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Date:', style: pw.TextStyle(fontSize: labelSize, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  _formatDateTime(data.sale.date),
                  style: pw.TextStyle(fontSize: labelSize, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ],
          // Order Type field (Dine-in/Takeaway/Delivery)
          if (PrintSettings.showOrderType && data.orderType != null) ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Order Type:', style: pw.TextStyle(fontSize: labelSize, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  data.orderType!.toUpperCase(),
                  style: pw.TextStyle(fontSize: labelSize, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ],
          // Token/Order Number
          if (data.orderNo != null && data.orderNo!.isNotEmpty) ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Token #:', style: pw.TextStyle(fontSize: labelSize, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  data.orderNo!,
                  style: pw.TextStyle(fontSize: labelSize, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ],
          if (showPaymentMethod) ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Payment:', style: pw.TextStyle(fontSize: labelSize, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  data.sale.paymentType.toUpperCase(),
                  style: pw.TextStyle(fontSize: labelSize, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ],
          if (showCustomer && data.customer != null) ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Customer:', style: pw.TextStyle(fontSize: labelSize, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  data.customer!.name ?? '',
                  style: pw.TextStyle(fontSize: labelSize, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ],
        ],

        pw.SizedBox(height: lineSpacing),
        _buildDashedLine(isSmallMedia: isSmallMedia),
        pw.SizedBox(height: lineSpacing),
        // Items List - Different format for KOT vs Regular Receipt
        if (data.kotNumber != null) ...[
          // KOT Format: Just item name and quantity (no prices)
          ...data.items.map((item) => _buildKOTItemRow(
                item,
                data,
                fontSize: isPaperSaver
                    ? (isSmallMedia ? 7.5 : 9.0)
                    : (isSmallMedia ? 9.0 : 11.0),
                subFontSize: isPaperSaver
                    ? (isSmallMedia ? 6.0 : 7.5)
                    : (isSmallMedia ? 7.5 : 9.5),
                isPaperSaver: isPaperSaver,
              )),
          pw.SizedBox(height: lineSpacing),
          _buildDashedLine(isSmallMedia: isSmallMedia),
          // No footer for KOT - just end here
        ] else ...[
          // Regular Receipt Format: With headers and prices
          // Items Header
          pw.Row(
            children: [
              // HSN/SAC — retail bills only; restaurant header is unchanged.
              if (AppConfig.isRetail)
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(TariffCodeRule.shortLabel, style: pw.TextStyle(fontSize: tableHeaderSize, fontWeight: pw.FontWeight.bold)),
                ),
              pw.Expanded(
                flex: 3,
                child: pw.Text('Item', style: pw.TextStyle(fontSize: tableHeaderSize, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Expanded(
                flex: 1,
                child: pw.Text('Qty', style: pw.TextStyle(fontSize: tableHeaderSize, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Text('Price', style: pw.TextStyle(fontSize: tableHeaderSize, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Text('Amount', style: pw.TextStyle(fontSize: tableHeaderSize, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
              ),
            ],
          ),
          pw.SizedBox(height: lineSpacing),

          // Items List
          ...data.items.map((item) => _buildThermalItemRow(
                item,
                fontSize: bodySize,
                subFontSize: bodySize - 1.0,
                isPaperSaver: isPaperSaver,
                showItemDiscount: showItemDiscount,
              )),

          pw.SizedBox(height: lineSpacing),
          _buildDashedLine(isSmallMedia: isSmallMedia),
          pw.SizedBox(height: lineSpacing),

          // Totals - Display only (NO calculations)
          // All values pre-calculated by CartCalculationService
          () {
            // One detector for all three receipt layouts — see
            // [_receiptIsInclusive]. Held locally because the rows below read it
            // several times.
            final bool inclusive = _receiptIsInclusive(data);
            // Per-rate base for the tax table — the same figure the Amount
            // column prints, so rows and the tax table can never disagree.
            double lineGross(SaleItemModel it) => receiptLineGross(it);
            // Per-rate tax summary. A line discount belongs to its own GST
            // bucket; only the ORDER-level remainder is spread proportionally.
            // Passing the total as billDiscount would deduct line discounts
            // twice and smear them across every rate. 0% dropped.
            final taxLines = TaxBreakdown.computeWithLineDiscounts(
              items: data.items
                  .map((it) => (
                        gross: lineGross(it),
                        lineDiscount: receiptLineDiscount(it),
                        ratePercent: it.gstRate ?? 0,
                      ))
                  .toList(),
              billDiscount:
                  receiptBillDiscountRemainder(data.sale, data.items),
              isTaxInclusive: inclusive,
              reconcileToGst: data.sale.taxAmount, // lines must sum to the order's GST
            );
            final bool hasGst = showTax && taxLines.isNotEmpty;
            // Authoritative total — always matches the order's GST.
            final double totalGst = data.sale.taxAmount;
            // Tax toggle OFF → collapse the per-rate table to a single summary
            // line so Sub Total + Tax still reconcile to the Grand Total.
            final bool showTaxSummaryLine = data.taxEnabled && !showTax && totalGst > 0.009;

            return pw.Column(
              children: [
                if (showSubtotal)
                  _buildThermalTotalRow(
                      'Sub Total:', data.itemTotal ?? data.sale.subtotal, fontSize: totalRowSize),
                // Discount, split so a per-line reduction is not passed off as a
                // generic bill discount. Both figures come from the same items
                // rendered above, so the rows always sum to sale.discountAmount.
                if (showSubtotal &&
                    receiptLineDiscountTotal(data.items) > 0.009)
                  _buildThermalTotalRow(
                      'Item Discounts',
                      -receiptLineDiscountTotal(data.items),
                      fontSize: totalRowSize),
                if (showSubtotal &&
                    receiptBillDiscountRemainder(data.sale, data.items) > 0.009)
                  _buildThermalTotalRow(
                      receiptLineDiscountTotal(data.items) > 0.009
                          ? 'Bill Discount'
                          : 'Discount',
                      -receiptBillDiscountRemainder(data.sale, data.items),
                      fontSize: totalRowSize),
                if ((data.loyaltyPointsDiscount ?? 0) > 0)
                  _buildThermalTotalRow('Points Redeemed',
                      -(data.loyaltyPointsDiscount!.toDouble()), fontSize: totalRowSize),

                // Per-rate GST table (Taxable / CGST / SGST / Total Tax), framed
                // by dashed lines. Only when GST applies — all-0% bills skip it.
                if (hasGst) ...[
                  pw.SizedBox(height: lineSpacing),
                  _buildDashedLine(isSmallMedia: isSmallMedia),
                  pw.SizedBox(height: lineSpacing),
                  _buildTaxSummaryHeader(),
                  ...taxLines.map(_buildTaxSummaryRow),
                  pw.SizedBox(height: lineSpacing),
                  _buildDashedLine(isSmallMedia: isSmallMedia),
                  pw.SizedBox(height: lineSpacing),
                  _buildThermalTotalRow(
                      inclusive ? 'Total Tax (Included)' : 'Total Tax:',
                      totalGst, fontSize: totalRowSize),
                ] else if (showTaxSummaryLine)
                  _buildThermalTotalRow(
                      inclusive ? 'Tax (Incl.)' : 'Tax',
                      totalGst, fontSize: totalRowSize),

                // Service / Delivery Charge
                if ((data.serviceCharge ?? 0) > 0.009)
                  _buildThermalTotalRow(
                    (data.isDeliveryOrder ?? false)
                        ? 'Delivery Charge'
                        : 'Service Charge',
                    data.serviceCharge!,
                    fontSize: totalRowSize,
                  ),
              ],
            );
          }(),

          // Second Separator
          pw.SizedBox(height: lineSpacing),
          _buildDashedLine(isSmallMedia: isSmallMedia),
          pw.SizedBox(height: lineSpacing),

          // Round Off
          if ((data.roundOff ?? 0).abs() > 0.009)
            _buildThermalTotalRow('Round Off', data.roundOff!, fontSize: totalRowSize),

          // Grand Total
          _buildThermalTotalRow('TOTAL', data.sale.totalAmount, isBold: true, fontSize: grandTotalSize),

          // Payment status - Show only for PAID orders (NOT PAID already shown at top)
          if (showPaymentMethod && data.sale.isSplitPayment != true && data.sale.paymentType != null && data.sale.paymentType != 'credit' && data.sale.paymentType != 'NOT PAID') ...[
            _buildThermalTotalRow('Paid by ${data.sale.paymentType!.toUpperCase()}', data.sale.totalAmount, fontSize: totalRowSize),
          ],

          // Credit sale info
          if (data.sale.paymentType == 'credit' || data.sale.dueAmount > 0) ...[
            pw.SizedBox(height: lineSpacing),
            _buildDashedLine(isSmallMedia: isSmallMedia),
            pw.SizedBox(height: lineSpacing),
            _buildThermalTotalRow('Paid', data.sale.paidAmount, fontSize: totalRowSize),
            _buildThermalTotalRow('DUE', data.sale.dueAmount, isBold: true, fontSize: totalRowSize),
            pw.SizedBox(height: lineSpacing),
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.5),
              ),
              child: pw.Text(
                '** CREDIT SALE - PAYMENT PENDING **',
                style: pw.TextStyle(fontSize: totalRowSize, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],

          pw.SizedBox(height: lineSpacing),
          _buildDashedLine(isSmallMedia: isSmallMedia),

          // Split Payment Breakdown
          if (showPaymentPaid &&
              (data.sale.paymentList.length > 1 ||
                  data.sale.isSplitPayment == true)) ...[
            pw.SizedBox(height: 4),
            ..._buildSplitPaymentSection(data.sale, fontSize: totalRowSize, isSmallMedia: isSmallMedia),
            pw.SizedBox(height: 4),
            _buildDashedLine(isSmallMedia: isSmallMedia),
          ],
          pw.SizedBox(height: lineSpacing),

          // UPI "Scan & Pay" — only on UNPAID bills with UPI configured.
          ..._buildUpiPaySection(data, qrSize: qrS, fontSize: totalRowSize, isSmallMedia: isSmallMedia, isPaperSaver: isPaperSaver),

          // Footer
          // Outside the restaurant-only block: the ESC/POS builder prints this
          // for both verticals, so keeping it in there made the SAME retail
          // sale say different things depending on the printer route.
          if (data.taxEnabled && _receiptIsInclusive(data))
            pw.Text(
              'All prices include ${TaxLabelRule.name}',
              style: pw.TextStyle(fontSize: isSmallMedia ? 8 : 10),
              textAlign: pw.TextAlign.center,
            ),
          if (AppConfig.isRestaurant) ...[
            // Dynamic footer / "Thank You" message (owner-editable, multi-line).
            if (PrintSettings.footerMessage.trim().isNotEmpty)
              pw.Text(
                PrintSettings.footerMessage.trim(),
                style: pw.TextStyle(fontSize: footerSize, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            // "Powered by" + company line — forced by the admin flag, else the
            // shop's "Powered By" toggle decides.
            if (PlanEnforce.allows(ModeKeys.billingInvoicePrint) ||
                PrintSettings.showPoweredBy) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                'Powered by Bill Berry Lite',
                style: pw.TextStyle(fontSize: isSmallMedia ? 7.5 : 9),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Accrete Infosolution Technologies Private Limited',
                style: pw.TextStyle(fontSize: isSmallMedia ? 6.5 : 8),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Ph: 7041046049',
                style: pw.TextStyle(fontSize: isSmallMedia ? 6.5 : 8),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ] else if (showFooter) ...[
            if (footerText.isNotEmpty) ...[
              pw.Text(
                footerText,
                style: pw.TextStyle(fontSize: footerSize, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            ] else ...[
              pw.Text(
                'Thank you for your purchase!',
                style: pw.TextStyle(fontSize: footerSize + 1, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Visit us again!',
                style: pw.TextStyle(fontSize: footerSize),
              ),
            ],
          ],
          pw.SizedBox(height: 8),

          // Points earned (if customer)
          if (!AppConfig.isRestaurant && data.customer != null) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.5),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'Points Earned: ${LoyaltyPoints.earnedFor(data.sale.totalAmount)}',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Total Points: ${data.customer!.loyaltyPoints}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
          ],
          // Bottom print-time removed — the order date/time is already shown at
          // the top in the bill info.
        ],
      ],
    );
  }

  /// Build A4 invoice content
  pw.Widget _buildInvoiceContent(ReceiptData data) {
    final storeName = data.storeName ?? defaultStoreName;
    final storeAddress = data.storeAddress ?? defaultStoreAddress;
    final storePhone = data.storePhone ?? defaultStorePhone;
    final storeEmail = data.storeEmail ?? 'store@example.com';

    // Get settings based on mode
    final retailSettings = _getRetailSettings();
    final isRetail = AppConfig.isRetail;

    // Determine what to show based on mode
    final showLogo = isRetail ? (retailSettings?.showLogo ?? true) : PrintSettings.showRestaurantLogo;
    final showStoreName = isRetail ? (retailSettings?.showStoreName ?? true) : true;
    final showStoreAddress = isRetail ? (retailSettings?.showStoreAddress ?? true) : true;
    final showStorePhone = isRetail ? (retailSettings?.showStorePhone ?? true) : true;
    final showStoreEmail = isRetail ? (retailSettings?.showStoreEmail ?? false) : true;
    final showGST = data.taxEnabled && (isRetail ? (retailSettings?.showGSTNumber ?? true) : true);
    final showInvoiceNumber = isRetail ? (retailSettings?.showInvoiceNumber ?? true) : true;
    final showInvoiceDate = isRetail ? (retailSettings?.showInvoiceDate ?? true) : true;
    final showCustomer = isRetail ? (retailSettings?.showCustomerDetails ?? true) : true;
    final showPaymentMethod = isRetail ? (retailSettings?.showPaymentMethod ?? true) : true;
    final showSubtotal = isRetail ? (retailSettings?.showSubtotal ?? true) : true;
    final showDiscount = isRetail ? (retailSettings?.showDiscount ?? true) : true;
    final showTax = data.taxEnabled && (isRetail ? (retailSettings?.showTax ?? true) : true);
    final showGrandTotal = isRetail ? (retailSettings?.showGrandTotal ?? true) : true;
    final showLoyaltyPoints = isRetail ? (retailSettings?.showLoyaltyPoints ?? true) : true;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Store Logo and Info
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Logo — larger on restaurant invoices for brand visibility.
                  if (showLogo && data.logoBytes != null) ...[
                    pw.Container(
                      width: AppConfig.isRestaurant ? 120 : 80,
                      height: AppConfig.isRestaurant ? 120 : 80,
                      child: pw.Image(
                        pw.MemoryImage(data.logoBytes!),
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                    pw.SizedBox(width: 16),
                  ],
                  // Store Info
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (showStoreName)
                          pw.Text(
                            storeName,
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green800,
                            ),
                          ),
                        if (showStoreName) pw.SizedBox(height: 4),
                        if (showStoreAddress)
                          pw.Text(storeAddress, style: const pw.TextStyle(fontSize: 10)),
                        if (showStorePhone)
                          pw.Text('Phone: $storePhone', style: const pw.TextStyle(fontSize: 10)),
                        if (showStoreEmail)
                          pw.Text('Email: $storeEmail', style: const pw.TextStyle(fontSize: 10)),
                        if (showGST && data.gstNumber != null)
                          pw.Text('${TaxIdRule.printLabel}: ${data.gstNumber}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        if (FoodLicenseRule.number != null)
                          pw.Text('${FoodLicenseRule.label}: ${FoodLicenseRule.number}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Invoice Title
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green800,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    data.sale.isReturn == true ? 'CREDIT NOTE' : 'INVOICE',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
                // Both halves of an exchange print their shared reference.
                if (data.sale.exchangeGroupId != null) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'EXCHANGE ${data.sale.exchangeGroupId}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
                if (showInvoiceNumber || showInvoiceDate) pw.SizedBox(height: 8),
                if (showInvoiceNumber)
                  pw.Text(
                    data.billNumber != null
                        ? '# INV${data.billNumber}'
                        : '# ${data.sale.displayNumber}',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                if (showInvoiceNumber && showInvoiceDate) pw.SizedBox(height: 4),
                if (showInvoiceDate)
                  pw.Text(
                    'Date: ${_formatDate(data.sale.date)}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 24),

        // Restaurant Order Type Badge (if available)
        if (data.orderType != null) ...[
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: pw.BoxDecoration(
              color: _getOrderTypeColor(data.orderType!),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  data.orderType!.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                if (data.tableNo != null) ...[
                  pw.SizedBox(width: 12),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0x4DFFFFFF), // 30% opacity white
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      'Table: ${data.tableNo}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 16),
        ],

        // Bill To / Payment Info
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Bill To
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'BILL TO',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    if (data.customer != null) ...[
                      pw.Text(
                        data.customer!.name ?? '',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(data.customer!.phone ?? '', style: const pw.TextStyle(fontSize: 10)),
                      if (data.customer!.email != null)
                        pw.Text(data.customer!.email!, style: const pw.TextStyle(fontSize: 10)),
                      if (data.customer!.address != null)
                        pw.Text(data.customer!.address!, style: const pw.TextStyle(fontSize: 10)),
                    ] else ...[
                      pw.Text(
                        data.orderType != null ? '${data.orderType} Customer' : 'Walk-in Customer',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 16),
            // Payment Info
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ORDER DETAILS',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    _buildInvoiceInfoRow('Payment Method:', data.sale.paymentType.toUpperCase()),
                    _buildInvoiceInfoRow('Status:', _invoiceStatus(data.sale)),
                    _buildInvoiceInfoRow('Total Items:', '${data.sale.totalItems}'),
                    if (data.orderNo != null && data.orderNo!.isNotEmpty)
                      _buildInvoiceInfoRow('Token #:', data.orderNo!),
                    if (data.tableNo != null)
                      _buildInvoiceInfoRow('Table Number:', data.tableNo!),
                  ],
                ),
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 24),

        // Items Table
        _buildInvoiceTable(data.items),

        pw.SizedBox(height: 16),

        // Tax Summary (per-rate GST breakdown) — parity with thermal receipt.
        ..._buildInvoiceTaxSummary(data, showTax),

        // Totals Section - Display only (NO calculations)
        // All values pre-calculated by CartCalculationService
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // UPI Scan & Pay QR (unpaid bills) sits in the empty space at the
            // left, top-aligned with the totals — compact, not stranded below.
            pw.Expanded(child: _buildInvoiceUpiBox(data)),
            pw.Container(
              width: 250,
              child: () {
                // Was `AppConfig.isRestaurant && ...`, i.e. permanently false in
                // retail — so a retail invoice priced tax-inclusive still
                // printed "Sub Total (Before Tax)" and an added-looking GST row,
                // and could never show the "Tax (Incl.)" line at all.
                final isInclusive = _receiptIsInclusive(data);

                // ✅ GOLDEN RULE: Only display pre-calculated values
                // itemTotal: From CartCalculationService.itemTotal
                // discountAmount: From CartCalculationService.discountAmount
                // subtotal: From CartCalculationService.taxableAmount (mapped to sale.subtotal)
                // taxAmount: From CartCalculationService.totalGST (mapped to sale.taxAmount)
                // totalAmount: From CartCalculationService.grandTotal (mapped to sale.totalAmount)

                return pw.Column(
                  children: [
                    // Item Total - Pre-calculated
                    if (showSubtotal && data.itemTotal != null)
                      _buildInvoiceTotalRow('Item Total', data.itemTotal!),
                    // Discount, split into the per-line part and the
                    // order-level remainder. Same figures as the item table's
                    // Discount column, so the two always agree.
                    if (showDiscount &&
                        receiptLineDiscountTotal(data.items) > 0.009)
                      _buildInvoiceTotalRow(
                          'Item Discounts',
                          -receiptLineDiscountTotal(data.items),
                          isRed: true),
                    if (showDiscount &&
                        receiptBillDiscountRemainder(data.sale, data.items) >
                            0.009)
                      _buildInvoiceTotalRow(
                          receiptLineDiscountTotal(data.items) > 0.009
                              ? 'Bill Discount'
                              : 'Discount',
                          -receiptBillDiscountRemainder(
                              data.sale, data.items),
                          isRed: true),
                    // Points Redeemed - only show if loyalty points were used
                    if ((data.loyaltyPointsDiscount ?? 0) > 0)
                      _buildInvoiceTotalRow('Points Redeemed', -(data.loyaltyPointsDiscount!.toDouble()), isRed: true),

                    // First Separator
                    if (showSubtotal) pw.Divider(thickness: 0.5),

                    // Sub Total / Taxable Amount — only for tax-exclusive
                    if (!isInclusive && showSubtotal)
                      _buildInvoiceTotalRow('Sub Total (Before Tax)', data.sale.subtotal),
                    // GST summary row (exclusive) — always shown so the invoice
                    // reconciles even when the detailed table above is toggled off.
                    if (data.taxEnabled && !isInclusive && data.sale.taxAmount > 0)
                      _buildInvoiceTotalRow(TaxLabelRule.name, data.sale.taxAmount),
                    // Inclusive mode: the detailed table carries tax; when it's
                    // toggled off, show a single informational line instead.
                    if (data.taxEnabled && isInclusive && !showTax && data.sale.taxAmount > 0)
                      _buildInvoiceTotalRow('Tax (Incl.)', data.sale.taxAmount),
                    // Service / Delivery Charge
                    if ((data.serviceCharge ?? 0) > 0.009)
                      _buildInvoiceTotalRow(
                        (data.isDeliveryOrder ?? false) ? 'Delivery Charge' : 'Service Charge',
                        data.serviceCharge!,
                      ),

                    // Second Separator
                    if (showGrandTotal) pw.Divider(thickness: 1),

                    // Round Off
                    if ((data.roundOff ?? 0).abs() > 0.009)
                      _buildInvoiceTotalRow('Round Off', data.roundOff!),

                    // Grand Total - Pre-calculated
                    if (showGrandTotal)
                      _buildInvoiceTotalRow('TOTAL', data.sale.totalAmount, isBold: true, fontSize: 14),

                    // Payment status — match thermal: skip the single "Paid by"
                    // line for split payments (the per-method breakdown is shown
                    // below) and for credit (handled in the due section).
                    if (showPaymentMethod && data.sale.isSplitPayment != true && data.sale.paymentType != 'credit') ...[
                      if (data.sale.paymentType == 'NOT PAID')
                        _buildInvoiceTotalRow('NOT PAID', data.sale.totalAmount, fontSize: 11)
                      else
                        _buildInvoiceTotalRow('Paid by ${data.sale.paymentType.toUpperCase()}', data.sale.totalAmount, fontSize: 11),
                    ],

                    // Credit sale payment info
                    if (data.sale.paymentType == 'credit' || data.sale.dueAmount > 0) ...[
                      pw.SizedBox(height: 8),
                      pw.Divider(thickness: 0.5),
                      _buildInvoiceTotalRow('Amount Paid', data.sale.paidAmount, isRed: false),
                      _buildInvoiceTotalRow('Amount Due', data.sale.dueAmount, isBold: true, isRed: true, fontSize: 12),
                      if (data.sale.paymentType == 'credit')
                        pw.Container(
                          margin: const pw.EdgeInsets.only(top: 8),
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.red50,
                            borderRadius: pw.BorderRadius.circular(4),
                            border: pw.Border.all(color: PdfColors.red),
                          ),
                          child: pw.Text(
                            'CREDIT SALE - PAYMENT PENDING',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.red,
                            ),
                          ),
                        ),
                    ],
                  ],
                );
              }(),
            ),
          ],
        ),

        pw.SizedBox(height: 24),

        // Split Payment Section (for multiple payment methods)
        _buildInvoiceSplitPaymentSection(data.sale),

        pw.SizedBox(height: 16),

        // Customer Points Section
        if (!AppConfig.isRestaurant && showLoyaltyPoints && data.customer != null) ...[
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.green800),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Loyalty Points Earned:',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  '${LoyaltyPoints.earnedFor(data.sale.totalAmount)} points',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
        ],

        // Footer
        pw.Spacer(),
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(
                // Restaurant: owner-editable footer message. Retail: unchanged.
                AppConfig.isRestaurant &&
                        PrintSettings.footerMessage.trim().isNotEmpty
                    ? PrintSettings.footerMessage.trim()
                    : 'Thank you for your business!',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 4),
              // Not restaurant-only: the ESC/POS builder prints this for both
              // verticals, so gating it here made the SAME retail sale say
              // different things depending on which printer route it took.
              if (data.taxEnabled && _receiptIsInclusive(data))
                pw.Text(
                  'All prices include ${TaxLabelRule.name}',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              pw.Text(
                'This is a computer-generated invoice.',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
              // "Powered by" + company line — restaurant only. Forced by the admin
              // `billing.invoice.print` flag; otherwise the shop's toggle decides.
              if (AppConfig.isRestaurant &&
                  (PlanEnforce.allows(ModeKeys.billingInvoicePrint) ||
                      PrintSettings.showPoweredBy)) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  'Powered by Bill Berry Lite',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Accrete Infosolution Technologies Private Limited',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  'Ph: 7041046049',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// UPI "Scan & Pay" block for the A4 invoice — mirrors the thermal receipt's
  /// [_buildUpiPaySection]: shown only on unpaid bills with UPI configured.
  /// Prefers a pre-rendered QR image, else builds a upi:// QR with the amount.
  /// Compact UPI "Scan & Pay" box for the A4 invoice, placed to the left of the
  /// totals (top-aligned). Returns an empty box when hidden/paid/no-UPI so the
  /// totals stay right-aligned. Mirrors the thermal receipt's UPI logic.
  pw.Widget _buildInvoiceUpiBox(ReceiptData data) {
    if (!PrintSettings.showUpiQr) return pw.SizedBox(); // customization toggle
    final hasUpiId = (data.upiId?.trim().isNotEmpty ?? false);
    final hasQrImage = data.upiQrImageBytes != null;
    if (!hasUpiId && !hasQrImage) return pw.SizedBox();

    final unpaid = data.sale.paymentType == 'NOT PAID';
    // Restaurant prints the QR on every invoice (paid or unpaid); retail keeps
    // it to unpaid invoices only.
    if (!AppConfig.isRestaurant && !unpaid) return pw.SizedBox();

    final payee = (data.upiPayeeName?.trim().isNotEmpty ?? false)
        ? data.upiPayeeName!.trim()
        : (data.storeName ?? 'Merchant');
    // When "UPI QR Amount" is on and a VPA exists, generate a fresh QR with the
    // bill total baked in (…&am=…) so scanning pre-fills the amount — this wins
    // over the merchant's static QR image. Otherwise use the static image, then a
    // plain amount-less dynamic QR.
    final embedAmount = PrintSettings.showUpiQrAmount && hasUpiId;
    pw.Widget qr;
    if (embedAmount) {
      final link = 'upi://pay?pa=${data.upiId!.trim()}'
          '&pn=${Uri.encodeComponent(payee)}'
          '&am=${data.sale.totalAmount.toStringAsFixed(2)}&cu=INR';
      qr = pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(), data: link, width: 76, height: 76);
    } else if (hasQrImage) {
      qr = pw.Image(pw.MemoryImage(data.upiQrImageBytes!), width: 76, height: 76);
    } else {
      final link = 'upi://pay?pa=${data.upiId!.trim()}'
          '&pn=${Uri.encodeComponent(payee)}&cu=INR';
      qr = pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(), data: link, width: 76, height: 76);
    }

    return pw.Align(
      alignment: pw.Alignment.topLeft,
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.green800),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text('Scan & Pay via UPI',
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green800)),
            pw.SizedBox(height: 6),
            qr,
            pw.SizedBox(height: 4),
            pw.Text('Amount: ${_formatCurrency(data.sale.totalAmount)}',
                style:
                    pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  /// Real payment status for the A4 invoice header — never hardcoded.
  /// Reflects the same truth the thermal receipt prints (payment + due state).
  String _invoiceStatus(SaleModel sale) {
    final pt = sale.paymentType.toUpperCase();
    if (pt == 'NOT PAID') return 'NOT PAID';
    if (pt == 'CREDIT' || sale.dueAmount > 0.009) {
      return sale.paidAmount > 0.009 ? 'PARTIALLY PAID' : 'UNPAID';
    }
    return 'PAID';
  }

  /// Per-rate GST summary table for the A4 invoice — mirrors the thermal
  /// receipt's tax breakdown (GST% / Taxable / CGST / SGST / Total per rate).
  /// Returns an empty list when tax is hidden or the bill has no taxed lines.
  List<pw.Widget> _buildInvoiceTaxSummary(ReceiptData data, bool showTax) {
    if (!showTax) return [];

    // Same detector as the thermal layouts — see [_receiptIsInclusive].
    final bool inclusive = _receiptIsInclusive(data);
    // Per-rate base for the tax table — the same figure the Amount column
    // prints, so rows and the tax table can never disagree.
    double lineGross(SaleItemModel it) => receiptLineGross(it);

    // Same reasoning as the thermal path: a line discount stays in its own GST
    // bucket, and only the order-level remainder is spread proportionally.
    final taxLines = TaxBreakdown.computeWithLineDiscounts(
      items: data.items
          .map((it) => (
                gross: lineGross(it),
                lineDiscount: receiptLineDiscount(it),
                ratePercent: it.gstRate ?? 0,
              ))
          .toList(),
      billDiscount: receiptBillDiscountRemainder(data.sale, data.items),
      isTaxInclusive: inclusive,
      reconcileToGst: data.sale.taxAmount, // lines must sum to the order's GST
    );
    if (taxLines.isEmpty) return [];

    final totalGst = data.sale.taxAmount;

    String n(double v) => v.toStringAsFixed(2);

    pw.Widget headerCell(String t, {pw.TextAlign align = pw.TextAlign.right}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text(t,
              textAlign: align,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white)),
        );

    pw.Widget cell(String t,
            {bool bold = false, pw.TextAlign align = pw.TextAlign.right}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: pw.Text(t,
              textAlign: align,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        );

    return [
      pw.Text('Tax Summary',
          style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800)),
      pw.SizedBox(height: 6),
      pw.Container(
        width: 340,
        child: pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.8),
            1: const pw.FlexColumnWidth(1.6),
            2: const pw.FlexColumnWidth(1.4),
            3: const pw.FlexColumnWidth(1.6),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.green800),
              children: [
                headerCell('Tax', align: pw.TextAlign.left),
                headerCell('Taxable'),
                headerCell(TaxLabelRule.name),
                headerCell('Total'),
              ],
            ),
            ...taxLines.map((l) {
              return pw.TableRow(children: [
                cell(_taxLabel(l.ratePercent), align: pw.TextAlign.left),
                cell(n(l.taxable)),
                cell(n(l.gst)),
                cell(n(l.taxable + l.gst)),
              ]);
            }),
          ],
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Container(
        width: 340,
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(inclusive ? 'Total GST (Included):' : 'Total GST:',
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.Text(_formatCurrency(totalGst),
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
      pw.SizedBox(height: 16),
    ];
  }

  /// Build item row for KOT (Kitchen Order Ticket) - Simple format without prices
  pw.Widget _buildKOTItemRow(SaleItemModel item, ReceiptData data, {double fontSize = 14, double subFontSize = 12, bool isPaperSaver = false}) {
    final name = item.productName ?? 'Unknown';
    // Format item name with variant in parentheses: "Veg Pizza (Medium)"
    final displayName = item.size != null ? '$name (${item.size})' : name;

    // Cancel KOT: strike through the name and flag the qty as CANCEL (a clean,
    // font-safe marker — the old ❌ emoji had no glyph and printed as a box).
    final bool isCancel = data.kotStatus?.toUpperCase() == 'CANCEL';

    return pw.Container(
      padding: pw.EdgeInsets.only(
        top: isPaperSaver ? 1.0 : 3.0,
        bottom: isPaperSaver ? 1.0 : 3.0,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Item name (with variant) and quantity in a row
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text(
                  displayName,
                  style: pw.TextStyle(
                    fontSize: fontSize,
                    fontWeight: pw.FontWeight.bold,
                    decoration: isCancel
                        ? pw.TextDecoration.lineThrough
                        : pw.TextDecoration.none,
                  ),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Text(
                isCancel ? 'CANCEL x${item.qty}' : 'x${item.qty}',
                style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          // Display extras and add-ons (stored in weight field)
          if (item.weight != null && item.weight!.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 4, top: 1),
              child: pw.Text(
                '  ${item.weight!}',
                style: pw.TextStyle(fontSize: subFontSize, color: PdfColors.grey700),
              ),
            ),
        ],
      ),
    );
  }

  /// Build item row for thermal receipt
  pw.Widget _buildThermalItemRow(SaleItemModel item, {double fontSize = 9, double subFontSize = 8, bool isPaperSaver = false, bool showItemDiscount = false}) {
    final name = item.productName ?? 'Unknown';
    // Full name + variant — let it WRAP (no truncation) so variant/extra details
    // in parentheses aren't hidden behind an ellipsis.
    // Label only when we have real attribute names to show, i.e. a retail sale
    // recorded with generic attributes → "(Storage: 1tb)". Restaurant items
    // carry no map and fall back to the legacy columns, where `size` holds the
    // variant name — those stay bare, so KOT/bills still read "(Large)".
    final hasNamedAttributes = item.attributes?.isNotEmpty ?? false;
    final descriptor = describeAttributeMap(
      item.attributes,
      size: item.size,
      color: item.color,
      labelled: hasNamedAttributes,
    );
    final displayName = descriptor.isEmpty ? name : '$name ($descriptor)';

    // Rate and Amount both come off receiptLineGross, so the column sums to
    // Sub Total. Printing item.total here put a tax-inclusive ₹118 line above
    // a ₹100 ex-tax Sub Total on every retail bill.
    final lineAmount = receiptLineGross(item);
    final unitPrice = item.qty > 0 ? lineAmount / item.qty : lineAmount;

    final hsn = (item.hsnCode?.trim().isNotEmpty ?? false) ? item.hsnCode!.trim() : '-';

    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: isPaperSaver ? 0.5 : 2.0),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            // Top-align so Qty/Price/Amount stay on the first line when the
            // name wraps to two lines.
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HSN/SAC — retail bills only; must mirror the header's flex.
              if (AppConfig.isRetail)
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(hsn, style: pw.TextStyle(fontSize: fontSize)),
                ),
              pw.Expanded(
                flex: 3,
                child: pw.Text(displayName, style: pw.TextStyle(fontSize: fontSize)),
              ),
              pw.Expanded(
                flex: 1,
                child: pw.Text('${item.qty}', style: pw.TextStyle(fontSize: fontSize), textAlign: pw.TextAlign.center),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Text(
                  _formatCurrency(unitPrice),
                  style: pw.TextStyle(fontSize: fontSize),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Text(
                  _formatCurrency(lineAmount),
                  style: pw.TextStyle(fontSize: fontSize),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
          // This line's OWN discount, shown under it. The Amount column above
          // stays GROSS so it still sums to Sub Total and still matches what the
          // tax table was computed from; the totals block subtracts this once,
          // as "Item Discounts".
          if (showItemDiscount && receiptLineDiscount(item) > 0.009)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 8, top: 2),
              child: pw.Text(
                '${receiptLineDiscountLabel(item)}  '
                '-${_formatCurrency(receiptLineDiscount(item))}',
                style: pw.TextStyle(
                  fontSize: subFontSize,
                  color: PdfColors.grey600,
                ),
              ),
            ),
          // Display extras and add-ons (stored in weight field)
          if (item.weight != null && item.weight!.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 8, top: 2),
              child: pw.Text(
                item.weight!,
                style: pw.TextStyle(fontSize: subFontSize, color: PdfColors.grey600),
              ),
            ),
        ],
      ),
    );
  }

  /// "Scan & Pay via UPI" block — printed only on UNPAID bills when UPI is
  /// configured. Prefers the merchant's uploaded QR image; otherwise generates a
  /// dynamic UPI QR with the amount pre-filled. Returns [] when it shouldn't show.
  List<pw.Widget> _buildUpiPaySection(ReceiptData data, {double qrSize = 80, double fontSize = 12, bool isSmallMedia = false, bool isPaperSaver = false}) {
    if (!PrintSettings.showUpiQr) return []; // customization toggle
    final hasUpiId = (data.upiId?.trim().isNotEmpty ?? false);
    final hasQrImage = data.upiQrImageBytes != null;
    if (!hasUpiId && !hasQrImage) return [];

    final unpaid = data.sale.paymentType == 'NOT PAID';
    // Restaurant prints the QR on EVERY bill (paid, cash or unpaid); retail
    // keeps it to unpaid bills only.
    if (!AppConfig.isRestaurant && !unpaid) return [];

    final payee = (data.upiPayeeName?.trim().isNotEmpty ?? false)
        ? data.upiPayeeName!.trim()
        : (data.storeName ?? 'Merchant');
    // When "UPI QR Amount" is on and a VPA exists, generate a fresh QR with the
    // bill total baked in (…&am=…) so scanning pre-fills the amount — this wins
    // over the merchant's static QR image. Otherwise use the static image, then a
    // plain amount-less dynamic QR.
    final embedAmount = PrintSettings.showUpiQrAmount && hasUpiId;
    pw.Widget qr;
    if (embedAmount) {
      final link = 'upi://pay?pa=${data.upiId!.trim()}'
          '&pn=${Uri.encodeComponent(payee)}'
          '&am=${data.sale.totalAmount.toStringAsFixed(2)}&cu=INR';
      qr = pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(), data: link, width: qrSize, height: qrSize);
    } else if (hasQrImage) {
      qr = pw.Image(pw.MemoryImage(data.upiQrImageBytes!),
          width: qrSize, height: qrSize);
    } else {
      final link = 'upi://pay?pa=${data.upiId!.trim()}'
          '&pn=${Uri.encodeComponent(payee)}&cu=INR';
      qr = pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(), data: link, width: qrSize, height: qrSize);
    }

    return [
      // No leading divider — the section is always preceded by the divider
      // printed after the TOTAL, so adding one here doubled the dashed line.
      pw.Text('Scan & Pay via UPI',
          style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center),
      pw.SizedBox(height: isPaperSaver ? 1.0 : 3.0),
      pw.Center(child: qr),
      pw.SizedBox(height: isPaperSaver ? 1.0 : 3.0),
      _buildDashedLine(isSmallMedia: isSmallMedia),
      pw.SizedBox(height: isPaperSaver ? 1.0 : 2.0),
    ];
  }

  /// Label for a tax rate, e.g. "GST1 (5%)". Uses the configured tax name when
  /// a single tax matches the rate (restaurant); otherwise the country's own
  /// name for the tax — "VAT (20%)" in the UK, not "GST (20%)".
  String _taxLabel(double ratePercent) {
    final rateStr = ratePercent % 1 == 0
        ? ratePercent.toStringAsFixed(0)
        : ratePercent.toStringAsFixed(2);
    String name = TaxLabelRule.name;
    if (AppConfig.isRestaurant) {
      for (final t in taxStore.taxes) {
        if (((t.taxperecentage ?? 0) - ratePercent).abs() < 0.001 &&
            t.taxname.trim().isNotEmpty) {
          name = t.taxname.trim();
          break;
        }
      }
    }
    return '$name ($rateStr%)';
  }

  /// Header row for the per-rate GST table (Tax | Taxable | GST | Total).
  /// Small font so the whole block stays compact.
  /// The tax mode to assume when the totals detector cannot run — a credit
  /// note's gross is negative, so [TaxBreakdown.isInclusiveFromTotals] has
  /// nothing to work from.
  ///
  /// Retail falls back to the mode STORED on the sale. Restaurant additionally
  /// falls back to its own live setting. Gating the whole expression on
  /// `isRestaurant` made it permanently false in retail, so an inclusive retail
  /// bill printed exclusive labels.
  static bool _fallbackInclusive(ReceiptData data) => AppConfig.isRestaurant
      ? (data.isTaxInclusive ?? AppSettings.isTaxInclusive)
      : (data.isTaxInclusive ?? false);

  /// Whether THIS receipt was priced tax-inclusive. Derived from the order's
  /// own totals so a later settings change cannot re-label an old invoice,
  /// falling back to [_fallbackInclusive] when the totals cannot say.
  static bool _receiptIsInclusive(ReceiptData data) {
    final itemsGross =
        data.items.fold<double>(0, (s, it) => s + receiptLineGross(it));
    final grossTotal = data.itemTotal ?? itemsGross;
    if (grossTotal <= 0) return _fallbackInclusive(data);
    return TaxBreakdown.isInclusiveFromTotals(
      grossBeforeDiscount: grossTotal,
      discount: data.sale.discountAmount,
      taxAmount: data.sale.taxAmount,
      grandTotal: data.sale.totalAmount,
      serviceCharge: data.serviceCharge ?? 0,
      loyaltyDiscount: (data.loyaltyPointsDiscount ?? 0).toDouble(),
      fallback: _fallbackInclusive(data),
    );
  }

  pw.Widget _buildTaxSummaryHeader() {
    const style = pw.TextStyle(fontSize: 8, color: PdfColors.grey700);
    pw.Widget cell(String t, int flex, {pw.TextAlign align = pw.TextAlign.right}) =>
        pw.Expanded(flex: flex, child: pw.Text(t, style: style, textAlign: align));
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
      child: pw.Row(
        children: [
          cell('Tax', 6, align: pw.TextAlign.left),
          cell('Taxable', 5),
          cell(TaxLabelRule.name, 4),
          cell('Total', 5),
        ],
      ),
    );
  }

  /// One per-rate line: Tax (name + %) | Taxable | GST | Total (taxable + GST).
  pw.Widget _buildTaxSummaryRow(TaxRateLine line) {
    const style = pw.TextStyle(fontSize: 8);
    pw.Widget cell(String t, int flex, {pw.TextAlign align = pw.TextAlign.right}) =>
        pw.Expanded(flex: flex, child: pw.Text(t, style: style, textAlign: align));
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
      child: pw.Row(
        children: [
          cell(_taxLabel(line.ratePercent), 6, align: pw.TextAlign.left),
          cell(_formatCurrency(line.taxable), 5),
          cell(_formatCurrency(line.gst), 4),
          cell(_formatCurrency(line.taxable + line.gst), 5),
        ],
      ),
    );
  }

  /// Build total row for thermal receipt
  pw.Widget _buildThermalTotalRow(String label, double amount, {bool isBold = false, double fontSize = 14}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            _formatCurrency(amount),
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// Build items table for A4 invoice
  pw.Widget _buildInvoiceTable(List<SaleItemModel> items) {
    // HSN/SAC column is retail-only; restaurant keeps the original 6 columns.
    final isRetail = AppConfig.isRetail;
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: <pw.TableColumnWidth>[
        const pw.FlexColumnWidth(1), // #
        if (isRetail) const pw.FlexColumnWidth(2), // HSN
        const pw.FlexColumnWidth(4), // Product
        const pw.FlexColumnWidth(2), // Unit Price
        const pw.FlexColumnWidth(1), // Qty
        const pw.FlexColumnWidth(2), // Discount
        const pw.FlexColumnWidth(2), // Total
      ].asMap(),
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.green800),
          children: [
            _buildTableHeader('#'),
            if (isRetail) _buildTableHeader(TariffCodeRule.shortLabel),
            _buildTableHeader('Product'),
            _buildTableHeader('Unit Price'),
            _buildTableHeader('Qty'),
            _buildTableHeader('Discount'),
            _buildTableHeader('Total'),
          ],
        ),
        // Data rows
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final bgColor = index % 2 == 0 ? PdfColors.white : PdfColors.grey50;

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bgColor),
            children: [
              _buildTableCell('${index + 1}', align: pw.TextAlign.center),
              if (isRetail)
                _buildTableCell(
                  (item.hsnCode?.trim().isNotEmpty ?? false) ? item.hsnCode!.trim() : '-',
                  align: pw.TextAlign.center,
                ),
              _buildProductCell(item),
              _buildTableCell(_formatCurrency(item.price), align: pw.TextAlign.right),
              _buildTableCell('${item.qty}', align: pw.TextAlign.center),
              // Per-item Discount column.
              //
              // Retail shows the line's OWN discount only — `discountAmount`
              // there also carries the line's share of the order-level discount,
              // which the totals block already subtracts once as "Bill
              // Discount"; printing it here too would read as a double
              // deduction. Restaurant keeps reading `discountAmount`, which is
              // its only per-item figure and unchanged by line discounts.
              _buildTableCell(
                isRetail
                    ? (receiptLineDiscount(item) > 0.009
                        ? _formatCurrency(receiptLineDiscount(item))
                        : '-')
                    : (item.discountAmount != null && item.discountAmount! > 0
                        ? _formatCurrency(item.discountAmount!)
                        : '-'),
                align: pw.TextAlign.right,
              ),
              // Gross, matching the "Item Total" row in the totals block —
              // the Discount column beside it is subtracted once there, not
              // twice. item.total was tax-inclusive on retail, so this column
              // never summed to Item Total.
              _buildTableCell(_formatCurrency(receiptLineGross(item)),
                  align: pw.TextAlign.right, isBold: true),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildTableHeader(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildTableCell(String text, {pw.TextAlign align = pw.TextAlign.left, bool isBold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
      ),
    );
  }

  pw.Widget _buildProductCell(SaleItemModel item) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            item.productName ?? 'Unknown Product',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          // Any configured attribute (Storage, Flavour…), falling back to the
          // legacy size/color columns for sales recorded before generic
          // attributes existed. `weight` is deliberately excluded — restaurant
          // reuses it as the extras blob rendered separately below.
          if (describeAttributeMap(item.attributes,
                  size: item.size, color: item.color, separator: ' | ')
              .isNotEmpty)
            pw.Text(
              describeAttributeMap(item.attributes,
                  size: item.size, color: item.color, separator: ' | '),
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          // Variant/choice/extras info (stored in weight) — must read as a
          // sub-line, smaller than the product name (9), not larger.
          if (item.weight != null && item.weight!.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(
                item.weight!,
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ),
          if (item.barcode != null)
            pw.Text(
              'SKU: ${item.barcode}',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildInvoiceInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _buildInvoiceTotalRow(String label, double amount, {bool isBold = false, double fontSize = 14, bool isRed = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            _formatCurrency(amount),
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isRed ? PdfColors.red : null,
            ),
          ),
        ],
      ),
    );
  }

  /// Build dashed line for thermal receipt
  pw.Widget _buildDashedLine({bool isSmallMedia = false}) {
    final int count = isSmallMedia ? 28 : 42;
    return pw.Container(
      padding: pw.EdgeInsets.zero,
      margin: pw.EdgeInsets.zero,
      child: pw.Text(
        '-' * count,
        style: pw.TextStyle(fontSize: 5.0, height: 0.8),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  /// Format date for display
  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return isoDate;
    }
  }

  /// Format date and time for display
  String _formatDateTime(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('dd/MM/yyyy hh:mm a').format(date);
    } catch (e) {
      return isoDate;
    }
  }

  /// Format currency with dynamic symbol and decimal precision
  String _formatCurrency(double amount) {
    final absAmount = amount.abs();
    final precision = DecimalSettings.precision;
    final symbol = CurrencyHelper.currentSymbol;

    // Create format pattern based on precision
    final decimalPattern = precision > 0 ? '.${'0' * precision}' : '';
    final formatted = NumberFormat('#,##0$decimalPattern', 'en_IN').format(absAmount);

    if (amount < 0) {
      return '-$symbol$formatted';
    }
    return '$symbol$formatted';
  }

  /// Build split payment section for thermal receipt
  List<pw.Widget> _buildSplitPaymentSection(SaleModel sale, {double fontSize = 11, bool isSmallMedia = false}) {
    final paymentList = sale.paymentList;
    final widgets = <pw.Widget>[];

    // Only show breakdown if there are multiple payment methods or split payment
    if (paymentList.length > 1 || sale.isSplitPayment == true) {
      widgets.add(
        pw.Text(
          'Payment Details',
          style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold),
        ),
      );
      widgets.add(pw.SizedBox(height: 4));

      // Restaurant receipts use larger body text (fontSize 11) than retail (8).
      final double rowFont = AppConfig.isRestaurant ? fontSize : 8;

      for (final payment in paymentList) {
        final method = (payment['method'] as String?)?.toUpperCase() ?? 'OTHER';
        final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
        final ref = payment['ref'] as String?;
        final received = (payment['received'] as num?)?.toDouble();
        final change = (payment['change'] as num?)?.toDouble();

        widgets.add(
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                ref != null ? '$method (Ref: $ref)' : method,
                style: pw.TextStyle(fontSize: rowFont),
              ),
              pw.Text(
                _formatCurrency(amount),
                style: pw.TextStyle(fontSize: rowFont),
              ),
            ],
          ),
        );

        // Show cash received/change only when the customer actually overpaid
        // (received > amount). For an exact split slice this is just noise.
        if (method == 'CASH' && received != null && received > amount) {
          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 8),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Cash Received:', style: pw.TextStyle(fontSize: isSmallMedia ? 6.5 : 7)),
                  pw.Text(_formatCurrency(received), style: pw.TextStyle(fontSize: isSmallMedia ? 6.5 : 7)),
                ],
              ),
            ),
          );
          if (change != null && change > 0) {
            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 8),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Change Given:', style: pw.TextStyle(fontSize: isSmallMedia ? 6.5 : 7, fontWeight: pw.FontWeight.bold)),
                    pw.Text(_formatCurrency(change), style: pw.TextStyle(fontSize: isSmallMedia ? 6.5 : 7, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            );
          }
        }
      }

      // Show total paid and change if any
      if (sale.totalPaid != null && sale.totalPaid! > sale.totalAmount) {
        widgets.add(pw.SizedBox(height: 4));
        widgets.add(
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total Paid:', style: pw.TextStyle(fontSize: isSmallMedia ? 7 : 8, fontWeight: pw.FontWeight.bold)),
              pw.Text(_formatCurrency(sale.totalPaid!), style: pw.TextStyle(fontSize: isSmallMedia ? 7 : 8, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        );
      }

      if (sale.changeReturn != null && sale.changeReturn! > 0) {
        widgets.add(
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Change:', style: pw.TextStyle(fontSize: isSmallMedia ? 7 : 8, fontWeight: pw.FontWeight.bold)),
              pw.Text(_formatCurrency(sale.changeReturn!), style: pw.TextStyle(fontSize: isSmallMedia ? 7 : 8, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        );
      }
    } else if (paymentList.isNotEmpty) {
      // Single payment - only show if there are additional details (cash received, change)
      // For restaurant: payment info is already shown after TOTAL, so skip basic payment line
      final payment = paymentList.first;
      final method = (payment['method'] as String?)?.toUpperCase() ?? 'CASH';
      final received = (payment['received'] as num?)?.toDouble();
      final change = (payment['change'] as num?)?.toDouble();

      // Only show cash received and change if they exist (retail feature)
      // Skip the basic "Paid by X" line for restaurant orders (already shown after TOTAL)
      if (method == 'CASH' && received != null && received > 0) {
        // For retail: show "Paid by CASH:" line before cash details
        if (!AppConfig.isRestaurant) {
          widgets.add(
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Paid by $method:', style: const pw.TextStyle(fontSize: 8)),
                pw.Text(_formatCurrency(sale.totalAmount), style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          );
        }

        widgets.add(
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Cash Received:', style: const pw.TextStyle(fontSize: 8)),
              pw.Text(_formatCurrency(received), style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
        );
        if (change != null && change > 0) {
          widgets.add(
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Change Given:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text(_formatCurrency(change), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          );
        }
      } else if (!AppConfig.isRestaurant) {
        // For retail: show basic payment line if no cash details
        widgets.add(
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Paid by $method:', style: const pw.TextStyle(fontSize: 8)),
              pw.Text(_formatCurrency(sale.totalAmount), style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
        );
      }
      // For restaurant: skip everything if no cash details - payment already shown after TOTAL
    } else {
      // No payment list - payment info is already shown after TOTAL
      // Return empty to avoid duplication
    }

    return widgets;
  }

  /// Build split payment section for A4 invoice
  pw.Widget _buildInvoiceSplitPaymentSection(SaleModel sale) {
    final paymentList = sale.paymentList;

    if (paymentList.length <= 1 && sale.isSplitPayment != true) {
      return pw.SizedBox.shrink();
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.blue200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'PAYMENT BREAKDOWN',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1),
            },
            children: [
              // Header
              pw.TableRow(
                children: [
                  pw.Text('Method', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Reference', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Amount', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                ],
              ),
              // Data rows
              ...paymentList.map((payment) {
                final method = (payment['method'] as String?)?.toUpperCase() ?? 'OTHER';
                final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
                final ref = payment['ref'] as String?;

                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Text(method, style: const pw.TextStyle(fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Text(ref ?? '-', style: const pw.TextStyle(fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Text(_formatCurrency(amount), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right),
                    ),
                  ],
                );
              }),
            ],
          ),
          if (sale.changeReturn != null && sale.changeReturn! > 0) ...[
            pw.Divider(color: PdfColors.blue200),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Paid:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text(_formatCurrency(sale.totalPaid ?? sale.totalAmount), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Change Returned:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.orange)),
                pw.Text(_formatCurrency(sale.changeReturn!), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.orange)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Get color for order type badge
  PdfColor _getOrderTypeColor(String orderType) {
    final type = orderType.toLowerCase();
    if (type.contains('dine in')) {
      return PdfColors.blue800; // Blue for Dine In
    } else if (type.contains('takeaway') || type.contains('take away')) {
      return PdfColors.green800; // Green for Takeaway
    } else if (type.contains('delivery')) {
      return PdfColors.orange800; // Orange for Delivery
    } else {
      return PdfColors.purple800; // Purple for other types
    }
  }
}