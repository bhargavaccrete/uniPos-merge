import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:unipos/core/di/service_locator.dart';

import 'package:unipos/data/models/retail/hive_model/sale_model_203.dart';

import '../../../domain/services/retail/return_service.dart';
import 'sale_detail_screen.dart';


class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  List<SaleModel> _sales = [];
  List<SaleModel> _filteredSales = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, today, dateRange, cash, card, upi
  final ReturnService _returnService = ReturnService();
  final Map<String, bool> _returnedSalesCache = {};

  // Search and date range
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSales() async {
    setState(() {
      _isLoading = true;
      _returnedSalesCache.clear(); // Clear cache when refreshing
    });

    try {
      final sales = await saleStore.getAllSales();
      // Sort by date descending (most recent first)
      sales.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _sales = sales;
        _filteredSales = sales;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sales: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      _applyAllFilters();
    });
  }

  void _applyAllFilters() {
    List<SaleModel> result = _sales;

    // Apply date filter
    switch (_selectedFilter) {
      case 'today':
        final today = DateTime.now();
        result = result.where((sale) {
          final saleDate = DateTime.parse(sale.date);
          return saleDate.year == today.year &&
              saleDate.month == today.month &&
              saleDate.day == today.day;
        }).toList();
        break;
      case 'dateRange':
        if (_startDate != null && _endDate != null) {
          result = result.where((sale) {
            final saleDate = DateTime.parse(sale.date);
            final saleDateOnly = DateTime(saleDate.year, saleDate.month, saleDate.day);
            final startDateOnly = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
            final endDateOnly = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
            return !saleDateOnly.isBefore(startDateOnly) && !saleDateOnly.isAfter(endDateOnly);
          }).toList();
        }
        break;
      case 'cash':
      case 'card':
      case 'upi':
        result = result.where((sale) => sale.paymentType.toLowerCase() == _selectedFilter).toList();
        break;
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((sale) {
        final saleIdMatch = sale.saleId.toLowerCase().contains(query);
        final amountMatch = sale.totalAmount.toStringAsFixed(2).contains(query);
        return saleIdMatch || amountMatch;
      }).toList();
    }

    _filteredSales = result;
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _applyAllFilters();
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 7)),
              end: DateTime.now(),
            ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4CAF50),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1A1A1A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedFilter = 'dateRange';
        _applyAllFilters();
      });
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedFilter = 'all';
      _applyAllFilters();
    });
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final saleDate = DateTime(date.year, date.month, date.day);

      if (saleDate == today) {
        return 'Today, ${DateFormat('hh:mm a').format(date)}';
      } else if (saleDate == yesterday) {
        return 'Yesterday, ${DateFormat('hh:mm a').format(date)}';
      } else {
        return DateFormat('dd MMM yyyy, hh:mm a').format(date);
      }
    } catch (e) {
      return isoDate;
    }
  }

  Color _getPaymentColor(String paymentType) {
    switch (paymentType.toLowerCase()) {
      case 'cash':
        return const Color(0xFF4CAF50);
      case 'card':
        return const Color(0xFF2196F3);
      case 'upi':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF6B6B6B);
    }
  }

  IconData _getPaymentIcon(String paymentType) {
    switch (paymentType.toLowerCase()) {
      case 'cash':
        return Icons.money;
      case 'card':
        return Icons.credit_card;
      case 'upi':
        return Icons.qr_code_2;
      default:
        return Icons.payment;
    }
  }

  Future<bool> _checkIfReturned(String saleId) async {
    // Check cache first
    if (_returnedSalesCache.containsKey(saleId)) {
      return _returnedSalesCache[saleId]!;
    }

    // Check if sale has been returned
    final isReturned = await _returnService.isFullyReturned(saleId);

    // Cache the result
    _returnedSalesCache[saleId] = isReturned;

    return isReturned;
  }

  @override
  Widget build(BuildContext context) {
    final totalRevenue = _filteredSales.fold<double>(
      0.0,
      (sum, sale) => sum + sale.totalAmount,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text(
          'Sales History',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSales,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search Bar
                _buildSearchBar(),

                // Summary Card
                _buildSummaryCard(totalRevenue),

                // Filter Chips
                _buildFilterChips(),

                // Date Range Display
                if (_selectedFilter == 'dateRange' && _startDate != null && _endDate != null)
                  _buildDateRangeDisplay(),

                // Sales List
                Expanded(
                  child: _filteredSales.isEmpty
                      ? _buildEmptyState()
                      : _buildSalesList(),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search by Sale ID or amount...',
          hintStyle: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF6B6B6B), size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFF6B6B6B), size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDateRangeDisplay() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4CAF50), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range, size: 18, color: Color(0xFF4CAF50)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${DateFormat('dd MMM yyyy').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4CAF50),
              ),
            ),
          ),
          InkWell(
            onTap: _clearDateRange,
            child: const Icon(Icons.close, size: 18, color: Color(0xFF4CAF50)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double totalRevenue) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Sales',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_filteredSales.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 50,
            width: 1,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Revenue',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${totalRevenue.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('All Sales', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip("Today", 'today'),
          const SizedBox(width: 8),
          _buildDateRangeChip(),
          const SizedBox(width: 8),
          _buildFilterChip('Cash', 'cash'),
          const SizedBox(width: 8),
          _buildFilterChip('Card', 'card'),
          const SizedBox(width: 8),
          _buildFilterChip('UPI', 'upi'),
        ],
      ),
    );
  }

  Widget _buildDateRangeChip() {
    final isSelected = _selectedFilter == 'dateRange';

    return ActionChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.date_range,
            size: 16,
            color: isSelected ? const Color(0xFF4CAF50) : const Color(0xFF6B6B6B),
          ),
          const SizedBox(width: 4),
          Text('Date Range'),
        ],
      ),
      onPressed: _selectDateRange,
      backgroundColor: isSelected ? const Color(0xFF4CAF50).withOpacity(0.2) : Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF4CAF50) : const Color(0xFF6B6B6B),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFF4CAF50) : const Color(0xFFE8E8E8),
        width: isSelected ? 1.5 : 0.5,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) => _applyFilter(value),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF4CAF50).withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF4CAF50) : const Color(0xFF6B6B6B),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected
            ? const Color(0xFF4CAF50)
            : const Color(0xFFE8E8E8),
        width: isSelected ? 1.5 : 0.5,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Color(0xFFD0D0D0),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 'all'
                ? 'No sales yet'
                : 'No sales found for this filter',
            style: const TextStyle(fontSize: 16, color: Color(0xFF6B6B6B)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sales will appear here after checkout',
            style: TextStyle(fontSize: 13, color: Color(0xFFB0B0B0)),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredSales.length,
      itemBuilder: (context, index) {
        final sale = _filteredSales[index];
        return _buildSaleCard(sale);
      },
    );
  }

  Widget _buildSaleCard(SaleModel sale) {
    // Skip return transactions themselves from the list
    if (sale.isReturn ?? false) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<bool>(
      future: _checkIfReturned(sale.saleId),
      builder: (context, snapshot) {
        final isReturned = snapshot.data ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isReturned ? Colors.red.withOpacity(0.3) : const Color(0xFFE8E8E8),
              width: isReturned ? 1.5 : 0.5,
            ),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SaleDetailScreen(saleId: sale.saleId),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Payment Method Badge
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getPaymentColor(sale.paymentType).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getPaymentIcon(sale.paymentType),
                          size: 20,
                          color: _getPaymentColor(sale.paymentType),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Sale #${sale.saleId.substring(0, 8).toUpperCase()}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ),
                                if (isReturned) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.red,
                                        width: 1,
                                      ),
                                    ),
                                    child: const Text(
                                      'RETURNED',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.red,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(sale.date),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B6B6B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${sale.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getPaymentColor(sale.paymentType)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              sale.paymentType.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _getPaymentColor(sale.paymentType),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, thickness: 0.5, color: Color(0xFFE8E8E8)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.shopping_bag_outlined,
                            size: 16,
                            color: Color(0xFF6B6B6B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${sale.totalItems} items',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B6B6B),
                            ),
                          ),
                        ],
                      ),
                      if (sale.discountAmount > 0)
                        Row(
                          children: [
                            const Icon(
                              Icons.local_offer_outlined,
                              size: 16,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '₹${sale.discountAmount.toStringAsFixed(0)} off',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      Row(
                        children: [
                          Text(
                            'View Details',
                            style: TextStyle(
                              fontSize: 13,
                              color: _getPaymentColor(sale.paymentType),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: _getPaymentColor(sale.paymentType),
                          ),
                        ],
                      ),
                    ],
                  ),

                ],
              ),
            ),
          ),
        );
      },
    );
  }
}