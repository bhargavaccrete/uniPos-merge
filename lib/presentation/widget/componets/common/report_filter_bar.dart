import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// One selectable period on a [ReportFilterBar].
///
/// A [locked] option is still rendered and still tappable — tapping runs
/// [onLockedTap] (an upgrade sheet) instead of selecting it. That is the app's
/// "show, then block" model; hiding it would leave the user unaware it exists.
class ReportFilterOption<T> {
  final T value;
  final String label;
  final IconData icon;
  final bool locked;
  final VoidCallback? onLockedTap;

  const ReportFilterOption({
    required this.value,
    required this.label,
    required this.icon,
    this.locked = false,
    this.onLockedTap,
  });
}

/// The period selector every report shares. Generic over the screen's own
/// period enum. [trailing] takes screen-specific controls (a month/year
/// dropdown, say) that scroll alongside the buttons.
class ReportFilterBar<T> extends StatelessWidget {
  final List<ReportFilterOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final List<Widget> trailing;

  const ReportFilterBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.trailing = const [],
  });

  @override
  Widget build(BuildContext context) {
    final gap = AppResponsive.horizontalSpace(context, size: SpacingSize.small);
    final children = <Widget>[];

    for (final option in options) {
      if (children.isNotEmpty) children.add(gap);
      children.add(_ReportFilterButton(
        label: option.label,
        icon: option.icon,
        selected: selected == option.value && !option.locked,
        locked: option.locked,
        onPressed: () {
          if (option.locked) {
            option.onLockedTap?.call();
            return;
          }
          onSelected(option.value);
        },
      ));
    }
    for (final widget in trailing) {
      children.add(gap);
      children.add(widget);
    }

    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: AppResponsive.horizontalPadding(context).copyWith(top: 12, bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: children),
      ),
    );
  }
}

class _ReportFilterButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool locked;
  final VoidCallback onPressed;

  const _ReportFilterButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.locked,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(locked ? Icons.lock_outline : icon,
          size: AppResponsive.smallIconSize(context)),
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.smallFontSize(context),
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.getValue(context, mobile: 16.0, tablet: 20.0),
          vertical: AppResponsive.getValue(context, mobile: 12.0, tablet: 14.0),
        ),
        backgroundColor: selected ? AppColors.primary : AppColors.white,
        foregroundColor: selected
            ? AppColors.white
            : (locked ? AppColors.textSecondary : AppColors.textPrimary),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.divider,
            width: 1,
          ),
        ),
      ),
    );
  }
}
