import 'dart:math';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';


import '../../../data/models/retail/hive_model/customer_model_208.dart';
import '../../../data/models/retail/hive_model/sale_item_model_204.dart';
import '../../../data/models/retail/hive_model/sale_model_203.dart';

/// Data class to hold all receipt information
class ReceiptData {
  final SaleModel sale;
  final List<SaleItemModel> items;
  final CustomerModel? customer;
  final String? storeName;
  final String? storeAddress;
  final String? storePhone;
  final String? storeEmail;
  final String? gstNumber;

  // Restaurant-specific fields
  final String? orderType; // e.g., "Dine In", "Takeaway", "Delivery"
  final String? tableNo; // Table number for dine-in orders
  final int? kotNumber; // KOT number for kitchen orders (single KOT prints)
  final List<int>? kotNumbers; // All KOT numbers for this order (customer bill)
  final DateTime? orderTimestamp; // Order timestamp for KOT
  final String? orderNo; // Order number/ID for KOT
  final bool? isAddonKot; // True if this is an additional KOT for existing order
  final int? billNumber; // Daily bill number for completed orders (resets every day)

  // Store logo
  final Uint8List? logoBytes; // Store logo image

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
    this.kotNumbers,
    this.orderTimestamp,
    this.orderNo,
    this.isAddonKot,
    this.billNumber,
    this.logoBytes,
  });
}

/// Service for generating PDF receipts and invoices
class ReceiptPdfService {
  /// Default store info - can be customized via settings
  static const String defaultStoreName = 'UniPos Store';
  static const String defaultStoreAddress = 'Your Store Address';
  static const String defaultStorePhone = '+91 1234567890';

  /// Generate a thermal receipt style PDF (narrow, suitable for 80mm printers)
  Future<pw.Document> generateThermalReceipt(ReceiptData data) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(8),
        build: (context) => _buildThermalReceiptContent(data),
      ),
    );

    return pdf;
  }

  /// Generate a full A4 invoice PDF
  Future<pw.Document> generateInvoice(ReceiptData data) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => _buildInvoiceContent(data),
      ),
    );

    return pdf;
  }

  /// Build thermal receipt content (80mm width)
  pw.Widget _buildThermalReceiptContent(ReceiptData data) {
    final storeName = data.storeName ?? defaultStoreName;
    final storeAddress = data.storeAddress ?? defaultStoreAddress;
    final storePhone = data.storePhone ?? defaultStorePhone;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Store Logo (Both retail and restaurant)
        if (data.logoBytes != null) ...[
          pw.Container(
            width: 60,
            height: 60,
            child: pw.Image(
              pw.MemoryImage(data.logoBytes!),
              fit: pw.BoxFit.contain,
            ),
          ),
          pw.SizedBox(height: 8),
        ],

        // Store Header
        pw.Text(
          storeName,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          storeAddress,
          style: const pw.TextStyle(fontSize: 8),
          textAlign: pw.TextAlign.center,
        ),
        pw.Text(
          'Tel: $storePhone',
          style: const pw.TextStyle(fontSize: 8),
        ),
        if (data.gstNumber != null) ...[
          pw.Text(
            'GST: ${data.gstNumber}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
        pw.SizedBox(height: 8),
        _buildDashedLine(),
        pw.SizedBox(height: 4),

        // Receipt Info / KOT Info
        if (data.kotNumber != null) ...[
          // KOT Format (simplified for kitchen)
          pw.Text(
            'KOT #: ${data.kotNumber.toString().padLeft(3, '0')}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          if (data.tableNo != null && data.tableNo!.isNotEmpty) ...[
            pw.Text(
              'Table: ${data.tableNo}',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ],
          if (data.orderNo != null && data.orderNo!.isNotEmpty) ...[
            pw.Text(
              'Order No: ${data.orderNo}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
          if (data.orderType != null) ...[
            pw.Text(
              'Type: ${data.orderType!.toUpperCase()}${data.isAddonKot == true ? ' (ADD-ON)' : ''}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
          if (data.orderTimestamp != null) ...[
            pw.Text(
              _formatDateTime(data.orderTimestamp!.toIso8601String()),
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ] else ...[
          // Regular Receipt Info - Show Bill Number for completed orders
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(data.billNumber != null ? 'Bill No:' : 'Receipt #:', style: const pw.TextStyle(fontSize: 8)),
              pw.Text(
                data.billNumber != null
                  ? data.billNumber.toString().padLeft(3, '0')
                  : data.sale.saleId.substring(0, min(8, data.sale.saleId.length)).toUpperCase(),
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Date:', style: const pw.TextStyle(fontSize: 8)),
              pw.Text(
                _formatDateTime(data.sale.date),
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Payment:', style: const pw.TextStyle(fontSize: 8)),
              pw.Text(
                data.sale.paymentType.toUpperCase(),
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          if (data.customer != null) ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Customer:', style: const pw.TextStyle(fontSize: 8)),
                pw.Text(
                  data.customer!.name,
                  style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ],
          // Display all KOT numbers for this order
          if (data.kotNumbers != null && data.kotNumbers!.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('KOT #:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  data.kotNumbers!.map((num) => '#$num').join(', '),
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ],
        ],

        pw.SizedBox(height: 4),
        _buildDashedLine(),
        pw.SizedBox(height: 4),

        // Items List - Different format for KOT vs Regular Receipt
        if (data.kotNumber != null) ...[
          // KOT Format: Just item name and quantity (no prices)
          ...data.items.map((item) => _buildKOTItemRow(item)),
          pw.SizedBox(height: 4),
          _buildDashedLine(),
          // No footer for KOT - just end here
        ] else ...[
          // Regular Receipt Format: With headers and prices
          // Items Header
          pw.Row(
            children: [
              pw.Expanded(
                flex: 4,
                child: pw.Text('Item', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Expanded(
                flex: 1,
                child: pw.Text('Qty', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Text('Amount', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
              ),
            ],
          ),
          pw.SizedBox(height: 4),

          // Items List
          ...data.items.map((item) => _buildThermalItemRow(item)),

          pw.SizedBox(height: 4),
          _buildDashedLine(),
          pw.SizedBox(height: 4),

          // Totals
          _buildThermalTotalRow('Subtotal', data.sale.subtotal),
          if (data.sale.discountAmount > 0)
            _buildThermalTotalRow('Discount', -data.sale.discountAmount),
          if (data.sale.taxAmount > 0)
            _buildThermalTotalRow('Tax', data.sale.taxAmount),
          pw.SizedBox(height: 4),
          _buildDashedLine(),
          pw.SizedBox(height: 4),
          _buildThermalTotalRow('TOTAL', data.sale.totalAmount, isBold: true, fontSize: 12),

          // Credit sale info
          if (data.sale.paymentType == 'credit' || data.sale.dueAmount > 0) ...[
            pw.SizedBox(height: 4),
            _buildDashedLine(),
            pw.SizedBox(height: 4),
            _buildThermalTotalRow('Paid', data.sale.paidAmount),
            _buildThermalTotalRow('DUE', data.sale.dueAmount, isBold: true, fontSize: 11),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.5),
              ),
              child: pw.Text(
                '** CREDIT SALE - PAYMENT PENDING **',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],

          pw.SizedBox(height: 8),
          _buildDashedLine(),
          pw.SizedBox(height: 4),

          // Split Payment Breakdown
          ..._buildSplitPaymentSection(data.sale),

          pw.SizedBox(height: 4),
          _buildDashedLine(),
          pw.SizedBox(height: 8),

          // Footer
          pw.Text(
            'Thank you for your purchase!',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Please come again',
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 8),

          // Points earned (if customer)
          if (data.customer != null) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.5),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'Points Earned: ${(data.sale.totalAmount / 10).floor()}',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Total Points: ${data.customer!.pointsBalance}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
          ],

          pw.Text(
            _formatDateTime(DateTime.now().toIso8601String()),
            style: const pw.TextStyle(fontSize: 7),
          ),
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
                  // Logo (Both retail and restaurant)
                  if (data.logoBytes != null) ...[
                    pw.Container(
                      width: 80,
                      height: 80,
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
                        pw.Text(
                          storeName,
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green800,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(storeAddress, style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Phone: $storePhone', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Email: $storeEmail', style: const pw.TextStyle(fontSize: 10)),
                        if (data.gstNumber != null)
                          pw.Text('GST No: ${data.gstNumber}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
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
                pw.SizedBox(height: 8),
                pw.Text(
                  '# ${data.sale.saleId.substring(0, min(13, data.sale.saleId.length)).toUpperCase()}',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
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
                        data.customer!.name,
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(data.customer!.phone, style: const pw.TextStyle(fontSize: 10)),
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
                    _buildInvoiceInfoRow('Status:', 'PAID'),
                    _buildInvoiceInfoRow('Total Items:', '${data.sale.totalItems}'),
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

        // Totals Section
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Container(
              width: 250,
              child: pw.Column(
                children: [
                  _buildInvoiceTotalRow('Subtotal', data.sale.subtotal),
                  if (data.sale.discountAmount > 0)
                    _buildInvoiceTotalRow('Discount', -data.sale.discountAmount, isRed: true),
                  if (data.sale.taxAmount > 0)
                    _buildInvoiceTotalRow('Tax', data.sale.taxAmount),
                  pw.Divider(thickness: 1),
                  _buildInvoiceTotalRow('Grand Total', data.sale.totalAmount, isBold: true, fontSize: 14),
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
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 24),

        // Split Payment Section (for multiple payment methods)
        _buildInvoiceSplitPaymentSection(data.sale),

        pw.SizedBox(height: 16),

        // Customer Points Section
        if (data.customer != null) ...[
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
                  '${(data.sale.totalAmount / 10).floor()} points',
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
                'Thank you for your business!',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'This is a computer-generated invoice.',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build item row for KOT (Kitchen Order Ticket) - Simple format without prices
  pw.Widget _buildKOTItemRow(SaleItemModel item) {
    final name = item.productName ?? 'Unknown';
    // Format item name with variant in parentheses: "Veg Pizza (Medium)"
    final displayName = item.size != null ? '$name (${item.size})' : name;

    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 3, bottom: 3),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Item name (with variant) and quantity in a row
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  displayName,
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Text(
                'x${item.qty}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          // Display extras and add-ons (stored in weight field)
          if (item.weight != null && item.weight!.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 4, top: 1),
              child: pw.Text(
                '  ${item.weight!}',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ),
        ],
      ),
    );
  }

  /// Build item row for thermal receipt
  pw.Widget _buildThermalItemRow(SaleItemModel item) {
    final name = item.productName ?? 'Unknown';
    final displayName = name.length > 20 ? '${name.substring(0, 18)}...' : name;

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                flex: 4,
                child: pw.Text(displayName, style: const pw.TextStyle(fontSize: 8)),
              ),
              pw.Expanded(
                flex: 1,
                child: pw.Text('${item.qty}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Text(
                  _formatCurrency(item.total),
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
          // Display size/variant
          if (item.size != null || item.color != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 8),
              child: pw.Text(
                [
                  if (item.size != null) 'Size: ${item.size}',
                  if (item.color != null) 'Color: ${item.color}',
                ].join(' | '),
                style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
              ),
            ),
          // Display extras and add-ons (stored in weight field)
          if (item.weight != null && item.weight!.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 8, top: 2),
              child: pw.Text(
                item.weight!,
                style: pw.TextStyle(fontSize: 6, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  /// Build total row for thermal receipt
  pw.Widget _buildThermalTotalRow(String label, double amount, {bool isBold = false, double fontSize = 9}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
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
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(1),
        4: const pw.FlexColumnWidth(2),
        5: const pw.FlexColumnWidth(2),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.green800),
          children: [
            _buildTableHeader('#'),
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
              _buildProductCell(item),
              _buildTableCell(_formatCurrency(item.price), align: pw.TextAlign.right),
              _buildTableCell('${item.qty}', align: pw.TextAlign.center),
              _buildTableCell(
                item.discountAmount != null && item.discountAmount! > 0
                    ? _formatCurrency(item.discountAmount!)
                    : '-',
                align: pw.TextAlign.right,
              ),
              _buildTableCell(_formatCurrency(item.total), align: pw.TextAlign.right, isBold: true),
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
          if (item.size != null || item.color != null)
            pw.Text(
              [
                if (item.size != null) 'Size: ${item.size}',
                if (item.color != null) 'Color: ${item.color}',
              ].join(' | '),
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          // Display extras and add-ons
          if (item.weight != null && item.weight!.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(
                item.weight!,
                style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
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

  pw.Widget _buildInvoiceTotalRow(String label, double amount, {bool isBold = false, double fontSize = 10, bool isRed = false}) {
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
  pw.Widget _buildDashedLine() {
    return pw.Container(
      child: pw.Text(
        '-' * 40,
        style: const pw.TextStyle(fontSize: 8),
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

  /// Format currency
  /// Note: Using "Rs." instead of "₹" because default PDF fonts don't support the Rupee symbol
  String _formatCurrency(double amount) {
    final absAmount = amount.abs();
    final formatted = NumberFormat('#,##0.00', 'en_IN').format(absAmount);
    if (amount < 0) {
      return '-Rs.$formatted';
    }
    return 'Rs.$formatted';
  }

  /// Build split payment section for thermal receipt
  List<pw.Widget> _buildSplitPaymentSection(SaleModel sale) {
    final paymentList = sale.paymentList;
    final widgets = <pw.Widget>[];

    // Only show breakdown if there are multiple payment methods or split payment
    if (paymentList.length > 1 || sale.isSplitPayment == true) {
      widgets.add(
        pw.Text(
          'PAYMENT BREAKDOWN',
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        ),
      );
      widgets.add(pw.SizedBox(height: 4));

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
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.Text(
                _formatCurrency(amount),
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
        );

        // Show cash received and change for cash payments
        if (method == 'CASH' && received != null && received > 0) {
          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 8),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Cash Received:', style: const pw.TextStyle(fontSize: 7)),
                  pw.Text(_formatCurrency(received), style: const pw.TextStyle(fontSize: 7)),
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
                    pw.Text('Change Given:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                    pw.Text(_formatCurrency(change), style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
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
              pw.Text('Total Paid:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Text(_formatCurrency(sale.totalPaid!), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        );
      }

      if (sale.changeReturn != null && sale.changeReturn! > 0) {
        widgets.add(
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Change:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Text(_formatCurrency(sale.changeReturn!), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        );
      }
    } else if (paymentList.isNotEmpty) {
      // Single payment - show paid amount with cash details if applicable
      final payment = paymentList.first;
      final method = (payment['method'] as String?)?.toUpperCase() ?? 'CASH';
      final received = (payment['received'] as num?)?.toDouble();
      final change = (payment['change'] as num?)?.toDouble();

      widgets.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Paid by $method:', style: const pw.TextStyle(fontSize: 8)),
            pw.Text(_formatCurrency(sale.totalAmount), style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
      );

      // Show cash received and change for single cash payment
      if (method == 'CASH' && received != null && received > 0) {
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
      }
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