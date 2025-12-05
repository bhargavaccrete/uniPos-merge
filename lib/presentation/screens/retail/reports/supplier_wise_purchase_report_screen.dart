import 'package:flutter/material.dart';
import 'package:unipos/domain/services/retail/report_service.dart';

class SupplierWisePurchaseReportScreen extends StatefulWidget {
  const SupplierWisePurchaseReportScreen({super.key});
  @override
  State<SupplierWisePurchaseReportScreen> createState() => _SupplierWisePurchaseReportScreenState();
}

class _SupplierWisePurchaseReportScreenState extends State<SupplierWisePurchaseReportScreen> {
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
    final data = await _reportService.getSupplierWisePurchaseReport();
    setState(() {
      _reportData = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(title: const Text('Supplier-wise Purchases'), centerTitle: true, backgroundColor: Colors.white, elevation: 0),
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
                Text(item['supplierName'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${item['totalPurchases']} purchases', style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B6B))),
                    Text('₹${(item['totalAmount'] as double).toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
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