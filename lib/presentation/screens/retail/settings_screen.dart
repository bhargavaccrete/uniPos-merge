import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../../core/di/service_locator.dart';
import 'package:unipos/presentation/screens/retail/backup_screen.dart';
import 'package:unipos/presentation/screens/retail/gst_settings_screen.dart';
import 'package:unipos/presentation/screens/retail/gst_report_screen.dart';
import 'package:unipos/presentation/screens/retail/attributes_screen.dart';
import 'package:unipos/presentation/screens/retail/store_info_settings_screen.dart';
import 'package:unipos/presentation/screens/retail/settings/printer_settings_screen.dart';
import 'package:unipos/presentation/screens/retail/start_day_screen.dart';
import 'package:unipos/presentation/screens/retail/eod_screen.dart';
import 'package:unipos/presentation/screens/retail/eod_reports_list_screen.dart';
import 'package:unipos/presentation/screens/retail/payment_methods_screen.dart';
import 'package:unipos/domain/services/restaurant/day_management_service.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Key to rebuild the FutureBuilder when returning from Start Day or End Day screens
  int _refreshKey = 0;

  void _refreshDayStatus() {
    setState(() {
      _refreshKey++;
    });
  }

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
          // Store Information Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'BUSINESS INFORMATION',
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
            icon: Icons.store,
            title: 'Store Information',
            subtitle: 'Configure store name, address, and contact details',
            iconColor: const Color(0xFF4CAF50),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StoreInfoSettingsScreen()),
              );
            },
          ),
          const SizedBox(height: 16),

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

          // Day Management Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'DAY MANAGEMENT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B6B6B),
                letterSpacing: 0.5,
              ),
            ),
          ),
          FutureBuilder<bool>(
            key: ValueKey(_refreshKey), // Rebuild when _refreshKey changes
            future: DayManagementService.isDayStarted(),
            builder: (context, snapshot) {
              final isDayStarted = snapshot.data ?? false;

              return Column(
                children: [
                  _buildSettingsCard(
                    context,
                    icon: Icons.wb_sunny,
                    title: 'Start Day',
                    subtitle: isDayStarted
                        ? 'Day already started - Open to view/edit'
                        : 'Set opening balance to begin operations',
                    iconColor: const Color(0xFF4CAF50),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const StartDayScreen()),
                      );
                      // Refresh the day status after returning
                      _refreshDayStatus();
                    },
                  ),
                  if (isDayStarted)
                    _buildSettingsCard(
                      context,
                      icon: Icons.nights_stay,
                      title: 'End of Day',
                      subtitle: 'Close day and reconcile cash',
                      iconColor: const Color(0xFF2196F3),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RetailEODScreen()),
                        );
                        // Refresh the day status after returning
                        _refreshDayStatus();
                      },
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Printing Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'PRINTING',
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
            icon: Icons.print,
            title: 'Printer Settings',
            subtitle: 'Configure invoice layout, paper size, and print options',
            iconColor: const Color(0xFF673AB7),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrinterSettingsScreen()),
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

          // Display & Format Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'DISPLAY & FORMAT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B6B6B),
                letterSpacing: 0.5,
              ),
            ),
          ),
          _buildCurrencyCard(context),
          _buildDecimalPrecisionCard(context),

          const SizedBox(height: 16),

          // Payment Settings Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'PAYMENT SETTINGS',
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
            icon: Icons.payment,
            title: 'Payment Methods',
            subtitle: 'Configure available payment options',
            iconColor: const Color(0xFF4CAF50),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PaymentMethodsScreen()),
              );
            },
          ),

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
          _buildSettingsCard(
            context,
            icon: Icons.receipt_long_outlined,
            title: 'EOD Reports',
            subtitle: 'View saved End of Day reports',
            iconColor: const Color(0xFFFF9800),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EODReportsListScreen()),
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

  Widget _buildCurrencyCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: ListTile(
        onTap: () => _showCurrencyDialog(context),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.attach_money, color: Color(0xFF4CAF50), size: 24),
        ),
        title: const Text(
          'Currency',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: ValueListenableBuilder<String>(
          valueListenable: CurrencyHelper.currencyNotifier,
          builder: (context, currencyCode, child) {
            final currency = CurrencyHelper.currencies[currencyCode];
            return Text(
              '${currency?.name ?? 'Indian Rupee'} (${currency?.symbol ?? '₹'})',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B6B6B),
              ),
            );
          },
        ),
        trailing: ValueListenableBuilder<String>(
          valueListenable: CurrencyHelper.currencyNotifier,
          builder: (context, currencyCode, child) {
            final symbol = CurrencyHelper.currencies[currencyCode]?.symbol ?? '₹';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                symbol,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4CAF50),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showCurrencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Currency'),
        content: SizedBox(
          width: double.maxFinite,
          child: ValueListenableBuilder<String>(
            valueListenable: CurrencyHelper.currencyNotifier,
            builder: (context, currentCurrency, child) {
              final currencies = CurrencyHelper.getAllCurrencies();
              return ListView.builder(
                shrinkWrap: true,
                itemCount: currencies.length,
                itemBuilder: (context, index) {
                  final currency = currencies[index];
                  final isSelected = currency.code == currentCurrency;
                  return ListTile(
                    title: Text(currency.name),
                    subtitle: Text('${currency.code} - ${currency.symbol}'),
                    leading: Radio<String>(
                      value: currency.code,
                      groupValue: currentCurrency,
                      onChanged: (value) async {
                        if (value != null) {
                          await CurrencyHelper.setCurrency(value);
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        }
                      },
                    ),
                    selected: isSelected,
                    onTap: () async {
                      await CurrencyHelper.setCurrency(currency.code);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDecimalPrecisionCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: ListTile(
        onTap: () => _showDecimalPrecisionDialog(context),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.format_list_numbered, color: Color(0xFF2196F3), size: 24),
        ),
        title: const Text(
          'Decimal Precision',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: ValueListenableBuilder<int>(
          valueListenable: DecimalSettings.precisionNotifier,
          builder: (context, precision, child) {
            return Text(
              DecimalSettings.getPrecisionLabel(precision),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B6B6B),
              ),
            );
          },
        ),
        trailing: ValueListenableBuilder<int>(
          valueListenable: DecimalSettings.precisionNotifier,
          builder: (context, precision, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$precision',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2196F3),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showDecimalPrecisionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decimal Precision'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select how many decimal places to show for prices:',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<int>(
              valueListenable: DecimalSettings.precisionNotifier,
              builder: (context, currentPrecision, child) {
                return Column(
                  children: [0, 1, 2, 3].map((precision) {
                    final isSelected = currentPrecision == precision;
                    return ListTile(
                      title: Text(DecimalSettings.getPrecisionLabel(precision)),
                      leading: Radio<int>(
                        value: precision,
                        groupValue: currentPrecision,
                        onChanged: (value) async {
                          if (value != null) {
                            await DecimalSettings.updatePrecision(value);
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          }
                        },
                      ),
                      selected: isSelected,
                      onTap: () async {
                        await DecimalSettings.updatePrecision(precision);
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}