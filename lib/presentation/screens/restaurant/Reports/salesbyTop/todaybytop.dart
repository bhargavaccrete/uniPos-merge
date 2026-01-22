import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import '../../../../../constants/restaurant/color.dart';
import 'package:unipos/util/color.dart';
import 'package:intl/intl.dart';


class TodaybyTop extends StatefulWidget {
  const TodaybyTop({super.key});

  @override
  State<TodaybyTop> createState() => _TodaybyTopState();
}

class _TodaybyTopState extends State<TodaybyTop> {
  @override
  void initState() {
    super.initState();
    _loadTopSellingItems();
  }

  Future<void> _loadTopSellingItems() async {
    // Load from pastOrderStore instead of direct Hive access
    await pastOrderStore.loadPastOrders();
  }

  List<Map<String, dynamic>> _calculateTopSellingItems() {
    // Get all past orders from store
    final allOrders = pastOrderStore.pastOrders.toList();
    final today = DateTime.now();

    // Filter orders for today only
    final todayOrders = allOrders.where((order) {
      if (order.orderAt == null) return false;
      final orderDate = order.orderAt!;
      return orderDate.year == today.year &&
          orderDate.month == today.month &&
          orderDate.day == today.day;
    }).toList();

    // Calculate item sales with refund handling
    Map<String, Map<String, dynamic>> itemSales = {};

      for (var order in todayOrders) {
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
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      body: Observer(
        builder: (_) {
          if (pastOrderStore.isLoading) {
            return Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final topSellingItems = _calculateTopSellingItems();

          return SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CommonButton(
                  width: width * 0.6,
                  height: height * 0.06,
                  bordercircular: 5,
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.note_add_outlined,
                        color: Colors.white,
                      ),
                      Text(
                        'Export TO Excel',
                        textScaler: TextScaler.linear(1),
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w500),
                      )
                    ],
                  )),
              SizedBox(height: 25),
              if (topSellingItems.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Icon(Icons.shopping_bag_outlined,
                            size: 60, color: Colors.grey),
                        SizedBox(height: 10),
                        Text(
                          'No sales data for today',
                          style: GoogleFonts.poppins(
                              fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                      headingRowHeight: 50,
                      columnSpacing: 2,
                      headingRowColor:
                      WidgetStateProperty.all(Colors.grey[300]),
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
                                    style:
                                    GoogleFonts.poppins(fontSize: 14),
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
                                    style:
                                    GoogleFonts.poppins(fontSize: 14),
                                    textAlign: TextAlign.center))),
                      ],
                      rows: topSellingItems.map((item) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Center(
                                  child: Text(today,
                                      style: GoogleFonts.poppins(
                                          fontSize: 12))),
                            ),
                            DataCell(
                              Center(
                                  child: Text(item['itemName'],
                                      style: GoogleFonts.poppins(
                                          fontSize: 12))),
                            ),
                            DataCell(
                              Center(
                                  child: Text('${item['quantity']}',
                                      style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600))),
                            ),
                            DataCell(
                              Center(
                                  child: Text(
                                      '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(item['totalAmount'])}',
                                      style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600))),
                            ),
                          ],
                        );
                      }).toList()),
                )
            ],
          ),
        ));
        },
      ),
    );
  }
}