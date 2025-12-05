import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:unipos/domain/services/retail/report_service.dart';

class DailySalesReportScreen extends StatefulWidget {
  const DailySalesReportScreen({super.key});

  @override
  State<DailySalesReportScreen> createState() => _DailySalesReportScreenState();
}

class _DailySalesReportScreenState extends State<DailySalesReportScreen> {
  final ReportService _reportService = ReportService();
  DateTime _selectedDate = DateTime.now();
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
      final data = await _reportService.getDailySalesReport(_selectedDate);
      setState(() {
        _reportData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading report: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Daily Sales Report'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reportData == null
              ? const Center(child: Text('No data available'))
              : RefreshIndicator(
                  onRefresh: _loadReport,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildDateCard(),
                      const SizedBox(height: 16),
                      _buildSummaryCards(),
                      const SizedBox(height: 16),
                      _buildStatisticsCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDateCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Selected Date',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('EEEE, MMMM dd, yyyy').format(_selectedDate),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Total Sales',
            '${_reportData!['totalSales']}',
            Icons.receipt_long,
            const Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Revenue',
            '₹${(_reportData!['totalRevenue'] as double).toStringAsFixed(2)}',
            Icons.currency_rupee,
            const Color(0xFF2196F3),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detailed Statistics',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _buildStatRow('Total Items Sold', '${_reportData!['totalItems']}'),
          _buildStatRow('Total Discount', '₹${(_reportData!['totalDiscount'] as double).toStringAsFixed(2)}'),
          _buildStatRow('Total Tax', '₹${(_reportData!['totalTax'] as double).toStringAsFixed(2)}'),
          _buildStatRow('Total Returns', '${_reportData!['totalReturns']}'),
          _buildStatRow('Return Amount', '₹${(_reportData!['totalReturnAmount'] as double).toStringAsFixed(2)}'),
          const Divider(height: 24),
          _buildStatRow(
            'Net Revenue',
            '₹${(_reportData!['netRevenue'] as double).toStringAsFixed(2)}',
            isHighlighted: true,
          ),
          _buildStatRow(
            'Avg Sale Value',
            '₹${(_reportData!['averageSaleValue'] as double).toStringAsFixed(2)}',
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isHighlighted ? const Color(0xFF1A1A1A) : const Color(0xFF6B6B6B),
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isHighlighted ? const Color(0xFF4CAF50) : const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
}