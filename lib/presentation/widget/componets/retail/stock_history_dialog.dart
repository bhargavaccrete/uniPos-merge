import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

import '../../../../data/models/restaurant/db/stock_movement_model.dart';
import '../../../../domain/services/retail/stock_adjustment_service.dart';

/// Manual stock corrections for one product, newest first.
///
/// Read-only and unsortable on purpose: this is an audit trail. Correcting an
/// entry means recording another adjustment, never editing this list.
class StockHistoryDialog extends StatelessWidget {
  final String productId;
  final String productName;

  const StockHistoryDialog({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  Widget build(BuildContext context) {
    final movements = StockAdjustmentService.historyForProduct(productId);

    return AppDialogShell(
      title: 'Stock History',
      subtitle: productName,
      accent: AppColors.primary,
      icon: Icons.history_rounded,
      body: movements.isEmpty
          ? const AppEmptyState(
              icon: Icons.history_toggle_off_rounded,
              title: 'No adjustments yet',
              message:
                  'Stock has only moved through receipts, sales and returns.',
            )
          : ConstrainedBox(
              // Caps the sheet on a long history instead of letting the dialog
              // grow past the screen.
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: movements.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 12, color: AppColors.divider),
                itemBuilder: (context, i) => _Row(movement: movements[i]),
              ),
            ),
      actions: [appDialogCancelButton(context, label: 'Close')],
    );
  }
}

class _Row extends StatelessWidget {
  final StockMovementModel movement;

  const _Row({required this.movement});

  @override
  Widget build(BuildContext context) {
    final isIn = movement.isIn;
    final color = isIn ? AppColors.success : AppColors.danger;
    final signed = movement.signedQuantity.toInt();
    final before =
        (movement.balanceAfter - movement.signedQuantity).toInt();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isIn ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: AppResponsive.smallIconSize(context),
          color: color,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                movement.reason,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '$before → ${movement.balanceAfter.toInt()} pcs'
                ' • by ${movement.staffName}',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
              if (movement.note?.isNotEmpty ?? false)
                Text(
                  movement.note!,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
              Text(
                DateFormat('dd MMM yyyy, hh:mm a').format(movement.timestamp),
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          isIn ? '+$signed' : '$signed',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
