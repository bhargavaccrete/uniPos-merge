import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../../domain/services/retail/report_service.dart';

class ProfitReportScreen extends StatefulWidget {
  const ProfitReportScreen({super.key});
  @override
  State<ProfitReportScreen> createState() => _ProfitReportScreenState();
}

class _ProfitReportScreenState extends State<ProfitReportScreen> with SingleTickerProviderStateMixin {
  final ReportService _reportService = ReportService();
  Map<String, dynamic>? _overallReport;
  List<Map<String, dynamic>> _profitPerDay = [];
  List<Map<String, dynamic>> _profitPerItem = [];
  List<Map<String, dynamic>> _profitPerSale = [];
  bool _isLoading = false;
  late TabController _tabController;

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllReports() async {
    setState(() => _isLoading = true);

    final overallData = await _reportService.getProfitReport(
      startDate: _startDate,
      endDate: _endDate,
    );
    final perDayData = await _reportService.getProfitPerDayReport(
      startDate: _startDate,
      endDate: _endDate,
    );
    final perItemData = await _reportService.getProfitPerItemReport(
      startDate: _startDate,
      endDate: _endDate,
    );
    final perSaleData = await _reportService.getProfitPerSaleReport(
      startDate: _startDate,
      endDate: _endDate,
    );

    setState(() {
      _overallReport = overallData;
      _profitPerDay = perDayData;
      _profitPerItem = perItemData;
      _profitPerSale = perSaleData;
      _isLoading = false;
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadAllReports();
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _loadAllReports();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Profit Analysis'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_startDate != null ? Icons.clear : Icons.date_range),
            onPressed: _startDate != null ? _clearDateRange : _selectDateRange,
            tooltip: _startDate != null ? 'Clear Date Filter' : 'Select Date Range',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFF1A1A1A),
          unselectedLabelColor: const Color(0xFF6B6B6B),
          indicatorColor: const Color(0xFF1A1A1A),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Daily Trend'),
            Tab(text: 'By Item'),
            Tab(text: 'By Sale'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildDailyTrendTab(),
                _buildProfitPerItemTab(),
                _buildProfitPerSaleTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    if (_overallReport == null) return const Center(child: Text('No data'));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_startDate != null && _endDate != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.date_range, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}',
                    style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF388E3C)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Text('Gross Profit', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Text(
                '₹${(_overallReport!['grossProfit'] as double).toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_overallReport!['profitMargin'] as double).toStringAsFixed(1)}% margin',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildCard('Total Revenue', '₹${(_overallReport!['totalRevenue'] as double).toStringAsFixed(2)}', Icons.trending_up, Colors.blue),
        _buildCard('Total Cost', '₹${(_overallReport!['totalCost'] as double).toStringAsFixed(2)}', Icons.shopping_cart, Colors.orange),
        _buildCard('Items Sold', '${_overallReport!['itemCount']}', Icons.inventory, Colors.purple),
      ],
    );
  }

  Widget _buildDailyTrendTab() {
    if (_profitPerDay.isEmpty) {
      return const Center(child: Text('No daily profit data available'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 250,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8E8E8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profit Trend',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildProfitChart()),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Daily Breakdown',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ..._profitPerDay.map((day) => _buildDailyProfitCard(day)),
      ],
    );
  }

  Widget _buildProfitChart() {
    final spots = <FlSpot>[];
    for (int i = 0; i < _profitPerDay.length && i < 30; i++) {
      final profit = _profitPerDay[i]['totalProfit'] as double;
      spots.add(FlSpot(i.toDouble(), profit));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  '₹${(value / 1000).toStringAsFixed(0)}k',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF6B6B6B)),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < _profitPerDay.length) {
                  final date = DateTime.parse(_profitPerDay[value.toInt()]['date']);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('MM/dd').format(date),
                      style: const TextStyle(fontSize: 10, color: Color(0xFF6B6B6B)),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF4CAF50),
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF4CAF50).withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyProfitCard(Map<String, dynamic> day) {
    final date = DateTime.parse(day['date']);
    final profit = day['totalProfit'] as double;
    final revenue = day['totalRevenue'] as double;
    final margin = day['profitMargin'] as double;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEEE, MMM dd, yyyy').format(date),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: profit >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${margin.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: profit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSmallStat('Profit', '₹${profit.toStringAsFixed(2)}', Colors.green),
              ),
              Expanded(
                child: _buildSmallStat('Revenue', '₹${revenue.toStringAsFixed(2)}', Colors.blue),
              ),
              Expanded(
                child: _buildSmallStat('Sales', '${day['totalSales']}', Colors.orange),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfitPerItemTab() {
    if (_profitPerItem.isEmpty) {
      return const Center(child: Text('No item profit data available'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Profit by Product Variant',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ..._profitPerItem.map((item) => _buildItemProfitCard(item)),
      ],
    );
  }

  Widget _buildItemProfitCard(Map<String, dynamic> item) {
    final profit = item['totalProfit'] as double;
    final margin = item['profitMargin'] as double;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['productName'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    if (item['size'] != null || item['color'] != null)
                      Text(
                        '${item['size'] ?? ''} ${item['color'] ?? ''}'.trim(),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: profit >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${margin.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: profit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSmallStat('Profit', '₹${profit.toStringAsFixed(2)}', Colors.green),
              ),
              Expanded(
                child: _buildSmallStat('Revenue', '₹${(item['totalRevenue'] as double).toStringAsFixed(2)}', Colors.blue),
              ),
              Expanded(
                child: _buildSmallStat('Qty Sold', '${item['totalQuantitySold']}', Colors.orange),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfitPerSaleTab() {
    if (_profitPerSale.isEmpty) {
      return const Center(child: Text('No sale profit data available'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Profit by Individual Sale',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ..._profitPerSale.take(50).map((sale) => _buildSaleProfitCard(sale)),
      ],
    );
  }

  Widget _buildSaleProfitCard(Map<String, dynamic> sale) {
    final profit = sale['profit'] as double;
    final margin = sale['profitMargin'] as double;
    final date = DateTime.parse(sale['date']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sale #${sale['saleId'].toString().substring(0, 8)}...',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM dd, yyyy hh:mm a').format(date),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: profit >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${margin.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: profit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSmallStat('Profit', '₹${profit.toStringAsFixed(2)}', Colors.green),
              ),
              Expanded(
                child: _buildSmallStat('Revenue', '₹${(sale['totalRevenue'] as double).toStringAsFixed(2)}', Colors.blue),
              ),
              Expanded(
                child: _buildSmallStat('Items', '${sale['totalItems']}', Colors.orange),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B6B6B)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }

  Widget _buildCard(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B6B))),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}