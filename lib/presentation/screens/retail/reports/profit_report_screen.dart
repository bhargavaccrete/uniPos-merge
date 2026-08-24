import 'package:flutter/material.dart';
import 'package:billberrylite/util/common/short_ref.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../../domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';

class ProfitReportScreen extends StatefulWidget {
  const ProfitReportScreen({super.key});
  @override
  State<ProfitReportScreen> createState() => _ProfitReportScreenState();
}

class _ProfitReportScreenState extends State<ProfitReportScreen>
    with SingleTickerProviderStateMixin {
  final ReportService _reportService = ReportService();
  Map<String, dynamic>? _overallReport;
  List<Map<String, dynamic>> _profitPerDay = [];
  List<Map<String, dynamic>> _profitPerItem = [];
  List<Map<String, dynamic>> _profitPerSale = [];
  List<Map<String, dynamic>> _bundleMargin = [];
  bool _isLoading = false;
  late TabController _tabController;

  DateTime? _startDate;
  DateTime? _endDate;

  /// Incremented per load so a slow in-flight request can be discarded when a
  /// newer one has already been issued.
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Bounds in the form `ReportService` expects: inclusive start, **exclusive**
  /// end.
  ///
  /// `showDateRangePicker` hands back midnight of the final day, and
  /// `_inWindow` rejects anything not before the end — so passing it straight
  /// through silently dropped every sale on the last day of the range. Same
  /// `+1 day` as `ReportPageScaffold._bounds`.
  (DateTime?, DateTime?) get _bounds {
    if (_startDate == null || _endDate == null) return (null, null);
    final start = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
    );
    final end = DateTime(
      _endDate!.year,
      _endDate!.month,
      _endDate!.day,
    ).add(const Duration(days: 1));
    return (start, end);
  }

  Future<void> _loadAllReports() async {
    // Change the range twice quickly and the slower first load could land after
    // the second and overwrite it with stale numbers. Only the newest token
    // gets to publish.
    final token = ++_loadToken;
    setState(() => _isLoading = true);
    final (start, end) = _bounds;

    // Started together rather than awaited one after another — four sequential
    // round-trips through the sales box was the whole load time.
    final overallFuture = _reportService.getProfitReport(
      startDate: start,
      endDate: end,
    );
    final perDayFuture = _reportService.getProfitPerDayReport(
      startDate: start,
      endDate: end,
    );
    final perItemFuture = _reportService.getProfitPerItemReport(
      startDate: start,
      endDate: end,
    );
    final perSaleFuture = _reportService.getProfitPerSaleReport(
      startDate: start,
      endDate: end,
    );
    // Not window-bound — a bundle's margin is a current-catalogue pricing
    // question, not a sales-history one (see ReportService.getBundleMarginReport).
    final bundleMarginFuture = _reportService.getBundleMarginReport();

    final overallData = await overallFuture;
    final perDayData = await perDayFuture;
    final perItemData = await perItemFuture;
    final perSaleData = await perSaleFuture;
    final bundleMarginData = await bundleMarginFuture;

    if (!mounted || token != _loadToken) return;
    setState(() {
      _overallReport = overallData;
      _profitPerDay = perDayData;
      _profitPerItem = perItemData;
      _profitPerSale = perSaleData;
      _bundleMargin = bundleMarginData;
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
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Profit Analysis',
        actions: [
          IconButton(
            icon: Icon(_startDate != null ? Icons.clear : Icons.date_range),
            color: Colors.white,
            onPressed: _startDate != null ? _clearDateRange : _selectDateRange,
            tooltip: _startDate != null
                ? 'Clear Date Filter'
                : 'Select Date Range',
          ),
        ],
        // Tabs read on the primary fill, matching every other AppBar in the app.
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Daily Trend'),
            Tab(text: 'By Item'),
            Tab(text: 'By Sale'),
            Tab(text: 'Bundles'),
          ],
        ),
      ),
      // Every amount here goes through formatMoney; MoneyScope is the single
      // subscription that re-renders them when the store's currency or decimal
      // precision changes.
      body: MoneyScope(
        child: AppResponsive.constrainedContent(
          context: context,
          alignment: Alignment.topCenter,
          maxWidth: AppResponsive.maxContentWidth(context),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildDailyTrendTab(),
                    _buildProfitPerItemTab(),
                    _buildProfitPerSaleTab(),
                    _buildBundleMarginTab(),
                  ],
                ),
        ),
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
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                'Gross Profit',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: AppResponsive.bodyFontSize(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formatMoney((_overallReport!['grossProfit'] as double)),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: AppResponsive.headingFontSize(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_overallReport!['profitMargin'] as double).toStringAsFixed(1)}% margin',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: AppResponsive.bodyFontSize(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildCard(
          'Total Revenue',
          formatMoney((_overallReport!['totalRevenue'] as double)),
          Icons.trending_up,
          Colors.blue,
        ),
        _buildCard(
          'Total Cost',
          formatMoney((_overallReport!['totalCost'] as double)),
          Icons.shopping_cart,
          Colors.orange,
        ),
        _buildCard(
          'Items Sold',
          '${_overallReport!['itemCount']}',
          Icons.inventory,
          Colors.purple,
        ),
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
              Text(
                'Profit Trend',
                style: TextStyle(
                  fontSize: AppResponsive.subheadingFontSize(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildProfitChart()),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Daily Breakdown',
          style: TextStyle(
            fontSize: AppResponsive.subheadingFontSize(context),
            fontWeight: FontWeight.w600,
          ),
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
                  '${formatMoney((value / 1000))}k',
                  style: TextStyle(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: Color(0xFF6B6B6B),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 &&
                    value.toInt() < _profitPerDay.length) {
                  final date = DateTime.parse(
                    _profitPerDay[value.toInt()]['date'],
                  );
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('MM/dd').format(date),
                      style: TextStyle(
                        fontSize: AppResponsive.captionFontSize(context),
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                  );
                }
                return Text('');
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
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
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: AppResponsive.bodyFontSize(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: profit >= 0
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${margin.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: profit >= 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontSize: AppResponsive.captionFontSize(context),
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
                child: _buildSmallStat(
                  'Profit',
                  formatMoney(profit),
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildSmallStat(
                  'Revenue',
                  formatMoney(revenue),
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildSmallStat(
                  'Sales',
                  '${day['totalSales']}',
                  Colors.orange,
                ),
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
        Text(
          'Profit by Product Variant',
          style: TextStyle(
            fontSize: AppResponsive.subheadingFontSize(context),
            fontWeight: FontWeight.w600,
          ),
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
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: AppResponsive.bodyFontSize(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if ((item['variantLabel'] as String?)?.isNotEmpty ?? false)
                      Text(
                        item['variantLabel'] as String,
                        style: TextStyle(
                          fontSize: AppResponsive.captionFontSize(context),
                          color: Color(0xFF6B6B6B),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: profit >= 0
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${margin.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: profit >= 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontSize: AppResponsive.captionFontSize(context),
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
                child: _buildSmallStat(
                  'Profit',
                  formatMoney(profit),
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildSmallStat(
                  'Revenue',
                  formatMoney((item['totalRevenue'] as double)),
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildSmallStat(
                  'Qty Sold',
                  '${item['totalQuantitySold']}',
                  Colors.orange,
                ),
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
        Text(
          'Profit by Individual Sale',
          style: TextStyle(
            fontSize: AppResponsive.subheadingFontSize(context),
            fontWeight: FontWeight.w600,
          ),
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
                    'Sale #${shortRef(sale['saleId']?.toString(), ellipsis: true)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: AppResponsive.bodyFontSize(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM dd, yyyy hh:mm a').format(date),
                    style: TextStyle(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: Color(0xFF6B6B6B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: profit >= 0
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${margin.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: profit >= 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontSize: AppResponsive.captionFontSize(context),
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
                child: _buildSmallStat(
                  'Profit',
                  formatMoney(profit),
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildSmallStat(
                  'Revenue',
                  formatMoney((sale['totalRevenue'] as double)),
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildSmallStat(
                  'Items',
                  '${sale['totalItems']}',
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bundle/repack margin — not affected by the date filter, since it reads
  /// the current catalogue rather than a sales window (see
  /// ReportService.getBundleMarginReport).
  Widget _buildBundleMarginTab() {
    if (_bundleMargin.isEmpty) {
      return const Center(
        child: Text('No bundle or repack products configured yet'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Bundle & Repack Margin',
          style: TextStyle(
            fontSize: AppResponsive.subheadingFontSize(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Selling price vs. summed component cost — current catalogue, not a sales window.',
          style: TextStyle(
            fontSize: AppResponsive.captionFontSize(context),
            color: const Color(0xFF6B6B6B),
          ),
        ),
        const SizedBox(height: 8),
        ..._bundleMargin.map((row) => _buildBundleMarginCard(row)),
      ],
    );
  }

  Widget _buildBundleMarginCard(Map<String, dynamic> row) {
    final margin = row['margin'] as double;
    final marginPercent = row['marginPercent'] as double;
    final isRepack = row['isRepack'] == true;

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
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        row['productName'] as String? ?? 'Unknown',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: AppResponsive.bodyFontSize(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isRepack ? 'Repack' : 'Bundle',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: margin >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${marginPercent.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: margin >= 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontSize: AppResponsive.captionFontSize(context),
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
                child: _buildSmallStat(
                  'Margin',
                  formatMoney(margin),
                  margin >= 0 ? Colors.green : Colors.red,
                ),
              ),
              Expanded(
                child: _buildSmallStat(
                  'Selling Price',
                  formatMoney((row['sellingPrice'] as double)),
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildSmallStat(
                  'Component Cost',
                  formatMoney((row['componentCost'] as double)),
                  Colors.orange,
                ),
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
          style: TextStyle(
            fontSize: AppResponsive.captionFontSize(context),
            color: Color(0xFF6B6B6B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: FontWeight.w600,
            color: color,
          ),
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
              Text(
                label,
                style: TextStyle(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: Color(0xFF6B6B6B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: AppResponsive.subheadingFontSize(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
