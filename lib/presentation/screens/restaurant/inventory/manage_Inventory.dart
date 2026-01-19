import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:hive_flutter/adapters.dart';
import 'package:unipos/core/routes/routes_name.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_variante.dart';
import 'package:unipos/presentation/screens/restaurant/inventory/stockHistoy.dart';
import 'package:unipos/util/color.dart';
import '../../../../constants/restaurant/color.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/categorymodel_300.dart';
import '../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../data/models/restaurant/db/itemvariantemodel_312.dart';
import '../../../../data/models/restaurant/db/variantmodel_305.dart';
import '../../../widget/componets/restaurant/componets/Button.dart';
import '../../../widget/componets/restaurant/componets/drawermanage.dart';


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
  Map<String, VariantModel> _variantCache = {};

  @override
  void initState() {
    super.initState();
    _loadVariants();
  }

  @override

  void dispose() {
    for (var controller in _stockControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadVariants() async {
    try {
      final variants = await HiveVariante.getAllVariante();
      setState(() {
        _variantCache = {for (var variant in variants) variant.id: variant};
      });
    } catch (e) {
      print('Error loading variants: $e');
    }
  }

  String _getVariantName(String variantId) {
    return _variantCache[variantId]?.name ?? 'Unknown Variant';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter stock quantity')),
        );
      }
      return;
    }

    final isWeightBased = item.isSoldByWeight;
    final unit = item.unit ?? (isWeightBased ? 'kg' : 'pcs');

    final stockToAdd = double.tryParse(controller.text);
    if (stockToAdd == null || stockToAdd <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a valid positive number')),
        );
      }
      return;
    }

    // Validate whole numbers for unit-based items
    if (!isWeightBased && stockToAdd % 1 != 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unit-based items must be whole numbers only (e.g., 5 $unit, not 2.5 $unit)'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    try {
      if (variant != null) {
        // Update the variant's stock quantity
        variant.stockQuantity = (variant.stockQuantity ?? 0) + stockToAdd;
        // Ensure the item tracks inventory when stock is added
        item.trackInventory = true;
        // Save the parent item to persist the variant changes
        await item.save();
        print('✅ Added stock to variant ${variant.variantId}. New stock: ${variant.stockQuantity}');
      } else {
        // Ensure the item tracks inventory when stock is added
        item.trackInventory = true;
        item.stockQuantity = item.stockQuantity + stockToAdd;
        await item.save();
        print('✅ Added stock to item ${item.name}. New stock: ${item.stockQuantity}, trackInventory: ${item.trackInventory}');
      }

      controller.clear();

      // Force UI refresh
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isWeightBased
                    ? 'Added ${stockToAdd.toStringAsFixed(2)} $unit to stock'
                    : 'Added ${stockToAdd.toStringAsFixed(0)} $unit to stock'
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error adding stock: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding stock: $e')),
        );
      }
    }
  }


  // Add this new function inside your _ManageInventoryState class

  void _removeStock(Items item, {ItemVariante? variant}) async {
    final controller = _getStockController(
        variant != null ? '${item.id}_${variant.variantId}' : item.id);

    if (controller.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter quantity to remove')),
        );
      }
      return;
    }

    final stockToRemove = double.tryParse(controller.text);
    if (stockToRemove == null || stockToRemove <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a valid positive number')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Not enough stock. Only ${currentStock.toStringAsFixed(isWeightBased ? 2 : 0)} $unit available.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    // Validate whole numbers for unit-based items
    if (!isWeightBased && stockToRemove % 1 != 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unit-based items must be whole numbers only (e.g., 5 $unit, not 2.5 $unit)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      if (variant != null) {
        // ** SUBTRACT from variant stock **
        variant.stockQuantity = (variant.stockQuantity ?? 0) - stockToRemove;
        await item.save(); // Save the parent item
        print('✅ Removed stock from variant ${variant.variantId}. New stock: ${variant.stockQuantity}');
      } else {
        // ** SUBTRACT from item stock **
        item.stockQuantity = item.stockQuantity - stockToRemove;
        await item.save();
        print('✅ Removed stock from item ${item.name}. New stock: ${item.stockQuantity}');
      }

      controller.clear();

      // Force UI refresh
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isWeightBased
                    ? 'Removed ${stockToRemove.toStringAsFixed(2)} $unit from stock'
                    : 'Removed ${stockToRemove.toStringAsFixed(0)} $unit from stock'
            ),
            backgroundColor: Colors.orange[800], // Use a different color for removal
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error removing stock: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing stock: $e')),
        );
      }
    }
  }


  Widget _buildItemTile(Items item) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
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
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: item.isSoldByWeight ? Colors.blue[50] : Colors.purple[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.isSoldByWeight ? 'Weight-based' : 'Unit-based',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    color: item.isSoldByWeight ? Colors.blue[600] : Colors.purple[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                '(${item.unit ?? (item.isSoldByWeight ? 'kg' : 'pcs')})',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.isInStock ? Colors.green[100] : Colors.red[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.isInStock ? 'In Stock' : 'Out of Stock',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: item.isInStock ? Colors.green[800] : Colors.red[800],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),

                // Show item stock management if no variants or item-level tracking
                if (!item.hasVariants) ...[
                  _buildStockRow(item: item),
                ],

                // Show variants if available
                if (item.hasVariants) ...[
                  Text(
                    'Variants:',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  ...item.variant!.map((variant) => Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey[200]!),
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
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Text(
                              '\$${variant.price.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        _buildStockRow(item: item, variant: variant),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
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
                  color: Colors.grey[600],
                ),
              ),
              Text(
                isWeightBased
                    ? currentStock.toStringAsFixed(2)
                    : currentStock.toStringAsFixed(0),
                style: GoogleFonts.poppins(
                  fontSize: 16, // Slightly larger font
                  fontWeight: FontWeight.w600,
                  color: currentStock > 0 ? Colors.green[700] : Colors.red[700],
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
              hintText: 'Enter Qty (${unit})', // Shorter hint text
              hintStyle: GoogleFonts.poppins(fontSize: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.primary),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
            style: GoogleFonts.poppins(fontSize: 14),
          ),
        ),
        SizedBox(width: 8),

        // ** NEW BUTTONS ROW **
        Expanded(
          flex: 3, // Adjusted flex for two buttons
          child: Row(
            children: [
              // REMOVE BUTTON
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    onPressed: () => _removeStock(item, variant: variant),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Icon(Icons.remove, size: 18),
                  ),
                ),
              ),
              SizedBox(width: 4),
              // ADD BUTTON
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    onPressed: () => _addStock(item, variant: variant),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Icon(Icons.add, size: 18),
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
    final width = MediaQuery.of(context).size.width * 1;
    final height = MediaQuery.of(context).size.height * 1;
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        shadowColor: Colors.black,
        actions: [
          Padding(
            padding: EdgeInsets.all(10),
            child: Row(
              children: [
                Icon(Icons.person),
                Text(
                  "Admin",
                  style: GoogleFonts.poppins(),
                ),
              ],
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Manage Inventory",
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textScaler: TextScaler.linear(1.2),
                    ),
                    CommonButton(
                        bordercircular: 10,
                        width: width * 0.42,
                        height: height * 0.05,
                        onTap: () {
                       /*   Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => StockHistory()));

                       */
                       Navigator.pushNamed(context,RouteNames.restaurantStockHistory);

                        },
                        child: Text(
                          'Stock History',
                          textScaler: TextScaler.linear(1.2),
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.white),
                        )),
                  ],
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue[600]),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Weight-based items: decimals allowed (2.5 kg) • Unit-based items: whole numbers only (5 pcs)',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
            thickness: 1,
            color: Colors.grey,
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Hive.box<Category>('categories').listenable(),
              builder: (context, categoryBox, _) {
                return ValueListenableBuilder(
                  valueListenable: Hive.box<Items>('itemBoxs').listenable(),
                  builder: (context, itemBox, _) {
                    final categories = categoryBox.values.toList();
                    final items = itemBox.values.toList();

                    // Check if there are any items with inventory tracking enabled
                    final inventoryItems = items.where((item) => item.trackInventory == true).toList();

                    if (categories.isEmpty) {
                      return Center(
                        child: Text(
                          "No Categories Found",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      );
                    }

                    if (inventoryItems.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              "No Items with Inventory Tracking",
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Items with 'Manage Inventory' set to 'Yes' will appear here",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.all(16),
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

                        return Card(
                          margin: EdgeInsets.only(bottom: 8),
                          elevation: 2,
                          child: ExpansionTile(
                            title: Text(
                              category.name,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              '${categoryItems.length} items',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            leading: Icon(
                              Icons.category,
                              color: AppColors.primary,
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
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      drawer: DrawerManage(
        issync: false,
        isDelete: true,
        islogout: true,
      ),
    );
  }
}

