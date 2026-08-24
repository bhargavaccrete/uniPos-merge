import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/domain/services/retail/exchange_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// The money block of an exchange: what is going back, what is coming out, and
/// the difference between them.
///
/// Renders only — every figure comes from [ExchangeQuote], which the service
/// produced. It must never compute a total of its own, or the screen could show
/// something other than what gets written.
class ExchangeSummaryCard extends StatelessWidget {
  final ExchangeQuote quote;

  const ExchangeSummaryCard({super.key, required this.quote});

  @override
  Widget build(BuildContext context) {
    // Green when money comes in, amber when it goes out, neutral when even.
    final accent = quote.customerPays
        ? AppColors.success
        : quote.customerRefunded
            ? AppColors.warning
            : AppColors.textSecondary;

    return Container(
      margin: AppResponsive.padding(context),
      padding: AppResponsive.padding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line(
            context,
            label: 'Returning',
            // The HISTORICAL charged amount, not today's catalogue price.
            value: formatMoney(quote.returnValue),
          ),
          _line(
            context,
            label: 'Replacement',
            value: formatMoney(quote.replacementValue),
          ),
          if (quote.appliedToDue > 0) ...[
            const Divider(height: 20),
            _line(
              context,
              label: 'Off outstanding due',
              value: formatMoney(quote.appliedToDue),
              color: AppColors.warning,
              // Spelled out because the cashier must not expect to hand this
              // back as cash — it cancels a debt instead.
              caption: 'Reduces what the customer owes',
            ),
          ],
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _differenceLabel,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatMoney(quote.differenceAmount),
                    maxLines: 1,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.getValue(
                        context,
                        mobile: 26.0,
                        tablet: 30.0,
                        desktop: 34.0,
                      ),
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _differenceLabel {
    if (quote.customerPays) return 'Customer Pays';
    if (quote.customerRefunded) return 'Customer Receives';
    return 'No Difference';
  }

  Widget _line(
    BuildContext context, {
    required String label,
    required String value,
    Color? color,
    String? caption,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (caption != null)
            Text(
              caption,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
