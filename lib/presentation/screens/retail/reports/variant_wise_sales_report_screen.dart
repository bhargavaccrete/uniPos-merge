import 'package:flutter/material.dart';
import 'package:unipos/domain/services/retail/report_service.dart';

class VariantWiseSalesReportScreen extends StatefulWidget {
  const VariantWiseSalesReportScreen({super.key});
  @override
  State<VariantWiseSalesReportScreen> createState() => _VariantWiseSalesReportScreenState();
}

class _VariantWiseSalesReportScreenState extends State<VariantWiseSalesReportScreen> {
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
    final data = await _reportService.getVariantWiseSalesReport();
    setState(() {
      _reportData = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(title: const Text('Variant-wise Sales'), centerTitle: true, backgroundColor: Colors.white, elevation: 0),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _reportData.isEmpty ? const Center(child: Text('No data')) : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reportData.length,
        itemBuilder: (context, index) {
          final item = _reportData[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE8E8E8))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['productName'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                if (item['size'] != null || item['color'] != null)
                  Text('${item['size'] ?? ''} ${item['color'] ?? ''}'.trim(), style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.inventory, size: 16, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text('Qty: ${item['totalQuantity']}', style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 16),
                    Icon(Icons.currency_rupee, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    Text('₹${(item['totalRevenue'] as double).toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
