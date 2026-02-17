import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/core/routes/routes_name.dart';
import 'package:unipos/util/color.dart';
import '../../../../constants/restaurant/color.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../data/models/restaurant/db/itemvariantemodel_312.dart';
import '../../../widget/componets/restaurant/componets/Button.dart';
import '../../../widget/componets/restaurant/componets/drawermanage.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import '../../../../util/common/currency_helper.dart';


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
        orElse: () => variantStore.variants.first,
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
    final controller = _getStockController(
        variant != null ? '${item.id}_${variant.variantId}' : item.id);

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
        print('✅ Added stock to variant ${variant.variantId}. New stock: ${(variant.stockQuantity ?? 0) + stockToAdd}');
      } else {
        // Use store's updateItem to ensure MobX observers are notified
        await itemStore.updateItem(item.copyWith(
          trackInventory: true,
          stockQuantity: item.stockQuantity + stockToAdd,
        ));
        print('✅ Added stock to item ${item.name}. New stock: ${item.stockQuantity + stockToAdd}, trackInventory: true');
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
      print('Error adding stock: $e');
      if (mounted) {
        NotificationService.instance.showError('Error adding stock: $e');
      }
    }
  }


  // Add this new function inside your _ManageInventoryState class

  void _removeStock(Items item, {ItemVariante? variant}) async {
    final controller = _getStockController(
        variant != null ? '${item.id}_${variant.variantId}' : item.id);

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

    // ** CRUCIAL VALIDATION STEP **
    // Check if there is enough stock to remove.
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

    try {
      if (variant != null) {
        // ** SUBTRACT from variant stock **
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
        print('✅ Removed stock from variant ${variant.variantId}. New stock: ${(variant.stockQuantity ?? 0) - stockToRemove}');
      } else {
        // ** SUBTRACT from item stock **
        // Use store's updateItem to ensure MobX observers are notified
        await itemStore.updateItem(item.copyWith(
          stockQuantity: item.stockQuantity - stockToRemove,
        ));
        print('✅ Removed stock from item ${item.name}. New stock: ${item.stockQuantity - stockToRemove}');
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
      print('Error removing stock: $e');
      if (mounted) {
        NotificationService.instance.showError('Error removing stock: $e');
      }
    }
  }


  Widget _buildItemTile(Items item) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

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
                                  ? Colors.blue.withOpacity(0.1)
                                  : Colors.purple.withOpacity(0.1),
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
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
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
                margin: EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.all(isTablet ? 12 : 10),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
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
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${CurrencyHelper.currentSymbol}${variant.price.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
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

  Widget _buildStockRow({required Items item, ItemVariante? variant}) {
    final currentStock = variant?.stockQuantity ?? item.stockQuantity;
    final controllerKey =
    variant != null ? '${item.id}_${variant.variantId}' : item.id;
    final controller = _getStockController(controllerKey);
    final isWeightBased = item.isSoldByWeight;
    final unit = item.unit ?? (isWeightBased ? 'kg' : 'pcs');

    return Row(
      children: [
        Expanded(
          flex: 3, // Adjusted flex
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Stock:',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                isWeightBased
                    ? currentStock.toStringAsFixed(2)
                    : currentStock.toStringAsFixed(0),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: currentStock > 0 ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
              Text(
                unit,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          flex: 4, // Adjusted flex
          child: TextField(
            controller: controller,
            keyboardType: isWeightBased
                ? TextInputType.numberWithOptions(decimal: true)
                : TextInputType.number,
            inputFormatters: isWeightBased
                ? [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ]
                : [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              hintText: 'Enter qty',
              hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400),
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        SizedBox(width: 8),

        // Action Buttons
        Expanded(
          flex: 3,
          child: Row(
            children: [
              // REMOVE BUTTON
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
              // ADD BUTTON
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
        )
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final width = size.width;
    final height = size.height;

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
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Builder(
                    builder: (context) {
                      return GestureDetector(
                        onTap: () => Scaffold.of(context).openDrawer(),
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.menu, color: AppColors.white, size: 24),
                        ),
                      );
                    },
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Inventory',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Track and update stock levels',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(isTablet ? 10 : 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.person,
                      size: isTablet ? 22 : 20,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Actions Section
          Container(
            color: AppColors.white,
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Column(
              children: [
                // Stock History Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, RouteNames.restaurantStockHistory);
                    },
                    icon: Icon(Icons.history_rounded, size: isTablet ? 20 : 18),
                    label: Text(
                      'Stock History',
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 16 : 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: isTablet ? 14 : 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12),

                // Info Card
                Container(
                  padding: EdgeInsets.all(isTablet ? 14 : 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.info_outline,
                          size: isTablet ? 20 : 18,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Weight-based items: decimals allowed (2.5 kg) • Unit-based items: whole numbers only (5 pcs)',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 13 : 12,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                        Container(
                          padding: EdgeInsets.all(isTablet ? 24 : 20),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMedium,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.category_rounded,
                            size: isTablet ? 64 : 56,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No Categories Found',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (inventoryItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(isTablet ? 24 : 20),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMedium,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            size: isTablet ? 64 : 56,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No Items with Inventory Tracking',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Items with 'Manage Inventory' set to 'Yes' will appear here",
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 15 : 14,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
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
                        .where((item) => item.categoryOfItem == category.id && item.trackInventory == true)
                        .toList();

                    if (categoryItems.isEmpty) {
                      return SizedBox.shrink();
                    }

                    final isExpanded = _expandedCategories[category.id] ?? false;

                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 20 : 16,
                            vertical: 4,
                          ),
                          childrenPadding: EdgeInsets.only(bottom: 12),
                          title: Text(
                            category.name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: isTablet ? 17 : 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            '${categoryItems.length} item${categoryItems.length != 1 ? 's' : ''}',
                            style: GoogleFonts.poppins(
                              color: AppColors.textSecondary,
                              fontSize: isTablet ? 13 : 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          leading: Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.category_rounded,
                              color: AppColors.primary,
                              size: isTablet ? 24 : 22,
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

