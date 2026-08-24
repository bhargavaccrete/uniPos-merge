import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/retail_store_types.dart';
import '../../../../util/color.dart';

/// Icon for a [RetailStoreType.iconName].
///
/// The catalogue is pure Dart and stores a string rather than an `IconData`, so
/// the mapping lives here — the same convention `SetupWizardStore.businessTypes`
/// uses. An unknown name falls back to a generic storefront rather than
/// throwing, so adding a type without touching this file still renders.
IconData retailStoreTypeIcon(String iconName) {
  switch (iconName) {
    case 'apparel':
      return Icons.dry_cleaning_rounded;
    case 'footwear':
      return Icons.ice_skating_rounded;
    case 'sports':
      return Icons.sports_tennis_rounded;
    case 'cosmetics':
      return Icons.brush_rounded;
    case 'stationery':
      return Icons.edit_note_rounded;
    case 'gift':
      return Icons.card_giftcard_rounded;
    case 'other':
      return Icons.category_rounded;
    default:
      return Icons.storefront_rounded;
  }
}

/// "What do you sell?" — the retail store-type selector on Store Details.
///
/// Deliberately built the same way as [LocationDropdownField] (Country / State /
/// City on this very screen): a fixed-height field that opens a **dialog**, not
/// a `DropdownButtonFormField`. The raw Material menu drops an unrounded,
/// edge-to-edge overlay across the form, hides the field it belongs to, and has
/// nowhere to show each type's description — the one thing that makes the choice
/// meaningful.
///
/// Validation flows through the surrounding [Form]: the [FormField] reads the
/// external [value] (owned by the wizard store), so `_formKey.validate()` catches
/// an empty selection like every other required field.
class RetailStoreTypeField extends StatelessWidget {
  /// Currently selected key, or null when nothing is chosen. An unknown key (a
  /// type retired in a later build) renders as empty rather than throwing.
  final String? value;

  final ValueChanged<String> onChanged;

  /// Blocks Continue when nothing is picked. Pass false to make it optional.
  final bool required;

  const RetailStoreTypeField({
    super.key,
    required this.value,
    required this.onChanged,
    this.required = true,
  });

  RetailStoreType? get _selected => RetailStoreTypes.byKey(value);

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return FormField<String>(
      // Holds no value of its own — it validates the store's value, so a reset
      // elsewhere can never desync an internal copy.
      validator: (_) => required && selected == null
          ? 'Please choose what you sell'
          : null,
      builder: (field) {
        // Only flag an error while the value is ACTUALLY still empty, so a stale
        // error from a previous Continue clears the moment a type is picked.
        final showError = field.hasError && selected == null;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final picked = await _openPicker(context, selected?.key);
                if (picked != null) {
                  onChanged(picked);
                  field.didChange(picked); // clears any prior error
                }
              },
              child: Container(
                // Same fixed height as the Country/State/City fields below, so
                // the form reads as one set of controls.
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: showError ? Colors.red : AppColors.divider,
                    width: showError ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      retailStoreTypeIcon(selected?.iconName ?? ''),
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        selected?.name ??
                            (required
                                ? 'What do you sell? *'
                                : 'What do you sell?'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: selected == null
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down_rounded,
                        color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            // Error sits BELOW the box, so an error never changes the field's
            // height relative to its neighbours.
            if (showError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 12),
                child: Text(
                  field.errorText!,
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.red),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<String?> _openPicker(BuildContext context, String? selectedKey) {
    return showDialog<String>(
      context: context,
      builder: (_) => _StoreTypePickerDialog(selected: selectedKey),
    );
  }
}

/// Centred picker with an accent header, matching `_LocationPickerDialog` and
/// `AppDialogShell`.
///
/// No search box: there are seven options, so a search field would be noise. Each
/// row carries the type's **description**, which is what tells the shop what the
/// choice actually does.
class _StoreTypePickerDialog extends StatelessWidget {
  final String? selected;

  const _StoreTypePickerDialog({required this.selected});

  @override
  Widget build(BuildContext context) {
    final maxH = (MediaQuery.of(context).size.height * 0.72).clamp(320.0, 560.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 440, maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Accent header: icon badge + title + close
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.storefront_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What do you sell?',
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sets the product fields you start with',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: RetailStoreTypes.all.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: AppColors.divider.withValues(alpha: 0.5),
                ),
                itemBuilder: (context, i) {
                  final type = RetailStoreTypes.all[i];
                  final isSel = type.key == selected;

                  return InkWell(
                    onTap: () => Navigator.pop(context, type.key),
                    child: Container(
                      color: isSel
                          ? AppColors.primary.withValues(alpha: 0.06)
                          : Colors.transparent,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              retailStoreTypeIcon(type.iconName),
                              size: 20,
                              color: isSel
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type.name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14.5,
                                    fontWeight: isSel
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isSel
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  type.description,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSel) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.check_circle_rounded,
                                color: AppColors.primary, size: 20),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
