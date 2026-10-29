import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Building blocks for the Settings screens of BOTH verticals.
///
/// Lifted unchanged from the restaurant Settings screen's private helpers so
/// restaurant and retail render settings with one grouped-card look: a
/// [SettingsSectionHeader] above a [SettingsGroupCard] whose rows are
/// [SettingsNavTile] / [SettingsSwitchTile] / [SettingsExpandableTile],
/// separated by [SettingsTileDivider]. Presentational only — permission and
/// entitlement checks stay at the call site.

class SettingsSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const SettingsSectionHeader({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppResponsive.smallSpacing(context),
        bottom: AppResponsive.smallSpacing(context),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(
                AppResponsive.smallBorderRadius(context),
              ),
            ),
            child: Icon(
              icon,
              size: AppResponsive.smallIconSize(context),
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// One rounded card holding a group of related rows.
class SettingsGroupCard extends StatelessWidget {
  final List<Widget> children;

  const SettingsGroupCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final radius = AppResponsive.borderRadius(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: AppResponsive.shadowBlurRadius(context),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Column(children: children),
      ),
    );
  }
}

/// Header + card + trailing gap — one Settings section. Renders nothing when
/// [children] is empty, so a section whose rows are all gated away vanishes
/// instead of leaving an empty card under its heading.
class SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const SettingsTileDivider());
      rows.add(children[i]);
    }
    return Padding(
      padding: EdgeInsets.only(bottom: AppResponsive.largeSpacing(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSectionHeader(title: title, icon: icon),
          SettingsGroupCard(children: rows),
        ],
      ),
    );
  }
}

class SettingsTileDivider extends StatelessWidget {
  const SettingsTileDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: AppColors.divider, indent: 56);
}

/// Tinted rounded icon used as the leading element of every row.
class SettingsTileIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const SettingsTileIcon({super.key, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
      ),
      child: Icon(icon, size: AppResponsive.iconSize(context), color: color),
    );
  }
}

/// Title + subtitle column shared by every row type.
class _TileText extends StatelessWidget {
  final String title;
  final Widget subtitle;

  const _TileText({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        DefaultTextStyle.merge(
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            color: AppColors.textSecondary,
          ),
          child: subtitle,
        ),
      ],
    );
  }
}

/// Row that opens another screen or dialog. [trailing] defaults to a chevron.
class SettingsNavTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final Widget? trailing;

  const SettingsNavTile({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    required this.icon,
    required this.color,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.largeSpacing(context),
          vertical: AppResponsive.mediumSpacing(context),
        ),
        child: Row(
          children: [
            SettingsTileIcon(icon: icon, color: color),
            SizedBox(width: AppResponsive.mediumSpacing(context)),
            Expanded(
              child: _TileText(
                title: title,
                subtitle: subtitleWidget ?? Text(subtitle ?? ''),
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  size: AppResponsive.iconSize(context),
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
          ],
        ),
      ),
    );
  }
}

/// On/off row. When [expandedChild] is given and the switch is on, it shows
/// under a divider — e.g. Round Off's step chips.
class SettingsSwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? expandedChild;

  const SettingsSwitchTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.value,
    required this.onChanged,
    this.expandedChild,
  });

  @override
  Widget build(BuildContext context) {
    final tint = value ? color : AppColors.textSecondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppResponsive.largeSpacing(context),
            vertical: AppResponsive.smallSpacing(context) * 0.5,
          ),
          secondary: SettingsTileIcon(icon: icon, color: tint),
          title: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
          value: value,
          activeThumbColor: AppColors.primary,
          onChanged: onChanged,
        ),
        if (value && expandedChild != null) ...[
          const SettingsTileDivider(),
          SettingsExpandedBody(child: expandedChild!),
        ],
      ],
    );
  }
}

/// Padding used under a row for its inline controls.
class SettingsExpandedBody extends StatelessWidget {
  final Widget child;

  const SettingsExpandedBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppResponsive.largeSpacing(context),
        AppResponsive.mediumSpacing(context),
        AppResponsive.largeSpacing(context),
        AppResponsive.mediumSpacing(context),
      ),
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }
}

/// Row that toggles inline controls open below it. Owns its expanded state.
class SettingsExpandableTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget expandedChild;

  const SettingsExpandableTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.expandedChild,
  });

  @override
  State<SettingsExpandableTile> createState() => _SettingsExpandableTileState();
}

class _SettingsExpandableTileState extends State<SettingsExpandableTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SettingsNavTile(
          title: widget.title,
          subtitle: widget.subtitle,
          icon: widget.icon,
          color: widget.color,
          onTap: () => setState(() => _expanded = !_expanded),
          trailing: Icon(
            _expanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            size: AppResponsive.iconSize(context),
            color: AppColors.textSecondary,
          ),
        ),
        if (_expanded) ...[
          Divider(height: 1, color: AppColors.divider),
          SettingsExpandedBody(child: widget.expandedChild),
        ],
      ],
    );
  }
}

/// Selectable chip for short option lists. Filled in primary when selected.
class SettingsOptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const SettingsOptionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A [Wrap] of [SettingsOptionChip]s for one value picked from [options].
class SettingsChipGroup<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  const SettingsChipGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          SettingsOptionChip(
            label: o.$2,
            selected: o.$1 == selected,
            onTap: () => onSelected(o.$1),
          ),
      ],
    );
  }
}

/// Radio-style row for option lists inside a dialog (currency picker).
class SettingsOptionRow extends StatelessWidget {
  final String label;
  final String? sublabel;
  final bool selected;
  final VoidCallback onTap;

  const SettingsOptionRow({
    super.key,
    required this.label,
    this.sublabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: AppResponsive.smallIconSize(context),
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                SizedBox(width: AppResponsive.mediumSpacing(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (sublabel != null)
                        Text(
                          sublabel!,
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.captionFontSize(context),
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
