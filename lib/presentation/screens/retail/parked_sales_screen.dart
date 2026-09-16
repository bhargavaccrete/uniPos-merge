import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/data/models/retail/hive_model/hold_sale_item_model_210.dart';
import 'package:billberrylite/data/models/retail/hive_model/hold_sale_model_209.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/domain/services/retail/hold_sale_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/row_action_button.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
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
          'Restored to cart — $skipped item(s) skipped (no longer available)',
        );
      } else {
        NotificationService.instance.showSuccess(
          'Parked sale restored to cart',
        );
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
                  padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(
                      AppResponsive.borderRadius(context),
                    ),
                    border: Border.all(color: AppColors.divider, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Total Items', '${holdSale.totalItems}'),
                      SizedBox(height: AppResponsive.smallSpacing(context)),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.divider,
                      ),
                      SizedBox(height: AppResponsive.smallSpacing(context)),
                      _buildDetailRow(
                        'Subtotal',
                        formatMoney(holdSale.subtotal),
                        emphasis: true,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppResponsive.largeSpacing(context)),
                Text(
                  'ITEMS (${items.length})',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.7,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: AppResponsive.smallSpacing(context)),
                ...items.map(_buildDetailItemRow),
              ],
            ),
            actions: [
              appDialogCancelButton(dialogContext, label: 'Close'),
              SizedBox(width: AppResponsive.mediumSpacing(context)),
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
      margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.mediumSpacing(context),
        vertical: AppResponsive.smallSpacing(context),
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider, width: 0.5),
        boxShadow: _cardShadow,
      ),
      child: Row(
        children: [
          // Qty badge — scanning "how many" is faster than reading "3 ×"
          Container(
            width: AppResponsive.smallAvatarSize(context),
            height: AppResponsive.smallAvatarSize(context),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(
                AppResponsive.smallBorderRadius(context),
              ),
            ),
            child: Text(
              '${item.qty}',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          SizedBox(width: AppResponsive.smallSpacing(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@ ${formatMoney(item.price)}',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: AppResponsive.smallSpacing(context)),
          Text(
            formatMoney(item.total),
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
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
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.poppins(
            // 16 → subheading, 13.5 → body, per the snapping table. The
            // ternary is why the standard `fontSize: [0-9]` grep read this
            // file as clean.
            fontSize: emphasis
                ? AppResponsive.subheadingFontSize(context)
                : AppResponsive.bodyFontSize(context),
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
      // MoneyScope: currency/precision changes rebuild every money label.
      body: MoneyScope(
        child: Observer(
          builder: (context) {
            if (holdSaleStore.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
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
                // NOT inside the cap: the band is a background element
                // continuing the AppBar, and the AppBar is full-bleed.
                // Capping it put ~260px of grey either side of it at 1920px,
                // so the primary band floated under a full-width AppBar. It
                // caps its own CONTENT instead — see _buildSummaryCard.
                _buildSummaryCard(context),
                Expanded(
                  child: AppResponsive.constrainedContent(
                    context: context,
                    alignment: Alignment.topCenter,
                    maxWidth: AppResponsive.maxContentWidth(context),
                    child: _buildHoldSalesList(),
                  ),
                ),
              ],
            );
          },
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
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(AppResponsive.largeBorderRadius(context)),
            ),
          ),
          // Cap OUTSIDE the padding, so the band's content starts at the same
          // x as the list's cards below. Padding inside the cap would offset
          // this row by 16px against them.
          child: AppResponsive.constrainedContent(
            context: context,
            alignment: Alignment.topCenter,
            maxWidth: AppResponsive.maxContentWidth(context),
            child: Padding(
              // Horizontal gutter shared with the list below — see PS1: these
              // two must stay equal or the band's content sits off the cards.
              padding: EdgeInsets.symmetric(
                horizontal: AppResponsive.padding(context).left,
                vertical: AppResponsive.largeSpacing(context),
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
                            fontSize: AppResponsive.captionFontSize(context),
                            color: AppColors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppResponsive.mediumSpacing(context)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'TOTAL VALUE',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.captionFontSize(context),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.7,
                          color: AppColors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        formatMoney(holdSaleStore.totalHoldSalesValue),
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.subheadingFontSize(context),
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
          padding: EdgeInsets.fromLTRB(
            AppResponsive.padding(context).left,
            AppResponsive.mediumSpacing(context),
            AppResponsive.padding(context).left,
            AppResponsive.extraLargeSpacing(context),
          ),
          itemCount: holdSales.length,
          separatorBuilder: (_, _) =>
              SizedBox(height: AppResponsive.mediumSpacing(context)),
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
            // Right and bottom stay tight on purpose: the action row's own
            // buttons carry padding, so matching the left/top here would
            // double it. 6 is below the 8px spacing floor and stays static.
            padding: EdgeInsets.fromLTRB(
              AppResponsive.mediumSpacing(context),
              AppResponsive.mediumSpacing(context),
              AppResponsive.smallSpacing(context),
              6,
            ),
            child: Column(
              children: [
                // Identity row — who/when on the left, money on the right
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: AppResponsive.avatarSize(context),
                      height: AppResponsive.avatarSize(context),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          AppResponsive.borderRadius(context),
                        ),
                      ),
                      child: Icon(
                        Icons.pause_circle_outline,
                        color: AppColors.warning,
                        size: AppResponsive.iconSize(context),
                      ),
                    ),
                    SizedBox(width: AppResponsive.mediumSpacing(context)),
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
                              fontSize: AppResponsive.captionFontSize(context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: AppResponsive.smallSpacing(context)),
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 6),
                      child: Text(
                        formatMoney(holdSale.subtotal),
                        maxLines: 1,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.subheadingFontSize(context),
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppResponsive.smallSpacing(context)),
                Divider(height: 1, thickness: 1, color: AppColors.divider),
                // Action row — restore is the primary job of this screen, so it
                // is visible; view/delete stay in the overflow.
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _restoreHoldSale(holdSale),
                      icon: Icon(
                        Icons.play_circle_outline,
                        size: AppResponsive.smallIconSize(context),
                      ),
                      label: Text(
                        'Restore to Cart',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
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
                    // Delete only. 'View Details' left with the menu — tapping
                    // the card already opens the details sheet, so the entry
                    // was a second route to the same place.
                    RowActionButton(
                      icon: Icons.delete_outline_rounded,
                      color: AppColors.danger,
                      tooltip: 'Delete Parked Sale',
                      onTap: () => _deleteHoldSale(holdSale),
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
}
