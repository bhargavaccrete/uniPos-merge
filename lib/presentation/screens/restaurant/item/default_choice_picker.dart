import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/choicemodel_306.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart'
    show CommonButton;

/// Bottom sheet to pick which choice OPTIONS are pre-selected (default) for an
/// item. Single-select groups behave like radios (one default); multi-select
/// like checkboxes (any number). Returns the chosen option IDs, or null if
/// dismissed. Shared by Add-More-Info and Edit-Item so the UX is identical.
Future<List<String>?> showDefaultChoicePicker(
  BuildContext context,
  List<String> selectedChoiceIds,
  List<String> currentDefaults,
) async {
  final groups = <ChoicesModel>[];
  for (final id in selectedChoiceIds.toSet()) {
    final g = await choiceStore.getChoiceById(id);
    if (g != null) groups.add(g);
  }
  if (!context.mounted || groups.isEmpty) return null;

  // Drop stale defaults whose option no longer exists in an attached group.
  final validIds = groups.expand((g) => g.choiceOption.map((o) => o.id)).toSet();
  final selected = <String>{...currentDefaults.where(validIds.contains)};

  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grab handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.task_alt_outlined,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Default Selection',
                            style: GoogleFonts.poppins(
                                fontSize: 16.5, fontWeight: FontWeight.w700)),
                        Text('Pre-tick options this item normally comes with',
                            style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                      icon: Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            const Divider(height: 1),

            // Choice groups
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                children: groups.map((g) {
                  final multi = g.allowMultipleSelection ?? false;
                  final groupOptionIds = g.choiceOption.map((o) => o.id).toSet();
                  // Single-select groups use the brand colour; multi-select uses
                  // the secondary colour so the interaction rule is glanceable.
                  final accent = multi ? AppColors.secondary : AppColors.primary;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(g.name,
                                  style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(multi ? 'Multiple' : 'Single',
                                  style: GoogleFonts.poppins(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: accent)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...g.choiceOption.map((opt) {
                          final isSel = selected.contains(opt.id);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => setSheet(() {
                                if (multi) {
                                  isSel
                                      ? selected.remove(opt.id)
                                      : selected.add(opt.id);
                                } else {
                                  // single-select: only one default per group
                                  selected.removeWhere(groupOptionIds.contains);
                                  if (!isSel) selected.add(opt.id);
                                }
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? AppColors.primary.withValues(alpha: 0.08)
                                      : AppColors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSel
                                        ? AppColors.primary
                                        : AppColors.divider,
                                    width: isSel ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      multi
                                          ? (isSel
                                              ? Icons.check_box
                                              : Icons.check_box_outline_blank)
                                          : (isSel
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_unchecked),
                                      color: isSel
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(opt.name,
                                          style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: isSel
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                              color: AppColors.textPrimary)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            // Done button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: CommonButton(
                  onTap: () => Navigator.pop(ctx, selected.toList()),
                  bordercircular: 10,
                  height: AppResponsive.height(context, 0.06),
                  child: Text('Done',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
