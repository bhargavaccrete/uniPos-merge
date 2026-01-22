
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbyItem/thisweek.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbyItem/today.dart';

import '../../../../../constants/restaurant/color.dart';
import 'ItemsReportData.dart';
import 'package:unipos/util/color.dart';
class Salesbyitem extends StatefulWidget {
  @override
  _SalesbyitemState createState() => _SalesbyitemState();
}

class _SalesbyitemState extends State<Salesbyitem> {
  // State Variables
  String _selectedFilter = "Today";

  @override
  void initState() {
    super.initState();
    // Load data from pastOrderStore
    _initAndLoadData();
  }

  @override
  void didUpdateWidget(covariant Salesbyitem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data when returning to this screen
    _loadData();
  }

  Future<void> _initAndLoadData() async {
    // Load from pastOrderStore instead of direct Hive access
    await pastOrderStore.loadPastOrders();
  }

  Future<void> _loadData() async {
    // Reload from pastOrderStore
    await pastOrderStore.loadPastOrders();
  }

  List<ItemReportData> _getReportData() {
    // Get data from pastOrderStore
    final allOrders = pastOrderStore.pastOrders.toList();

    // Map the UI filter string to the logic string
    String periodLogicString;
    switch (_selectedFilter) {
      case "This Week":
        periodLogicString = "This Week";
        break;
      case "Month Wise Sales":
        periodLogicString = "This Month";
        break;
      case "Year Wise":
        periodLogicString = "This Year";
        break;
      case "Today":
      default:
        periodLogicString = "Today";
        break;
    }

    // Generate and return the report data
    return generateItemWiseReport(allOrders, periodLogicString);
  }

  // When a filter button is tapped
  void _onFilterSelected(String title) {
    setState(() {
      _selectedFilter = title;
    });
  }

  Widget _getBody(List<ItemReportData> reportData) {
    if (reportData.isEmpty) {
      return const Center(child: Text("No sales data for this period."));
    }

    // Pass the calculated data to the appropriate child widget
    switch (_selectedFilter) {
      case "Today":
        return TodayByItem(reportData: reportData);
      case "This Week":
        return ThisWeekItems(reportData: reportData);
    // case "Day Wise":
    //   return DayWiseItem(reportData: reportData); // This will need a date picker
    // case "Month Wise Sales":
    //   return MonthWiseItem(reportData: reportData);
    // case "Year Wise":
    //   return YearWiseItem(reportData: reportData);
      default:
      // By default, show today's data or a placeholder
        return TodayByItem(reportData: reportData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text("Sales By Items", style: GoogleFonts.poppins(fontSize: 20, color: Colors.white)),
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Observer(
        builder: (_) {
          if (pastOrderStore.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final reportData = _getReportData();

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filter Buttons Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterButton("Today"),
                      // _filterButton("Day Wise"), // Needs separate logic
                      _filterButton("This Week"),
                      _filterButton("Month Wise Sales"),
                      _filterButton("Year Wise"),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Body of the report
                Expanded(
                  child: _getBody(reportData),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _filterButton(String title) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ElevatedButton(
        onPressed: () => _onFilterSelected(title),
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedFilter == title ? AppColors.primary : Colors.white,
          foregroundColor: _selectedFilter == title ? Colors.white : AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side:  BorderSide(color: AppColors.primary),
          ),
          elevation: _selectedFilter == title ? 2 : 0,
        ),
        child: Text(title, style: GoogleFonts.poppins(fontSize: 14)),
      ),
    );
  }
}


// --- DATA PROCESSING LOGIC WITH REFUND SUPPORT ---
// This function properly handles refunded items and quantities

List<ItemReportData> generateItemWiseReport(List<pastOrderModel> allOrders, String period) {
  final filteredOrders = filterOrders(allOrders, period);
  final Map<String, ItemReportData> itemSummary = {};

  for (final order in filteredOrders) {
    // Skip fully refunded orders
    if (order.orderStatus == 'FULLY_REFUNDED') continue;

    for (final cartItem in order.items) {
      // Calculate effective quantity (exclude refunded quantities)
      final originalQuantity = cartItem.quantity;
      final refundedQuantity = cartItem.refundedQuantity ?? 0;
      final effectiveQuantity = originalQuantity - refundedQuantity;

      // Skip items that are fully refunded
      if (effectiveQuantity <= 0) continue;

      // Calculate proportional revenue for partially refunded orders
      final orderRefundRatio = order.totalPrice > 0
          ? ((order.totalPrice - (order.refundAmount ?? 0.0)) / order.totalPrice)
          : 1.0;
      final effectiveRevenue = cartItem.totalPrice * orderRefundRatio;

      if (itemSummary.containsKey(cartItem.title)) {
        final existingItem = itemSummary[cartItem.title]!;
        existingItem.totalQuantity += effectiveQuantity;
        existingItem.totalRevenue += effectiveRevenue;
      } else {
        itemSummary[cartItem.title] = ItemReportData(
          itemName: cartItem.title,
          totalQuantity: effectiveQuantity,
          totalRevenue: effectiveRevenue,
        );
      }
    }
  }

  final reportList = itemSummary.values.toList()
    ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
  return reportList;
}

List<pastOrderModel> filterOrders(List<pastOrderModel> allOrders, String period) {
  final now = DateTime.now();
  switch (period) {
    case 'Today':
      return allOrders.where((order) => order.orderAt != null && isSameDay(order.orderAt!, now)).toList();
    case 'This Week':
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      return allOrders.where((order) {
        if (order.orderAt == null) return false;
        final orderDay = DateTime(order.orderAt!.year, order.orderAt!.month, order.orderAt!.day);
        final startDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        final endDay = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day);
        return (orderDay.isAfter(startDay) || orderDay.isAtSameMomentAs(startDay)) &&
            (orderDay.isBefore(endDay) || orderDay.isAtSameMomentAs(endDay));
      }).toList();
    case 'This Month':
      return allOrders.where((o) => o.orderAt != null && o.orderAt!.year == now.year && o.orderAt!.month == now.month).toList();
    case 'This Year':
      return allOrders.where((o) => o.orderAt != null && o.orderAt!.year == now.year).toList();
    default:
      return allOrders;
  }
}

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;