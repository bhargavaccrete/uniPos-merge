import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/restaurant_store_types.dart';
import '../../../../util/color.dart';
import '../../../../util/common/app_responsive.dart';

/// Icon for a [RestaurantStoreType.iconName].
///
/// The catalogue is pure Dart and stores a string rather than an `IconData`, so
/// the mapping lives here (mirrors `retailStoreTypeIcon`). An unknown name
/// falls back to a generic restaurant glyph rather than throwing, so adding a
/// type without touching this file still renders.
IconData restaurantStoreTypeIcon(String iconName) {
  switch (iconName) {
    case 'cafe':
      return Icons.local_cafe_rounded;
    case 'qsr':
      return Icons.lunch_dining_rounded;
    case 'restaurant':
      return Icons.restaurant_rounded;
    case 'food_truck':
      return Icons.local_shipping_rounded;
    case 'food_cart':
      return Icons.storefront_rounded;
    case 'other':
      return Icons.category_rounded;
    default:
      return Icons.restaurant_menu_rounded;
  }
}

/// "What kind of restaurant?" — the restaurant store-type selector on Store
/// Details. Mirrors [RetailStoreTypeField] exactly (fixed-height field that
/// opens a dialog; validation flows through the surrounding [Form] via a
/// [FormField] that reads the external [value] owned by the wizard store).
class RestaurantStoreTypeField extends StatelessWidget {
  /// Currently selected key, or null when nothing is chosen. An unknown key (a
  /// type retired in a later build) renders as empty rather than throwing.
  final String? value;

  final ValueChanged<String> onChanged;

  /// Blocks Continue when nothing is picked. Pass false to make it optional.
  final bool required;

  const RestaurantStoreTypeField({
    super.key,
    required this.value,
    required this.onChanged,
    this.required = true,
  });

  RestaurantStoreType? get _selected => RestaurantStoreTypes.byKey(value);

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return FormField<String>(
      validator: (_) => required && selected == null
          ? 'Please choose your restaurant type'
          : null,
      builder: (field) {
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
                      restaurantStoreTypeIcon(selected?.iconName ?? ''),
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        selected?.name ??
                            (required
                                ? 'What kind of restaurant? *'
                                : 'What kind of restaurant?'),
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
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
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
      builder: (_) => _RestaurantTypePickerDialog(selected: selectedKey),
    );
  }
}

/// Centred picker with an accent header, matching the retail store-type dialog.
/// Each row carries the type's description.
class _RestaurantTypePickerDialog extends StatelessWidget {
  final String? selected;

  const _RestaurantTypePickerDialog({required this.selected});

  @override
  Widget build(BuildContext context) {
    final maxH = (MediaQuery.of(context).size.height * 0.72).clamp(
      320.0,
      560.0,
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: AppResponsive.dialogWidth(context),
          maxHeight: maxH,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.restaurant_menu_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What kind of restaurant?',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.getValue(
                              context,
                              mobile: 17.0,
                              tablet: 18.0,
                              desktop: 20.0,
                            ),
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Helps tailor your setup',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: RestaurantStoreTypes.all.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: AppColors.divider.withValues(alpha: 0.5),
                ),
                itemBuilder: (context, i) {
                  final type = RestaurantStoreTypes.all[i];
                  final isSel = type.key == selected;

                  return InkWell(
                    onTap: () => Navigator.pop(context, type.key),
                    child: Container(
                      color: isSel
                          ? AppColors.primary.withValues(alpha: 0.06)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
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
                              restaurantStoreTypeIcon(type.iconName),
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
                                    fontSize: AppResponsive.bodyFontSize(
                                      context,
                                    ),
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
                                    fontSize: AppResponsive.smallFontSize(
                                      context,
                                    ),
                                    color: AppColors.textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSel) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
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
