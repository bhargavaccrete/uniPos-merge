import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/domain/services/common/list_sort_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Presentation for [ListSortOption]. Lives here rather than on the enum so
/// the service stays free of Flutter widget types.
extension ListSortOptionDisplay on ListSortOption {
  /// Shown on the inline button — kept to one short word so the control
  /// stays narrow next to the search field on a phone.
  String get shortLabel {
    switch (this) {
      case ListSortOption.nameAsc:
        return 'A–Z';
      case ListSortOption.nameDesc:
        return 'Z–A';
      case ListSortOption.newest:
        return 'Newest';
      case ListSortOption.oldest:
        return 'Oldest';
    }
  }

  String get label {
    switch (this) {
      case ListSortOption.nameAsc:
        return 'Name (A–Z)';
      case ListSortOption.nameDesc:
        return 'Name (Z–A)';
      case ListSortOption.newest:
        return 'Newest first';
      case ListSortOption.oldest:
        return 'Oldest first';
    }
  }

  String get subtitle {
    switch (this) {
      case ListSortOption.nameAsc:
        return 'Alphabetical, the default';
      case ListSortOption.nameDesc:
        return 'Reverse alphabetical';
      case ListSortOption.newest:
        return 'Most recently added at the top';
      case ListSortOption.oldest:
        return 'Earliest added at the top';
    }
  }

  IconData get icon {
    switch (this) {
      case ListSortOption.nameAsc:
        return Icons.sort_by_alpha_rounded;
      case ListSortOption.nameDesc:
        return Icons.sort_by_alpha_rounded;
      case ListSortOption.newest:
        return Icons.schedule_rounded;
      case ListSortOption.oldest:
        return Icons.history_rounded;
    }
  }
}

/// Bottom sheet for picking a list's sort order.
class ListSortSheet extends StatelessWidget {
  final ListSortOption currentOption;
  final ValueChanged<ListSortOption> onSelected;

  const ListSortSheet({
    super.key,
    required this.currentOption,
    required this.onSelected,
  });

  static Future<ListSortOption?> show(
    BuildContext context, {
    required ListSortOption currentOption,
  }) async {
    ListSortOption? result;
    await showModalBottomSheet(
      context: context,
      // Nearest navigator, matching the other sheets in this folder, so the
      // sheet stays inside a nested pane instead of covering the sidebar.
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => ListSortSheet(
        currentOption: currentOption,
        onSelected: (value) {
          result = value;
          Navigator.pop(sheetContext);
        },
      ),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        28 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle — 4px bar, decorative, so it stays static.
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.swap_vert_rounded,
                  color: AppColors.primary,
                  size: AppResponsive.iconSize(context),
                ),
              ),
              SizedBox(width: AppResponsive.mediumSpacing(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sort by',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.subheadingFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Applies to this list and is remembered',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(context),
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: Colors.grey.shade500),
                splashRadius: 20,
              ),
            ],
          ),
          SizedBox(height: AppResponsive.largeSpacing(context)),

          // ── Options ───────────────────────────────────────────────────
          for (final option in ListSortOption.values) ...[
            _buildOption(context, option),
            if (option != ListSortOption.values.last)
              SizedBox(height: AppResponsive.smallSpacing(context)),
          ],
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, ListSortOption option) {
    final isSelected = currentOption == option;
    return InkWell(
      onTap: () => onSelected(option),
      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.07)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(
            AppResponsive.borderRadius(context),
          ),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(
                  alpha: isSelected ? 0.15 : 0.08,
                ),
                borderRadius: BorderRadius.circular(
                  AppResponsive.borderRadius(context),
                ),
              ),
              child: Icon(
                option.icon,
                color: AppColors.primary,
                size: AppResponsive.iconSize(context),
              ),
            ),
            SizedBox(width: AppResponsive.mediumSpacing(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.primary : Colors.black87,
                    ),
                  ),
                  Text(
                    option.subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, width: 1.5),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The inline sort control that sits beside a list's search field.
///
/// Reads and writes [ListSortService] itself, and **listens to it itself** —
/// a screen drops it into a header row and never threads the value back down.
/// That self-containment matters on the POS menu, whose tree is deliberately
/// split into narrow rebuild boundaries: the screen wraps only its *list* in
/// a `ListenableBuilder`, not the header, and the label still keeps up.
///
/// Sized by the parent `Row`'s `IntrinsicHeight` + `CrossAxisAlignment
/// .stretch`, which matches `AppTextField`'s ~50px height without
/// hardcoding it (`AppTextField` is deliberately not responsive).
class ListSortButton extends StatelessWidget {
  final SortableList list;

  const ListSortButton({super.key, required this.list});

  Future<void> _pick(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final current = ListSortService.instance.optionFor(list);
    final result = await ListSortSheet.show(context, currentOption: current);
    if (result != null) {
      await ListSortService.instance.setOption(list, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ListSortService.instance,
      builder: (context, _) => _button(context),
    );
  }

  Widget _button(BuildContext context) {
    final option = ListSortService.instance.optionFor(list);
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(
            AppResponsive.borderRadius(context),
          ),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_vert_rounded,
              size: AppResponsive.iconSize(context),
              color: AppColors.primary,
            ),
            // Sub-8 gap: this binds the icon to its label as one unit, it is
            // not layout spacing, so the 8px spacing floor doesn't apply.
            const SizedBox(width: 6),
            Text(
              option.shortLabel,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
