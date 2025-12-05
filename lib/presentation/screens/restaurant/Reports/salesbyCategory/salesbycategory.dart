// In your file: lib/screens/Reports/salesByCategory/SalesByCategory.dart

// In SalesByCategory.dart, make sure your imports look like this at the top

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

// --- YOUR IMPORTS ---

import 'package:unipos/data/models/restaurant/db/cartmodel_308.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';

// --- THE FIX: USE THESE TWO IMPORTS ---
import '../../../../../constants/restaurant/color.dart';
import '../../../../../data/models/restaurant/db/categorymodel_300.dart';
import '../../../../../data/models/restaurant/db/itemmodel_302.dart';
import 'CategoryReportData.dart'; // Imports the data model
import 'CategoryReportView.dart';   // Imports the UI widget
class SalesbyCategory extends StatefulWidget {
  @override
  _SalesbyCategoryState createState() => _SalesbyCategoryState();
}

class _SalesbyCategoryState extends State<SalesbyCategory> {
  // State Variables
  String _selectedFilter = "Today";
  bool _isLoading = true;
  List<CategoryReportData> _categoryReportList = [];
  late Box<pastOrderModel> _ordersBox;

  // State for Custom Date Range
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to prevent jank on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAndLoadData();
    });
  }

  @override
  void didUpdateWidget(covariant SalesbyCategory oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data when returning to this screen
    _updateReportData();
  }

  Future<void> _initAndLoadData() async {
    _ordersBox = await Hive.openBox<pastOrderModel>('pastorderBox');
    _updateReportData();
  }

  void _updateReportData() {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    final allOrders = _ordersBox.values.toList();
    final reportData = _generateCategoryWiseReport(allOrders, _selectedFilter, _startDate, _endDate);

    if (!mounted) return;
    setState(() {
      _categoryReportList = reportData;
      _isLoading = false;
    });
  }

  Future<void> _showCustomDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)

          : null,
    );

    if (picked != null) {
      if (!mounted) return;
      setState(() {

        _startDate = picked.start;
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
        _selectedFilter = "Custom";
      });
      _updateReportData();
    }
  }

  void _onFilterSelected(String title) {
    if (title == "Custom") {
      _showCustomDateRangePicker();

    } else {
      if (!mounted) return;
      setState(() {
        _selectedFilter = title;
        _startDate = null;
        _endDate = null;
      });
      _updateReportData();
    }
  }

  Widget _getBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_categoryReportList.isEmpty) {
      return const Center(child: Text("No sales data for this period."));
    }

    // Always show the SAME display widget, just with the new, updated data.
    return CategoryReportView(reportData: _categoryReportList,);
  }

  String get customDateRangeText {
    if (_startDate != null && _endDate != null) {
      final DateFormat formatter = DateFormat('dd MMM');
      return "${formatter.format(_startDate!)} - ${formatter.format(_endDate!)}";
    }
    return "Custom Date";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Sales By Category", style: GoogleFonts.poppins(fontSize: 20, color: Colors.white)),
        backgroundColor: primarycolor,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text('Sales By Category', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
            // const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterButton("Today"),
                  _filterButton("This Week"),
                  _filterButton("Month"),
                  _filterButton("Year"),
                  _filterButton(customDateRangeText, isCustom: true),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _getBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterButton(String title, {bool isCustom = false}) {
    final filterValue = isCustom ? "Custom" : title;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ElevatedButton(
        onPressed: () => _onFilterSelected(filterValue),
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedFilter == filterValue ? primarycolor : Colors.white,
          foregroundColor: _selectedFilter == filterValue ? Colors.white : primarycolor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side:  BorderSide(color: primarycolor),
          ),
        ),
        child: Text(title, style: GoogleFonts.poppins(fontSize: 14)),
      ),
    );
  }

  // --- DATA PROCESSING LOGIC ---
  List<CategoryReportData> _generateCategoryWiseReport(
      List<pastOrderModel> allOrders,
      String period,
      DateTime? startDate,
      DateTime? endDate,
      ) {
    final filteredOrders = _filterOrders(allOrders, period, startDate, endDate);
    final Map<String, CategoryReportData> categorySummary = {};

    // Build fast lookups once
    final itemBox = Hive.box<Items>('itemBoxs');
    final categoryBox = Hive.box<Category>('categories');

    final Map<String, String> categoryNameById = {
      for (final c in categoryBox.values) c.id: c.name.trim(),
    };

    final Map<String, String> itemIdToCategoryName = {
      for (final it in itemBox.values)
        it.id: (categoryNameById[it.categoryOfItem] ?? 'Uncategorized'),
    };

    String resolveCategoryName(CartItem ci) {
      // 1) Use snapshot on the line item if present
      final snap = ci.categoryName?.trim();
      if (snap != null && snap.isNotEmpty && snap.toLowerCase() != 'uncategorized') {
        return snap;
      }
      // 2) Fallback: derive from the catalog
      final fromCatalog = itemIdToCategoryName[ci.id];
      if (fromCatalog != null && fromCatalog.trim().isNotEmpty) return fromCatalog.trim();
      // 3) Last resort
      return 'Uncategorized';
    }

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

        final cat = resolveCategoryName(cartItem);

        final existing = categorySummary.putIfAbsent(
          cat,
              () => CategoryReportData(categoryName: cat, totalItemsSold: 0, totalRevenue: 0),
        );

        // Add only effective (non-refunded) quantities
        existing.totalItemsSold += effectiveQuantity;

        // Calculate proportional revenue for partially refunded orders
        final orderRefundRatio = order.totalPrice > 0
            ? ((order.totalPrice - (order.refundAmount ?? 0.0)) / order.totalPrice)
            : 1.0;

        final lineTotal = (cartItem.totalPrice != null && cartItem.totalPrice > 0)
            ? cartItem.totalPrice
            : (cartItem.price * cartItem.quantity);

        // Apply proportional revenue reduction for refunds
        final effectiveRevenue = lineTotal * orderRefundRatio;
        existing.totalRevenue += effectiveRevenue;
      }
    }

    // Sort by revenue (desc) or name—your call
    final list = categorySummary.values.toList();
    list.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    return list;
  }

  List<pastOrderModel> _filterOrders(List<pastOrderModel> allOrders, String period, DateTime? startDate, DateTime? endDate) {
    final now = DateTime.now();
    return allOrders.where((order) {
      final orderDate = order.orderAt;
      if (orderDate == null) return false;

      switch (period) {
        case 'Today':
          return orderDate.year == now.year && orderDate.month == now.month && orderDate.day == now.day;
        case 'This Week':
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final endOfWeek = startOfWeek.add(const Duration(days: 7));
          return orderDate.isAfter(startOfWeek) && orderDate.isBefore(endOfWeek);
        case 'Month':
          return orderDate.year == now.year && orderDate.month == now.month;
        case 'Year':
          return orderDate.year == now.year;
        case 'Custom':
          if (startDate != null && endDate != null) {
            return (orderDate.isAfter(startDate) || orderDate.isAtSameMomentAs(startDate)) && orderDate.isBefore(endDate);
          }
          return false;
        default:
          return false;
      }
    }).toList();
  }
}