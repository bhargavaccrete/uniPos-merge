import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../data/models/restaurant/db/itemvariantemodel_312.dart';
import '../../../../data/models/restaurant/db/stock_movement_model.dart';
import '../../../../data/repositories/restaurant/stock_movement_repository.dart';
import '../../../../domain/services/restaurant/day_management_service.dart';
import '../../../../util/restaurant/restaurant_session.dart';
import '../../../../util/restaurant/staticswitch.dart';
import '../../../../domain/services/restaurant/stock_adjust_service.dart';
import 'low_stock_screen.dart';
import '../../../widget/componets/restaurant/componets/drawermanage.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'stock_history_screen.dart';


class ManageInventory extends StatefulWidget {
  const ManageInventory({
    super.key,
  });

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

  /// Item needs attention: opted into alerts and is low or out of stock.
  bool _isAlertItem(Items item) =>
      item.trackInventory &&
      item.lowStockAlertEnabled &&
      AppSettings.lowStockAlertsEnabled &&
      (item.isLowStock || !item.isInStock);

  @override
  void initState() {
    super.initState();
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

  final _stockRepo = StockMovementRepository();

  // Reasons offered in the dropdown when adjusting stock.
  // Tune these lists to match how this restaurant categorises stock changes.
  static const List<String> _addReasons = [
    'Restock / Purchase',
    'Customer return',
    'Stock correction',
    'Transfer in',
    'Other',
  ];
  static const List<String> _removeReasons = [
    'Wastage / Spoilage',
    'Theft / Loss',
    'Stock correction',
    'Transfer out',
    'Sample / Complimentary',
    'Other',
  ];

  /// Ask for a reason (+ optional note) before adjusting stock.
  /// Returns null if the user cancels.
  Future<({String reason, String? note})?> _promptReason({
    required bool isAdd,
    required String itemName,
    required double quantity,
    required double newBalance,
    required String unit,
    required bool isWeightBased,
  }) async {
    final reasons = isAdd ? _addReasons : _removeReasons;
    String selectedReason = reasons.first;
    final noteController = TextEditingController();

    // Intent-driven accent: green for adding, red for removing.
    final Color accent = isAdd ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final IconData headerIcon = isAdd ? Icons.add_circle_rounded : Icons.remove_circle_rounded;

    final result = await showDialog<({String reason, String? note})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        Text(isAdd ? 'Adding' : 'Removing',
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          '${isAdd ? '+' : '−'}${_formatStock(quantity, unit, isWeightBased)}',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: accent),
                        ),
                      ],
                    ),
                    Icon(Icons.arrow_forward_rounded,
                        size: 18, color: AppColors.textSecondary),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('New balance',
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          _formatStock(newBalance, unit, isWeightBased),
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('Reason',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: reasons.map((r) {
                  final selected = r == selectedReason;
                  return InkWell(
                    onTap: () => setLocal(() => selectedReason = r),
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: selected
                            ? accent.withValues(alpha: 0.12)
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: selected ? accent : AppColors.divider,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selected) ...[
                            Icon(Icons.check_rounded, size: 15, color: accent),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            r,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: selected ? accent : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text('Note (optional)',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
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
              onPressed: () => Navigator.pop(
                ctx,
                (
                  reason: selectedReason,
                  note: noteController.text.trim().isEmpty
                      ? null
                      : noteController.text.trim(),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    noteController.dispose();
    return result;
  }

  /// Append a stock movement to the audit log.
  Future<void> _recordMovement({
    required Items item,
    ItemVariante? variant,
    required bool isAdd,
    required double quantity,
    required double balanceAfter,
    required String reason,
    String? note,
    required String unit,
  }) async {
    final sessionId = await DayManagementService.getCurrentSessionId();
    await _stockRepo.saveMovement(StockMovementModel(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      itemId: item.id,
      variantId: variant?.variantId,
      itemName: variant != null
          ? '${item.name} (${_getVariantName(variant.variantId)})'
          : item.name,
      type: isAdd ? 'in' : 'out',
      quantity: quantity,
      balanceAfter: balanceAfter,
      reason: reason,
      note: note,
      unit: unit,
      staffName: RestaurantSession.staffName ?? RestaurantSession.effectiveRole,
      sessionId: sessionId,
    ));
  }

  /// Stock status pill — priority: Out of Stock > Low Stock > In Stock.
  Widget _buildStockBadge(Items item) {
    final MaterialColor base;
    final String label;
    if (!item.isInStock) {
      base = Colors.red;
      label = 'Out of Stock';
    } else if (item.isLowStock) {
      base = Colors.orange;
      label = 'Low Stock';
    } else {
      base = Colors.green;
      label = 'In Stock';
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.getValue(context, mobile: 10.0, tablet: 12.0, desktop: 14.0),
        vertical: AppResponsive.getValue(context, mobile: 5.0, tablet: 6.0, desktop: 7.0),
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
            decoration: BoxDecoration(color: base.shade600, shape: BoxShape.circle),
          ),
          SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.getValue(context, mobile: 11.0, tablet: 12.0, desktop: 13.0),
              fontWeight: FontWeight.w600,
              color: base.shade700,
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
    final bool low = !out &&
        item.lowStockAlertEnabled &&
        AppSettings.lowStockAlertsEnabled &&
        qty <= item.effectiveLowStockThreshold;
    if (!out && !low) return const SizedBox.shrink();
    final MaterialColor color = out ? Colors.red : Colors.orange;
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
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color.shade700,
        ),
      ),
    );
  }

  void _openHistory(Items item) {
    final unit = item.unit ?? (item.isSoldByWeight ? 'kg' : 'pcs');
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

    final isWeightBased = item.isSoldByWeight;
    final unit = item.unit ?? (isWeightBased ? 'kg' : 'pcs');

    final stockToAdd = double.tryParse(controller.text);
    if (stockToAdd == null || stockToAdd <= 0) {
      if (mounted) {
        NotificationService.instance.showError('Please enter a valid positive number');
      }
      return;
    }

    // Validate whole numbers for unit-based items
    if (!isWeightBased && stockToAdd % 1 != 0) {
      if (mounted) {
        NotificationService.instance.showError('Unit-based items must be whole numbers only (e.g., 5 $unit, not 2.5 $unit)');
      }
      return;
    }

    final newBalance = (variant != null ? (variant.stockQuantity ?? 0) : item.stockQuantity) + stockToAdd;

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
      if (variant != null) {
        // Update the variant's stock quantity
        final updatedVariants = item.variant?.map((v) {
          if (v.variantId == variant.variantId) {
            return ItemVariante(
              variantId: v.variantId,
              price: v.price,
              stockQuantity: (v.stockQuantity ?? 0) + stockToAdd,
            );
          }
          return v;
        }).toList();

        // Use store's updateItem to ensure MobX observers are notified
        await itemStore.updateItem(item.copyWith(
          trackInventory: true,
          variant: updatedVariants,
        ));
      } else {
        // Use store's updateItem to ensure MobX observers are notified
        await itemStore.updateItem(item.copyWith(
          trackInventory: true,
          stockQuantity: item.stockQuantity + stockToAdd,
        ));
      }

      await _recordMovement(
        item: item,
        variant: variant,
        isAdd: true,
        quantity: stockToAdd,
        balanceAfter: newBalance,
        reason: reasonData.reason,
        note: reasonData.note,
        unit: unit,
      );

      controller.clear();

      if (mounted) {
        NotificationService.instance.showSuccess(
          isWeightBased
              ? 'Added ${stockToAdd.toStringAsFixed(2)} $unit to stock'
              : 'Added ${stockToAdd.toStringAsFixed(0)} $unit to stock'
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError('Error adding stock. Please try again.');
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
        NotificationService.instance.showError('Please enter quantity to remove');
      }
      return;
    }

    final stockToRemove = double.tryParse(controller.text);
    if (stockToRemove == null || stockToRemove <= 0) {
      if (mounted) {
        NotificationService.instance.showError('Please enter a valid positive number');
      }
      return;
    }

    // Get the current stock to perform validation
    final currentStock = variant != null ? (variant.stockQuantity ?? 0) : item.stockQuantity;
    final isWeightBased = item.isSoldByWeight;
    final unit = item.unit ?? (isWeightBased ? 'kg' : 'pcs');

    // Check if there is enough stock to remove
    if (currentStock < stockToRemove) {
      if (mounted) {
        NotificationService.instance.showError('Not enough stock. Only ${currentStock.toStringAsFixed(isWeightBased ? 2 : 0)} $unit available.');
      }
      return;
    }

    // Validate whole numbers for unit-based items
    if (!isWeightBased && stockToRemove % 1 != 0) {
      if (mounted) {
        NotificationService.instance.showError('Unit-based items must be whole numbers only (e.g., 5 $unit, not 2.5 $unit)');
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
      if (variant != null) {
        // Subtract from variant stock
        final updatedVariants = item.variant?.map((v) {
          if (v.variantId == variant.variantId) {
            return ItemVariante(
              variantId: v.variantId,
              price: v.price,
              stockQuantity: (v.stockQuantity ?? 0) - stockToRemove,
            );
          }
          return v;
        }).toList();

        // Use store's updateItem to ensure MobX observers are notified
        await itemStore.updateItem(item.copyWith(
          variant: updatedVariants,
        ));
      } else {
        // Subtract from item stock
        await itemStore.updateItem(item.copyWith(
          stockQuantity: item.stockQuantity - stockToRemove,
        ));
      }

      await _recordMovement(
        item: item,
        variant: variant,
        isAdd: false,
        quantity: stockToRemove,
        balanceAfter: newBalance,
        reason: reasonData.reason,
        note: reasonData.note,
        unit: unit,
      );

      controller.clear();

      if (mounted) {
        NotificationService.instance.showSuccess(
          isWeightBased
              ? 'Removed ${stockToRemove.toStringAsFixed(2)} $unit from stock'
              : 'Removed ${stockToRemove.toStringAsFixed(0)} $unit from stock'
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError('Error removing stock. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busyKeys.remove(key));
    }
  }


  Widget _buildItemTile(Items item) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.getValue(context, mobile: 16.0, tablet: 20.0, desktop: 24.0),
        vertical: 6,
      ),
      child: Container(
        padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 12.0, tablet: 14.0, desktop: 16.0)),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
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
                          fontSize: AppResponsive.getValue(context, mobile: 14.0, tablet: 15.0, desktop: 16.0),
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppResponsive.getValue(context, mobile: 8.0, tablet: 10.0, desktop: 12.0),
                              vertical: AppResponsive.getValue(context, mobile: 4.0, tablet: 5.0, desktop: 6.0),
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.isSoldByWeight ? 'Weight-based' : 'Unit-based',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.getValue(context, mobile: 10.0, tablet: 11.0, desktop: 12.0),
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '(${item.unit ?? (item.isSoldByWeight ? 'kg' : 'pcs')})',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.getValue(context, mobile: 11.0, tablet: 12.0, desktop: 13.0),
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
                  icon: Icon(Icons.history_rounded, size: 20, color: AppColors.primary),
                  tooltip: 'Stock history',
                  visualDensity: VisualDensity.compact,
                ),
                _buildStockBadge(item),
              ],
            ),
            SizedBox(height: 12),

                // Show item stock management if no variants or item-level tracking
                if (!item.hasVariants) ...[
                  _buildStockRow(item: item),
                ],

            // Show variants if available
            if (item.hasVariants) ...[
              Text(
                'Variants:',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: AppResponsive.getValue(context, mobile: 12.0, tablet: 13.0, desktop: 14.0),
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 10),
              ...item.variant!.map((variant) => Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 10.0, tablet: 12.0, desktop: 14.0)),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
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
                              fontSize: AppResponsive.getValue(context, mobile: 13.0, tablet: 14.0, desktop: 15.0),
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        _variantStatusBadge(item, variant),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppResponsive.getValue(context, mobile: 8.0, tablet: 10.0, desktop: 12.0),
                            vertical: AppResponsive.getValue(context, mobile: 4.0, tablet: 5.0, desktop: 6.0),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha:0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(variant.price)}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: AppResponsive.getValue(context, mobile: 12.0, tablet: 13.0, desktop: 14.0),
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
              )),
            ],
              ],
            ),
          ));

  }

// Replace your existing _buildStockRow method with this one

  /// Format stock for display with smart unit conversion
  String _formatStock(double stock, String unit, bool isWeightBased) {
    if (!isWeightBased) return '${stock.toStringAsFixed(0)} $unit';
    final upperUnit = unit.toUpperCase();
    if (upperUnit.contains('GM') || upperUnit.contains('GRAM') || upperUnit == 'G') {
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
    if (upperUnit.contains('GM') || upperUnit.contains('GRAM') || upperUnit == 'G') {
      if (val >= 1000) return '= ${(val / 1000).toStringAsFixed(2)} kg';
    } else if (upperUnit.contains('KG')) {
      if (val >= 1) return '= ${(val * 1000).toStringAsFixed(0)} gm';
    }
    return null;
  }

  Widget _buildStockRow({required Items item, ItemVariante? variant}) {
    final currentStock = variant != null ? (variant.stockQuantity ?? 0) : item.stockQuantity;
    final controllerKey =
    variant != null ? '${item.id}_${variant.variantId}' : item.id;
    final controller = _getStockController(controllerKey);
    final isWeightBased = item.isSoldByWeight;
    final unit = item.unit ?? (isWeightBased ? 'kg' : 'pcs');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    _formatStock(currentStock, unit, isWeightBased),
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: currentStock > 0 ? Colors.green.shade700 : Colors.red.shade700,
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
                    ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
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
                          backgroundColor: Colors.red,
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
                          backgroundColor: Colors.green,
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
        // Live conversion hint for weight-based items
        if (isWeightBased && controller.text.isNotEmpty)
          Builder(builder: (_) {
            final hint = _conversionHint(controller.text, unit);
            if (hint == null) return SizedBox.shrink();
            return Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                hint,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      drawer: DrawerManage(
        issync: false,
        isDelete: true,
        islogout: true,
      ),
      appBar: buildPrimaryAppBar(
        title: 'Inventory',
        leading: Builder(
          builder: (context) => IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu),
          ),
        ),
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
                        MaterialPageRoute(builder: (_) => const LowStockScreen()),
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
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Text(
                            '$count',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 10,
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
      body: Column(
        children: [
          // Search
          Container(
            color: AppColors.white,
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: AppTextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              hint: 'Search items...',
              icon: Icons.search_rounded,
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                      onPressed: () => setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      }),
                    )
                  : null,
            ),
          ),

          SizedBox(height: 8),
          // Inventory List
          Expanded(
            child: Observer(
              builder: (context) {
                final categories = categoryStore.categories.toList();
                final items = itemStore.items.toList();

                // Check if there are any items with inventory tracking enabled
                final inventoryItems = items.where((item) => item.trackInventory == true).toList();

                if (categories.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.category_rounded, size: 48, color: AppColors.divider),
                        SizedBox(height: 12),
                        Text('No Categories Found', style: GoogleFonts.poppins(fontSize: 15, color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }

                if (inventoryItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.divider),
                        SizedBox(height: 12),
                        Text('No items with inventory tracking', style: GoogleFonts.poppins(fontSize: 15, color: AppColors.textSecondary)),
                        SizedBox(height: 4),
                        Text("Enable 'Manage Inventory' on items to track stock", style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 12.0, tablet: 16.0, desktop: 20.0)),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final categoryItems = items
                        .where((item) =>
                            item.categoryOfItem == category.id &&
                            item.trackInventory == true &&
                            (!_showLowStockOnly || _isAlertItem(item)) &&
                            (_searchQuery.isEmpty ||
                             item.name.toLowerCase().contains(_searchQuery) ||
                             (item.itemCode != null && item.itemCode!.toLowerCase().contains(_searchQuery))))
                        .toList();

                    if (categoryItems.isEmpty) {
                      return SizedBox.shrink();
                    }

                    // Auto-expand when searching or filtering to low stock
                    final isExpanded = (_searchQuery.isNotEmpty || _showLowStockOnly)
                        ? true
                        : (_expandedCategories[category.id] ?? false);

                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          // Key includes isExpanded so toggling search / low-stock
                          // filter rebuilds the tile and re-applies initiallyExpanded
                          // (ExpansionTile ignores initiallyExpanded changes otherwise).
                          key: ValueKey('${category.id}_$isExpanded'),
                          tilePadding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          childrenPadding: EdgeInsets.only(bottom: 8),
                          leading: Icon(Icons.category_rounded, color: AppColors.primary, size: 20),
                          title: Text(category.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14)),
                          subtitle: Text('${categoryItems.length} item${categoryItems.length != 1 ? 's' : ''}', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
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
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

