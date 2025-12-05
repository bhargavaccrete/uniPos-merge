import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:unipos/domain/services/retail/receipt_pdf_service.dart';

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
  }) async {
    final receiptData = ReceiptData(
      sale: sale,
      items: items,
      customer: customer,
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
      storeEmail: storeEmail,
      gstNumber: gstNumber,
    );

    final pdf = format == ReceiptFormat.thermal
        ? await _receiptPdfService.generateThermalReceipt(receiptData)
        : await _receiptPdfService.generateInvoice(receiptData);

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Receipt_${sale.saleId.substring(0, 8)}',
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
  }) async {
    final receiptData = ReceiptData(
      sale: sale,
      items: items,
      customer: customer,
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
      storeEmail: storeEmail,
      gstNumber: gstNumber,
    );

    final pdf = format == ReceiptFormat.thermal
        ? await _receiptPdfService.generateThermalReceipt(receiptData)
        : await _receiptPdfService.generateInvoice(receiptData);

    if (!context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(format == ReceiptFormat.thermal ? 'Receipt Preview' : 'Invoice Preview'),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () async {
                  await sharePdf(
                    sale: sale,
                    items: items,
                    customer: customer,
                    format: format,
                    storeName: storeName,
                    storeAddress: storeAddress,
                    storePhone: storePhone,
                    storeEmail: storeEmail,
                    gstNumber: gstNumber,
                  );
                },
              ),
            ],
          ),
          body: PdfPreview(
            build: (format) async => pdf.save(),
            canChangePageFormat: false,
            canChangeOrientation: false,
            pdfFileName: 'Receipt_${sale.saleId.substring(0, 8)}.pdf',
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
  }) async {
    final receiptData = ReceiptData(
      sale: sale,
      items: items,
      customer: customer,
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
      storeEmail: storeEmail,
      gstNumber: gstNumber,
    );

    final pdf = format == ReceiptFormat.thermal
        ? await _receiptPdfService.generateThermalReceipt(receiptData)
        : await _receiptPdfService.generateInvoice(receiptData);

    final bytes = await pdf.save();

    // Save to temp file
    final tempDir = await getTemporaryDirectory();
    final fileName = 'Receipt_${sale.saleId.substring(0, 8)}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes);

    // Share the file
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Receipt #${sale.saleId.substring(0, 8).toUpperCase()}',
    );
  }

  /// Save PDF to downloads
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
  }) async {
    final receiptData = ReceiptData(
      sale: sale,
      items: items,
      customer: customer,
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
      storeEmail: storeEmail,
      gstNumber: gstNumber,
    );

    final pdf = format == ReceiptFormat.thermal
        ? await _receiptPdfService.generateThermalReceipt(receiptData)
        : await _receiptPdfService.generateInvoice(receiptData);

    final bytes = await pdf.save();

    // Get the documents directory
    final dir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory('${dir.path}/receipts');
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }

    final fileName = 'Receipt_${sale.saleId.substring(0, 8)}_${DateTime.now().millisecondsSinceEpoch}.pdf';
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