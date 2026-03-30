import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../data/models/restaurant/db/itemvariantemodel_312.dart';
import '../../../widget/componets/restaurant/componets/drawermanage.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';


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
    final currentStock = variant?.stockQuantity ?? item.stockQuantity;
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
    final isTablet = AppResponsive.isTablet(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 20 : 16,
        vertical: 6,
      ),
      child: Container(
        padding: EdgeInsets.all(isTablet ? 14 : 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
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
                          fontSize: isTablet ? 15 : 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 10 : 8,
                              vertical: isTablet ? 5 : 4,
                            ),
                            decoration: BoxDecoration(
                              color: item.isSoldByWeight
                                  ? Colors.blue.withValues(alpha:0.1)
                                  : Colors.purple.withValues(alpha:0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.isSoldByWeight ? 'Weight-based' : 'Unit-based',
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 11 : 10,
                                color: item.isSoldByWeight ? Colors.blue.shade700 : Colors.purple.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '(${item.unit ?? (item.isSoldByWeight ? 'kg' : 'pcs')})',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 12 : 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 12 : 10,
                    vertical: isTablet ? 6 : 5,
                  ),
                  decoration: BoxDecoration(
                    color: item.isInStock
                        ? Colors.green.withValues(alpha:0.1)
                        : Colors.red.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: item.isInStock ? Colors.green.shade600 : Colors.red.shade600,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        item.isInStock ? 'In Stock' : 'Out of Stock',
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 12 : 11,
                          fontWeight: FontWeight.w600,
                          color: item.isInStock ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
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
                  fontSize: isTablet ? 13 : 12,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 10),
              ...item.variant!.map((variant) => Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(isTablet ? 12 : 10),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(8),
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
                              fontSize: isTablet ? 14 : 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 10 : 8,
                            vertical: isTablet ? 5 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha:0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(variant.price)}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: isTablet ? 13 : 12,
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
    final currentStock = variant?.stockQuantity ?? item.stockQuantity;
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
                  color: Colors.blue.shade600,
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
    final isTablet = AppResponsive.isTablet(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      drawer: DrawerManage(
        issync: false,
        isDelete: true,
        islogout: true,
      ),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(12, 16, 20, 12),
            color: AppColors.white,
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: Icon(Icons.menu, size: 24),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('Inventory', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ],
              ),
            ),
          ),

          // Search
          Container(
            color: AppColors.white,
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                        Icon(Icons.category_rounded, size: 48, color: Colors.grey.shade300),
                        SizedBox(height: 12),
                        Text('No Categories Found', style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey.shade500)),
                      ],
                    ),
                  );
                }

                if (inventoryItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade300),
                        SizedBox(height: 12),
                        Text('No items with inventory tracking', style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey.shade500)),
                        SizedBox(height: 4),
                        Text("Enable 'Manage Inventory' on items to track stock", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(isTablet ? 16 : 12),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final categoryItems = items
                        .where((item) =>
                            item.categoryOfItem == category.id &&
                            item.trackInventory == true &&
                            (_searchQuery.isEmpty || item.name.toLowerCase().contains(_searchQuery)))
                        .toList();

                    if (categoryItems.isEmpty) {
                      return SizedBox.shrink();
                    }

                    // Auto-expand when search is active
                    final isExpanded = _searchQuery.isNotEmpty
                        ? true
                        : (_expandedCategories[category.id] ?? false);

                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          childrenPadding: EdgeInsets.only(bottom: 8),
                          leading: Icon(Icons.category_rounded, color: AppColors.primary, size: 20),
                          title: Text(category.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14)),
                          subtitle: Text('${categoryItems.length} item${categoryItems.length != 1 ? 's' : ''}', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
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

