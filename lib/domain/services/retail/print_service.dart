import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_selector/file_selector.dart';
import 'package:billberrylite/domain/services/retail/receipt_pdf_service.dart';
import 'package:billberrylite/domain/services/restaurant/esc_pos_image.dart';
import 'package:billberrylite/domain/services/retail/store_settings_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/config/tax_feature.dart';
import 'package:billberrylite/domain/services/restaurant/esc_pos_receipt_builder.dart';

import '../../../data/models/common/customer_model_125.dart';
import '../../../data/models/retail/hive_model/sale_item_model_204.dart';
import '../../../data/models/retail/hive_model/sale_model_203.dart';
import 'label_pdf_service.dart';

/// Enum for receipt format types
enum ReceiptFormat {
  thermal, // 80mm thermal receipt
  a4Invoice, // Full A4 invoice
}

/// Service for handling all print operations
class PrintService {
  final LabelPdfService _labelPdfService = const LabelPdfService();

  final ReceiptPdfService _receiptPdfService = ReceiptPdfService();
  final StoreSettingsService _storeSettingsService = StoreSettingsService();

  /// Load store logo for all bills (both retail and restaurant)
  Future<Uint8List?> _loadStoreLogo() async {
    try {
      return await _storeSettingsService.getStoreLogo();
    } catch (e) {
      print('Error loading logo: $e');
      return null;
    }
  }

  /// Load the UPI scan-and-pay config (shown on unpaid bills only).
  Future<({String? id, String? payee, Uint8List? qr})> _loadUpiConfig() async {
    try {
      return (
        id: await _storeSettingsService.getUpiId(),
        payee: await _storeSettingsService.getUpiPayeeName(),
        qr: await _storeSettingsService.getUpiQrImage(),
      );
    } catch (e) {
      return (id: null, payee: null, qr: null);
    }
  }

  /// Print a sale receipt/invoice
  Future<void> printReceipt({
    required BuildContext context,
    required SaleModel sale,
    required List<SaleItemModel> items,
    Customer? customer,
    ReceiptFormat format = ReceiptFormat.thermal,
    String? storeName,
    String? storeAddress,
    String? storePhone,
    String? storeEmail,
    String? gstNumber,
    String? orderType,
    String? tableNo,
    int? kotNumber,
    String? kotStatus,
    String? cancelReference,
    List<int>? kotNumbers,
    DateTime? orderTimestamp,
    String? orderNo,
    bool? isAddonKot,
    String? kotRemark, // Restaurant: order-level kitchen note (KOT only)
    double? itemTotal, // Restaurant: Pre-calculated from CartCalculationService
    int? loyaltyPointsDiscount, // Loyalty points redeemed
    int paperWidth = 80, // Target paper width
  }) async {
    // Load logo for all bills
    final logoBytes = await _loadStoreLogo();
    final upi = await _loadUpiConfig();

    final receiptData = ReceiptData(
      sale: sale,
      items: items,
      customer: customer,
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
      storeEmail: storeEmail,
      gstNumber: gstNumber,
      taxEnabled: TaxFeature.enabled,
      orderType: orderType,
      tableNo: tableNo,
      kotNumber: kotNumber,
      kotStatus: kotStatus,
      cancelReference: cancelReference,
      kotNumbers: kotNumbers,
      orderTimestamp: orderTimestamp,
      orderNo: orderNo,
      isAddonKot: isAddonKot,
      kotRemark: kotRemark,
      logoBytes: logoBytes,
      itemTotal: itemTotal,
      loyaltyPointsDiscount: loyaltyPointsDiscount,
      upiId: upi.id,
      upiPayeeName: upi.payee,
      upiQrImageBytes: upi.qr,
    );

    final pdf = format == ReceiptFormat.thermal
        ? await _receiptPdfService.generateThermalReceipt(receiptData, paperWidth: paperWidth)
        : await _receiptPdfService.generateInvoice(receiptData);

    final pageFormat = format == ReceiptFormat.thermal
        ? (paperWidth <= 58
            ? const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 0)
            : const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 0))
        : PdfPageFormat.a4;

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat _) async => pdf.save(),
      name: 'Receipt_${sale.saleId.length > 8 ? sale.saleId.substring(0, 8) : sale.saleId}',
      format: pageFormat,
    );
  }

  /// Show print preview dialog
  /// Rasterize an already-built thermal [ReceiptData] (bill OR KOT) to a complete
  /// ESC/POS ticket, so a DIRECT print looks identical to the PDF. Reused by both
  /// the bill path (below) and the KOT path. Null on any failure → caller falls
  /// back to the plain text ESC/POS builder.
  Future<List<int>?> rasterizeThermalReceipt(
    ReceiptData data, {
    required int paperWidth,
  }) async {
    try {
      final pdf = await _receiptPdfService.generateThermalReceipt(data, paperWidth: paperWidth);
      final pdfBytes = await pdf.save();
      final targetW = paperWidth <= 58 ? 384 : 576;
      await for (final page in Printing.raster(pdfBytes, dpi: 203)) {
        final png = await page.toPng();
        final raster = await EscPosImage.toRaster(png, targetWidth: targetW);
        if (raster == null) return null;
        return <int>[
          0x1B, 0x40, // ESC @  — init
          0x1B, 0x61, 0x01, // ESC a 1 — center
          ...raster,
          0x0A, 0x0A, 0x0A, 0x0A, // feed
          0x1D, 0x56, 0x01, // GS V 1 — partial cut
        ];
      }
      return null;
    } catch (e, s) {
      debugPrint('Error in rasterizeThermalReceipt: $e\n$s');
      return null;
    }
  }

  /// Direct thermal: render the SAME thermal PDF (logo + QR + Poppins font) to a
  /// raster image and return a complete ESC/POS ticket, so a direct print looks
  /// IDENTICAL to the downloaded PDF. Returns null on any failure so the caller
  /// falls back to the plain text-based ESC/POS builder.
  Future<List<int>?> buildThermalRasterTicket({
    required SaleModel sale,
    required List<SaleItemModel> items,
    Customer? customer,
    String? storeName,
    String? storeAddress,
    String? storePhone,
    String? storeEmail,
    String? gstNumber,
    String? orderType,
    String? tableNo,
    List<int>? kotNumbers,
    int? billNumber,
    double? itemTotal,
    String? paymentBreakdown,
    int? loyaltyPointsDiscount,
    double? serviceCharge,
    bool? isDeliveryOrder,
    bool? isTaxInclusive,
    double? roundOff,
    required int paperWidth,
  }) async {
    try {
      final logoBytes = await _loadStoreLogo();
      final upi = await _loadUpiConfig();
      final receiptData = ReceiptData(
        sale: sale,
        items: items,
        customer: customer,
        storeName: storeName,
        storeAddress: storeAddress,
        storePhone: storePhone,
        storeEmail: storeEmail,
        gstNumber: gstNumber,
        taxEnabled: TaxFeature.enabled,
        orderType: orderType,
        tableNo: tableNo,
        kotNumbers: kotNumbers,
        billNumber: billNumber,
        logoBytes: logoBytes,
        itemTotal: itemTotal,
        loyaltyPointsDiscount: loyaltyPointsDiscount,
        serviceCharge: serviceCharge,
        isDeliveryOrder: isDeliveryOrder,
        roundOff: roundOff,
        paymentBreakdown: paymentBreakdown,
        isTaxInclusive: isTaxInclusive,
        upiId: upi.id,
        upiPayeeName: upi.payee,
        upiQrImageBytes: upi.qr,
      );
      final pdf = await _receiptPdfService.generateThermalReceipt(receiptData, paperWidth: paperWidth);
      final pdfBytes = await pdf.save();
      final targetW = paperWidth <= 58 ? 384 : 576;
      await for (final page in Printing.raster(pdfBytes, dpi: 203)) {
        final png = await page.toPng();
        final raster = await EscPosImage.toRaster(png, targetWidth: targetW);
        if (raster == null) return null;
        return <int>[
          0x1B, 0x40, // ESC @  — init
          0x1B, 0x61, 0x01, // ESC a 1 — center
          ...raster,
          0x0A, 0x0A, 0x0A, 0x0A, // feed
          0x1D, 0x56, 0x01, // GS V 1 — partial cut
        ];
      }
      return null;
    } catch (e, s) {
      debugPrint('Error in buildThermalRasterTicket: $e\n$s');
      return null;
    }
  }

  Future<void> showPrintPreview({
    required BuildContext context,
    required SaleModel sale,
    required List<SaleItemModel> items,
    Customer? customer,
    ReceiptFormat format = ReceiptFormat.a4Invoice,
    String? storeName,
    String? storeAddress,
    String? storePhone,
    String? storeEmail,
    String? gstNumber,
    String? orderType,
    String? tableNo,
    int? kotNumber,
    String? kotStatus,
    String? cancelReference,
    List<int>? kotNumbers,
    DateTime? orderTimestamp,
    String? orderNo,
    bool? isAddonKot,
    String? kotRemark, // Restaurant: order-level kitchen note (KOT only)
    int? billNumber,
    double? itemTotal, // Restaurant: Pre-calculated from CartCalculationService
    String? paymentBreakdown, // Split payment breakdown
    int? loyaltyPointsDiscount, // Loyalty points redeemed
    double? serviceCharge, // Service or delivery charge amount
    bool? isDeliveryOrder,
    bool? isTaxInclusive,
    double? roundOff, // Rounding adjustment applied to reach grand total
    int paperWidth = 80, // Target paper width
  }) async {
    // Grab the navigator BEFORE any await.
    //
    // Rendering the PDF (logo raster + UPI QR) takes long enough that the
    // widget which opened this can be gone by the time it finishes — the print
    // options sheet is popped on tap, and re-checking `context.mounted`
    // afterwards then returned silently. That is why a receipt "sometimes"
    // never appeared: a race between the sheet's dismiss animation and the
    // render. A captured NavigatorState survives it.
    final navigator = Navigator.of(context, rootNavigator: true);

    final pw.Document pdf;
    try {
      // Load logo for all bills
      final logoBytes = await _loadStoreLogo();
      final upi = await _loadUpiConfig();

      final receiptData = ReceiptData(
        sale: sale,
        items: items,
        customer: customer,
        storeName: storeName,
        storeAddress: storeAddress,
        storePhone: storePhone,
        storeEmail: storeEmail,
        gstNumber: gstNumber,
        taxEnabled: TaxFeature.enabled,
        orderType: orderType,
        tableNo: tableNo,
        kotNumber: kotNumber,
        kotStatus: kotStatus,
        cancelReference: cancelReference,
        kotNumbers: kotNumbers,
        orderTimestamp: orderTimestamp,
        orderNo: orderNo,
        isAddonKot: isAddonKot,
        kotRemark: kotRemark,
        billNumber: billNumber,
        logoBytes: logoBytes,
        itemTotal: itemTotal,
        loyaltyPointsDiscount: loyaltyPointsDiscount,
        serviceCharge: serviceCharge,
        isDeliveryOrder: isDeliveryOrder,
        roundOff: roundOff,
        paymentBreakdown: paymentBreakdown,
        isTaxInclusive: isTaxInclusive,
        upiId: upi.id,
        upiPayeeName: upi.payee,
        upiQrImageBytes: upi.qr,
      );

      pdf = format == ReceiptFormat.thermal
          ? await _receiptPdfService.generateThermalReceipt(receiptData,
              paperWidth: paperWidth)
          : await _receiptPdfService.generateInvoice(receiptData);
    } catch (e, s) {
      // A throw here used to unwind past the caller with nothing on screen.
      debugPrint('Error building receipt preview: $e\n$s');
      NotificationService.instance.showError('Could not build the receipt');
      return;
    }

    if (!navigator.mounted) return;

    await navigator.push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: const Color(0xFFF7F8FA),
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              format == ReceiptFormat.thermal ? 'Receipt Preview' : 'Invoice Preview',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            centerTitle: true,
          ),
          body: PdfPreview(
            build: (pageFormat) async => pdf.save(),
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            pdfFileName: 'Receipt_${sale.saleId.length > 8 ? sale.saleId.substring(0, 8) : sale.saleId}.pdf',
            initialPageFormat: format == ReceiptFormat.thermal
                ? (paperWidth <= 58
                    ? const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 0)
                    : const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 0))
                : PdfPageFormat.a4,
          ),
        ),
      ),
    );
  }

  /// Share PDF via system share sheet
  Future<void> sharePdf({
    required SaleModel sale,
    required List<SaleItemModel> items,
    Customer? customer,
    ReceiptFormat format = ReceiptFormat.a4Invoice,
    String? storeName,
    String? storeAddress,
    String? storePhone,
    String? storeEmail,
    String? gstNumber,
    String? orderType,
    String? tableNo,
    int? kotNumber,
    DateTime? orderTimestamp,
    int? billNumber,
    double? itemTotal, // Restaurant: Pre-calculated from CartCalculationService
    String? paymentBreakdown, // Split payment breakdown
    int? loyaltyPointsDiscount, // Loyalty points redeemed
    double? serviceCharge,
    bool? isDeliveryOrder,
    bool? isTaxInclusive,
    double? roundOff, // Rounding adjustment baked into the total
  }) async {
    // Load logo for all bills
    final logoBytes = await _loadStoreLogo();
    final upi = await _loadUpiConfig();

    final receiptData = ReceiptData(
      sale: sale,
      items: items,
      customer: customer,
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
      storeEmail: storeEmail,
      gstNumber: gstNumber,
      taxEnabled: TaxFeature.enabled,
      orderType: orderType,
      tableNo: tableNo,
      kotNumber: kotNumber,
      orderTimestamp: orderTimestamp,
      billNumber: billNumber,
      logoBytes: logoBytes,
      itemTotal: itemTotal,
      loyaltyPointsDiscount: loyaltyPointsDiscount,
      serviceCharge: serviceCharge,
      isDeliveryOrder: isDeliveryOrder,
      paymentBreakdown: paymentBreakdown,
      isTaxInclusive: isTaxInclusive,
      upiId: upi.id,
      upiPayeeName: upi.payee,
      upiQrImageBytes: upi.qr,
    );

    final pdf = format == ReceiptFormat.thermal
        ? await _receiptPdfService.generateThermalReceipt(receiptData)
        : await _receiptPdfService.generateInvoice(receiptData);

    final bytes = await pdf.save();

    if (kIsWeb) {
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Receipt_${sale.saleId.length > 8 ? sale.saleId.substring(0, 8) : sale.saleId}.pdf',
      );
      return;
    }

    // Save to temp file
    final tempDir = await getTemporaryDirectory();
    final safeId = sale.saleId.length > 8 ? sale.saleId.substring(0, 8) : sale.saleId;
    final fileName = 'Receipt_${safeId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes);

    // Share the file
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Receipt #${safeId.toUpperCase()}',
    );
  }

  /// Save PDF to downloads or let user select location
  Future<String?> savePdfToDownloads({
    required SaleModel sale,
    required List<SaleItemModel> items,
    Customer? customer,
    ReceiptFormat format = ReceiptFormat.a4Invoice,
    String? storeName,
    String? storeAddress,
    String? storePhone,
    String? storeEmail,
    String? gstNumber,
    int? billNumber,
    double? itemTotal, // Restaurant: Pre-calculated from CartCalculationService
    String? paymentBreakdown, // Split payment breakdown
    int? loyaltyPointsDiscount, // Loyalty points redeemed
    double? serviceCharge,
    bool? isDeliveryOrder,
    bool? isTaxInclusive,
    double? roundOff, // Rounding adjustment baked into the total
  }) async {
    // Load logo for all bills
    final logoBytes = await _loadStoreLogo();
    final upi = await _loadUpiConfig();

    final receiptData = ReceiptData(
      sale: sale,
      items: items,
      customer: customer,
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
      storeEmail: storeEmail,
      gstNumber: gstNumber,
      taxEnabled: TaxFeature.enabled,
      billNumber: billNumber,
      logoBytes: logoBytes,
      itemTotal: itemTotal,
      loyaltyPointsDiscount: loyaltyPointsDiscount,
      serviceCharge: serviceCharge,
      isDeliveryOrder: isDeliveryOrder,
      paymentBreakdown: paymentBreakdown,
      isTaxInclusive: isTaxInclusive,
      upiId: upi.id,
      upiPayeeName: upi.payee,
      upiQrImageBytes: upi.qr,
    );

    final pdf = format == ReceiptFormat.thermal
        ? await _receiptPdfService.generateThermalReceipt(receiptData)
        : await _receiptPdfService.generateInvoice(receiptData);

    final bytes = await pdf.save();
    final safeId = sale.saleId.length > 8 ? sale.saleId.substring(0, 8) : sale.saleId;
    final fileName = 'Receipt_${safeId}_${DateTime.now().millisecondsSinceEpoch}.pdf';

    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
      return null;
    }

    // Try using file_selector for Desktop (Windows, MacOS, Linux)
    // Check kIsWeb first to avoid Platform errors on web
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      try {
        final FileSaveLocation? result = await getSaveLocation(
          suggestedName: fileName,
          acceptedTypeGroups: [
            const XTypeGroup(
              label: 'PDF',
              extensions: ['pdf'],
              mimeTypes: ['application/pdf'],
            ),
          ],
        );

        if (result != null) {
          final file = File(result.path);
          await file.writeAsBytes(bytes);
          return file.path;
        } else {
          // User cancelled
          return null;
        }
      } catch (e) {
        debugPrint('Error using file_selector: $e');
        // Fallback to default logic
      }
    }

    // Default Fallback (Mobile or if file_selector fails)
    Directory? dir;
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        dir = await getApplicationDocumentsDirectory();
      } else {
        // Use downloads directory for desktop fallback
        dir = await getDownloadsDirectory();
      }
    } catch (e) {
      // Ignore
    }
    
    // Final fallback
    dir ??= await getApplicationDocumentsDirectory();
    
    final receiptsDir = Directory('${dir.path}/receipts');
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }

    final file = File('${receiptsDir.path}/$fileName');
    await file.writeAsBytes(bytes);

    return file.path;
  }

  // ==================== LABELS ====================

  /// Send an A4 sticker sheet of barcode/price labels to the OS print dialog.
  ///
  /// Reuses the same `Printing.layoutPdf` path as an A4 invoice, so labels need
  /// no printer role, no new transport and no second printer architecture.
  ///
  /// Read-only with respect to the catalogue: [labels] are already-resolved
  /// values, so printing can never mint or change a barcode.
  Future<void> printLabels(List<LabelSpec> labels) async {
    if (labels.isEmpty) return;
    final pdf = await _labelPdfService.build(labels);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat _) async => pdf.save(),
      name: 'Labels_${labels.length}',
      format: PdfPageFormat.a4,
    );
  }

  /// On-screen preview of the label sheet, so a misaligned pitch is caught
  /// before a sheet of stickers is spent. Mirrors [showPrintPreview].
  Future<void> showLabelPreview({
    required BuildContext context,
    required List<LabelSpec> labels,
  }) async {
    if (labels.isEmpty) return;
    final pdf = await _labelPdfService.build(labels);

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
            title: Text(
              'Label Preview',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
            centerTitle: true,
          ),
          body: PdfPreview(
            build: (pageFormat) async => pdf.save(),
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            pdfFileName: 'Labels_${labels.length}.pdf',
            initialPageFormat: PdfPageFormat.a4,
          ),
        ),
      ),
    );
  }

  /// Show print options dialog
  Future<void> showPrintOptionsDialog({
    required BuildContext context,
    required SaleModel sale,
    required List<SaleItemModel> items,
    Customer? customer,
    String? storeName,
    String? storeAddress,
    String? storePhone,
    String? storeEmail,
    String? gstNumber,
    String? orderType, // Take Away, Dine In, Delivery
    int? billNumber, // Bill number for completed orders
    List<int>? kotNumbers, // KOT numbers for restaurant orders
    double? itemTotal, // Restaurant: Pre-calculated from CartCalculationService
    String? paymentBreakdown, // Split payment breakdown (e.g., "cash: ₹100, card: ₹200")
    int? loyaltyPointsDiscount, // Loyalty points redeemed
    double? serviceCharge, // Service or delivery charge amount
    bool? isDeliveryOrder, // True if delivery order
    bool? isTaxInclusive, // Tax inclusive mode
    double? roundOff, // Rounding adjustment baked into the total
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'Print Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // Direct Thermal Printer — only shown when a receipt printer is saved.
            // This is the fastest path: one tap → ESC/POS bytes → printer.
            // No PDF rendering, no system dialog.
            if (printerStore.hasDefaultReceiptPrinter)
              _buildOptionTile(
                icon: Icons.print,
                title: 'Print to ${printerStore.defaultReceiptPrinter!.name}',
                subtitle: 'Direct thermal print (${printerStore.defaultReceiptPrinter!.type.toUpperCase()})',
                onTap: () async {
                  Navigator.pop(sheetContext);
                  // Build the ReceiptData needed by the ESC/POS builder
                  final receiptData = ReceiptData(
                    sale: sale,
                    items: items,
                    customer: customer,
                    storeName: storeName,
                    storeAddress: storeAddress,
                    storePhone: storePhone,
                    storeEmail: storeEmail,
                    gstNumber: gstNumber,
                    taxEnabled: TaxFeature.enabled,
                    orderType: orderType,
                    billNumber: billNumber,
                    kotNumbers: kotNumbers,
                    itemTotal: itemTotal,
                    loyaltyPointsDiscount: loyaltyPointsDiscount,
                    serviceCharge: serviceCharge,
                    isDeliveryOrder: isDeliveryOrder,
                    paymentBreakdown: paymentBreakdown,
                    isTaxInclusive: isTaxInclusive,
                    roundOff: roundOff,
                  );
                  final printer = printerStore.defaultReceiptPrinter!;
                  // Raster the thermal PDF first: the PDF renderer is the only
                  // path that reads RETAIL's own toggles (via _getRetailSettings)
                  // — EscPosReceiptBuilder reads restaurant's PrintSettings map,
                  // so a text ticket would ignore every retail setting. Text
                  // stays as the fallback when rasterizing fails.
                  final bytes = await rasterizeThermalReceipt(
                        receiptData,
                        paperWidth: printer.paperSize,
                      ) ??
                      EscPosReceiptBuilder.buildReceiptTicket(
                        receiptData: receiptData,
                        paperWidth: printer.paperSize,
                      );
                  final success = await printerStore.sendBytes(bytes, printer);
                  // NotificationService, not ScaffoldMessenger — the sheet that
                  // owned the context is already gone by the time the printer
                  // answers, which silently swallowed the result.
                  if (success) {
                    NotificationService.instance
                        .showSuccess('Receipt sent to ${printer.name}');
                  } else {
                    NotificationService.instance.showError(
                        'Print failed: ${printerStore.errorMessage ?? "Unknown error"}');
                  }
                },
              ),

            // Print A4 Invoice
            _buildOptionTile(
              icon: Icons.description_outlined,
              title: 'Print Invoice (A4)',
              subtitle: 'Full-size invoice for accounting',
              onTap: () {
                Navigator.pop(sheetContext);
                showPrintPreview(
                  context: context,
                  sale: sale,
                  items: items,
                  customer: customer,
                  format: ReceiptFormat.a4Invoice,
                  storeName: storeName,
                  storeAddress: storeAddress,
                  storePhone: storePhone,
                  storeEmail: storeEmail,
                  gstNumber: gstNumber,
                  orderType: orderType,
                  billNumber: billNumber,
                  kotNumbers: kotNumbers,
                  itemTotal: itemTotal,
                  paymentBreakdown: paymentBreakdown,
                  loyaltyPointsDiscount: loyaltyPointsDiscount,
                  serviceCharge: serviceCharge,
                  isDeliveryOrder: isDeliveryOrder,
                  isTaxInclusive: isTaxInclusive,
                  roundOff: roundOff,
                );
              },
            ),

            // Print Thermal Receipt
            _buildOptionTile(
              icon: Icons.receipt_long_outlined,
              title: 'Print Receipt (Thermal)',
              subtitle: 'For 80mm thermal printers',
              onTap: () {
                Navigator.pop(sheetContext);
                showPrintPreview(
                  context: context,
                  sale: sale,
                  items: items,
                  customer: customer,
                  format: ReceiptFormat.thermal,
                  storeName: storeName,
                  storeAddress: storeAddress,
                  storePhone: storePhone,
                  storeEmail: storeEmail,
                  gstNumber: gstNumber,
                  orderType: orderType,
                  billNumber: billNumber,
                  kotNumbers: kotNumbers,
                  itemTotal: itemTotal,
                  paymentBreakdown: paymentBreakdown,
                  loyaltyPointsDiscount: loyaltyPointsDiscount,
                  serviceCharge: serviceCharge,
                  isDeliveryOrder: isDeliveryOrder,
                  isTaxInclusive: isTaxInclusive,
                  roundOff: roundOff,
                );
              },
            ),

            // Share PDF
            _buildOptionTile(
              icon: Icons.share_outlined,
              title: 'Share Invoice',
              subtitle: 'Send via WhatsApp, Email, etc.',
              onTap: () async {
                Navigator.pop(sheetContext);
                await sharePdf(
                  sale: sale,
                  items: items,
                  customer: customer,
                  format: ReceiptFormat.a4Invoice,
                  storeName: storeName,
                  storeAddress: storeAddress,
                  storePhone: storePhone,
                  storeEmail: storeEmail,
                  gstNumber: gstNumber,
                  billNumber: billNumber,
                  itemTotal: itemTotal, // Pass item total
                  paymentBreakdown: paymentBreakdown, // Pass split payment breakdown
                  loyaltyPointsDiscount: loyaltyPointsDiscount,
                  serviceCharge: serviceCharge,
                  isDeliveryOrder: isDeliveryOrder,
                  isTaxInclusive: isTaxInclusive,
                  roundOff: roundOff,
                );
              },
            ),

            // Save to Device
            _buildOptionTile(
              icon: Icons.save_alt_outlined,
              title: 'Save to Device',
              subtitle: 'Save PDF to documents folder',
              onTap: () async {
                Navigator.pop(sheetContext);
                final path = await savePdfToDownloads(
                  sale: sale,
                  items: items,
                  customer: customer,
                  format: ReceiptFormat.a4Invoice,
                  storeName: storeName,
                  storeAddress: storeAddress,
                  storePhone: storePhone,
                  storeEmail: storeEmail,
                  gstNumber: gstNumber,
                  billNumber: billNumber,
                  itemTotal: itemTotal, // Pass item total
                  paymentBreakdown: paymentBreakdown, // Pass split payment breakdown
                  loyaltyPointsDiscount: loyaltyPointsDiscount,
                  serviceCharge: serviceCharge,
                  isDeliveryOrder: isDeliveryOrder,
                  isTaxInclusive: isTaxInclusive,
                  roundOff: roundOff,
                );
                if (path != null) {
                  NotificationService.instance.showSuccess('Saved to: $path');
                }
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF4CAF50),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}