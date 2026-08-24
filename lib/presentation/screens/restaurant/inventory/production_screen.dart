import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_ingredient_model.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_production_model.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/domain/services/restaurant/inventory_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/gradient_hero_header.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// "Prep ahead of time" counterpart to sale-time cascading deduction: pick a
/// Semi-Finished item, enter a batch quantity, see whether current raw
/// material stock covers it, and confirm. All the state mutation lives in
/// [InventoryService.produceBatch] — this screen is presentation only. See
/// docs/inventory_recipe_system_plan.md §6.3.
class ProductionScreen extends StatefulWidget {
  const ProductionScreen({super.key});

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  Items? _selectedItem;
  final TextEditingController _batchQtyController = TextEditingController();
  bool _producing = false;

  @override
  void initState() {
    super.initState();
    if (itemStore.items.isEmpty) {
      itemStore.loadItems();
    }
  }

  @override
  void dispose() {
    _batchQtyController.dispose();
    super.dispose();
  }

  List<Items> get _semiFinishedItems =>
      itemStore.items.where((i) => i.isSemiFinished).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  RecipeModel? get _recipe =>
      _selectedItem == null ? null : recipeRepository.getRecipeForItem(_selectedItem!.id);

  double get _batchQty => double.tryParse(_batchQtyController.text.trim()) ?? 0;

  bool get _canSubmit =>
      _selectedItem != null &&
      _recipe != null &&
      _recipe!.hasIngredients &&
      _batchQty > 0;

  void _selectItem(Items item) {
    setState(() {
      _selectedItem = item;
      _batchQtyController.clear();
    });
  }

  void _pickItem() async {
    final items = _semiFinishedItems;
    if (items.isEmpty) return;
    final selected = await showDialog<Items>(
      context: context,
      builder: (_) => _SemiFinishedPickerDialog(items: items),
    );
    if (selected != null) {
      _selectItem(selected);
    }
  }

  Future<void> _produce() async {
    final item = _selectedItem;
    final qty = _batchQty;
    if (item == null || qty <= 0) return;

    setState(() => _producing = true);
    try {
      final production = await InventoryService.produceBatch(
        semiFinishedItem: item,
        batchQty: qty,
      );
      if (!mounted) return;
      _batchQtyController.clear();
      NotificationService.instance.showSuccess(
        'Produced ${_fmt(production.batchQty)} ${item.unit ?? "units"} of ${item.name}',
      );
      // Re-sync the selection to the freshly reloaded items list so the
      // ingredient stock numbers shown below reflect the new balances.
      Items? refreshed;
      try {
        refreshed = itemStore.items.firstWhere((i) => i.id == item.id);
      } catch (_) {
        refreshed = item;
      }
      setState(() => _selectedItem = refreshed);
    } catch (e) {
      if (!mounted) return;
      NotificationService.instance.showError(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _producing = false);
    }
  }

  String _fmt(double v) =>
      v.truncateToDouble() == v ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'Production'),
      body: Observer(
        builder: (_) {
          final semiFinishedItems = _semiFinishedItems;

          return Column(
            children: [
              GradientHeroHeader(
                title: 'Production',
                subtitle:
                    'Batch-prep semi-finished items straight from their recipes',
                icon: Icons.outdoor_grill_rounded,
                accent: AppColors.secondary,
                stats: [
                  HeroStat(
                    icon: Icons.soup_kitchen_rounded,
                    value: '${semiFinishedItems.length}',
                    label: 'Semi-Finished Items',
                  ),
                ],
              ),
              Expanded(
                child: semiFinishedItems.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.outdoor_grill_rounded,
                        title: 'No semi-finished items yet',
                        message:
                            'Mark an item Semi-Finished to start producing batches here.',
                      )
                    : SingleChildScrollView(
                        padding: AppResponsive.padding(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildItemPicker(context),
                            if (_selectedItem != null) ...[
                              const SizedBox(height: 16),
                              _buildRecipeCard(context),
                              const SizedBox(height: 20),
                              _buildRecentBatches(context),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildItemPicker(BuildContext context) {
    return InkWell(
      onTap: _pickItem,
      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
          border: Border.all(
            color: _selectedItem != null ? AppColors.primary : AppColors.divider,
            width: _selectedItem != null ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.outdoor_grill_rounded,
                color: AppColors.secondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Semi-Finished item',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedItem?.name ?? 'Select an item to produce',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _selectedItem != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeCard(BuildContext context) {
    final item = _selectedItem!;
    final recipe = _recipe;

    if (recipe == null || !recipe.hasIngredients) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${item.name} has no recipe configured. Add one from the Recipes screen before producing a batch.',
                style: GoogleFonts.poppins(fontSize: 13, color: AppColors.danger),
              ),
            ),
          ],
        ),
      );
    }

    final yieldQty = recipe.yieldQty > 0 ? recipe.yieldQty : 1.0;
    final batches = _batchQty / yieldQty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.blender_rounded, size: 18, color: AppColors.info),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Makes ${_fmt(yieldQty)} ${recipe.yieldUnit ?? item.unit ?? 'units'} per batch',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.info,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _batchQtyController,
          label: 'Batch Quantity',
          hint: 'How many ${recipe.yieldUnit ?? item.unit ?? 'units'} to produce',
          icon: Icons.numbers_rounded,
          required: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Text(
          'Ingredients Required',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ...recipe.ingredients.map(
          (line) => _buildIngredientRow(context, line, batches),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_canSubmit && !_producing) ? _produce : null,
            icon: _producing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.outdoor_grill_rounded),
            label: Text(
              _producing ? 'Producing...' : 'Produce Batch',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.divider,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientRow(
    BuildContext context,
    RecipeIngredientModel line,
    double batches,
  ) {
    Items? ingredient;
    try {
      ingredient = itemStore.items.firstWhere((i) => i.id == line.ingredientItemId);
    } catch (_) {
      ingredient = null;
    }

    final ingredientName = ingredient?.name ?? 'Unknown ingredient';
    final unit = line.unit ?? ingredient?.unit ?? 'units';
    final required = batches * line.effectiveQuantity;
    final available = ingredient?.stockQuantity ?? 0;
    final hasEnough = ingredient != null && available >= required;

    final Color color = ingredient == null
        ? AppColors.textSecondary
        : (hasEnough ? AppColors.success : AppColors.danger);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ingredientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Need ${_fmt(required)} $unit  ·  Have ${_fmt(available)} $unit',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  ingredient == null
                      ? Icons.help_outline_rounded
                      : (hasEnough ? Icons.check_circle_rounded : Icons.warning_rounded),
                  size: 13,
                  color: color,
                ),
                const SizedBox(width: 5),
                Text(
                  ingredient == null
                      ? 'Missing'
                      : (hasEnough ? 'Sufficient' : 'Short'),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentBatches(BuildContext context) {
    final productions =
        recipeProductionRepository.getProductionsForItem(_selectedItem!.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Batches',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        if (productions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(
              'No batches produced yet.',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          ...productions.map((p) => _buildProductionTile(context, p)),
      ],
    );
  }

  Widget _buildProductionTile(BuildContext context, RecipeProductionModel p) {
    final unit = _recipe?.yieldUnit ?? _selectedItem?.unit ?? 'units';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              size: 16,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '+${_fmt(p.batchQty)} $unit',
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM yyyy · hh:mm a').format(p.producedTime),
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (p.producedBy != null && p.producedBy!.isNotEmpty)
            Text(
              p.producedBy!,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Simple searchable list dialog limited to Semi-Finished items — same shape
/// as the Raw Material picker in `add_purchase_order_screen.dart`.
class _SemiFinishedPickerDialog extends StatefulWidget {
  final List<Items> items;

  const _SemiFinishedPickerDialog({required this.items});

  @override
  State<_SemiFinishedPickerDialog> createState() =>
      _SemiFinishedPickerDialogState();
}

class _SemiFinishedPickerDialogState extends State<_SemiFinishedPickerDialog> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.items
        : widget.items
            .where((i) => i.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return AppDialogShell(
      title: 'Select Semi-Finished Item',
      accent: AppColors.secondary,
      icon: Icons.outdoor_grill_rounded,
      body: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.5,
        child: Column(
          children: [
            AppTextField(
              controller: _searchController,
              hint: 'Search semi-finished items...',
              icon: Icons.search_rounded,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const AppEmptyState(
                      dense: true,
                      icon: Icons.search_off_rounded,
                      title: 'No items found',
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            'Stock: ${item.stockQuantity} ${item.unit ?? ''}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [appDialogCancelButton(context, label: 'Close')],
    );
  }
}
