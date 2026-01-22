import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
class DayWisebyTop extends StatefulWidget {
  const DayWisebyTop({super.key});

  @override
  State<DayWisebyTop> createState() => _DayWisebyTopState();
}

class _DayWisebyTopState extends State<DayWisebyTop> {
  DateTime? _fromDate;

  // Function to show the Date Picker
  Future<void> _pickDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));

    if (pickedDate != null) {
      setState(() {
        _fromDate = pickedDate;
      });
    }
  }

  Future<void> _loadTopSellingItems() async {
    if (_fromDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a date first'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Load from pastOrderStore instead of direct Hive access
    await pastOrderStore.loadPastOrders();
    setState(() {});
  }

  List<Map<String, dynamic>> _calculateTopSellingItems() {
    if (_fromDate == null) return [];

    // Get all past orders from store
    final allOrders = pastOrderStore.pastOrders.toList();

    // Filter orders for selected date only
    final selectedDateOrders = allOrders.where((order) {
      if (order.orderAt == null) return false;
      final orderDate = order.orderAt!;
      return orderDate.year == _fromDate!.year &&
          orderDate.month == _fromDate!.month &&
          orderDate.day == _fromDate!.day;
    }).toList();

    // Calculate item sales with refund handling
    Map<String, Map<String, dynamic>> itemSales = {};

    for (var order in selectedDateOrders) {
      // Skip fully refunded orders
      if (order.orderStatus == 'FULLY_REFUNDED') continue;

      // Calculate order-level refund ratio
      final orderTotal = order.totalPrice ?? 0.0;
      final refundAmount = order.refundAmount ?? 0.0;
      final orderRefundRatio = orderTotal > 0 ? ((orderTotal - refundAmount) / orderTotal) : 1.0;

      for (var item in order.items) {
        final itemName = item.title;

        // Calculate effective quantity (after refunds)
        final originalQuantity = item.quantity ?? 0;
        final refundedQuantity = item.refundedQuantity ?? 0;
        final effectiveQuantity = originalQuantity - refundedQuantity;

        // Skip fully refunded items
        if (effectiveQuantity <= 0) continue;

        final price = item.price;
        final baseTotal = price * effectiveQuantity;

        // Apply order-level refund ratio for accurate revenue
        final totalAmount = baseTotal * orderRefundRatio;

        if (itemSales.containsKey(itemName)) {
          itemSales[itemName]!['quantity'] += effectiveQuantity;
          itemSales[itemName]!['totalAmount'] += totalAmount;
        } else {
          itemSales[itemName] = {
            'itemName': itemName,
            'quantity': effectiveQuantity,
            'totalAmount': totalAmount,
          };
        }
      }
    }

    // Convert to list and sort by quantity (most sold first)
    final sortedItems = itemSales.values.toList()
      ..sort((a, b) => (b['quantity'] as int).compareTo(a['quantity'] as int));

    return sortedItems;
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    final displayDate = _fromDate != null ? DateFormat('yyyy-MM-dd').format(_fromDate!) : '';

    return Scaffold(
      body: Observer(
        builder: (_) {
          final topSellingItems = _calculateTopSellingItems();

          return SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Date:',
                textScaler: TextScaler.linear(1),
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500),
              ),

              // date picker
              Row(
                children: [
                  InkWell(
                    onTap: () {
                      _pickDate(context);
                    },
                    child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        width: width * 0.6,
                        height: height * 0.05,
                        decoration: BoxDecoration(
                            border: Border.all(color: AppColors.primary),
                            borderRadius: BorderRadius.circular(5)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _fromDate == null
                                  ? ' DD/MM/YYYY'
                                  : '${_fromDate!.day}/${_fromDate!.month}/${_fromDate!.year}',
                              textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                            Icon(Icons.date_range, color: AppColors.primary)
                          ],
                        )),
                  ),
                  SizedBox(width: 10),
                  InkWell(
                    onTap: _loadTopSellingItems,
                    child: Container(
                      padding: EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          color: AppColors.primary, borderRadius: BorderRadius.circular(50)),
                      child: Icon(Icons.search, size: 25, color: Colors.white),
                    ),
                  )
                ],
              ),

              SizedBox(height: 20),
              // Export TO Excel
              CommonButton(
                  width: width * 0.6,
                  height: height * 0.06,
                  bordercircular: 5,
                  onTap: () {},
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note_add_outlined, color: Colors.white),
                      Text(
                        'Export TO Excel',
                        textScaler: TextScaler.linear(1),
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
                      )
                    ],
                  )),

              SizedBox(height: 25),

              // Loading or Results
              if (pastOrderStore.isLoading)
                Center(child: CircularProgressIndicator(color: AppColors.primary))
              else if (topSellingItems.isEmpty && _fromDate != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 60, color: Colors.grey),
                        SizedBox(height: 10),
                        Text(
                          'No sales data for selected date',
                          style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else if (topSellingItems.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                        headingRowHeight: 50,
                        columnSpacing: 2,
                        headingRowColor: WidgetStateProperty.all(Colors.grey[300]),
                        border: TableBorder.all(color: Colors.white),
                        columns: [
                          DataColumn(
                              columnWidth: FixedColumnWidth(width * 0.2),
                              label: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(50),
                                      bottomLeft: Radius.circular(50),
                                    ),
                                  ),
                                  child: Text(
                                    'Date',
                                    textScaler: TextScaler.linear(1),
                                    style: GoogleFonts.poppins(fontSize: 14),
                                  ))),
                          DataColumn(
                              headingRowAlignment: MainAxisAlignment.center,
                              columnWidth: FixedColumnWidth(width * 0.3),
                              label: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(10),
                                      bottomLeft: Radius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    "Item Name",
                                    textScaler: TextScaler.linear(1),
                                    style: GoogleFonts.poppins(fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ))),
                          DataColumn(
                              headingRowAlignment: MainAxisAlignment.center,
                              columnWidth: FixedColumnWidth(width * 0.2),
                              label: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(10),
                                      bottomLeft: Radius.circular(10),
                                    ),
                                  ),
                                  child: Text('Quantity',
                                      textScaler: TextScaler.linear(1),
                                      style: GoogleFonts.poppins(fontSize: 14),
                                      textAlign: TextAlign.center))),
                          DataColumn(
                              headingRowAlignment: MainAxisAlignment.center,
                              columnWidth: FixedColumnWidth(width * 0.25),
                              label: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(10),
                                      bottomLeft: Radius.circular(10),
                                    ),
                                  ),
                                  child: Text('Total (${CurrencyHelper.currentSymbol})',
                                      textScaler: TextScaler.linear(1),
                                      style: GoogleFonts.poppins(fontSize: 14),
                                      textAlign: TextAlign.center))),
                        ],
                        rows: topSellingItems.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Center(
                                    child: Text(displayDate, style: GoogleFonts.poppins(fontSize: 12))),
                              ),
                              DataCell(
                                Center(
                                    child: Text(item['itemName'],
                                        style: GoogleFonts.poppins(fontSize: 12))),
                              ),
                              DataCell(
                                Center(
                                    child: Text('${item['quantity']}',
                                        style: GoogleFonts.poppins(
                                            fontSize: 12, fontWeight: FontWeight.w600))),
                              ),
                              DataCell(
                                Center(
                                    child: Text('${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(item['totalAmount'])}',
                                        style: GoogleFonts.poppins(
                                            fontSize: 12, fontWeight: FontWeight.w600))),
                              ),
                            ],
                          );
                        }).toList()),
                  )
            ],
          ),
        ),
        );
        },
      ),
    );
  }
}