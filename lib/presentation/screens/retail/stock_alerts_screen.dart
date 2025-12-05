import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/domain/store/retail/stock_alert_store.dart';

import '../../../core/di/service_locator.dart';


class StockAlertsScreen extends StatefulWidget {
  const StockAlertsScreen({super.key});

  @override
  State<StockAlertsScreen> createState() => _StockAlertsScreenState();
}

class _StockAlertsScreenState extends State<StockAlertsScreen> {
  late final StockAlertStore _alertStore;

  @override
  void initState() {
    super.initState();
    _alertStore = stockAlertStore;
    _alertStore.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Stock Alerts'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Observer(
            builder: (_) => PopupMenuButton<int>(
              onSelected: (value) {
                _alertStore.setThreshold(value);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 5, child: Text('Threshold: 5')),
                const PopupMenuItem(value: 10, child: Text('Threshold: 10')),
                const PopupMenuItem(value: 15, child: Text('Threshold: 15')),
                const PopupMenuItem(value: 20, child: Text('Threshold: 20')),
              ],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.tune, size: 20),
                    const SizedBox(width: 4),
                    Text('≤${_alertStore.threshold}', style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Observer(
        builder: (_) {
          if (_alertStore.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_alertStore.lowStockItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 80, color: Colors.green.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text(
                    'All products are well stocked!',
                    style: TextStyle(fontSize: 16, color: Color(0xFF6B6B6B)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No items below threshold of ${_alertStore.threshold}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Summary Cards
              _buildSummarySection(),
              // Alert List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _alertStore.refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _alertStore.lowStockItems.length,
                    itemBuilder: (context, index) {
                      final item = _alertStore.lowStockItems[index];
                      return _buildAlertCard(item);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummarySection() {
    return Observer(
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE8E8E8))),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total Alerts',
                _alertStore.totalAlerts.toString(),
                const Color(0xFF1A1A1A),
                Icons.notifications_active,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Critical',
                _alertStore.criticalCount.toString(),
                Colors.red,
                Icons.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Out of Stock',
                _alertStore.outOfStockCount.toString(),
                Colors.red.shade900,
                Icons.remove_shopping_cart,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> item) {
    final stock = item['currentStock'] as int;
    final isOutOfStock = stock == 0;
    final isCritical = stock <= 3;

    Color alertColor;
    IconData alertIcon;
    String alertLabel;

    if (isOutOfStock) {
      alertColor = Colors.red.shade900;
      alertIcon = Icons.remove_shopping_cart;
      alertLabel = 'OUT OF STOCK';
    } else if (isCritical) {
      alertColor = Colors.red;
      alertIcon = Icons.warning_amber;
      alertLabel = 'CRITICAL';
    } else {
      alertColor = const Color(0xFFFF9800);
      alertIcon = Icons.info_outline;
      alertLabel = 'LOW STOCK';
    }

    final variantInfo = _buildVariantDescription(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: alertColor, width: isOutOfStock || isCritical ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: alertColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Alert Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: alertColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(alertIcon, color: alertColor, size: 28),
            ),
            const SizedBox(width: 16),
            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['productName'] ?? 'Unknown Product',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (variantInfo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      variantInfo,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: alertColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      alertLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: alertColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Stock Quantity
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: alertColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$stock',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: alertColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'in stock',
                  style: TextStyle(
                    fontSize: 10,
                    color: alertColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _buildVariantDescription(Map<String, dynamic> item) {
    final parts = <String>[];

    if (item['size'] != null && item['size'].toString().isNotEmpty) {
      parts.add('Size: ${item['size']}');
    }
    if (item['color'] != null && item['color'].toString().isNotEmpty) {
      parts.add('Color: ${item['color']}');
    }
    if (item['weight'] != null && item['weight'].toString().isNotEmpty) {
      parts.add('Weight: ${item['weight']}');
    }
    if (item['barcode'] != null && item['barcode'].toString().isNotEmpty) {
      parts.add('Barcode: ${item['barcode']}');
    }

    return parts.join(' | ');
  }
}