import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/domain/services/restaurant/inventory_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/gradient_hero_header.dart';
import '../manage menu/tab/edit_item.dart';

/// Content cap for the recipe grid.
///
/// Wider than `maxFormWidth` (800) because this is a card grid: at 800 four
/// columns give 177px cards. At 1100 they land at ~252px, which also matches
/// what an uncapped 1024 screen already shows — so `gridColumns` stays correct
/// and only the widest screens change.
const double _kRecipesMaxWidth = 1100.0;

/// Horizontal inset that centres the grid inside [_kRecipesMaxWidth].
///
/// A `SliverGrid` cannot be wrapped in a box widget, so the cap is expressed
/// as padding rather than a `ConstrainedBox`.
double _recipesSidePad(BuildContext context) {
  final base = AppResponsive.padding(context).left;
  final overflow = AppResponsive.screenWidth(context) - _kRecipesMaxWidth;
  return overflow > 0 ? base + overflow / 2 : base;
}

/// Card-grid overview of every Semi-Finished and Recipe-Based item — the
/// primary "eye-catching" surface that visualizes recipe cost, margin, and
/// availability together. See docs/inventory_recipe_system_plan.md §8.3.
class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  @override
  void initState() {
    super.initState();
    if (itemStore.items.isEmpty) {
      itemStore.loadItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'Recipes'),
      body: Observer(
        builder: (_) {
          final items =
              itemStore.items
                  .where((i) => i.isSemiFinished || i.isRecipeBased)
                  .toList()
                ..sort((a, b) => a.name.compareTo(b.name));

          final semiCount = items.where((i) => i.isSemiFinished).length;
          final recipeCount = items.where((i) => i.isRecipeBased).length;

          final columns = AppResponsive.gridColumns(
            context,
            mobile: 2,
            tablet: 3,
            desktop: 4,
          );

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: GradientHeroHeader(
                  title: 'Recipes & BOMs',
                  subtitle:
                      'Live food cost, margin & how many you can make right now',
                  icon: Icons.menu_book_rounded,
                  accent: AppColors.secondary,
                  stats: [
                    HeroStat(
                      icon: Icons.lunch_dining_rounded,
                      value: '$recipeCount',
                      label: 'Recipe-Based',
                    ),
                    HeroStat(
                      icon: Icons.soup_kitchen_rounded,
                      value: '$semiCount',
                      label: 'Semi-Finished',
                    ),
                    HeroStat(
                      icon: Icons.receipt_long_rounded,
                      value: '${items.length}',
                      label: 'Total Recipes',
                    ),
                  ],
                ),
              ),
              if (items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'No recipes yet',
                    message:
                        'Mark an item Semi-Finished or Recipe-Based to add one.',
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _recipesSidePad(context),
                    vertical: AppResponsive.padding(context).top,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: AppResponsive.gridSpacing(context),
                      mainAxisSpacing: AppResponsive.gridSpacing(context),
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _RecipeCard(item: items[index]),
                      childCount: items.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Items item;

  const _RecipeCard({required this.item});

  double _costOf(String ingredientItemId) {
    try {
      final ingredient = itemStore.items.firstWhere(
        (i) => i.id == ingredientItemId,
      );
      return ingredient.lastPurchaseCost ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final RecipeModel? recipe = recipeRepository.getRecipeForItem(item.id);
    final ingredientCount = recipe?.ingredients.length ?? 0;
    final double costPerUnit = recipe != null && recipe.hasIngredients
        ? recipe.estimatedCostPerUnit(_costOf)
        : 0.0;

    double? marginPercent;
    if (item.price != null && item.price! > 0) {
      marginPercent = ((item.price! - costPerUnit) / item.price!) * 100;
    }

    final isSemi = item.isSemiFinished;
    final Color accent = isSemi ? AppColors.secondary : AppColors.accent;
    final IconData typeIcon = isSemi
        ? Icons.soup_kitchen_rounded
        : Icons.lunch_dining_rounded;
    final String typeLabel = isSemi ? 'Semi-Finished' : 'Recipe-Based';

    final bool isRecipeBased = item.isRecipeBased;
    final double? availableToMake = isRecipeBased
        ? InventoryService.calculateAvailableToMake(item)
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EdititemScreen(items: item)),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.14),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gradient header band, colour-coded by type.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent,
                      Color.lerp(accent, Colors.black, 0.22) ?? accent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(typeIcon, size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        typeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.captionFontSize(context),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Body.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.blender_outlined,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$ingredientCount ingredient${ingredientCount == 1 ? '' : 's'}',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.captionFontSize(context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      _costMarginRow(context, costPerUnit, marginPercent),
                      if (isRecipeBased) ...[
                        const SizedBox(height: 8),
                        _buildAvailabilityChip(context, availableToMake ?? 0),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _costMarginRow(
    BuildContext context,
    double costPerUnit,
    double? marginPercent,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cost / unit',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(costPerUnit)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (marginPercent != null) _marginPill(context, marginPercent),
      ],
    );
  }

  Widget _marginPill(BuildContext context, double marginPercent) {
    final bool positive = marginPercent >= 0;
    final Color color = positive ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            '${marginPercent.toStringAsFixed(0)}%',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityChip(BuildContext context, double available) {
    final Color color;
    if (available <= 0) {
      color = AppColors.danger;
    } else if (available <= 5) {
      color = AppColors.warning;
    } else {
      color = AppColors.success;
    }
    final label = available.isInfinite
        ? '∞ can be made'
        : '${available.toStringAsFixed(0)} can be made';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
