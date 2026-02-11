import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/domain/services/common/report_export_service.dart';
import 'package:unipos/util/color.dart';

/// Reusable Export Button Widget
///
/// Easy-to-use button for exporting reports
///
/// Usage:
/// ```dart
/// ExportButtonWidget(
///   onExport: () async {
///     await ReportExportService.showExportDialog(
///       context: context,
///       fileName: 'my_report',
///       reportTitle: 'My Report Title',
///       headers: ['Column 1', 'Column 2'],
///       data: [['Row 1 Data', 'Row 1 Data']],
///     );
///   },
/// )
/// ```
class ExportButtonWidget extends StatelessWidget {
  final VoidCallback onExport;
  final String label;
  final IconData icon;
  final double? width;
  final double? height;

  const ExportButtonWidget({
    Key? key,
    required this.onExport,
    this.label = 'Export Report',
    this.icon = Icons.file_download_outlined,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return ElevatedButton(
      onPressed: onExport,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: Size(
          width ?? screenWidth * 0.6,
          height ?? screenHeight * 0.06,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mixin to add export functionality to report screens
///
/// Usage:
/// ```dart
/// class MyReportScreen extends StatefulWidget with ReportExportMixin {
///   // ... your code
/// }
/// ```
mixin ReportExportMixin {
  /// Helper method to create standard report export
  Future<void> exportStandardReport({
    required BuildContext context,
    required String fileName,
    required String reportTitle,
    required List<String> headers,
    required List<List<dynamic>> data,
    Map<String, dynamic>? summary,
  }) async {
    await ReportExportService.showExportDialog(
      context: context,
      fileName: fileName,
      reportTitle: reportTitle,
      headers: headers,
      data: data,
      summary: summary,
    );
  }

  /// Helper to export order-based reports
  Future<void> exportOrderReport({
    required BuildContext context,
    required String fileName,
    required String reportTitle,
    required List<dynamic> orders,
    List<String>? customHeaders,
    List<dynamic> Function(dynamic order)? customDataExtractor,
  }) async {
    final headers = customHeaders ?? [
      'Order #',
      'Date',
      'Customer',
      'Order Type',
      'Items',
      'Amount',
      'Status',
    ];

    final data = orders.map((order) {
      if (customDataExtractor != null) {
        return customDataExtractor(order);
      }

      // Default order data extraction
      return [
        order.billNumber?.toString() ?? order.id?.substring(0, 8) ?? 'N/A',
        ReportExportService.formatDateTime(order.orderAt),
        order.customerName ?? 'Guest',
        order.orderType ?? 'N/A',
        order.items?.length.toString() ?? '0',
        ReportExportService.formatCurrency(order.totalPrice ?? 0),
        order.orderStatus ?? 'COMPLETED',
      ];
    }).toList();

    final summary = {
      'Total Orders': orders.length.toString(),
      'Total Amount': ReportExportService.formatCurrency(
        orders.fold<double>(0, (sum, order) => sum + (order.totalPrice ?? 0)),
      ),
    };

    await ReportExportService.showExportDialog(
      context: context,
      fileName: fileName,
      reportTitle: reportTitle,
      headers: headers,
      data: data,
      summary: summary,
    );
  }

  /// Helper to export item sales reports
  Future<void> exportItemSalesReport({
    required BuildContext context,
    required String fileName,
    required String reportTitle,
    required Map<String, dynamic> itemSalesData,
  }) async {
    final headers = ['Item Name', 'Category', 'Quantity Sold', 'Total Sales'];

    final data = itemSalesData.entries.map((entry) {
      final itemData = entry.value as Map<String, dynamic>;
      return [
        entry.key,
        itemData['category'] ?? 'N/A',
        itemData['quantity']?.toString() ?? '0',
        ReportExportService.formatCurrency(itemData['amount'] ?? 0),
      ];
    }).toList();

    final totalQuantity = itemSalesData.values.fold<int>(
      0,
      (sum, item) => sum + ((item as Map)['quantity'] as int? ?? 0),
    );
    final totalAmount = itemSalesData.values.fold<double>(
      0,
      (sum, item) => sum + ((item as Map)['amount'] as num? ?? 0).toDouble(),
    );

    final summary = {
      'Total Items': itemSalesData.length.toString(),
      'Total Quantity Sold': totalQuantity.toString(),
      'Total Sales': ReportExportService.formatCurrency(totalAmount),
    };

    await ReportExportService.showExportDialog(
      context: context,
      fileName: fileName,
      reportTitle: reportTitle,
      headers: headers,
      data: data,
      summary: summary,
    );
  }
}