import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../../core/di/service_locator.dart';
import 'package:unipos/presentation/screens/retail/backup_screen.dart';
import 'package:unipos/presentation/screens/retail/gst_settings_screen.dart';
import 'package:unipos/presentation/screens/retail/gst_report_screen.dart';
import 'package:unipos/presentation/screens/retail/attributes_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Data Management Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'DATA MANAGEMENT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B6B6B),
                letterSpacing: 0.5,
              ),
            ),
          ),
          _buildSettingsCard(
            context,
            icon: Icons.backup,
            title: 'Backup & Restore',
            subtitle: 'Manage your data backups',
            iconColor: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BackupScreen()),
              );
            },
          ),
          const SizedBox(height: 16),

          // Product Settings Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'PRODUCT SETTINGS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B6B6B),
                letterSpacing: 0.5,
              ),
            ),
          ),
          _buildSettingsCard(
            context,
            icon: Icons.tune,
            title: 'Product Attributes',
            subtitle: 'Manage global attributes (Color, Size, etc.)',
            iconColor: const Color(0xFF9C27B0),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AttributesScreen()),
              );
            },
          ),
          const SizedBox(height: 16),

          // Stock Alerts Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'NOTIFICATIONS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B6B6B),
                letterSpacing: 0.5,
              ),
            ),
          ),
          _buildStockAlertThresholdCard(context),

          const SizedBox(height: 16),

          // GST/Tax Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'TAX SETTINGS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B6B6B),
                letterSpacing: 0.5,
              ),
            ),
          ),
          _buildSettingsCard(
            context,
            icon: Icons.receipt_long,
            title: 'GST Settings',
            subtitle: 'Configure GST rates and categories',
            iconColor: const Color(0xFF4CAF50),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GstSettingsScreen()),
              );
            },
          ),
          _buildSettingsCard(
            context,
            icon: Icons.analytics,
            title: 'GST Reports',
            subtitle: 'View GST collection reports',
            iconColor: const Color(0xFF2196F3),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GstReportScreen()),
              );
            },
          ),

          const SizedBox(height: 16),

          // App Information Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'ABOUT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B6B6B),
                letterSpacing: 0.5,
              ),
            ),
          ),
          _buildSettingsCard(
            context,
            icon: Icons.info_outline,
            title: 'App Information',
            subtitle: 'Version 1.0.0',
            iconColor: Colors.grey,
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'rPOS',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.point_of_sale, size: 48),
                children: [
                  const Text('A modern Point of Sale system built with Flutter'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B6B6B),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Color(0xFF6B6B6B),
        ),
      ),
    );
  }

  Widget _buildStockAlertThresholdCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: ListTile(
        onTap: () => _showThresholdDialog(context),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFF9800).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.notifications_active, color: Color(0xFFFF9800), size: 24),
        ),
        title: const Text(
          'Stock Alert Threshold',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Observer(
          builder: (_) => Text(
            'Alert when stock falls below ${stockAlertStore.threshold}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B6B6B),
            ),
          ),
        ),
        trailing: Observer(
          builder: (_) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${stockAlertStore.threshold}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF9800),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showThresholdDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stock Alert Threshold'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select the stock level below which you want to receive alerts:',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
            ),
            const SizedBox(height: 16),
            Observer(
              builder: (_) => Column(
                children: [5, 10, 15, 20, 25, 50].map((value) {
                  final isSelected = stockAlertStore.threshold == value;
                  return ListTile(
                    title: Text('$value units'),
                    leading: Radio<int>(
                      value: value,
                      groupValue: stockAlertStore.threshold,
                      onChanged: (newValue) {
                        if (newValue != null) {
                          stockAlertStore.setThreshold(newValue);
                        }
                      },
                    ),
                    selected: isSelected,
                    onTap: () {
                      stockAlertStore.setThreshold(value);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}