import 'package:flutter/material.dart';

import '../../../../domain/services/retail/report_service.dart';

class TopSellingProductsReportScreen extends StatefulWidget {
  const TopSellingProductsReportScreen({super.key});
  @override
  State<TopSellingProductsReportScreen> createState() => _TopSellingProductsReportScreenState();
}

class _TopSellingProductsReportScreenState extends State<TopSellingProductsReportScreen> {
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
    final data = await _reportService.getTopSellingProductsReport(limit: 20);
    setState(() {
      _reportData = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(title: const Text('Top Selling Products'), centerTitle: true, backgroundColor: Colors.white, elevation: 0),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _reportData.isEmpty ? const Center(child: Text('No data')) : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reportData.length,
        itemBuilder: (context, index) {
          final item = _reportData[index];
          final rank = index + 1;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE8E8E8)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: rank <= 3 ? const Color(0xFFFFD700).withOpacity(0.2) : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: rank <= 3 ? const Color(0xFFFF9800) : const Color(0xFF6B6B6B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['productName'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.inventory_2, size: 14, color: Color(0xFF2196F3)),
                          const SizedBox(width: 4),
                          Text('${item['totalQuantity']} sold', style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B))),
                        ],
                      ),
                    ],
                  ),
                ),
                Text('₹${(item['totalRevenue'] as double).toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4CAF50))),
              ],
            ),
          );
        },
      ),
    );
  }
}