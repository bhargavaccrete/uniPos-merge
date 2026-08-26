import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/domain/services/retail/expiry_alert_service.dart';
import 'package:billberrylite/domain/services/retail/expiry_status.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_status_pill.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_row.dart';
import 'package:billberrylite/presentation/widget/componets/retail/expiry_date_field.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

import '../../../core/di/service_locator.dart';

/// Products at or near their expiry date.
///
/// Mirrors [StockAlertsScreen] deliberately — same summary band, same pill,
/// same empty state — so the two alert destinations feel identical.
///
/// **The list is DERIVED, never stored.** It is recomputed from live variant
/// data on every build, which is what makes the alert rules hold with no
/// bookkeeping: re-opening the screen cannot produce a duplicate, editing an
/// expiry date is simply reflected next build, and clearing one drops the row.
/// The whole body sits in an `Observer` over `productStore`, so a save
/// elsewhere repaints this immediately.
class ExpiryAlertsScreen extends StatelessWidget {
  const ExpiryAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'Expiry Alerts'),
      body: SafeArea(
        child: Observer(
          builder: (_) {
            // Touch the observable collections so MobX re-runs this builder
            // when a product or variant changes.
            productStore.products.length;
            productStore.variants.length;

            final summary = ExpiryAlertService.getExpirySummary();
            final items = summary['items'] as List<Map<String, dynamic>>;

            if (items.isEmpty) {
              return const AppEmptyState(
                icon: Icons.check_circle,
                title: 'Nothing expiring',
                message:
                    'No product is expired or expiring within $kExpiryWarningDays days.',
              );
            }

            return Column(
              children: [
                _buildSummarySection(context, summary),
                Expanded(
                  child: ListView.builder(
                    padding: AppResponsive.padding(context),
                    itemCount: items.length,
                    itemBuilder: (context, index) =>
                        _buildAlertCard(context, items[index]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummarySection(
    BuildContext context,
    Map<String, dynamic> summary,
  ) {
    return Container(
      padding: AppResponsive.padding(context),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: ReportSummaryRow(
        cards: [
          ReportSummaryCard(
            title: 'Total Alerts',
            value: '${summary['totalAlerts']}',
            icon: Icons.notifications_active,
            color: AppColors.primary,
          ),
          ReportSummaryCard(
            title: 'Expired',
            value: '${summary['expiredCount']}',
            icon: Icons.event_busy,
            color: AppColors.danger,
          ),
          ReportSummaryCard(
            title: 'Expiring Soon',
            value: '${summary['expiringSoonCount']}',
            icon: Icons.hourglass_bottom,
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, Map<String, dynamic> item) {
    final status = item['status'] as RetailExpiryStatus;
    final color = status.color;
    final expiry = DateTime.tryParse(item['expiryDate'] as String? ?? '');
    final daysUntil = item['daysUntil'] as num;
    // `num`, never `int` — a loose-goods variant carries a fractional stock.
    final stock = (item['currentStock'] as num?)?.toDouble() ?? 0;
    final unit = item['unit'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: AppResponsive.padding(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['productName'] as String? ?? 'Product',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_variantDescription(item).isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _variantDescription(item),
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  AppStatusPill(
                    label: status.label,
                    color: color,
                    dense: true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (expiry != null)
                  Text(
                    kExpiryDateFormat.format(expiry),
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  _relativeLabel(daysUntil),
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${formatQty(stock)}${unit == null ? '' : ' $unit'} in stock',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// "3 days left" / "Today" / "5 days ago", from the row's signed day count.
  String _relativeLabel(num daysUntil) {
    if (daysUntil == 0) return 'Today';
    if (daysUntil < 0) {
      final d = daysUntil.abs().toInt();
      return d == 1 ? '1 day ago' : '$d days ago';
    }
    final d = daysUntil.toInt();
    return d == 1 ? '1 day left' : '$d days left';
  }

  String _variantDescription(Map<String, dynamic> item) {
    final parts = <String>[];
    final label = item['variantLabel'] as String?;
    if (label != null && label.isNotEmpty) parts.add(label);
    final barcode = item['barcode'] as String?;
    if (barcode != null && barcode.isNotEmpty) parts.add('Barcode: $barcode');
    return parts.join('  ·  ');
  }
}
