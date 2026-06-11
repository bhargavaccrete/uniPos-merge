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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.task_alt_outlined, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Default Selection',
                        style: GoogleFonts.poppins(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                children: groups.map((g) {
                  final multi = g.allowMultipleSelection ?? false;
                  final groupOptionIds = g.choiceOption.map((o) => o.id).toSet();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 2),
                        child: Row(
                          children: [
                            Text(g.name,
                                style: GoogleFonts.poppins(
                                    fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            Text(multi ? 'Multi-select' : 'Single',
                                style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      ...g.choiceOption.map((opt) {
                        final isSel = selected.contains(opt.id);
                        return InkWell(
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
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
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
                                Text(opt.name,
                                    style: GoogleFonts.poppins(fontSize: 14)),
                              ],
                            ),
                          ),
                        );
                      }),
                      const Divider(height: 16),
                    ],
                  );
                }).toList(),
              ),
            ),
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
