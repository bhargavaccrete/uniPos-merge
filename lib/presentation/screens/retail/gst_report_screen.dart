import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:unipos/data/models/retail/hive_model/sale_model_203.dart';


class GstReportScreen extends StatefulWidget {
  const GstReportScreen({super.key});

  @override
  State<GstReportScreen> createState() => _GstReportScreenState();
}

class _GstReportScreenState extends State<GstReportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  bool _isLoading = true;

  // Report data
  List<SaleModel> _sales = [];
  List<SaleItemModel> _saleItems = [];
  Map<double, _GstRateSummary> _gstByRate = {};
  Map<String, _ProductGstSummary> _gstByProduct = {};
  Map<String, _CategoryGstSummary> _gstByCategory = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadReportData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    try {
      // Get all sales in date range
      final allSales = saleStore.sales.toList();
      _sales = allSales.where((sale) {
        final saleDate = DateTime.parse(sale.date);
        return saleDate.isAfter(_dateRange.start.subtract(const Duration(days: 1))) &&
            saleDate.isBefore(_dateRange.end.add(const Duration(days: 1)));
      }).toList();

      // Get all sale items for these sales
      _saleItems = [];
      for (var sale in _sales) {
        final items = await saleItemRepository.getItemsBySaleId(sale.saleId);
        _saleItems.addAll(items);
      }

      // Calculate GST summaries
      _calculateGstByRate();
      _calculateGstByProduct();
      _calculateGstByCategory();
    } catch (e) {
      debugPrint('Error loading GST report: $e');
    }
    setState(() => _isLoading = false);
  }

  void _calculateGstByRate() {
    _gstByRate = {};
    for (var item in _saleItems) {
      final rate = item.gstRate ?? 0;
      if (!_gstByRate.containsKey(rate)) {
        _gstByRate[rate] = _GstRateSummary(rate: rate);
      }
      _gstByRate[rate]!.addItem(item);
    }
  }

  void _calculateGstByProduct() {
    _gstByProduct = {};
    for (var item in _saleItems) {
      final productId = item.productId;
      if (!_gstByProduct.containsKey(productId)) {
        _gstByProduct[productId] = _ProductGstSummary(
          productId: productId,
          productName: item.productName ?? 'Unknown',
        );
      }
      _gstByProduct[productId]!.addItem(item);
    }
  }

  void _calculateGstByCategory() {
    _gstByCategory = {};
    // Group by GST rate as a proxy for category
    for (var item in _saleItems) {
      final rate = item.gstRate ?? 0;
      final categoryKey = '${rate.toInt()}%';
      if (!_gstByCategory.containsKey(categoryKey)) {
        _gstByCategory[categoryKey] = _CategoryGstSummary(
          categoryName: 'GST $categoryKey Items',
          gstRate: rate,
        );
      }
      _gstByCategory[categoryKey]!.addItem(item);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4CAF50),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
      _loadReportData();
    }
  }

  double get _totalTaxableAmount {
    double total = 0;
    for (var item in _saleItems) {
      total += item.taxableAmount ?? 0;
    }
    return total;
  }

  double get _totalGstAmount {
    double total = 0;
    for (var item in _saleItems) {
      total += item.gstAmount ?? 0;
    }
    return total;
  }

  double get _totalCgstAmount {
    double total = 0;
    for (var item in _saleItems) {
      total += item.cgstAmount ?? 0;
    }
    return total;
  }

  double get _totalSgstAmount {
    double total = 0;
    for (var item in _saleItems) {
      total += item.sgstAmount ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('GST Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4CAF50),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF4CAF50),
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'By Rate'),
            Tab(text: 'By Product'),
            Tab(text: 'By Category'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Date Range Selector
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectDateRange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE8E8E8)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18, color: Color(0xFF4CAF50)),
                          const SizedBox(width: 12),
                          Text(
                            '${dateFormat.format(_dateRange.start)} - ${dateFormat.format(_dateRange.end)}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down, color: Color(0xFF6B6B6B)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Tab Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSummaryTab(),
                      _buildByRateTab(),
                      _buildByProductTab(),
                      _buildByCategoryTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildSummaryRow('Total Sales', '${_sales.length}'),
                const SizedBox(height: 12),
                _buildSummaryRow('Total Items Sold', '${_saleItems.length}'),
                const Divider(height: 24),
                _buildSummaryRow('Total Taxable Amount', 'Rs. ${_totalTaxableAmount.toStringAsFixed(2)}'),
                const SizedBox(height: 12),
                _buildSummaryRow('Total CGST', 'Rs. ${_totalCgstAmount.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                _buildSummaryRow('Total SGST', 'Rs. ${_totalSgstAmount.toStringAsFixed(2)}'),
                const Divider(height: 24),
                _buildSummaryRow(
                  'Total GST Collected',
                  'Rs. ${_totalGstAmount.toStringAsFixed(2)}',
                  isBold: true,
                  fontSize: 18,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // GST Rate Distribution
          const Text(
            'GST Distribution by Rate',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE8E8E8)),
            ),
            child: Column(
              children: _gstByRate.entries.map((entry) {
                final summary = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${entry.key.toInt()}%',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rs. ${summary.totalGst.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '${summary.itemCount} items',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildByRateTab() {
    final sortedRates = _gstByRate.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedRates.length,
      itemBuilder: (context, index) {
        final entry = sortedRates[index];
        final summary = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE8E8E8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'GST ${entry.key.toInt()}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${summary.itemCount} items',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildDetailRow('Taxable Amount', 'Rs. ${summary.taxableAmount.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              _buildDetailRow('CGST (${(entry.key / 2).toStringAsFixed(1)}%)', 'Rs. ${summary.cgst.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              _buildDetailRow('SGST (${(entry.key / 2).toStringAsFixed(1)}%)', 'Rs. ${summary.sgst.toStringAsFixed(2)}'),
              const Divider(height: 16),
              _buildDetailRow('Total GST', 'Rs. ${summary.totalGst.toStringAsFixed(2)}', isBold: true),
            ],
          ),
        );
      },
    );
  }

  Widget _buildByProductTab() {
    final sortedProducts = _gstByProduct.values.toList()
      ..sort((a, b) => b.totalGst.compareTo(a.totalGst));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedProducts.length,
      itemBuilder: (context, index) {
        final summary = sortedProducts[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE8E8E8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      summary.productName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    'Qty: ${summary.quantity}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Taxable: Rs. ${summary.taxableAmount.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'GST Rate: ${summary.avgGstRate.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'GST: Rs. ${summary.totalGst.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildByCategoryTab() {
    final sortedCategories = _gstByCategory.values.toList()
      ..sort((a, b) => b.totalGst.compareTo(a.totalGst));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedCategories.length,
      itemBuilder: (context, index) {
        final summary = sortedCategories[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE8E8E8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      summary.categoryName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${summary.gstRate.toInt()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              _buildDetailRow('Items Sold', '${summary.itemCount}'),
              const SizedBox(height: 8),
              _buildDetailRow('Taxable Amount', 'Rs. ${summary.taxableAmount.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              _buildDetailRow('CGST', 'Rs. ${summary.cgst.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              _buildDetailRow('SGST', 'Rs. ${summary.sgst.toStringAsFixed(2)}'),
              const Divider(height: 16),
              _buildDetailRow('Total GST', 'Rs. ${summary.totalGst.toStringAsFixed(2)}', isBold: true),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, double? fontSize}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize ?? 14,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize ?? 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: const Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isBold ? const Color(0xFF1A1A1A) : Colors.grey[600],
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
            color: isBold ? const Color(0xFF4CAF50) : const Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }
}

// Helper classes for summaries
class _GstRateSummary {
  final double rate;
  int itemCount = 0;
  double taxableAmount = 0;
  double cgst = 0;
  double sgst = 0;
  double totalGst = 0;

  _GstRateSummary({required this.rate});

  void addItem(SaleItemModel item) {
    itemCount++;
    taxableAmount += item.taxableAmount ?? 0;
    cgst += item.cgstAmount ?? 0;
    sgst += item.sgstAmount ?? 0;
    totalGst += item.gstAmount ?? 0;
  }
}

class _ProductGstSummary {
  final String productId;
  final String productName;
  int quantity = 0;
  double taxableAmount = 0;
  double totalGst = 0;
  double _totalRate = 0;
  int _rateCount = 0;

  _ProductGstSummary({required this.productId, required this.productName});

  double get avgGstRate => _rateCount > 0 ? _totalRate / _rateCount : 0;

  void addItem(SaleItemModel item) {
    quantity += item.qty;
    taxableAmount += item.taxableAmount ?? 0;
    totalGst += item.gstAmount ?? 0;
    if (item.gstRate != null) {
      _totalRate += item.gstRate!;
      _rateCount++;
    }
  }
}

class _CategoryGstSummary {
  final String categoryName;
  final double gstRate;
  int itemCount = 0;
  double taxableAmount = 0;
  double cgst = 0;
  double sgst = 0;
  double totalGst = 0;

  _CategoryGstSummary({required this.categoryName, required this.gstRate});

  void addItem(SaleItemModel item) {
    itemCount++;
    taxableAmount += item.taxableAmount ?? 0;
    cgst += item.cgstAmount ?? 0;
    sgst += item.sgstAmount ?? 0;
    totalGst += item.gstAmount ?? 0;
  }
}