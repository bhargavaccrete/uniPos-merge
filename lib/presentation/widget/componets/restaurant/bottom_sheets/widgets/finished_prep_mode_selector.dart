import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// How a Finished item is prepared — shared by the quick-add sheet and the
/// full item editor, next to [ProductTypeSelector], so Add and Edit cannot
/// drift. Presentational: callers apply the stock defaults.
///
/// Made to order owns no stock (a sale uses its recipe, if any); made in
/// advance sells prepared stock and may "make fresh when out".
class FinishedPrepModeSelector extends StatelessWidget {
  /// [ProductType.madeToOrder] or [ProductType.madeInAdvance].
  final String prepMode;
  final ValueChanged<String> onPrepModeChanged;
  final bool makeFreshWhenOut;
  final ValueChanged<bool> onMakeFreshChanged;

  const FinishedPrepModeSelector({
    super.key,
    required this.prepMode,
    required this.onPrepModeChanged,
    required this.makeFreshWhenOut,
    required this.onMakeFreshChanged,
  });

  static const List<({String mode, IconData icon, String label, String desc})>
      _options = [
    (
      mode: ProductType.madeToOrder,
      icon: Icons.restaurant_rounded,
      label: 'Made to order',
      desc: 'Cooked when sold — uses its recipe',
    ),
    (
      mode: ProductType.madeInAdvance,
      icon: Icons.kitchen_rounded,
      label: 'Made in advance',
      desc: 'Prepared ahead — sells its own stock',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preparation',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: AppResponsive.smallSpacing(context)),
        Row(
          children: [
            for (final o in _options) ...[
              if (o != _options.first)
                SizedBox(width: AppResponsive.smallSpacing(context)),
              Expanded(child: _option(context, o)),
            ],
          ],
        ),
        if (prepMode == ProductType.madeInAdvance)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              'Make fresh when prepared stock runs out',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Sells prepared stock first, then makes the rest from the '
              'recipe if its ingredients are available.',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
            value: makeFreshWhenOut,
            activeThumbColor: AppColors.primary,
            onChanged: onMakeFreshChanged,
          ),
      ],
    );
  }

  Widget _option(BuildContext context,
      ({String mode, IconData icon, String label, String desc}) o) {
    final selected = prepMode == o.mode;
    final color = AppColors.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        onTap: () => onPrepModeChanged(o.mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.all(AppResponsive.smallSpacing(context) + 2),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.10)
                : AppColors.surfaceLight,
            borderRadius:
                BorderRadius.circular(AppResponsive.borderRadius(context)),
            border: Border.all(
              color: selected ? color : AppColors.divider,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(o.icon,
                  size: AppResponsive.smallIconSize(context),
                  color: selected ? color : AppColors.textSecondary),
              SizedBox(width: AppResponsive.smallSpacing(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(context),
                        fontWeight: FontWeight.w700,
                        color: selected ? color : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      o.desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        height: 1.25,
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
    );
  }
}
