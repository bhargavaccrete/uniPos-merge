import 'package:flutter/material.dart';
import 'package:unipos/presentation/screens/retail/reports/daily_sales_report_screen.dart';
import 'package:unipos/presentation/screens/retail/reports/monthly_sales_report_screen.dart';
import 'package:unipos/presentation/screens/retail/reports/product_wise_sales_report_screen.dart';
import 'package:unipos/presentation/screens/retail/reports/variant_wise_sales_report_screen.dart';
import 'package:unipos/presentation/screens/retail/reports/category_wise_sales_report_screen.dart';
import 'package:unipos/presentation/screens/retail/reports/supplier_wise_purchase_report_screen.dart';
import 'package:unipos/presentation/screens/retail/reports/low_stock_report_screen.dart';
import 'package:unipos/presentation/screens/retail/reports/top_selling_products_report_screen.dart';
import 'package:unipos/presentation/screens/retail/reports/profit_report_screen.dart';
import 'package:unipos/presentation/screens/retail/reports/monthly_sales_report_screen.dart';

import 'reports/daily_sales_report_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Sales Reports'),
          _buildReportCard(
            context,
            title: 'Daily Sales',
            subtitle: 'View sales for a specific date',
            icon: Icons.today,
            color: const Color(0xFF2196F3),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DailySalesReportScreen()),
            ),
          ),
          _buildReportCard(
            context,
            title: 'Monthly Sales',
            subtitle: 'View monthly sales breakdown',
            icon: Icons.calendar_month,
            color: const Color(0xFF9C27B0),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MonthlySalesReportScreen()),
            ),
          ),
          _buildReportCard(
            context,
            title: 'Product-wise Sales',
            subtitle: 'Sales grouped by products',
            icon: Icons.shopping_bag,
            color: const Color(0xFF4CAF50),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProductWiseSalesReportScreen()),
            ),
          ),
          _buildReportCard(
            context,
            title: 'Variant-wise Sales',
            subtitle: 'Sales grouped by product variants',
            icon: Icons.settings,
            color: const Color(0xFFFF9800),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const VariantWiseSalesReportScreen()),
            ),
          ),
          _buildReportCard(
            context,
            title: 'Category-wise Sales',
            subtitle: 'Sales grouped by categories',
            icon: Icons.category,
            color: const Color(0xFF00BCD4),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CategoryWiseSalesReportScreen()),
            ),
          ),
          _buildReportCard(
            context,
            title: 'Top Selling Products',
            subtitle: 'Best performing products',
            icon: Icons.trending_up,
            color: const Color(0xFFE91E63),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TopSellingProductsReportScreen()),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('Purchase Reports'),
          _buildReportCard(
            context,
            title: 'Supplier-wise Purchase',
            subtitle: 'Purchases grouped by suppliers',
            icon: Icons.local_shipping,
            color: const Color(0xFF673AB7),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SupplierWisePurchaseReportScreen()),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('Inventory Reports'),
          _buildReportCard(
            context,
            title: 'Low Stock Alert',
            subtitle: 'Products running low on stock',
            icon: Icons.warning_amber,
            color: Colors.red,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LowStockReportScreen()),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('Financial Reports'),
          _buildReportCard(
            context,
            title: 'Profit Report',
            subtitle: 'Revenue vs Cost analysis',
            icon: Icons.attach_money,
            color: const Color(0xFF4CAF50),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfitReportScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A1A),
        ),
      ),
    );
  }

  Widget _buildReportCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B6B6B),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFB0B0B0)),
        onTap: onTap,
      ),
    );
  }
}