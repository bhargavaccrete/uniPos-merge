import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// One selectable product-type card's presentation.
typedef ProductTypeOption = ({
  String type,
  IconData icon,
  Color color,
  String label,
  String desc,
});

/// The four Product Type cards, shared by the quick-add sheet and the full
/// item editor.
///
/// This used to live privately inside `add_item_sheet.dart` while
/// `edit_item.dart` used the legacy `Dropdown` component — so the same
/// decision looked like two different controls depending on where you made
/// it, and only one of them explained what the types mean. Extracted here for
/// the same reason [CategorySelectorButton], [InventoryToggle] and
/// [SellingMethodButton] live in this folder: Add and Edit must not drift.
///
/// Renders the cards only — each screen supplies its own section header, so
/// the control drops into either layout without fighting it.
class ProductTypeSelector extends StatelessWidget {
  /// Current value, e.g. [ProductType.finishedGood]. A null/unknown stored
  /// type reads as Finished Good via [ProductType.effective], matching how
  /// the rest of the app treats legacy items.
  final String selectedType;

  final ValueChanged<String> onChanged;

  /// Shows the "save first, then build the recipe" note under the cards when
  /// a recipe-bearing type is picked. The quick-add sheet sets this (it has
  /// no recipe builder); the full editor leaves it off because it shows the
  /// real builder inline instead.
  final bool showRecipeHint;

  const ProductTypeSelector({
    super.key,
    required this.selectedType,
    required this.onChanged,
    this.showRecipeHint = false,
  });

  static const List<ProductTypeOption> options = [
    (
      type: ProductType.finishedGood,
      icon: Icons.inventory_2_rounded,
      color: AppColors.info,
      label: 'Finished Good',
      desc: 'Ready to sell as-is',
    ),
    (
      type: ProductType.recipeBased,
      icon: Icons.lunch_dining_rounded,
      color: AppColors.accent,
      label: 'Recipe-Based',
      desc: 'Assembled from a recipe when sold',
    ),
    (
      type: ProductType.rawMaterial,
      icon: Icons.grass_rounded,
      color: AppColors.success,
      label: 'Raw Material',
      desc: 'Ingredient — bought & stocked',
    ),
    (
      type: ProductType.semiFinished,
      icon: Icons.soup_kitchen_rounded,
      color: AppColors.secondary,
      label: 'Semi-Finished',
      desc: 'Prepped in batches',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final effective = ProductType.effective(selectedType);
    final hasRecipe = ProductType.hasRecipe(effective);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 10.0;
            final cardWidth = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: options
                  .map(
                    (o) => SizedBox(
                      width: cardWidth,
                      child: _card(context, o, effective),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        if (showRecipeHint && hasRecipe) ...[
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.12),
                  AppColors.accent.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(
                AppResponsive.borderRadius(context),
              ),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: AppResponsive.smallIconSize(context),
                  color: AppColors.accent,
                ),
                SizedBox(width: AppResponsive.smallSpacing(context)),
                Expanded(
                  child: Text(
                    'Save the item first, then open it to build its recipe '
                    '(ingredients, yield & live food cost).',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _card(BuildContext context, ProductTypeOption o, String effective) {
    final bool selected = effective == o.type;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        onTap: () => onChanged(o.type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: selected
                ? o.color.withValues(alpha: 0.10)
                : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(
              AppResponsive.borderRadius(context),
            ),
            border: Border.all(
              color: selected ? o.color : AppColors.divider,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: o.color.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          o.color,
                          Color.lerp(o.color, Colors.black, 0.2) ?? o.color,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(o.icon, size: 15, color: Colors.white),
                  ),
                  const Spacer(),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: AppResponsive.smallIconSize(context),
                    color: selected ? o.color : AppColors.divider,
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                o.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  fontWeight: FontWeight.w700,
                  color: selected ? o.color : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                o.desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  height: 1.25,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
