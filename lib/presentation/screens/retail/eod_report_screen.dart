import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:unipos/domain/services/retail/eod_report_service.dart';

/// End of Day Report Screen
class EODReportScreen extends StatefulWidget {
  const EODReportScreen({super.key});

  @override
  State<EODReportScreen> createState() => _EODReportScreenState();
}

class _EODReportScreenState extends State<EODReportScreen> {
  final EODReportService _reportService = EODReportService();
  DateTime _selectedDate = DateTime.now();
  EODReport? _report;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final report = await _reportService.generateEODReport(date: _selectedDate);
      setState(() => _report = report);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('End of Day Report'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReport,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _report == null
              ? const Center(child: Text('No data available'))
              : RefreshIndicator(
                  onRefresh: _loadReport,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date Header
                        _buildDateHeader(),
                        const SizedBox(height: 16),

                        // Sales Summary
                        _buildSalesSummary(),
                        const SizedBox(height: 16),

                        // Collections Summary
                        _buildCollectionsSummary(),
                        const SizedBox(height: 16),

                        // Profit Summary
                        _buildProfitSummary(),
                        const SizedBox(height: 16),

                        // Cash Drawer Summary
                        _buildCashDrawerSummary(),
                        const SizedBox(height: 16),

                        // Outstanding Summary
                        _buildOutstandingSummary(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildDateHeader() {
    final dateFormat = DateFormat('EEEE, dd MMMM yyyy');
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.assessment, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? 'Today\'s Report' : 'EOD Report',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateFormat.format(_selectedDate),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          if (!isToday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Historical',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSalesSummary() {
    return _buildSectionCard(
      title: 'Sales Summary',
      icon: Icons.shopping_cart,
      iconColor: const Color(0xFF4CAF50),
      children: [
        _buildSalesRow('Cash Sales', _report!.cashSales, _report!.cashCount, const Color(0xFF4CAF50)),
        _buildSalesRow('Card Sales', _report!.cardSales, _report!.cardCount, const Color(0xFF2196F3)),
        _buildSalesRow('UPI Sales', _report!.upiSales, _report!.upiCount, const Color(0xFF9C27B0)),
        _buildSalesRow('Credit Sales', _report!.creditSales, _report!.creditCount, Colors.red),
        if (_report!.splitSales > 0)
          _buildSalesRow('Split Sales', _report!.splitSales, _report!.splitCount, const Color(0xFFFF9800)),
        const Divider(height: 24),
        _buildTotalRow('Total Sales', _report!.totalSales, _report!.totalTransactions),
      ],
    );
  }

  Widget _buildCollectionsSummary() {
    return _buildSectionCard(
      title: 'Collections Summary',
      icon: Icons.payments,
      iconColor: const Color(0xFF1976D2),
      subtitle: 'Credit payments received',
      children: [
        _buildAmountRow('Cash Collections', _report!.cashCollections, const Color(0xFF4CAF50)),
        _buildAmountRow('Card Collections', _report!.cardCollections, const Color(0xFF2196F3)),
        _buildAmountRow('UPI Collections', _report!.upiCollections, const Color(0xFF9C27B0)),
        const Divider(height: 24),
        _buildTotalRow('Total Collections', _report!.totalCollections, null),
      ],
    );
  }

  Widget _buildProfitSummary() {
    final isProfitable = _report!.totalProfit >= 0;

    return _buildSectionCard(
      title: 'Profit Summary',
      icon: Icons.trending_up,
      iconColor: isProfitable ? const Color(0xFF4CAF50) : Colors.red,
      children: [
        _buildAmountRow('Total Revenue', _report!.totalRevenue, const Color(0xFF1A1A1A)),
        _buildAmountRow('Total Cost', _report!.totalCost, Colors.grey),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Net Profit',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isProfitable ? '+' : ''}₹${_report!.totalProfit.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isProfitable ? const Color(0xFF4CAF50) : Colors.red,
                  ),
                ),
                Text(
                  '${_report!.profitMargin.toStringAsFixed(1)}% margin',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCashDrawerSummary() {
    return _buildSectionCard(
      title: 'Cash Drawer',
      icon: Icons.point_of_sale,
      iconColor: const Color(0xFFFF9800),
      children: [
        _buildAmountRow('Opening Balance', _report!.openingBalance, Colors.grey),
        _buildAmountRow('+ Cash Sales', _report!.cashSales, const Color(0xFF4CAF50)),
        _buildAmountRow('+ Cash Collections', _report!.cashCollections, const Color(0xFF4CAF50)),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Cash in Drawer',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              '₹${_report!.cashInDrawer.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOutstandingSummary() {
    return _buildSectionCard(
      title: 'Customer Outstanding',
      icon: Icons.account_balance_wallet,
      iconColor: Colors.red,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Outstanding',
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${_report!.totalOutstanding.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    '${_report!.customersWithDue}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                  ),
                  const Text(
                    'Customers',
                    style: TextStyle(fontSize: 11, color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_report!.customersWithCredit.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Top Due Customers',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF6B6B6B)),
          ),
          const SizedBox(height: 8),
          ..._report!.customersWithCredit.take(5).map((customer) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      '₹${customer.creditBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesRow(String label, double amount, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 14)),
            ],
          ),
          Row(
            children: [
              Text(
                '($count)',
                style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
              ),
              const SizedBox(width: 8),
              Text(
                '₹${amount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF6B6B6B))),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, int? count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        Row(
          children: [
            if (count != null) ...[
              Text(
                '($count txns)',
                style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              '₹${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4CAF50),
              ),
            ),
          ],
        ),
      ],
    );
  }
}