import 'package:flutter/material.dart';

import 'package:billberrylite/util/common/app_responsive.dart';

/// Compact square icon button for per-row secondary actions (Rename, Delete,
/// Print Label…) on list rows and cards.
///
/// Retail's category, product and variant rows all show their actions as
/// visible buttons rather than an overflow menu, so the affordance lives here
/// once instead of being re-declared in each screen. Chips and other dense
/// micro-elements keep their long-press menus — this is for full-width rows.
class RowActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;

  /// Long-press/hover label. Also the accessibility label, so write it as the
  /// action ('Rename'), not the icon ('pencil').
  final String tooltip;

  /// Null disables the button and fades it, for callers that want to keep the
  /// row's layout stable when an action is unavailable.
  final VoidCallback? onTap;

  const RowActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  /// Horizontal room a pair of these needs, gap included — so a row can budget
  /// for its actions before laying out the text beside them.
  static double pairWidth(BuildContext context) => _size(context) * 2 + 6;

  /// Deliberately smaller on phones. Two of these sit at the end of rows that
  /// also carry a name, a detail line and a price; at a fixed 34 they ate
  /// enough width on a ~360dp screen to ellipsize the detail line away.
  static double _size(BuildContext context) =>
      AppResponsive.isMobile(context) ? 30 : 34;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final size = _size(context);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withValues(alpha: enabled ? 0.1 : 0.04),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: size * 0.47,
            color: enabled ? color : color.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
