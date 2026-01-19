
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:unipos/util/color.dart';
import 'package:uuid/uuid.dart';

import '../../../../constants/restaurant/color.dart';
import '../../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../../data/models/restaurant/db/choicemodel_306.dart';
import '../../../../data/models/restaurant/db/choiceoptionmodel_307.dart';
import '../../../../data/models/restaurant/db/extramodel_303.dart';
import '../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../data/models/restaurant/db/itemvariantemodel_312.dart';
import '../../../../data/models/restaurant/db/toppingmodel_304.dart';
import '../../../../data/models/restaurant/db/variantmodel_305.dart';
import '../../../../util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
class DisplayVariant {
  final String id;
  final String name;
  final double price;
  DisplayVariant({required this.id, required this.name, required this.price});
}

class ItemOptionsDialog extends StatefulWidget {
  final Items item;
  final String? categoryName;

  const ItemOptionsDialog({super.key, required this.item,
    this.categoryName
  });

  @override
  State<ItemOptionsDialog> createState() => _ItemOptionsDialogState();
}

class _ItemOptionsDialogState extends State<ItemOptionsDialog> {
  // State for Variants
  List<DisplayVariant> _displayVariants = [];
  DisplayVariant? _selectedVariant;

  // State for Choices
  List<ChoicesModel> _displayChoiceGroups = [];
  Set<ChoiceOption> _selectedChoices = {}; // Use a Set to store multiple selected choices

  List<Extramodel> _displayExtra = [];
  Set<Topping> _selectedExtra ={};

  // Track quantity of each extra topping
  Map<String, int> _extraQuantities = {}; // toppingId -> quantity

  double _totalPrice = 0.0;

  @override
  void initState() {
    super.initState();
    _prepareVariants();
    _prepareChoices();
    _prepareExtra();
    _recalculateTotal();
  }

  void _prepareVariants() {
    if (widget.item.variant == null || widget.item.variant!.isEmpty) return;
    final variantBox = Hive.box<VariantModel>('variante');

    for (ItemVariante itemVariant in widget.item.variant!) {
      // Use direct key lookup which is O(1) and safer
      final variantDetails = variantBox.get(itemVariant.variantId);

      if (variantDetails != null) {
        _displayVariants.add(DisplayVariant(id: variantDetails.id, name: variantDetails.name, price: itemVariant.price));
      } else {
        print("Warning: Variant ID ${itemVariant.variantId} found in item but not in 'variante' box.");
      }
    }
    if (_displayVariants.isNotEmpty) {
      _selectedVariant = _displayVariants.first;
    }
  }

  void _prepareChoices() {
    if (widget.item.choiceIds == null || widget.item.choiceIds!.isEmpty) return;
    final choiceBox = Hive.box<ChoicesModel>('choice'); // Use your choice group box name
    for (String choiceId in widget.item.choiceIds!) {
      // Use direct key lookup
      final choiceGroup = choiceBox.get(choiceId);

      if (choiceGroup != null) {
        _displayChoiceGroups.add(choiceGroup);
      } else {
         print("Warning: Choice ID $choiceId found in item but not in 'choice' box.");
      }
    }
  }

  void _prepareExtra(){
    if(widget.item.extraId == null || widget.item.extraId!.isEmpty) return ;
    final ExtraBox = Hive.box<Extramodel>('extra');
    for(String extraId in widget.item.extraId!){
      // Use direct key lookup
      final extraGroup = ExtraBox.get(extraId);

      if(extraGroup != null){
        _displayExtra.add(extraGroup);
        // Initialize quantities for all toppings in this category
        if (extraGroup.topping != null) {
          for (var topping in extraGroup.topping!) {
            _extraQuantities[topping.name] = 0;
          }
        }
      } else {
         print("Warning: Extra ID $extraId found in item but not in 'extra' box.");
      }
    }

  }

  // Helper method to get total count of extras in a category
  int _getExtraCategoryCount(String categoryId) {
    int count = 0;
    final category = _displayExtra.firstWhere((e) => e.Id == categoryId, orElse: () => Extramodel(Id: '', Ename: 'Unknown'));
    if (category.Ename != 'Unknown' && category.topping != null) {
      for (var topping in category.topping!) {
        count += _extraQuantities[topping.name] ?? 0;
      }
    }
    return count;
  }

  // Helper method to check if minimum requirements are met
  bool _validateMinimumRequirements() {
    if (widget.item.extraConstraints == null) return true;

    for (var extraGroup in _displayExtra) {
      final constraints = widget.item.extraConstraints![extraGroup.Id];
      if (constraints != null) {
        final minRequired = constraints['min'] ?? 0;
        if (minRequired > 0) {
          final currentCount = _getExtraCategoryCount(extraGroup.Id);
          if (currentCount < minRequired) {
            return false;
          }
        }
      }
    }
    return true;
  }


  void _recalculateTotal() {
    double price = 0.0;
    // Add price from the selected variant
    if (_selectedVariant != null) {
      price += _selectedVariant!.price;
    } else {
      price = widget.item.price ?? 0.0;
    }

    // Add prices from extras based on quantities
    for (var extraGroup in _displayExtra) {
      if (extraGroup.topping != null) {
        for (var topping in extraGroup.topping!) {
          final quantity = _extraQuantities[topping.name] ?? 0;
          if (quantity > 0) {
            double toppingPrice = topping.price;
            // Use variant-specific price if available and variant is selected
            if (_selectedVariant != null && topping.isContainSize == true && topping.variantPrices != null) {
              toppingPrice = topping.getPriceForVariant(_selectedVariant!.id);
            }
            price += toppingPrice * quantity;
          }
        }
      }
    }

    setState(() {
      _totalPrice = price;
    });
  }

  void _confirmAndAddItem() {
    // Validate minimum requirements for extras
    if (!_validateMinimumRequirements()) {
      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Minimum Requirements Not Met', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text(
            'Please select the minimum required extras for this item.',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: GoogleFonts.poppins(color: AppColors.primary)),
            ),
          ],
        ),
      );
      return;
    }

    String finalTitle = widget.item.name;

    print("DEBUG in Dialog: Received category name: '${widget.categoryName}'");

    final cartItem = CartItem(
        productId: widget.item.id,
        isStockManaged: widget.item.trackInventory,
        id: const Uuid().v4(),
        title: finalTitle,
        price: _totalPrice,
        imagePath: '',
        quantity: 1,
        categoryName: widget.categoryName,
        variantName:  _selectedVariant?.name,
        variantPrice: _selectedVariant?.price,
        choiceNames: _selectedChoices.map((c) => c.name).toList(),
        taxRate: widget.item.taxRate,
        extras: _selectedExtra.map((e) {
          // Find the category this extra belongs to
          String categoryName = '';
          String categoryId = '';
          for (var extraGroup in _displayExtra) {
            if (extraGroup.topping!.contains(e)) {
              categoryName = extraGroup.Ename;
              categoryId = extraGroup.Id;
              break;
            }
          }

          final displayName = categoryName.isNotEmpty ? '$categoryName - ${e.name}' : e.name;
          final finalPrice = _selectedVariant != null && e.isContainSize == true && e.variantPrices != null
              ? e.getPriceForVariant(_selectedVariant!.id)
              : e.price;

          // Get the quantity for this extra
          final quantity = _extraQuantities[e.name] ?? 1;

          print('Extra Debug: Category="$categoryName", Name="${e.name}", DisplayName="$displayName", Quantity=$quantity');

          return {
            'name': e.name,
            'displayName': displayName,
            'price': finalPrice,
            'categoryName': categoryName,
            'categoryId': categoryId,
            'quantity': quantity,
          };
        }).toList()
    );

    print(cartItem);
    Navigator.of(context).pop(cartItem);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.name,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (widget.categoryName != null) ...[
                        SizedBox(height: 4),
                        Text(
                          widget.categoryName!,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMedium,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 20),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Variants Section ---
                  if (_displayVariants.isNotEmpty) _buildVariantSection(),

                  // --- Choices Section ---
                  if (_displayChoiceGroups.isNotEmpty) _buildChoiceSection(),

                  // ------Extra Section-----
                  if(_displayExtra.isNotEmpty) _buildExtraSection(),
                ],
              ),
            ),
          ),

          // Bottom Add to Cart button
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: GestureDetector(
                onTap: _confirmAndAddItem,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primary],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Total Amount',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.white.withOpacity(0.8),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalPrice)}',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            'Add to Cart',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, color: AppColors.white, size: 20),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceMedium,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.straighten_rounded, size: 16, color: AppColors.textSecondary),
            ),
            SizedBox(width: 10),
            Text(
              'Select Size',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        ..._displayVariants.map((variant) {
          final isSelected = _selectedVariant == variant;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedVariant = variant;
                // Clear selected extras that are not available for the new variant
                _selectedExtra.removeWhere((topping) {
                  if (topping.isContainSize == true && topping.variantPrices != null) {
                    return !topping.variantPrices!.containsKey(_selectedVariant?.id);
                  }
                  return false;
                });
                _recalculateTotal();
              });
            },
            child: Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.divider,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.white : AppColors.divider,
                        width: 2,
                      ),
                      color: isSelected ? AppColors.white : Colors.transparent,
                    ),
                    child: isSelected
                        ? Center(
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : null,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      variant.name,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? AppColors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.white.withOpacity(0.2) : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(variant.price)}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? AppColors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildChoiceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _displayChoiceGroups.map((choiceGroup) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMedium,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.checklist_rounded, size: 16, color: AppColors.textSecondary),
                ),
                SizedBox(width: 10),
                Text(
                  choiceGroup.name,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ...choiceGroup.choiceOption.map((option) {
              final isSelected = _selectedChoices.contains(option);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedChoices.remove(option);
                    } else {
                      _selectedChoices.add(option);
                    }
                    _recalculateTotal();
                  });
                },
                child: Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.divider,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.divider,
                            width: 2,
                          ),
                          color: isSelected ? AppColors.primary : Colors.transparent,
                        ),
                        child: isSelected
                            ? Icon(Icons.check, size: 14, color: AppColors.white)
                            : null,
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          option.name,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildExtraSection(){
    return Column(
        crossAxisAlignment:  CrossAxisAlignment.start,
        children: _displayExtra.map((extraGroup){
          // Get min/max constraints for this extra category
          final constraints = widget.item.extraConstraints?[extraGroup.Id];
          final minRequired = constraints?['min'] ?? 0;
          final maxAllowed = constraints?['max'] ?? 0;
          final currentCount = _getExtraCategoryCount(extraGroup.Id);

          // First, filter the toppings for this extra group
          final filteredToppings = extraGroup.topping!.where((topping) {
            // Filter toppings based on size availability
            if (topping.isContainSize == true) {
              if (_selectedVariant != null && topping.variantPrices != null) {
                if (topping.variantPrices!.containsKey(_selectedVariant!.id)) {
                  final price = topping.variantPrices![_selectedVariant!.id] ?? 0.0;
                  return price > 0;
                }
                return false;
              }
              return false;
            }
            return true;
          }).toList();

          // Only show this extra group if there are toppings to display
          if (filteredToppings.isEmpty) {
            return const SizedBox.shrink();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMedium,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.add_circle_outline, size: 16, color: AppColors.textSecondary),
                  ),
                  SizedBox(width: 10),
                  Text(
                    extraGroup.Ename,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (minRequired > 0 || maxAllowed > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '(${minRequired > 0 ? 'Min: $minRequired' : ''}${minRequired > 0 && maxAllowed > 0 ? ', ' : ''}${maxAllowed > 0 ? 'Max: $maxAllowed' : ''})',
                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 12),
              if (maxAllowed > 0 && currentCount >= maxAllowed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Maximum selection reached',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w500),
                  ),
                ),
              ...filteredToppings.map((topping){
                // Calculate the display price based on selected variant
                double displayPrice = topping.price;
                if (_selectedVariant != null && topping.isContainSize == true && topping.variantPrices != null) {
                  displayPrice = topping.getPriceForVariant(_selectedVariant!.id);
                }

                final currentQuantity = _extraQuantities[topping.name] ?? 0;
                final canIncrement = maxAllowed == 0 || currentCount < maxAllowed;

                return Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: currentQuantity > 0 ? AppColors.primary.withOpacity(0.05) : AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: currentQuantity > 0 ? AppColors.primary.withOpacity(0.3) : AppColors.divider,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topping.name,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(displayPrice)}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Quantity controls
                      Row(
                        children: [
                          GestureDetector(
                            onTap: currentQuantity > 0 ? () {
                              setState(() {
                                final newQuantity = currentQuantity - 1;
                                _extraQuantities[topping.name] = newQuantity;
                                if (newQuantity == 0) {
                                  _selectedExtra.remove(topping);
                                }
                                _recalculateTotal();
                              });
                            } : null,
                            child: Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: currentQuantity > 0 ? AppColors.primary.withOpacity(0.1) : AppColors.surfaceMedium,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.remove,
                                size: 18,
                                color: currentQuantity > 0 ? AppColors.primary : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Container(
                            width: 40,
                            alignment: Alignment.center,
                            child: Text(
                              currentQuantity.toString(),
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: canIncrement ? () {
                              setState(() {
                                final newQuantity = currentQuantity + 1;
                                _extraQuantities[topping.name] = newQuantity;
                                if (newQuantity == 1) {
                                  _selectedExtra.add(topping);
                                }
                                _recalculateTotal();
                              });
                            } : null,
                            child: Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: canIncrement ? AppColors.primary : AppColors.surfaceMedium,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.add,
                                size: 18,
                                color: canIncrement ? AppColors.white : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
              SizedBox(height: 16),
            ],
          );

        }).toList()
    );
  }

}
