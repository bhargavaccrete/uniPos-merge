import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/plan/entitlement_keys.dart';
import 'package:billberrylite/core/plan/plan_guard.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/repositories/restaurant/stock_movement_repository.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/domain/services/restaurant/trade_item_suggestion_rule.dart';
import 'package:billberrylite/presentation/screens/restaurant/manage%20menu/tab/edit_item.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

/// Read-only review list (Phase 1.9, Q2): legacy Finished items that look
/// bought-in and resold — see [TradeItemSuggestionRule]. Nothing here changes
/// an item; "Review" opens Edit Item, where the owner decides.
class SuggestedTradeItemsScreen extends StatefulWidget {
  const SuggestedTradeItemsScreen({super.key});

  @override
  State<SuggestedTradeItemsScreen> createState() =>
      _SuggestedTradeItemsScreenState();
}

class _SuggestedTradeItemsScreenState extends State<SuggestedTradeItemsScreen> {
  // Movements change only through other screens; re-read after each review.
  List<StockMovementModel> _movements = StockMovementRepository().allMovements();

  @override
  void initState() {
    super.initState();
    if (itemStore.items.isEmpty) itemStore.loadItems();
  }

  Future<void> _review(TradeItemSuggestion s) async {
    if (!PlanGuard.allowedOr(
      context,
      EntKeys.manageMenuItemsEdit,
      featureName: 'Edit Items',
    )) {
      return;
    }
    final fresh = itemStore.getItemById(s.item.id);
    if (fresh == null) {
      NotificationService.instance.showError('Item not found');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EdititemScreen(items: fresh)),
    );
    if (mounted) {
      setState(() => _movements = StockMovementRepository().allMovements());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'Suggested Trade Items'),
      body: Observer(
        builder: (_) {
          final suggestions = TradeItemSuggestionRule.suggest(
            items: itemStore.items,
            hasRecipe: (id) =>
                recipeRepository.getRecipeForItem(id)?.hasIngredients ?? false,
            movements: _movements,
          );
          return AppResponsive.constrainedContent(
            context: context,
            maxWidth: AppResponsive.maxContentWidth(context),
            alignment: Alignment.topCenter,
            child: ListView(
              padding: AppResponsive.padding(context),
              children: [
                SizedBox(height: AppResponsive.mediumSpacing(context)),
                _buildExplainer(context),
                SizedBox(height: AppResponsive.mediumSpacing(context)),
                if (suggestions.isEmpty)
                  const AppEmptyState(
                    icon: Icons.fact_check_rounded,
                    title: 'No suggestions',
                    message: 'No older Finished item shows signs of being '
                        'bought in and resold.',
                  )
                else
                  ...suggestions.map((s) => _buildRow(context, s)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildExplainer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.info),
          SizedBox(width: AppResponsive.smallSpacing(context)),
          Expanded(
            child: Text(
              'These are suggestions for review, not confirmed types. Each '
              'item was set up before Trade Items existed, has no recipe, was '
              'never produced, and has been bought — received on a purchase '
              'order or restocked as a purchase. Open one to '
              'check it and change its type yourself — nothing is changed '
              'automatically. Saving an item in Edit Item removes it from '
              'this list.',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, TradeItemSuggestion s) {
    final item = s.item;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Now: Finished'
                  '${item.trackInventory ? ' · Stock: ${formatQtyWithUnit(item.stockQuantity, item.unit)}' : ''}',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                ...s.reasons.map(
                  (r) => Text(
                    '• $r',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: AppResponsive.smallSpacing(context)),
          OutlinedButton.icon(
            onPressed: () => _review(s),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(
              'Review',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
