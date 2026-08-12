import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/data/models/retail/hive_model/hold_sale_item_model_210.dart';
import 'package:billberrylite/data/models/retail/hive_model/hold_sale_model_209.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/domain/services/retail/hold_sale_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import '../../../core/di/service_locator.dart';

/// House card elevation — same soft lift [ReportCard]/[ReportSummaryCard] use.
const List<BoxShadow> _cardShadow = [
  BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
];

class ParkedSalesScreen extends StatefulWidget {
  const ParkedSalesScreen({super.key});

  @override
  State<ParkedSalesScreen> createState() => _ParkedSalesScreenState();
}

class _ParkedSalesScreenState extends State<ParkedSalesScreen> {
  @override
  void initState() {
    super.initState();
    holdSaleStore.loadHoldSales();
  }

  /// Money string honouring the store's currency + decimal-precision settings.
  String _money(double amount) => CurrencyHelper.formatAmountWithSymbol(
        amount,
        CurrencyHelper.currentSymbol,
        decimalPlaces: DecimalSettings.precision,
      );

  String _formatDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _restoreHoldSale(HoldSaleModel holdSale) async {
    try {
      final skipped = await HoldSaleService.restore(holdSale);

      if (mounted) {
        Navigator.pop(context, true);
      }
      if (skipped > 0) {
        NotificationService.instance.showWarning(
            'Restored to cart — $skipped item(s) skipped (no longer available)');
      } else {
        NotificationService.instance
            .showSuccess('Parked sale restored to cart');
      }
    } catch (e) {
      NotificationService.instance.showError('Error restoring sale: $e');
    }
  }

  Future<void> _deleteHoldSale(HoldSaleModel holdSale) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete Parked Sale',
      message:
          'Are you sure you want to delete this parked sale? This action cannot be undone.',
      confirmLabel: 'Delete',
      accent: AppColors.danger,
      icon: Icons.delete_outline_rounded,
    );

    if (confirmed) {
      try {
        await holdSaleStore.deleteHoldSale(holdSale.holdSaleId);
        NotificationService.instance.showSuccess('Parked sale deleted');
      } catch (e) {
        NotificationService.instance.showError('Error deleting sale: $e');
      }
    }
  }

  Future<void> _showHoldSaleDetails(HoldSaleModel holdSale) async {
    await holdSaleStore.selectHoldSale(holdSale);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => Observer(
        builder: (dialogContext) {
          final items = holdSaleStore.currentHoldSaleItems;

          return AppDialogShell(
            title: holdSale.note ?? 'Parked Sale',
            subtitle: 'Parked ${_formatDate(holdSale.createdAt)}',
            accent: AppColors.warning,
            icon: Icons.pause_circle_outline,
            body: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Totals block — the two numbers that decide whether to restore
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(
                          'Total Items', '${holdSale.totalItems}'),
                      const SizedBox(height: 8),
                      Divider(height: 1, thickness: 1, color: AppColors.divider),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        'Subtotal',
                        _money(holdSale.subtotal),
                        emphasis: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'ITEMS (${items.length})',
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.7,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                ...items.map(_buildDetailItemRow),
              ],
            ),
            actions: [
              appDialogCancelButton(dialogContext, label: 'Close'),
              const SizedBox(width: 12),
              appDialogPrimaryButton(
                label: 'Restore',
                color: AppColors.success,
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _restoreHoldSale(holdSale);
                },
              ),
            ],
          );
        },
      ),
    ).then((_) => holdSaleStore.clearSelection());
  }

  Widget _buildDetailItemRow(HoldSaleItemModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.5),
        boxShadow: _cardShadow,
      ),
      child: Row(
        children: [
          // Qty badge — scanning "how many" is faster than reading "3 ×"
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${item.qty}',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@ ${_money(item.price)}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _money(item.total),
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool emphasis = false}) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: emphasis ? 16 : 13.5,
            fontWeight: emphasis ? FontWeight.w700 : FontWeight.w600,
            color: emphasis ? AppColors.success : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'Parked Sales'),
      // Currency/precision changes rebuild every money label on this screen.
      body: ValueListenableBuilder<String>(
        valueListenable: CurrencyHelper.currencyNotifier,
        builder: (context, _, _) => ValueListenableBuilder<int>(
          valueListenable: DecimalSettings.precisionNotifier,
          builder: (context, _, _) => Observer(
            builder: (context) {
              if (holdSaleStore.isLoading) {
                return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary));
              }

              if (holdSaleStore.holdSaleCount == 0) {
                return const AppEmptyState(
                  icon: Icons.pause_circle_outline,
                  title: 'No parked sales',
                  message:
                      'Sales you hold from the billing screen will appear here.',
                );
              }

              return Column(
                children: [
                  _buildSummaryCard(context),
                  Expanded(child: _buildHoldSalesList()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Header band, not a card — it reads as an extension of the app bar so it
  /// can never be mistaken for one of the parked-sale cards below it.
  Widget _buildSummaryCard(BuildContext context) {
    return Observer(
      builder: (context) {
        final count = holdSaleStore.holdSaleCount;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      count == 1 ? '1 Parked Sale' : '$count Parked Sales',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.subheadingFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Waiting to be settled',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: AppColors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TOTAL VALUE',
                    style: GoogleFonts.poppins(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.7,
                      color: AppColors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _money(holdSaleStore.totalHoldSalesValue),
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.subheadingFontSize(context) + 1,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHoldSalesList() {
    return Observer(
      builder: (context) {
        final holdSales = holdSaleStore.holdSales;

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: holdSales.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) =>
              _buildHoldSaleCard(context, holdSales[index]),
        );
      },
    );
  }

  Widget _buildHoldSaleCard(BuildContext context, HoldSaleModel holdSale) {
    final radius = BorderRadius.circular(AppResponsive.borderRadius(context));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: radius,
        border: Border.all(color: AppColors.divider, width: 0.5),
        boxShadow: _cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: () => _showHoldSaleDetails(holdSale),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 6),
            child: Column(
              children: [
                // Identity row — who/when on the left, money on the right
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.pause_circle_outline,
                          color: AppColors.warning, size: 21),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            holdSale.note ?? 'Parked Sale',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.bodyFontSize(context),
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${holdSale.totalItems} items  ·  ${_formatDate(holdSale.createdAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 6),
                      child: Text(
                        _money(holdSale.subtotal),
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context) + 2,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(height: 1, thickness: 1, color: AppColors.divider),
                // Action row — restore is the primary job of this screen, so it
                // is visible; view/delete stay in the overflow.
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _restoreHoldSale(holdSale),
                      icon: const Icon(Icons.play_circle_outline, size: 18),
                      label: Text(
                        'Restore to Cart',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 38),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert,
                          color: AppColors.textSecondary, size: 20),
                      tooltip: 'Options',
                      // M3 tints menu surfaces lavender by default — pin it
                      // to white so it matches the cards.
                      color: AppColors.white,
                      surfaceTintColor: AppColors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.divider),
                      ),
                      onSelected: (value) {
                        if (value == 'delete') {
                          _deleteHoldSale(holdSale);
                        } else if (value == 'details') {
                          _showHoldSaleDetails(holdSale);
                        }
                      },
                      itemBuilder: (context) => [
                        _menuItem('details', Icons.info_outline, 'View Details',
                            AppColors.info),
                        _menuItem('delete', Icons.delete_outline, 'Delete',
                            AppColors.danger),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label, Color color) {
    return PopupMenuItem<String>(
      value: value,
      height: 44,
      child: Row(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
