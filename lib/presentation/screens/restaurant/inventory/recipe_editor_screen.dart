import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/restaurant/recipe_builder_widget.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';

/// Create or edit THE recipe of one Finished or Semi-Finished item (Phase
/// 1.5) — recipes are managed here, separately from the item's product
/// type. Pops `true` when the recipe was saved or deleted.
class RecipeEditorScreen extends StatefulWidget {
  final Items item;

  const RecipeEditorScreen({super.key, required this.item});

  @override
  State<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends State<RecipeEditorScreen> {
  late final RecipeModel? _saved =
      recipeRepository.getRecipeForItem(widget.item.id);
  late RecipeModel? _draft = _saved;
  bool _saving = false;

  String get _usage {
    final i = widget.item;
    if (i.isSemiFinished) {
      return 'Production uses this recipe to make batches of ${i.name}.';
    }
    if (i.isMadeToOrder) {
      return 'Selling ${i.name} deducts these ingredients.';
    }
    return i.makeFreshWhenOut
        ? 'Production uses this recipe for prepared stock; a sale makes the '
            'rest fresh from it when prepared stock runs out.'
        : 'Production uses this recipe to make prepared stock of ${i.name}.';
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) {
      NotificationService.instance
          .showError('Add at least one ingredient to save the recipe.');
      return;
    }
    setState(() => _saving = true);
    try {
      await recipeRepository.saveForItem(draft.copyWith(
        itemId: widget.item.id,
        lastEditedTime: DateTime.now(),
        editedBy: RestaurantSession.staffName ?? RestaurantSession.effectiveRole,
        editCount: (_saved?.editCount ?? 0) + (_saved == null ? 0 : 1),
      ));
      if (!mounted) return;
      NotificationService.instance.showSuccess('Recipe saved');
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete recipe?',
      message: '${widget.item.name} will no longer use a recipe. Its sales and '
          'production stop deducting ingredients.',
      confirmLabel: 'Delete',
      accent: AppColors.danger,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed) return;
    await recipeRepository.deleteRecipeForItem(widget.item.id);
    NotificationService.instance.showSuccess('Recipe deleted');
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Recipe · ${widget.item.name}',
        actions: [
          if (_saved != null)
            IconButton(
              tooltip: 'Delete recipe',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: AppResponsive.constrainedContent(
          context: context,
          maxWidth: AppResponsive.maxContentWidth(context),
          alignment: Alignment.topCenter,
          child: ListView(
            padding: AppResponsive.padding(context),
            children: [
              SizedBox(height: AppResponsive.mediumSpacing(context)),
              Text(
                _usage,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: AppResponsive.mediumSpacing(context)),
              RecipeBuilderWidget(
                itemId: widget.item.id,
                allItems: itemStore.items,
                initialRecipe: _saved,
                sellingPrice: widget.item.isSemiFinished ? null : widget.item.price,
                onChanged: (recipe) => _draft = recipe,
              ),
              SizedBox(height: AppResponsive.extraLargeSpacing(context)),
              SizedBox(
                width: double.infinity,
                height: AppResponsive.buttonHeight(context),
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(
                    'Save Recipe',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppResponsive.largeSpacing(context)),
            ],
          ),
        ),
      ),
    );
  }
}
