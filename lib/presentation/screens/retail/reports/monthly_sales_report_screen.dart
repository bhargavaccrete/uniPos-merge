import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:unipos/domain/services/retail/report_service.dart';

class MonthlySalesReportScreen extends StatefulWidget {
  const MonthlySalesReportScreen({super.key});

  @override
  State<MonthlySalesReportScreen> createState() => _MonthlySalesReportScreenState();
}

class _MonthlySalesReportScreenState extends State<MonthlySalesReportScreen> {
  final ReportService _reportService = ReportService();
  DateTime _selectedMonth = DateTime.now();
  Map<String, dynamic>? _reportData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final data = await _reportService.getMonthlySalesReport(_selectedMonth.year, _selectedMonth.month);
      setState(() {
        _reportData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month));
      _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Monthly Sales Report'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.calendar_today), onPressed: _selectMonth),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reportData == null
              ? const Center(child: Text('No data'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Text('Selected Month', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 8),
                          Text(
                            DateFormat('MMMM yyyy').format(_selectedMonth),
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildCard('Sales', '${_reportData!['totalSales']}', Icons.receipt, Colors.green)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildCard('Revenue', '₹${(_reportData!['totalRevenue'] as double).toStringAsFixed(0)}', Icons.currency_rupee, Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildStatsCard(),
                  ],
                ),
    );
  }

  Widget _buildCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B))),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Statistics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          _buildRow('Items Sold', '${_reportData!['totalItems']}'),
          _buildRow('Discount', '₹${(_reportData!['totalDiscount'] as double).toStringAsFixed(2)}'),
          _buildRow('Tax', '₹${(_reportData!['totalTax'] as double).toStringAsFixed(2)}'),
          _buildRow('Returns', '${_reportData!['totalReturns']}'),
          const Divider(height: 24),
          _buildRow('Net Revenue', '₹${(_reportData!['netRevenue'] as double).toStringAsFixed(2)}', true),
          _buildRow('Avg Sale', '₹${(_reportData!['averageSaleValue'] as double).toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, [bool highlight = false]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: highlight ? Colors.black : const Color(0xFF6B6B6B))),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: highlight ? Colors.green : Colors.black)),
        ],
      ),
    );
  }
}