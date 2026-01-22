import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';

import '../../../../../data/models/restaurant/db/pastordermodel_313.dart';


// Enum to manage the selected time period safely
enum TimePeriod { Today, ThisWeek, Month, Year, Custom }

// This is the main screen widget that holds the filter buttons and displays the data view
class Totalsales extends StatefulWidget {
  const Totalsales({super.key});

  @override
  State<Totalsales> createState() => _TotalsalesState();
}

class _TotalsalesState extends State<Totalsales> {
  TimePeriod _selectedPeriod = TimePeriod.Today;

  @override
  Widget build(BuildContext context) {
    // --- FIX #1: Add responsive padding based on screen width ---
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 800 ? (screenWidth - 800) / 2 : 16.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          "Total Sales",
          style: GoogleFonts.poppins(
              fontSize: 20, color: Colors.white, fontWeight: FontWeight.w500),
        ),

        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        ),
      ),
      // Use a centered container with a max-width for the main content
      body: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200), // Max content width
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Row of filter buttons at the top
              SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center, // Center buttons
                    children: [
                      _filterButton(TimePeriod.Today, 'Today'),
                      const SizedBox(width: 10),
                      _filterButton(TimePeriod.ThisWeek, 'This Week'),
                      const SizedBox(width: 10),
                      _filterButton(TimePeriod.Month, 'Month Wise'),
                      const SizedBox(width: 10),
                      _filterButton(TimePeriod.Year, 'Year Wise'),
                      const SizedBox(width: 10),
                      _filterButton(TimePeriod.Custom, 'Custom'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: SalesDataView(
                  key: ValueKey(_selectedPeriod), // Force rebuild when period changes
                  period: _selectedPeriod,
                ),
              ),
            ],
          ),
        ),
      ),


    );
  }

  // Helper widget for building the filter buttons
  Widget _filterButton(TimePeriod period, String title) {
    bool isSelected = _selectedPeriod == period;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedPeriod = period;
        });
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        backgroundColor: isSelected ? AppColors.primary : Colors.white,
        foregroundColor: isSelected ? Colors.white : AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side:  BorderSide(color: AppColors.primary),
        ),
      ),
      child: Text(title),
    );
  }
}

// ----------------------------------------------------------------------
// SalesDataView now looks much better on wide screens
// ----------------------------------------------------------------------
class SalesDataView extends StatefulWidget {
  final TimePeriod period;
  const SalesDataView({super.key, required this.period});

  @override
  State<SalesDataView> createState() => _SalesDataViewState();
}

class _SalesDataViewState extends State<SalesDataView> {
  // State variables for the report data
  List<pastOrderModel> _allOrders = [];
  List<pastOrderModel> _filteredOrders = [];
  double _totalSales = 0.0;
  int _totalOrdersCount = 0;
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadDataAndFilter();
  }

  @override
  void didUpdateWidget(covariant SalesDataView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data from Hive when widget updates (e.g., when returning from another screen)
    _loadDataAndFilter();

    if (widget.period != oldWidget.period) {
      _startDate = null;
      _endDate = null;
    }
  }

  Future<void> _loadDataAndFilter() async {
    // Load data from pastOrderStore instead of direct Hive access
    await pastOrderStore.loadPastOrders();
    _allOrders = pastOrderStore.pastOrders.toList();
    _fetchAndFilterData();
  }

  void _fetchAndFilterData() {
    // ... (This function's logic remains the same)
    setState(() {
      _isLoading = true;
    });

    List<pastOrderModel> resultingList = [];
    final now = DateTime.now();

    if (widget.period == TimePeriod.Custom) {
      if (_startDate != null && _endDate != null) {
        resultingList = _allOrders.where((order) {
          final orderDate = order.orderAt;
          if (orderDate == null) return false;
          return orderDate.isAfter(_startDate!.subtract(const Duration(seconds: 1))) &&
              orderDate.isBefore(_endDate!.add(const Duration(days: 1)));
        }).toList();
      }
    }
    else {
      switch (widget.period) {
        case TimePeriod.Today:
          resultingList = _allOrders.where((order) {
            final orderDate = order.orderAt;
            if (orderDate == null) return false;
            return orderDate.year == now.year &&
                orderDate.month == now.month &&
                orderDate.day == now.day;
          }).toList();
          break;
        case TimePeriod.ThisWeek:
        // --- FIX: Normalize the start date to midnight ---
          final dayOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final startOfWeek = DateTime(dayOfWeek.year, dayOfWeek.month, dayOfWeek.day); // This sets the time to 00:00:00

          // The end of the week is 7 full days after the start
          final endOfWeek = startOfWeek.add(const Duration(days: 7));

          resultingList = _allOrders.where((order) {
            final orderDate = order.orderAt;
            if (orderDate == null) return false;

            // Check if the order date is on or after the start and before the end
            return !orderDate.isBefore(startOfWeek) &&
                orderDate.isBefore(endOfWeek);
          }).toList();
          break;
        case TimePeriod.Month:
          resultingList = _allOrders.where((order) {
            final orderDate = order.orderAt;
            if (orderDate == null) return false;
            return orderDate.year == now.year && orderDate.month == now.month;
          }).toList();
          break;
        case TimePeriod.Year:
          resultingList = _allOrders.where((order) {
            final orderDate = order.orderAt;
            if (orderDate == null) return false;
            return orderDate.year == now.year;
          }).toList();
          break;
        case TimePeriod.Custom:
          break;
      }
    }

    setState(() {
      _filteredOrders = resultingList;
      _totalOrdersCount = _filteredOrders.where((order) => order.orderStatus != 'FULLY_REFUNDED').length;
      _totalSales = _filteredOrders.fold(0.0, (sum, order) => sum + (order.totalPrice - (order.refundAmount ?? 0.0)));
      _isLoading = false;
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) {
    // ... (This function's logic remains the same)
    return showDatePicker(
      context: context,
      initialDate: (isStartDate ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    ).then((picked) {
      if (picked != null) {
        setState(() {
          if (isStartDate) {
            _startDate = picked;
          } else {
            _endDate = picked;
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.period == TimePeriod.Custom) {
      return _buildCustomDateSelector();
    }
    return _buildReportUI();
  }

  Widget _buildCustomDateSelector() {
    // ... (This function's logic remains the same)
    String formatDate(DateTime? date) {
      if (date == null) return 'Select Date';
      return DateFormat('dd MMM, yyyy').format(date);
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildDatePickerButton('Start Date', formatDate(_startDate), () => _selectDate(context, true))),
            const SizedBox(width: 16),
            Expanded(child: _buildDatePickerButton('End Date', formatDate(_endDate), () => _selectDate(context, false))),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_startDate != null && _endDate != null) ? _fetchAndFilterData : null,
            child: const Text('Apply Filter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const Divider(height: 32),
        Expanded(child: _buildReportUI()),
      ],
    );
  }

  Widget _buildDatePickerButton(String label, String value, VoidCallback onPressed) {
    // ... (This function's logic remains the same)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        InkWell(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value),
                const Icon(Icons.calendar_today, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportUI() {
    if (_filteredOrders.isEmpty && widget.period != TimePeriod.Custom) {
      return Center(child: Text('No sales data for this period.', style: GoogleFonts.poppins()));
    }
    return Column(
      children: [
        _buildSummaryCards(),
        const SizedBox(height: 24),
        _buildDataTable(),
      ],
    );
  }

  Widget _buildSummaryCards() {
    // --- FIX #2: Constrain the width of the summary cards ---
    return Align(
      alignment: Alignment.center,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600), // Max width for cards
        child: Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'Total Sales',
                value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalSales)}',
                icon: Icons.currency_rupee,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _SummaryCard(
                title: 'Total Orders',
                value: _totalOrdersCount.toString(),
                icon: Icons.receipt_long,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        // --- FIX #3: Let the DataTable fill the available space ---
        child: SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columnSpacing: 20,
                headingRowColor: MaterialStateProperty.all(Colors.teal.shade50),
                columns:  [
                  // --- FIX: Abbreviate headers for small screens ---
                  DataColumn(label: Text(isSmallScreen ? 'Date' : 'Date')),
                  DataColumn(label: Text(isSmallScreen ? 'ID' : 'Invoice ID')),
                  DataColumn(label: Text(isSmallScreen ? 'KOTs' : 'KOT Numbers')),
                  DataColumn(label: Text(isSmallScreen ? 'User' : 'User Name')),
                  DataColumn(label: Text('Total', textAlign: TextAlign.right), numeric: true),
                ],
                rows: _filteredOrders.map((order) {
                  final netAmount = order.totalPrice - (order.refundAmount ?? 0.0);
                  final kotNumbersText = order.kotNumbers.isNotEmpty
                      ? order.kotNumbers.join(', ')
                      : 'N/A';
                  return DataRow(
                    cells: [
                      DataCell(Text(order.orderAt != null
                          ? DateFormat('dd-MM-yy').format(order.orderAt!)
                          : 'N/A')),
                      DataCell(Text('#${order.id.substring(0, 6)}')),
                      DataCell(Text(kotNumbersText)),
                      DataCell(Text(order.customerName)),
                      DataCell(Text('${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(netAmount)}')),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Reusable card widget for the summary section
class _SummaryCard extends StatelessWidget {
  // ... (This widget's code remains the same)
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: Colors.grey.shade600),
                ),
                Icon(icon, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.poppins(
                  fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}