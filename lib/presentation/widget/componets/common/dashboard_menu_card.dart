import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Navigation tile used on the dashboards (restaurant + retail): white card,
/// tinted icon chip in the module's accent colour, centred title.
///
/// Purely presentational — pass an already-guarded [onTap] if the destination
/// is permission- or entitlement-gated, and an already-reactive [badge] widget
/// if its value is observable.
class DashboardMenuCard extends StatelessWidget {
  final String title;
  final IconData icon;

  /// Accent colour: tints the icon chip background and the icon itself.
  final Color color;

  /// Callers wrap their own guards — this widget never checks permissions.
  final VoidCallback onTap;

  /// Optional overlay pinned to the top-right of the icon chip, e.g. a
  /// [DashboardCardBadge] count. Wrap it in an `Observer` at the call site when
  /// the value is observable.
  final Widget? badge;

  /// Tighter padding/icon/text. Defaults to [AppResponsive.isMobile].
  final bool? compact;

  const DashboardMenuCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge,
    this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = compact ?? AppResponsive.isMobile(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: EdgeInsets.all(isCompact ? 14 : 20),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: isCompact ? 28 : 38, color: color),
                  ),
                  if (badge != null)
                    Positioned(right: -4, top: -4, child: badge!),
                ],
              ),
              SizedBox(height: isCompact ? 10 : 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: isCompact ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Count bubble for [DashboardMenuCard.badge]. Counts above [maxCount] render
/// as "99+".
class DashboardCardBadge extends StatelessWidget {
  final int count;
  final Color color;
  final int maxCount;

  const DashboardCardBadge({
    super.key,
    required this.count,
    this.color = Colors.red,
    this.maxCount = 99,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 1.5),
      ),
      child: Text(
        count > maxCount ? '$maxCount+' : '$count',
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
