import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// A single headline metric rendered as a frosted-glass pill inside a
/// [GradientHeroHeader]. Purely a data holder — the header lays them out.
class HeroStat {
  final IconData icon;
  final String value;
  final String label;

  const HeroStat({required this.icon, required this.value, required this.label});
}

/// A premium gradient banner that sits directly under [buildPrimaryAppBar].
///
/// It starts on [AppColors.primary] so it visually continues the flat app bar,
/// then fades toward [accent], curves its bottom corners, and floats a soft
/// icon medallion plus an optional row of live [stats] pills. This is the
/// signature "eye-catching" surface shared across the inventory suite so every
/// screen opens with the same rich, cohesive header instead of a hard seam.
class GradientHeroHeader extends StatelessWidget {
  /// When null, the icon/title/subtitle row is omitted entirely and the card
  /// shows only [stats] — for a screen whose app bar already carries the title.
  final String? title;
  final String? subtitle;
  final IconData? icon;

  /// Second gradient stop. Defaults to a lighter blue for a subtle sheen; pass
  /// e.g. [AppColors.secondary] to tint a screen toward its module colour, or
  /// [AppColors.primary] for a flat (non-gradient) card.
  final Color accent;

  /// Optional live metric pills laid out in a row beneath the title.
  final List<HeroStat> stats;

  /// Optional trailing widget (e.g. an action button) pinned top-right.
  final Widget? trailing;

  const GradientHeroHeader({
    super.key,
    this.title,
    this.subtitle,
    this.icon,
    this.accent = const Color(0xFF1565C0),
    this.stats = const [],
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final horizontalPad = AppResponsive.getValue(
      context,
      mobile: 18.0,
      tablet: 22.0,
      desktop: 26.0,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(horizontalPad, 18, horizontalPad, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, accent],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Row(
              children: [
                if (icon != null) ...[
                  // Frosted icon medallion.
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.85),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          if (stats.isNotEmpty) ...[
            if (title != null) const SizedBox(height: 18),
            Row(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  Expanded(child: _statPill(stats[i])),
                  if (i != stats.length - 1) const SizedBox(width: 10),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statPill(HeroStat stat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(stat.icon, size: 16, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(height: 8),
          Text(
            stat.value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
