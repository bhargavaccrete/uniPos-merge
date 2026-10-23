import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/constants/item_units.dart';
import '../../../../data/models/common/categorymodel_300.dart';
import '../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../data/models/restaurant/db/itemvariantemodel_312.dart';
import '../../../../util/restaurant/staticswitch.dart';
import '../../../../domain/services/restaurant/stock_adjust_service.dart';
import '../../../../domain/services/restaurant/inventory_service.dart';
import 'low_stock_screen.dart';
import 'recipes_screen.dart';
import 'raw_materials_screen.dart';
import 'purchase_order/purchase_order_list_screen.dart';
import 'purchase_order/restaurant_grn_list_screen.dart';
import 'supplier/restaurant_supplier_list_screen.dart';
import 'production_screen.dart';
import 'suggested_trade_items_screen.dart';
import 'food_cost_report_screen.dart';
import 'inventory_loss_list_screen.dart';
import 'stock_take_list_screen.dart';
import 'damaged_goods/restaurant_damaged_goods_hub_screen.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/restaurant/stock_reason_chips.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/dashboard_menu_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/gradient_hero_header.dart';
import 'stock_history_screen.dart';

/// Width cap for this screen's content.
///
/// Wider than `maxFormWidth` (800) on purpose: this is a module grid plus
/// per-item stock adjusters, not a form. The gradient hero stays full-bleed —
/// it is a background, and the rule caps content, not backgrounds.
/// Uses the shared ladder: the old local 1100 was a fourth width value in an
/// app that otherwise has three, and maxContentWidth (1000/1400) is wider on
/// desktop, so the module grid keeps its columns.

/// Hub module-grid columns from the MEASURED grid width, not the screen.
///
/// Once content is capped the grid no longer spans the window, so screen
/// breakpoints over-count it. These buckets reproduce the old 2/3/4 at every
/// real breakpoint while staying correct inside the cap.
int inventoryHubColumns(double gridWidth) {
  if (gridWidth < 420) return 2;
  if (gridWidth < 760) return 3;
  return 4;
}

/// Max width for the stock add/remove controls.
///
/// The row is `Expanded(flex: 3/4/3)`, and flex splits whatever width exists —
/// on a laptop that inflated the +/- buttons to several hundred pixels each.
/// Desktop-only so tablet and mobile render exactly as before.
const double kStockAdjusterMaxWidth = 560.0;

class ManageInventory extends StatefulWidget {
  /// Pre-fills the stock search — e.g. Edit Item's "Adjust Stock" opens
  /// straight onto that item.
  final String? initialSearch;

  const ManageInventory({super.key, this.initialSearch});

  @override
  State<ManageInventory> createState() => _ManageInventoryState();
}

class _ManageInventoryState extends State<ManageInventory> {
  final Map<String, TextEditingController> _stockControllers = {};
  final Map<String, bool> _expandedCategories = {};
  final Set<String> _busyKeys = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showLowStockOnly = false;

  /// Synthetic category id for tracked items with no real category assigned
  /// (Category is optional for Raw Material/Semi-Finished) — never a real
  /// Category's id, which is a generated UUID.
  static const _uncategorizedId = '__uncategorized__';

  /// Whether [item]'s stock can carry a fractional quantity, based on its
  /// actual unit — only 'piece' (or no unit at all) is a whole-count unit.
  /// The unit is the authority here, not `isSoldByWeight`: legacy items
  /// carry a real unit with no flag set, and reading the flag silently
  /// rounded away real fractional deductions (e.g. 0.20 kg used from stock).
  bool _allowsDecimals(Items item) {
    final normalized = normalizeItemUnit(item.unit);
    return normalized != null && normalized != 'piece';
  }

  String _unitFor(Items item) =>
      normalizeItemUnit(item.unit) ?? item.unit ?? 'pcs';

  /// Item needs attention: opted into alerts and is low or out of stock.
  ///
  /// Stock status comes from [InventoryService], not the `Items` getters, so a
  /// Recipe-Based item is judged on how many it can make from its ingredients
  /// rather than on a `stockQuantity` it never populates. Every other product
  /// type resolves to exactly the same answer as before.
  bool _isAlertItem(Items item) =>
      InventoryService.isStockGoverned(item) &&
      item.lowStockAlertEnabled &&
      AppSettings.lowStockAlertsEnabled &&
      (InventoryService.isLowStock(item) || !InventoryService.isInStock(item));

  @override
  void initState() {
    super.initState();
    final search = widget.initialSearch?.trim() ?? '';
    if (search.isNotEmpty) {
      _searchController.text = search;
      _searchQuery = search.toLowerCase();
    }
    _loadData();
  }

  @override
  void dispose() {
    for (var controller in _stockControllers.values) {
      controller.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await categoryStore.loadCategories();
    await itemStore.loadItems();
    await variantStore.loadVariants();
  }

  String _getVariantName(String variantId) {
    try {
      final variant = variantStore.variants.firstWhere(
        (v) => v.id == variantId,
      );
      return variant.name;
    } catch (e) {
      return 'Unknown Variant';
    }
  }

  TextEditingController _getStockController(String key) {
    if (!_stockControllers.containsKey(key)) {
      _stockControllers[key] = TextEditingController();
    }
    return _stockControllers[key]!;
  }

  static const _purchaseReason = 'Restock / Purchase';

  /// Ask for a reason (+ optional note, and an optional unit cost for a
  /// purchase) before adjusting stock. Returns null if the user cancels.
  Future<({String reason, String? note, double? unitCost})?> _promptReason({
    required bool isAdd,
    required String itemName,
    required double quantity,
    required double newBalance,
    required String unit,
    required bool isWeightBased,
  }) async {
    final reasons = isAdd
        ? StockAdjustService.addReasons
        : StockAdjustService.removeReasons;
    String selectedReason = reasons.first;
    final noteController = TextEditingController();
    final costController = TextEditingController();

    // Intent-driven accent: green for adding, red for removing.
    final Color accent = isAdd ? AppColors.success : AppColors.danger;
    final IconData headerIcon = isAdd
        ? Icons.add_circle_rounded
        : Icons.remove_circle_rounded;

    final result =
        await showDialog<({String reason, String? note, double? unitCost})>(
      context: context,
      builder: (ctx) => DialogDisposeScope(
        disposables: [noteController, costController],
        child: StatefulBuilder(
          builder: (ctx, setLocal) => AppDialogShell(
            title: isAdd ? 'Add Stock' : 'Remove Stock',
            subtitle: itemName,
            accent: accent,
            icon: headerIcon,
            body: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary: what changes and the resulting balance.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAdd ? 'Adding' : 'Removing',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.captionFontSize(context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${isAdd ? '+' : '−'}${_formatStock(quantity, unit, isWeightBased)}',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.subheadingFontSize(
                                context,
                              ),
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'New balance',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.captionFontSize(context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatStock(newBalance, unit, isWeightBased),
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.subheadingFontSize(
                                context,
                              ),
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Reason',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                StockReasonChips(
                  reasons: reasons,
                  selected: selectedReason,
                  accent: accent,
                  onSelected: (r) => setLocal(() => selectedReason = r),
                ),
                // A purchase can carry what was paid, so the item's cost and
                // food cost stay right. Blank = no cost recorded, as before.
                if (selectedReason == _purchaseReason) ...[
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: costController,
                    label: 'Unit cost per $unit (optional)',
                    hint: 'What you paid per $unit',
                    icon: Icons.currency_rupee_rounded,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Note (optional)',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: noteController,
                  hint: 'Add a note…',
                  icon: Icons.notes_outlined,
                  maxLines: 2,
                  minLines: 1,
                ),
              ],
            ),
            actions: [
              appDialogCancelButton(ctx),
              const SizedBox(width: 12),
              appDialogPrimaryButton(
                label: isAdd ? 'Add Stock' : 'Remove Stock',
                color: accent,
                onPressed: () {
                  final costText = costController.text.trim();
                  final cost = selectedReason == _purchaseReason &&
                          costText.isNotEmpty
                      ? double.tryParse(costText)
                      : null;
                  if (costText.isNotEmpty &&
                      selectedReason == _purchaseReason &&
                      (cost == null || cost <= 0)) {
                    NotificationService.instance.showError(
                      'Enter a unit cost above zero, or leave it blank',
                    );
                    return;
                  }
                  Navigator.pop(ctx, (
                    reason: selectedReason,
                    note: noteController.text.trim().isEmpty
                        ? null
                        : noteController.text.trim(),
                    unitCost: cost,
                  ));
                },
              ),
            ],
          ),
        ),
      ),
    );

    return result;
  }

  /// Stock status pill — priority: Out of Stock > Low Stock > In Stock.
  Widget _buildStockBadge(Items item) {
    final Color base;
    final String label;
    if (!InventoryService.isInStock(item)) {
      base = AppColors.danger;
      label = 'Out of Stock';
    } else if (InventoryService.isLowStock(item)) {
      base = AppColors.orange;
      label = 'Low Stock';
    } else {
      base = AppColors.success;
      label = 'In Stock';
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.getValue(
          context,
          mobile: 10.0,
          tablet: 12.0,
          desktop: 14.0,
        ),
        vertical: AppResponsive.getValue(
          context,
          mobile: 5.0,
          tablet: 6.0,
          desktop: 7.0,
        ),
      ),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: base, shape: BoxShape.circle),
          ),
          SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              fontWeight: FontWeight.w600,
              color: base,
            ),
          ),
        ],
      ),
    );
  }

  /// Small Low/Out pill for an individual variant (so you can see which
  /// variant of an item needs attention, not just the item as a whole).
  Widget _variantStatusBadge(Items item, ItemVariante variant) {
    final qty = variant.stockQuantity ?? 0;
    final bool out = qty <= 0;
    final bool low =
        !out &&
        item.lowStockAlertEnabled &&
        AppSettings.lowStockAlertsEnabled &&
        qty <= item.effectiveLowStockThreshold;
    if (!out && !low) return const SizedBox.shrink();
    final Color color = out ? AppColors.danger : AppColors.orange;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        out ? 'Out' : 'Low',
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.captionFontSize(context),
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  void _openHistory(Items item) {
    final unit = _unitFor(item);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockHistoryScreen(
          itemId: item.id,
          itemName: item.name,
          unit: unit,
        ),
      ),
    );
  }

  void _addStock(Items item, {ItemVariante? variant}) async {
    final key = variant != null ? '${item.id}_${variant.variantId}' : item.id;
    if (_busyKeys.contains(key)) return;

    final controller = _getStockController(key);

    if (controller.text.isEmpty) {
      if (mounted) {
        NotificationService.instance.showError('Please enter stock quantity');
      }
      return;
    }

    final isWeightBased = _allowsDecimals(item);
    final unit = _unitFor(item);

    final stockToAdd = double.tryParse(controller.text);
    if (stockToAdd == null || stockToAdd <= 0) {
      if (mounted) {
        NotificationService.instance.showError(
          'Please enter a valid positive number',
        );
      }
      return;
    }

    // Validate whole numbers for unit-based items
    if (!isWeightBased && stockToAdd % 1 != 0) {
      if (mounted) {
        NotificationService.instance.showError(
          'Unit-based items must be whole numbers only (e.g., 5 $unit, not 2.5 $unit)',
        );
      }
      return;
    }

    final newBalance =
        (variant != null ? (variant.stockQuantity ?? 0) : item.stockQuantity) +
        stockToAdd;

    // Capture WHY before changing stock (for the audit log).
    final reasonData = await _promptReason(
      isAdd: true,
      itemName: variant != null
          ? '${item.name} (${_getVariantName(variant.variantId)})'
          : item.name,
      quantity: stockToAdd,
      newBalance: newBalance,
      unit: unit,
      isWeightBased: isWeightBased,
    );
    if (reasonData == null) return;

    setState(() => _busyKeys.add(key));
    try {
      // The shared queued write: live balance, history after the write.
      await StockAdjustService.adjustBy(
        item: item,
        variant: variant,
        delta: stockToAdd,
        reason: reasonData.reason,
        note: reasonData.note,
        unitCost: reasonData.unitCost,
      );

      controller.clear();

      if (mounted) {
        NotificationService.instance.showSuccess(
          isWeightBased
              ? 'Added ${stockToAdd.toStringAsFixed(2)} $unit to stock'
              : 'Added ${stockToAdd.toStringAsFixed(0)} $unit to stock',
        );
      }
    } on StateError catch (e) {
      if (mounted) NotificationService.instance.showError(e.message);
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError(
          'Error adding stock. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busyKeys.remove(key));
    }
  }

  // Add this new function inside your _ManageInventoryState class

  void _removeStock(Items item, {ItemVariante? variant}) async {
    final key = variant != null ? '${item.id}_${variant.variantId}' : item.id;
    if (_busyKeys.contains(key)) return;

    final controller = _getStockController(key);

    if (controller.text.isEmpty) {
      if (mounted) {
        NotificationService.instance.showError(
          'Please enter quantity to remove',
        );
      }
      return;
    }

    final stockToRemove = double.tryParse(controller.text);
    if (stockToRemove == null || stockToRemove <= 0) {
      if (mounted) {
        NotificationService.instance.showError(
          'Please enter a valid positive number',
        );
      }
      return;
    }

    // Get the current stock to perform validation
    final currentStock = variant != null
        ? (variant.stockQuantity ?? 0)
        : item.stockQuantity;
    final isWeightBased = _allowsDecimals(item);
    final unit = _unitFor(item);

    // Check if there is enough stock to remove
    if (currentStock < stockToRemove) {
      if (mounted) {
        NotificationService.instance.showError(
          'Not enough stock. Only ${currentStock.toStringAsFixed(isWeightBased ? 2 : 0)} $unit available.',
        );
      }
      return;
    }

    // Validate whole numbers for unit-based items
    if (!isWeightBased && stockToRemove % 1 != 0) {
      if (mounted) {
        NotificationService.instance.showError(
          'Unit-based items must be whole numbers only (e.g., 5 $unit, not 2.5 $unit)',
        );
      }
      return;
    }

    final newBalance = currentStock - stockToRemove;

    // Capture WHY before changing stock (for the audit log).
    final reasonData = await _promptReason(
      isAdd: false,
      itemName: variant != null
          ? '${item.name} (${_getVariantName(variant.variantId)})'
          : item.name,
      quantity: stockToRemove,
      newBalance: newBalance,
      unit: unit,
      isWeightBased: isWeightBased,
    );
    if (reasonData == null) return;

    setState(() => _busyKeys.add(key));
    try {
      // The shared queued write; it refuses going below zero on the LIVE
      // balance and records the loss row for loss reasons.
      await StockAdjustService.adjustBy(
        item: item,
        variant: variant,
        delta: -stockToRemove,
        reason: reasonData.reason,
        note: reasonData.note,
      );

      controller.clear();

      if (mounted) {
        NotificationService.instance.showSuccess(
          isWeightBased
              ? 'Removed ${stockToRemove.toStringAsFixed(2)} $unit from stock'
              : 'Removed ${stockToRemove.toStringAsFixed(0)} $unit from stock',
        );
      }
    } on StateError catch (e) {
      if (mounted) NotificationService.instance.showError(e.message);
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError(
          'Error removing stock. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busyKeys.remove(key));
    }
  }

  Widget _buildItemTile(Items item) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.largeSpacing(context),
        vertical: 6,
      ),
      child: Container(
        padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(
            AppResponsive.borderRadius(context),
          ),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: AppResponsive.bodyFontSize(context),
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppResponsive.smallSpacing(context),
                              vertical: AppResponsive.getValue(
                                context,
                                mobile: 4.0,
                                tablet: 5.0,
                                desktop: 6.0,
                              ),
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _allowsDecimals(item)
                                  ? 'Weight-based'
                                  : 'Unit-based',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.getValue(
                                  context,
                                  mobile: 10.0,
                                  tablet: 11.0,
                                  desktop: 12.0,
                                ),
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '(${_unitFor(item)})',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.captionFontSize(context),
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _openHistory(item),
                  icon: Icon(
                    Icons.history_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  tooltip: 'Stock history',
                  visualDensity: VisualDensity.compact,
                ),
                _buildStockBadge(item),
              ],
            ),
            SizedBox(height: 12),

            // Show item stock management if no variants or item-level tracking
            if (!item.hasVariants) ...[_buildStockRow(item: item)],

            // Show variants if available
            if (item.hasVariants) ...[
              Text(
                'Variants:',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: AppResponsive.smallFontSize(context),
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 10),
              ...item.variant!.map(
                (variant) => Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(
                    AppResponsive.getValue(
                      context,
                      mobile: 10.0,
                      tablet: 12.0,
                      desktop: 14.0,
                    ),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(
                      AppResponsive.smallBorderRadius(context),
                    ),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _getVariantName(variant.variantId),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: AppResponsive.getValue(
                                  context,
                                  mobile: 13.0,
                                  tablet: 14.0,
                                  desktop: 15.0,
                                ),
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          _variantStatusBadge(item, variant),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppResponsive.smallSpacing(context),
                              vertical: AppResponsive.getValue(
                                context,
                                mobile: 4.0,
                                tablet: 5.0,
                                desktop: 6.0,
                              ),
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(variant.price)}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: AppResponsive.smallFontSize(context),
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      _buildStockRow(item: item, variant: variant),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Replace your existing _buildStockRow method with this one

  /// Format stock for display with smart unit conversion
  String _formatStock(double stock, String unit, bool isWeightBased) {
    if (!isWeightBased) return '${stock.toStringAsFixed(0)} $unit';
    final upperUnit = unit.toUpperCase();
    if (upperUnit.contains('GM') ||
        upperUnit.contains('GRAM') ||
        upperUnit == 'G') {
      if (stock >= 1000) {
        final kg = stock / 1000;
        return '${kg.toStringAsFixed(kg == kg.roundToDouble() ? 0 : 2)} kg';
      }
      return '${stock.toStringAsFixed(stock == stock.roundToDouble() ? 0 : 2)} $unit';
    }
    return '${stock.toStringAsFixed(stock == stock.roundToDouble() ? 0 : 2)} $unit';
  }

  /// Conversion hint for input — e.g. user types 2000 in a gm item → shows "= 2 kg"
  String? _conversionHint(String input, String unit) {
    if (input.isEmpty) return null;
    final val = double.tryParse(input);
    if (val == null || val <= 0) return null;
    final upperUnit = unit.toUpperCase();
    if (upperUnit.contains('GM') ||
        upperUnit.contains('GRAM') ||
        upperUnit == 'G') {
      if (val >= 1000) return '= ${(val / 1000).toStringAsFixed(2)} kg';
    } else if (upperUnit.contains('KG')) {
      if (val >= 1) return '= ${(val * 1000).toStringAsFixed(0)} gm';
    }
    return null;
  }

  /// Read-only availability for a Recipe-Based item: how many its ingredients
  /// currently support, from the same [InventoryService] figure the POS uses.
  Widget _buildRecipeAvailabilityRow(Items item) {
    final available = InventoryService.effectiveAvailableStock(item);
    final unlimited = available.isInfinite;
    final canMake = unlimited ? 0.0 : available;

    return Container(
      padding: EdgeInsets.all(
        AppResponsive.getValue(
          context,
          mobile: 10.0,
          tablet: 12.0,
          desktop: 14.0,
        ),
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(
          AppResponsive.smallBorderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(
            Icons.restaurant_menu_rounded,
            size: 18,
            color: AppColors.secondary,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Can make',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  unlimited
                      ? 'Not limited by ingredients'
                      : '${canMake.toStringAsFixed(0)} '
                            '${_unitFor(item)}',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: unlimited || canMake > 0
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: Text(
              'From recipe ingredients',
              textAlign: TextAlign.end,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Made in advance + make fresh when out: what the recipe can add on top
  /// of the prepared stock shown above it.
  String _makeFreshCaption(Items item, double prepared, String unit) {
    if (!InventoryService.makesFreshWhenOut(item)) {
      return 'No recipe — cannot make fresh';
    }
    final total = InventoryService.effectiveAvailableStock(item);
    if (total.isInfinite) return '+ made fresh when out';
    final fresh =
        total - (item.trackInventory && prepared > 0 ? prepared : 0);
    return '+${fresh.toStringAsFixed(0)} $unit can be made fresh';
  }

  Widget _buildStockRow({required Items item, ItemVariante? variant}) {
    // Recipe-Based items hold no stock of their own — there is nothing to add
    // or remove here, so show the derived "can make" figure read-only instead
    // of an adjuster that would write to a field nothing reads.
    if (item.isMadeToOrder) return _buildRecipeAvailabilityRow(item);

    final currentStock = variant != null
        ? (variant.stockQuantity ?? 0)
        : item.stockQuantity;
    final controllerKey = variant != null
        ? '${item.id}_${variant.variantId}'
        : item.id;
    final controller = _getStockController(controllerKey);
    final isWeightBased = _allowsDecimals(item);
    final unit = _unitFor(item);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppResponsive.isDesktop(context)
                ? kStockAdjusterMaxWidth
                : double.infinity,
          ),
          child: Row(
            children: [
              // Current Stock
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stock:',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      _formatStock(currentStock, unit, isWeightBased),
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: currentStock > 0
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                    ),
                    if (variant == null &&
                        InventoryService.usesDerivedAvailability(item))
                      Text(
                        _makeFreshCaption(item, currentStock, unit),
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.captionFontSize(context),
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              // Input with unit hint
              Expanded(
                flex: 4,
                child: AppTextField(
                  controller: controller,
                  hint: 'Qty ($unit)',
                  keyboardType: isWeightBased
                      ? TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.number,
                  inputFormatters: isWeightBased
                      ? [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ]
                      : [FilteringTextInputFormatter.digitsOnly],
                  onChanged: isWeightBased ? (_) => setState(() {}) : null,
                ),
              ),
              SizedBox(width: 8),
              // Action Buttons
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () => _removeStock(item, variant: variant),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Icon(Icons.remove_rounded, size: 18),
                        ),
                      ),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () => _addStock(item, variant: variant),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Icon(Icons.add_rounded, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Live conversion hint for weight-based items
        if (isWeightBased && controller.text.isNotEmpty)
          Builder(
            builder: (_) {
              final hint = _conversionHint(controller.text, unit);
              if (hint == null) return SizedBox.shrink();
              return Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  hint,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // ── Hub: quick-access module grid ─────────────────────────────────────────
  // Groups everything that used to be a wall of app-bar icons into one
  // clearly-labelled "Manage Inventory" section, separate from the item-level
  // "Stock Levels" list below it.
  List<
    ({
      String title,
      String subtitle,
      IconData icon,
      Color color,
      VoidCallback onTap,
    })
  >
  _hubActions(BuildContext context) => [
    (
      title: 'Recipes',
      subtitle: 'Build BOMs for composed items',
      icon: Icons.receipt_long_rounded,
      color: AppColors.secondary,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RecipesScreen()),
      ),
    ),
    (
      title: 'Suggested Trade Items',
      subtitle: 'Older items that look bought-in',
      icon: Icons.storefront_rounded,
      color: AppColors.info,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SuggestedTradeItemsScreen()),
      ),
    ),
    (
      title: 'Raw Materials',
      subtitle: 'Ingredients & stock levels',
      icon: Icons.grass_rounded,
      color: AppColors.success,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RawMaterialsScreen()),
      ),
    ),
    (
      title: 'Suppliers',
      subtitle: 'Contacts, balances & payments',
      icon: Icons.people_alt_rounded,
      color: AppColors.secondary,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RestaurantSupplierListScreen()),
      ),
    ),
    (
      title: 'Purchase Orders',
      subtitle: 'Order & receive from suppliers',
      icon: Icons.local_shipping_rounded,
      color: AppColors.info,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PurchaseOrderListScreen()),
      ),
    ),
    (
      title: 'Goods Received',
      subtitle: 'Confirmed receipts against POs',
      icon: Icons.inventory_rounded,
      color: AppColors.success,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RestaurantGRNListScreen()),
      ),
    ),
    (
      title: 'Production',
      subtitle: 'Batch-prep semi-finished items',
      icon: Icons.outdoor_grill_rounded,
      color: AppColors.accent,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProductionScreen()),
      ),
    ),
    (
      title: 'Stock Take',
      subtitle: 'Physical count reconciliation',
      icon: Icons.fact_check_rounded,
      color: AppColors.warning,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const RestaurantStockTakeListScreen(),
        ),
      ),
    ),
    (
      title: 'Inventory Losses',
      subtitle: 'Wastage, theft & write-offs',
      icon: Icons.money_off_rounded,
      color: AppColors.danger,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const RestaurantInventoryLossListScreen(),
        ),
      ),
    ),
    (
      title: 'Damaged Goods',
      subtitle: 'Supplier returns & claims',
      icon: Icons.assignment_return_rounded,
      color: AppColors.orange,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const RestaurantDamagedGoodsHubScreen(),
        ),
      ),
    ),
    (
      title: 'Food Cost Report',
      subtitle: 'Margins, usage & wastage %',
      icon: Icons.query_stats_rounded,
      color: AppColors.primary,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FoodCostReportScreen()),
      ),
    ),
  ];

  Widget _buildSectionHeading(String title, String subtitle) {
    return AppResponsive.constrainedContent(
      context: context,
      maxWidth: AppResponsive.maxContentWidth(context),
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppResponsive.largeSpacing(context),
          20,
          16,
          10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.subheadingFontSize(context),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHubGrid(BuildContext context) {
    final actions = _hubActions(context);
    return AppResponsive.constrainedContent(
      context: context,
      maxWidth: AppResponsive.maxContentWidth(context),
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.largeSpacing(context),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: inventoryHubColumns(constraints.maxWidth),
            crossAxisSpacing: AppResponsive.gridSpacing(context),
            mainAxisSpacing: AppResponsive.gridSpacing(context),
            childAspectRatio: AppResponsive.getValue(
              context,
              mobile: 1.02,
              tablet: 1.15,
              desktop: 1.25,
            ),
            children: actions
                .map(
                  (a) => DashboardMenuCard(
                    title: a.title,
                    subtitle: a.subtitle,
                    icon: a.icon,
                    color: a.color,
                    compact: AppResponsive.isMobile(context),
                    onTap: a.onTap,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  /// Gradient hero banner with live "at a glance" counters — Tracked / Low /
  /// Out — flowing straight out of the flat app bar.
  Widget _buildHero(int tracked, int low, int outOfStock) {
    // App bar already carries the "Inventory" title, so this card shows only
    // the live stats — no title/subtitle/icon. Keeps the primary→secondary
    // gradient (rather than a flat primary) so the card still visually
    // separates from the app bar instead of merging into one solid block.
    return GradientHeroHeader(
      accent: AppColors.secondary,
      stats: [
        HeroStat(
          icon: Icons.check_circle_rounded,
          value: '$tracked',
          label: 'Tracked',
        ),
        HeroStat(
          icon: Icons.trending_down_rounded,
          value: '$low',
          label: 'Low Stock',
        ),
        HeroStat(
          icon: Icons.remove_shopping_cart_rounded,
          value: '$outOfStock',
          label: 'Out of Stock',
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 18), action],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Inventory',
        actions: [
          Observer(
            builder: (context) {
              final count = StockAdjustService.lowStockEntries().length;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'Low stock',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LowStockScreen(),
                        ),
                      ),
                      icon: Icon(
                        count > 0
                            ? Icons.notifications_active
                            : Icons.notifications_none_rounded,
                        color: Colors.white,
                      ),
                    ),
                    if (count > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            '$count',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: AppResponsive.captionFontSize(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Observer(
        builder: (context) {
          final categories = categoryStore.categories.toList();
          final items = itemStore.items.toList();

          // Category is optional for Raw Material/Semi-Finished, so an item
          // with no category (or one pointing at a since-deleted category)
          // would otherwise match no group below and silently never render.
          // Give those items a synthetic "Uncategorized" group instead of
          // hiding them until someone assigns a real category.
          final categoryIds = categories.map((c) => c.id).toSet();
          final hasUncategorizedStock = items.any(
            (item) =>
                item.trackInventory == true &&
                !categoryIds.contains(item.categoryOfItem),
          );
          final displayCategories = [
            ...categories,
            if (hasUncategorizedStock)
              Category(id: _uncategorizedId, name: 'Uncategorized'),
          ];

          // Items whose availability is governed by stock: directly-tracked
          // ones, plus Recipe-Based items (governed by their ingredients, so
          // they qualify regardless of their own trackInventory flag — the
          // same rule the POS applies).
          final inventoryItems = items
              .where((item) => InventoryService.isStockGoverned(item))
              .toList();
          final lowCount = inventoryItems.where(_isAlertItem).length;
          final outCount = inventoryItems
              .where((item) => !InventoryService.isInStock(item))
              .length;

          final horizontalPad = AppResponsive.largeSpacing(context);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildHero(inventoryItems.length, lowCount, outCount),
              ),
              SliverToBoxAdapter(
                child: _buildSectionHeading(
                  'Manage Inventory',
                  'Recipes, purchasing, production & reports',
                ),
              ),
              SliverToBoxAdapter(child: _buildHubGrid(context)),
              SliverToBoxAdapter(
                child: _buildSectionHeading(
                  'Stock Levels',
                  'Track and adjust stock for individual menu items',
                ),
              ),
              SliverToBoxAdapter(
                child: AppResponsive.constrainedContent(
                  context: context,
                  maxWidth: AppResponsive.maxContentWidth(context),
                  alignment: Alignment.topCenter,
                  heightFactor: 1,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPad,
                      0,
                      horizontalPad,
                      10,
                    ),
                    child: Column(
                      children: [
                        AppTextField(
                          controller: _searchController,
                          onChanged: (v) => setState(
                            () => _searchQuery = v.trim().toLowerCase(),
                          ),
                          hint: 'Search items...',
                          icon: Icons.search_rounded,
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  onPressed: () => setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  }),
                                )
                              : null,
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilterChip(
                            label: Text(
                              'Low stock only',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.smallFontSize(context),
                                fontWeight: FontWeight.w600,
                                color: _showLowStockOnly
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                            avatar: Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: _showLowStockOnly
                                  ? Colors.white
                                  : AppColors.warning,
                            ),
                            selected: _showLowStockOnly,
                            onSelected: (v) =>
                                setState(() => _showLowStockOnly = v),
                            selectedColor: AppColors.warning,
                            backgroundColor: AppColors.warning.withValues(
                              alpha: 0.08,
                            ),
                            side: BorderSide(
                              color: AppColors.warning.withValues(
                                alpha: _showLowStockOnly ? 1 : 0.3,
                              ),
                            ),
                            showCheckmark: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (displayCategories.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(
                    icon: Icons.category_rounded,
                    color: AppColors.textSecondary,
                    title: 'No categories yet',
                    subtitle: 'Create a menu category before tracking stock.',
                  ),
                )
              else if (inventoryItems.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(
                    icon: Icons.inventory_2_outlined,
                    color: AppColors.primary,
                    title: 'No items with inventory tracking',
                    subtitle:
                        "Enable 'Manage Inventory' on a menu item to track its stock here.",
                    action: OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/restaurant-manage-menu',
                      ),
                      icon: const Icon(Icons.restaurant_menu_rounded, size: 16),
                      label: Text(
                        'Go to Menu Management',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.smallFontSize(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    0,
                    horizontalPad,
                    horizontalPad,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final category = displayCategories[index];
                      final isUncategorizedGroup =
                          category.id == _uncategorizedId;
                      final categoryItems = items
                          .where(
                            (item) =>
                                (isUncategorizedGroup
                                    ? !categoryIds.contains(item.categoryOfItem)
                                    : item.categoryOfItem == category.id) &&
                                item.trackInventory == true &&
                                (!_showLowStockOnly || _isAlertItem(item)) &&
                                (_searchQuery.isEmpty ||
                                    item.name.toLowerCase().contains(
                                      _searchQuery,
                                    ) ||
                                    (item.itemCode != null &&
                                        item.itemCode!.toLowerCase().contains(
                                          _searchQuery,
                                        ))),
                          )
                          .toList();

                      if (categoryItems.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      // Auto-expand when searching or filtering to low stock
                      final isExpanded =
                          (_searchQuery.isNotEmpty || _showLowStockOnly)
                          ? true
                          : (_expandedCategories[category.id] ?? false);

                      return AppResponsive.constrainedContent(
                        context: context,
                        maxWidth: AppResponsive.maxContentWidth(context),
                        alignment: Alignment.topCenter,
                        heightFactor: 1,
                        child: Container(
                          margin: EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(
                              AppResponsive.borderRadius(context),
                            ),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              // Key includes isExpanded so toggling search / low-stock
                              // filter rebuilds the tile and re-applies initiallyExpanded
                              // (ExpansionTile ignores initiallyExpanded changes otherwise).
                              key: ValueKey('${category.id}_$isExpanded'),
                              tilePadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 2,
                              ),
                              childrenPadding: EdgeInsets.only(bottom: 8),
                              leading: Icon(
                                Icons.category_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              title: Text(
                                category.name,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500,
                                  fontSize: AppResponsive.bodyFontSize(context),
                                ),
                              ),
                              subtitle: Text(
                                '${categoryItems.length} item${categoryItems.length != 1 ? 's' : ''}',
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.captionFontSize(
                                    context,
                                  ),
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              initiallyExpanded: isExpanded,
                              onExpansionChanged: (expanded) {
                                setState(() {
                                  _expandedCategories[category.id] = expanded;
                                });
                              },
                              children: categoryItems.map((item) {
                                return _buildItemTile(item);
                              }).toList(),
                            ),
                          ),
                        ),
                      );
                    }, childCount: displayCategories.length),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
