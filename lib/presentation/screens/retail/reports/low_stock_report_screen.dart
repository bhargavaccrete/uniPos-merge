import 'package:flutter/material.dart';
import 'package:unipos/domain/services/retail/report_service.dart';


class LowStockReportScreen extends StatefulWidget {
  const LowStockReportScreen({super.key});
  @override
  State<LowStockReportScreen> createState() => _LowStockReportScreenState();
}

class _LowStockReportScreenState extends State<LowStockReportScreen> {
  final ReportService _reportService = ReportService();
  List<Map<String, dynamic>> _reportData = [];
  bool _isLoading = false;
  int _threshold = 10;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final data = await _reportService.getLowStockReport(threshold: _threshold);
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
        title: const Text('Low Stock Alert'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<int>(
            onSelected: (value) {
              setState(() => _threshold = value);
              _loadReport();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 5, child: Text('Threshold: 5')),
              const PopupMenuItem(value: 10, child: Text('Threshold: 10')),
              const PopupMenuItem(value: 20, child: Text('Threshold: 20')),
            ],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.tune, size: 20),
                  const SizedBox(width: 4),
                  Text('≤$_threshold', style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _reportData.isEmpty ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('All products are well stocked!'),
          ],
        ),
      ) : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reportData.length,
        itemBuilder: (context, index) {
          final item = _reportData[index];
          final stock = item['currentStock'] as int;
          final isVeryLow = stock <= 3;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isVeryLow ? Colors.red : const Color(0xFFFF9800), width: isVeryLow ? 2 : 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isVeryLow ? Colors.red : const Color(0xFFFF9800)).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.warning_amber, color: isVeryLow ? Colors.red : const Color(0xFFFF9800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['productName'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      if (item['size'] != null || item['color'] != null)
                        Text('${item['size'] ?? ''} ${item['color'] ?? ''}'.trim(), style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isVeryLow ? Colors.red : const Color(0xFFFF9800)).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('$stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isVeryLow ? Colors.red : const Color(0xFFFF9800))),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}