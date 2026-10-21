import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/domain/services/retail/expiry_status.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Display format for an expiry date — `dd MMM yyyy`, the dominant read-only
/// date convention across retail reports and detail screens.
final DateFormat kExpiryDateFormat = DateFormat('dd MMM yyyy');

/// Tap-to-pick expiry date field with a clear button.
///
/// Shared by Add/Edit Product and the variant dialogs so all three agree on
/// the picker bounds and the rendered format. There is no generic date-field
/// widget in retail — the two existing date forms hand-roll the same
/// `InkWell` + bordered `Container` + `calendar_today` shape, which this
/// follows.
///
/// **Never free text**: the value can only be set through [showDatePicker].
class ExpiryDateField extends StatelessWidget {
  /// Currently chosen date, or null when the product does not expire.
  final DateTime? value;

  /// Called with the picked date, always normalised to midnight local.
  final ValueChanged<DateTime> onPick;

  /// Called when the user clears the date. Omit to hide the clear button.
  final VoidCallback? onClear;

  final String label;

  const ExpiryDateField({
    super.key,
    required this.value,
    required this.onPick,
    this.onClear,
    this.label = 'Expiry date',
  });

  Future<void> _pick(BuildContext context) async {
    final now = dateOnly(DateTime.now());
    final initial = value ?? now.add(const Duration(days: 7));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      // The past is allowed on purpose: a shop may be recording stock that has
      // ALREADY expired, and refusing it would make the Expired state
      // unreachable from the form.
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: now.add(const Duration(days: 365 * 10)),
      helpText: 'Select expiry date',
    );

    if (picked != null) onPick(dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final status = expiryStatusFor(value);
    final hasValue = value != null;

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _pick(context),
            borderRadius: BorderRadius.circular(
              AppResponsive.smallBorderRadius(context),
            ),
            child: Container(
              padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(
                  AppResponsive.smallBorderRadius(context),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    color: AppColors.textSecondary,
                    size: AppResponsive.iconSize(context),
                  ),
                  SizedBox(width: AppResponsive.mediumSpacing(context)),
                  Expanded(
                    child: Text(
                      hasValue
                          ? '$label: ${kExpiryDateFormat.format(value!)}'
                          : 'Set $label',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        color: hasValue
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  // Surfaced right where the date is set, so an already-expired
                  // or nearly-expired date is obvious before saving.
                  if (hasValue && status.isAlerting)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        status.label,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.captionFontSize(context),
                          fontWeight: FontWeight.w600,
                          color: status.color,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (hasValue && onClear != null)
          IconButton(
            icon: const Icon(Icons.clear_rounded),
            tooltip: 'Clear expiry date',
            color: AppColors.textSecondary,
            onPressed: onClear,
          ),
      ],
    );
  }
}

/// Small severity pill for an expiry status, for list rows and variant rows.
///
/// Renders nothing when the status is not alerting, so callers can drop it in
/// unconditionally without a surrounding `if`.
class ExpiryStatusPill extends StatelessWidget {
  final RetailExpiryStatus status;

  const ExpiryStatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (!status.isAlerting) return const SizedBox.shrink();

    final color = status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.captionFontSize(context),
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
