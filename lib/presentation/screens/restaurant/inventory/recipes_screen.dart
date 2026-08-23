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
import '../manage menu/tab/edit_item.dart';

/// Card-grid overview of every Semi-Finished and Recipe-Based item — the
/// primary "eye-catching" surface that visualizes recipe cost, margin, and
/// availability together. See docs/inventory_recipe_system_plan.md §8.3.
///
/// Not wired to a route yet — a later step adds the navigation entry point.
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

          if (items.isEmpty) {
            return const AppEmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'No recipes yet',
              message: 'Mark an item Semi-Finished or Recipe-Based to add one.',
            );
          }

          final columns = AppResponsive.gridColumns(
            context,
            mobile: 2,
            tablet: 3,
            desktop: 4,
          );
          return GridView.builder(
            padding: AppResponsive.padding(context),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: AppResponsive.gridSpacing(context),
              mainAxisSpacing: AppResponsive.gridSpacing(context),
              childAspectRatio: 0.82,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => _RecipeCard(item: items[index]),
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

    final isRecipeBased = item.isRecipeBased;
    final double? availableToMake = isRecipeBased
        ? InventoryService.calculateAvailableToMake(item)
        : null;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EdititemScreen(items: item)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTypeBadge(),
            const SizedBox(height: 10),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$ingredientCount ingredient${ingredientCount == 1 ? '' : 's'}',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cost',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(costPerUnit)}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  if (marginPercent != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Margin',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${marginPercent.toStringAsFixed(0)}%',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: marginPercent >= 0
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (isRecipeBased) ...[
              const SizedBox(height: 8),
              _buildAvailabilityChip(availableToMake ?? 0),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge() {
    final isSemi = item.isSemiFinished;
    final color = isSemi ? AppColors.info : AppColors.orange;
    final label = isSemi ? 'Semi-Finished' : 'Recipe-Based';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildAvailabilityChip(double available) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.blender_rounded, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 11,
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
