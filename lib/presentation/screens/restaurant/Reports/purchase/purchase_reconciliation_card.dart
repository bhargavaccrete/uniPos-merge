import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_card.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// The Billed → Credit → Net Cost reconciliation, shown on both the GRN report
/// and Purchase Summary.
///
/// It exists because five different money figures live in this module and it
/// is very easy to read one as another:
///
/// ```
/// Billed Value            what the supplier invoiced, damage included
///   less Supplier Credit  a return credit note, or a settled claim
///   = Net Cost            what the business actually bore
///   less Accepted Value   the goods that reached the shelf
///   = Unrecovered damage  paid for, never recovered
/// ```
///
/// **Damage is never netted out of the bill.** A damaged unit is invoiced like
/// any other and recovered afterwards — or absorbed. Spelling the subtraction
/// out is the whole point: a single "Purchases" number hides whether damage
/// was recovered, and that is the question this card exists to answer.
///
/// One widget rather than two so the two screens can never state the identity
/// differently.
class PurchaseReconciliationCard extends StatelessWidget {
  final double billed;
  final double accepted;
  final double recovered;

  /// Documented write-offs only — a rejected claim or a write-off at receipt.
  final double absorbed;

  /// Damage neither recovered nor formally written off. A cancelled return
  /// leaves exactly this: real cost, no paperwork deciding whose it is.
  final double unrecovered;

  /// Raised but not yet settled — shown as a footnote, since it has not
  /// changed what anything cost yet.
  final double expected;

  const PurchaseReconciliationCard({
    super.key,
    required this.billed,
    required this.accepted,
    required this.recovered,
    required this.absorbed,
    required this.unrecovered,
    this.expected = 0,
  });

  @override
  Widget build(BuildContext context) {
    final netCost = billed - recovered;

    return ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: AppResponsive.smallIconSize(context),
                color: AppColors.primary,
              ),
              SizedBox(width: AppResponsive.smallSpacing(context)),
              Text(
                'Purchase Reconciliation',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          _line(
            context,
            'Billed Value',
            billed,
            note: 'invoiced, damage included',
          ),
          _line(
            context,
            'less Supplier Credit',
            -recovered,
            note: 'credit notes & settled claims',
          ),
          const Divider(height: 18, color: AppColors.divider),
          _line(context, 'Net Cost', netCost, bold: true),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          _line(
            context,
            'less Accepted Value',
            -accepted,
            note: 'reached the shelf',
          ),
          const Divider(height: 18, color: AppColors.divider),
          _line(
            context,
            'Unrecovered damage',
            unrecovered,
            bold: true,
            danger: unrecovered > 0,
          ),
          if (absorbed > 0 || expected > 0) ...[
            SizedBox(height: AppResponsive.smallSpacing(context)),
            Text(
              [
                if (absorbed > 0)
                  'Written off: ${formatMoney(absorbed)}',
                // The difference matters: absorbed is a decision on record,
                // the remainder is damage nobody has decided about yet.
                if (unrecovered - absorbed > 0.004)
                  'Awaiting a decision: '
                      '${formatMoney(unrecovered - absorbed)}',
                if (expected > 0)
                  'Claimed, not yet credited: ${formatMoney(expected)}',
              ].join('  ·  '),
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(
    BuildContext context,
    String label,
    double amount, {
    String? note,
    bool bold = false,
    bool danger = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (note != null)
                  Text(
                    note,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            formatMoney(amount),
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: danger ? AppColors.danger : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
