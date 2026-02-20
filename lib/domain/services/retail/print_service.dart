import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_selector/file_selector.dart';
import 'package:unipos/domain/services/retail/receipt_pdf_service.dart';
import 'package:unipos/domain/services/retail/store_settings_service.dart';
import 'package:unipos/domain/services/retail/retail_printer_settings_service.dart';
import 'package:unipos/core/config/app_config.dart';
import 'package:unipos/util/color.dart';

import '../../../data/models/retail/hive_model/customer_model_208.dart';
import '../../../data/models/retail/hive_model/sale_item_model_204.dart';
import '../../../data/models/retail/hive_model/sale_model_203.dart';

/// Enum for receipt format types
enum ReceiptFormat {
  thermal, // 80mm thermal receipt
  a4Invoice, // Full A4 invoice
}

/// Service for handling all print operations
class PrintService {
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

  /// Print a sale receipt/invoice
  Future<void> printReceipt({
    required BuildContext context,
    required SaleModel sale,
    required List<SaleItemModel> items,
    CustomerModel? customer,
    ReceiptFormat format = ReceiptFormat.thermal,
    String? storeName,
    String? storeAddress,
    String? storePhone,
    String? storeEmail,
    String? gstNumber,
    String? orderType,
    String? tableNo,
    int? kotNumber,
    List<int>? kotNumbers,
    DateTime? orderTimestamp,
    String? orderNo,
    bool? isAddonKot,
    double? itemTotal, // Restaurant: Pre-calculated from CartCalculationService
  }) async {
    // Load logo for all bills
    final logoBytes = await _loadStoreLogo();

    final receiptData = ReceiptData(
      sale: sale,
      items: items,
      customer: customer,
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
      storeEmail: storeEmail,
      gstNumber: gstNumber,
      orderType: orderType,
      tableNo: tableNo,
      kotNumber: kotNumber,
      kotNumbers: kotNumbers,
      orderTimestamp: orderTimestamp,
      orderNo: orderNo,
      isAddonKot: isAddonKot,
      logoBytes: logoBytes,
      itemTotal: itemTotal,
    );

    final pdf = format == ReceiptFormat.thermal
        ? await _receiptPdfService.generateThermalReceipt(receiptData)
        : await _receiptPdfService.generateInvoice(receiptData);

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat pageFormat) async => pdf.save(),
      name: 'Receipt_${sale.saleId.length > 8 ? sale.saleId.substring(0, 8) : sale.saleId}',
      format: format == ReceiptFormat.thermal ? PdfPageFormat.roll80 : PdfPageFormat.a4,
    );
  }

  /// Show print preview dialog
  Future<void> showPrintPreview({
    required BuildContext context,
    required SaleModel sale,
    required List<SaleItemModel> items,
    CustomerModel? customer,
    ReceiptFormat format = ReceiptFormat.a4Invoice,
    String? storeName,
    String? storeAddress,
    String? storePhone,
    String? storeEmail,
    String? gstNumber,
    String? orderType,
    String? tableNo,
    int? kotNumber,
    List<int>? kotNumbers,
    DateTime? orderTimestamp,
    String? orderNo,
    bool? isAddonKot,
    int? billNumber,
    double? itemTotal, // Restaurant: Pre-calculated from CartCalculationService
    String? paymentBreakdown, // Split payment breakdown
  }) async {
    // Load logo for all bills
    final logoBytes = await _loadStoreLogo();

    final receiptData = ReceiptData(
      sale: sale,
      items: items,
      customer: customer,
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
      storeEmail: storeEmail,
      gstNumber: gstNumber,
      orderType: orderType,
      tableNo: tableNo,
      kotNumber: kotNumber,
      kotNumbers: kotNumbers,
      orderTimestamp: orderTimestamp,
      orderNo: orderNo,
      isAddonKot: isAddonKot,
      billNumber: billNumber,
      logoBytes: logoBytes,
      itemTotal: itemTotal,
    );

    final pdf = format == ReceiptFormat.thermal
        ? await _receiptPdfService.generateThermalReceipt(receiptData)
        : await _receiptPdfService.generateInvoice(receiptData);

    if (!context.mounted) return;

    await Navigator.push(
      context,
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
            initialPageFormat: format == ReceiptFormat.thermal ? PdfPageFormat.roll80 : PdfPageFormat.a4,
          ),
        ),
      ),
    );
  }

  /// Share PDF via system share sheet
  Future<void> sharePdf({
    required SaleModel sale,
    required List<SaleItemModel> items,
    CustomerModel? customer,
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
  }) async {
    // Load logo for all bills
    final logoBytes = await _loadStoreLogo();

    final receiptData = ReceiptData(
      sale: sale,
      items: items,
      customer: customer,
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
      storeEmail: storeEmail,
      gstNumber: gstNumber,
      orderType: orderType,
      tableNo: tableNo,
      kotNumber: kotNumber,
      orderTimestamp: orderTimestamp,
      billNumber: billNumber,
      logoBytes: logoBytes,
      itemTotal: itemTotal,
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
    CustomerModel? customer,
    ReceiptFormat format = ReceiptFormat.a4Invoice,
    String? storeName,
    String? storeAddress,
    String? storePhone,
    String? storeEmail,
    String? gstNumber,
    int? billNumber,
    double? itemTotal, // Restaurant: Pre-calculated from CartCalculationService
    String? paymentBreakdown, // Split payment breakdown
  }) async {
    // Load logo for all bills
    final logoBytes = await _loadStoreLogo();

    final receiptData = ReceiptData(
      sale: sale,
      items: items,
      customer: customer,
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
      storeEmail: storeEmail,
      gstNumber: gstNumber,
      billNumber: billNumber,
      logoBytes: logoBytes,
      itemTotal: itemTotal,
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

  /// Show print options dialog
  Future<void> showPrintOptionsDialog({
    required BuildContext context,
    required SaleModel sale,
    required List<SaleItemModel> items,
    CustomerModel? customer,
    String? storeName,
    String? storeAddress,
    String? storePhone,
    String? storeEmail,
    String? gstNumber,
    int? billNumber, // Bill number for completed orders
    List<int>? kotNumbers, // KOT numbers for restaurant orders
    double? itemTotal, // Restaurant: Pre-calculated from CartCalculationService
    String? paymentBreakdown, // Split payment breakdown (e.g., "cash: ₹100, card: ₹200")
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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

            // Print A4 Invoice
            _buildOptionTile(
              icon: Icons.description_outlined,
              title: 'Print Invoice (A4)',
              subtitle: 'Full-size invoice for accounting',
              onTap: () {
                Navigator.pop(context);
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
                  billNumber: billNumber,
                  kotNumbers: kotNumbers,
                  itemTotal: itemTotal, // Pass item total
                  paymentBreakdown: paymentBreakdown, // Pass split payment breakdown
                );
              },
            ),

            // Print Thermal Receipt
            _buildOptionTile(
              icon: Icons.receipt_long_outlined,
              title: 'Print Receipt (Thermal)',
              subtitle: 'For 80mm thermal printers',
              onTap: () {
                Navigator.pop(context);
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
                  billNumber: billNumber,
                  kotNumbers: kotNumbers,
                  itemTotal: itemTotal, // Pass item total
                  paymentBreakdown: paymentBreakdown, // Pass split payment breakdown
                );
              },
            ),

            // Share PDF
            _buildOptionTile(
              icon: Icons.share_outlined,
              title: 'Share Invoice',
              subtitle: 'Send via WhatsApp, Email, etc.',
              onTap: () async {
                Navigator.pop(context);
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
                );
              },
            ),

            // Save to Device
            _buildOptionTile(
              icon: Icons.save_alt_outlined,
              title: 'Save to Device',
              subtitle: 'Save PDF to documents folder',
              onTap: () async {
                Navigator.pop(context);
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
                );
                if (context.mounted && path != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Saved to: $path'),
                      backgroundColor: const Color(0xFF4CAF50),
                    ),
                  );
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