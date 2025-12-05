import 'package:flutter/material.dart';

import '../../../../domain/services/retail/report_service.dart';

class ProductWiseSalesReportScreen extends StatefulWidget {
  const ProductWiseSalesReportScreen({super.key});

  @override
  State<ProductWiseSalesReportScreen> createState() => _ProductWiseSalesReportScreenState();
}

class _ProductWiseSalesReportScreenState extends State<ProductWiseSalesReportScreen> {
  final ReportService _reportService = ReportService();
  List<Map<String, dynamic>> _reportData = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final data = await _reportService.getProductWiseSalesReport();
    setState(() {
      _reportData = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Product-wise Sales'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reportData.isEmpty
              ? const Center(child: Text('No data'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reportData.length,
                  itemBuilder: (context, index) {
                    final item = _reportData[index];
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
                          Text(
                            item['productName'],
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStat('Qty', '${item['totalQuantity']}', Icons.inventory_2, Colors.blue),
                              _buildStat('Revenue', '₹${(item['totalRevenue'] as double).toStringAsFixed(0)}', Icons.currency_rupee, Colors.green),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B6B6B))),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}