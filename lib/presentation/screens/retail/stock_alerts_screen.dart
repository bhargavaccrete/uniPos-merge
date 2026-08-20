import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_status_pill.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_row.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:billberrylite/domain/store/retail/stock_alert_store.dart';
import 'package:billberrylite/domain/services/retail/stock_alert_service.dart';

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

  /// Threshold picker, on the shared [AppDialogShell] rather than a
  /// `PopupMenuButton`. The menu gave no indication of which value was active
  /// and looked nothing like the app's other dialogs.
  Future<void> _pickThreshold() async {
    const options = StockAlertService.thresholdOptions;
    final current = _alertStore.threshold;

    final picked = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AppDialogShell(
        title: 'Alert Threshold',
        // Worth saying: a variant with its own minStock ignores this number,
        // so changing it appears to do nothing for those rows.
        subtitle:
            'Flags variants at or below this stock level, unless the '
            'variant sets its own minimum.',
        icon: Icons.tune_rounded,
        accent: AppColors.primary,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((value) {
            final selected = value == current;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.pop(dialogContext, value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: AppResponsive.smallIconSize(dialogContext),
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$value units or fewer',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(dialogContext),
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [appDialogCancelButton(dialogContext)],
      ),
    );

    if (picked == null || picked == current) return;
    await _alertStore.setThreshold(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Stock Alerts',
        actions: [
          Observer(
            builder: (_) => InkWell(
              onTap: _pickThreshold,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune,
                      size: AppResponsive.smallIconSize(context),
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '≤${_alertStore.threshold}',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: AppResponsive.constrainedContent(
        context: context,
        alignment: Alignment.topCenter,
        maxWidth: AppResponsive.maxContentWidth(context),
        child: Observer(
          builder: (_) {
            if (_alertStore.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (_alertStore.lowStockItems.isEmpty) {
              // AppEmptyState, not ReportEmptyState — this is a dashboard
              // destination, not a report.
              return AppEmptyState(
                icon: Icons.check_circle,
                title: 'All products are well stocked!',
                message: 'No items below threshold of ${_alertStore.threshold}',
              );
            }

            return Column(
              children: [
                // Summary Cards
                _buildSummarySection(context),
                // Alert List
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _alertStore.refresh(),
                    child: ListView.builder(
                      padding: AppResponsive.padding(context),
                      itemCount: _alertStore.lowStockItems.length,
                      itemBuilder: (context, index) {
                        final item = _alertStore.lowStockItems[index];
                        return _buildAlertCard(context, item);
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context) {
    return Observer(
      builder: (_) => Container(
        padding: AppResponsive.padding(context),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        // ReportSummaryRow instead of a hand-rolled Row of Expandeds: its cards
        // carry the FittedBox that keeps a 3-across band readable on a 360dp
        // phone, which the local version had no answer for.
        child: ReportSummaryRow(
          cards: [
            ReportSummaryCard(
              title: 'Total Alerts',
              value: _alertStore.totalAlerts.toString(),
              icon: Icons.notifications_active,
              color: AppColors.primary,
            ),
            ReportSummaryCard(
              title: 'Critical',
              value: _alertStore.criticalCount.toString(),
              icon: Icons.error,
              color: AppColors.danger,
            ),
            ReportSummaryCard(
              title: 'Out of Stock',
              value: _alertStore.outOfStockCount.toString(),
              icon: Icons.remove_shopping_cart,
              color: Colors.red.shade900,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, Map<String, dynamic> item) {
    final stock = item['currentStock'] as int;
    final isOutOfStock = stock == 0;
    // The store's rule — a third of THIS row's reorder point — not a flat
    // `stock <= 3`. The flat version disagreed with the Critical tile above,
    // so a variant reordering at 20 with 5 left counted as critical but was
    // painted as merely low.
    final isCritical = _alertStore.isCritical(item);

    Color alertColor;
    IconData alertIcon;
    String alertLabel;

    if (isOutOfStock) {
      alertColor = Colors.red.shade900;
      alertIcon = Icons.remove_shopping_cart;
      alertLabel = 'OUT OF STOCK';
    } else if (isCritical) {
      alertColor = AppColors.danger;
      alertIcon = Icons.warning_amber;
      alertLabel = 'CRITICAL';
    } else {
      alertColor = AppColors.warning;
      alertIcon = Icons.info_outline;
      alertLabel = 'LOW STOCK';
    }

    final variantInfo = _buildVariantDescription(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alertColor,
          width: isOutOfStock || isCritical ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: alertColor.withValues(alpha: 0.1),
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
                color: alertColor.withValues(alpha: 0.1),
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
                    style: TextStyle(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (variantInfo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      variantInfo,
                      style: TextStyle(
                        fontSize: AppResponsive.captionFontSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  // Same pill the damaged-goods and purchase-return reports
                  // use, so a severity badge looks the same wherever it appears.
                  AppStatusPill(
                    label: alertLabel,
                    color: alertColor,
                    dense: true,
                  ),
                ],
              ),
            ),
            // Stock Quantity
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: alertColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$stock',
                    style: TextStyle(
                      fontSize: AppResponsive.headingFontSize(context),
                      fontWeight: FontWeight.bold,
                      color: alertColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'in stock',
                  style: TextStyle(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: alertColor.withValues(alpha: 0.7),
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

    // Every configured attribute, not just the three legacy columns.
    final label =
        (item['variantLabel'] as String?) ??
        attributeStore.describeAttributes(
          null,
          size: item['size']?.toString(),
          color: item['color']?.toString(),
          weight: item['weight']?.toString(),
        );
    if (label.isNotEmpty) {
      parts.add(label);
    }
    if (item['barcode'] != null && item['barcode'].toString().isNotEmpty) {
      parts.add('Barcode: ${item['barcode']}');
    }

    return parts.join(' | ');
  }
}
