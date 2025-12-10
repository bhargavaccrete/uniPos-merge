
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
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


// Helper class for variants
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
    final variantBox = Hive.box<VariantModel>('variants');
    // ... (This logic is the same as before)
    for (ItemVariante itemVariant in widget.item.variant!) {
      final variantDetails = variantBox.values.firstWhere((v) => v.id == itemVariant.variantId, orElse: () => VariantModel(id: '', name: 'Unknown'));
      if (variantDetails.name != 'Unknown') {
        _displayVariants.add(DisplayVariant(id: variantDetails.id, name: variantDetails.name, price: itemVariant.price));
      }
    }
    if (_displayVariants.isNotEmpty) {
      _selectedVariant = _displayVariants.first;
    }
  }

  void _prepareChoices() {
    if (widget.item.choiceIds == null || widget.item.choiceIds!.isEmpty) return;
    final choiceBox = Hive.box<ChoicesModel>('choices'); // Use your choice group box name
    for (String choiceId in widget.item.choiceIds!) {
      final choiceGroup = choiceBox.values.firstWhere((c) => c.id == choiceId, orElse: () => ChoicesModel(id: '', name: 'Unknown'));
      if (choiceGroup.name != 'Unknown') {
        _displayChoiceGroups.add(choiceGroup);
      }
    }
  }

  void _prepareExtra(){
    if(widget.item.extraId == null || widget.item.extraId!.isEmpty) return ;
    final ExtraBox = Hive.box<Extramodel>('extras');
    for(String extraId in widget.item.extraId!){
      final extraGroup = ExtraBox.values.firstWhere((e)=> e.Id == extraId, orElse:  ()=> Extramodel(Id: '', Ename: 'Unknown'));
      if(extraGroup.Ename != 'Unknown'){
        _displayExtra.add(extraGroup);
        // Initialize quantities for all toppings in this category
        if (extraGroup.topping != null) {
          for (var topping in extraGroup.topping!) {
            _extraQuantities[topping.name] = 0;
          }
        }
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

  // void _confirmAndAddItem() {
  //   // Build the final title string
  //   List<String> optionNames = [];
  //   if (_selectedVariant != null) {
  //     optionNames.add(_selectedVariant!.name);
  //   }
  //   for (var choice in _selectedChoices) {
  //     optionNames.add(choice.name);
  //   }
  //   String finalTitle = widget.item.name;
  //   if (optionNames.isNotEmpty) {
  //     finalTitle += ' (${optionNames.join(', ')})';
  //   }
  //
  //   // Create the final CartItem
  //   final cartItem = CartItem(
  //     id: const Uuid().v4(),
  //     // title: finalTitle,
  //     title: widget.item.name,
  //     price: _totalPrice,
  //     imagePath: widget.item.imagePath ?? '',
  //     quantity: 1,
  //
  //     variantName:  _selectedVariant?.name,
  //     variantPrice: _selectedVariant?.price,
  //     choiceNames: _selectedChoices.map((c)=> c.name).toList()
  //
  //   );
  //   Navigator.of(context).pop(cartItem);
  // }

  // ... inside _ItemOptionsDialogState class

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
              child: Text('OK', style: GoogleFonts.poppins(color: primarycolor)),
            ),
          ],
        ),
      );
      return;
    }

    // --- MODIFIED LOGIC ---
    // The title will now only contain the item name and its selected variant.
    String finalTitle = widget.item.name;
    // if (_selectedVariant != null) {
    //   finalTitle += ' (${_selectedVariant!.name})';
    // }
    // --- END OF MODIFICATION ---

    // Create the final CartItem with separate fields

    print("DEBUG in Dialog: Received category name: '${widget.categoryName}'");

    final cartItem = CartItem(
      productId: widget.item.id,
      isStockManaged: widget.item.trackInventory,
        id: const Uuid().v4(),
        // 1. The title is now clean.
        title: finalTitle,
        price: _totalPrice,
        imagePath: widget.item.imagePath ?? '',
        quantity: 1,
        // 2. The variant info is stored separately.
        categoryName: widget.categoryName,
        variantName:  _selectedVariant?.name,
        variantPrice: _selectedVariant?.price,
        // 3. The choices are stored *only* in this list, not in the title.
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
        
        print('Extra Debug: Category="$categoryName", Name="${e.name}", DisplayName="$displayName"');
        
        return {
          'name': e.name,
          'displayName': displayName,
          'price': finalPrice,
          'categoryName': categoryName,
          'categoryId': categoryId,
        };
      }).toList()
    );

    print(cartItem);
    Navigator.of(context).pop(cartItem);
  }

// ... rest of the class
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(

        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(widget.item.name, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const Divider(),

            // --- Variants Section ---
            if (_displayVariants.isNotEmpty) _buildVariantSection(),

            // --- Choices Section ---
            if (_displayChoiceGroups.isNotEmpty) _buildChoiceSection(),


            // ------Extra Section-----
            if(_displayExtra.isNotEmpty) _buildExtraSection(),

            const SizedBox(height: 20),
            // Total and Add Button
            Container(
              decoration: BoxDecoration(color: primarycolor, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Text('Total: Rs. ${_totalPrice.toStringAsFixed(2)}', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)))),
                  TextButton(
                    style: TextButton.styleFrom(backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8))), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                    onPressed: _confirmAndAddItem,
                    child: Text('Add Item', style: GoogleFonts.poppins(color: primarycolor, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text('Select Size', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600))),
        ..._displayVariants.map((variant) => RadioListTile<DisplayVariant>(
          title: Text(variant.name),
          secondary: Text('Rs. ${variant.price.toStringAsFixed(2)}'),
          value: variant,
          groupValue: _selectedVariant,
          onChanged: (newValue) {
            setState(() {
              _selectedVariant = newValue;
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
          activeColor: primarycolor,
          contentPadding: EdgeInsets.zero,
        )),
        const Divider(),
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
            Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(choiceGroup.name, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600))),
            ...choiceGroup.choiceOption.map((option) {
              return CheckboxListTile(
                title: Text(option.name),
                // Note: Add a secondary widget here if your choices have a price.
                value: _selectedChoices.contains(option),
                onChanged: (bool? isSelected) {
                  setState(() {
                    if (isSelected == true) {
                      _selectedChoices.add(option);
                    } else {
                      _selectedChoices.remove(option);
                    }
                    _recalculateTotal();
                  });
                },
                activeColor: Colors.teal,
                contentPadding: EdgeInsets.zero,
              );
            }).toList(),
            const Divider(),
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
            // If topping is size-dependent, only show it if:
            // 1. A variant is selected AND
            // 2. The topping has a price for that variant AND
            // 3. The price is greater than 0
            if (_selectedVariant != null && topping.variantPrices != null) {
              if (topping.variantPrices!.containsKey(_selectedVariant!.id)) {
                final price = topping.variantPrices![_selectedVariant!.id] ?? 0.0;
                // Only show if price is greater than 0
                return price > 0;
              }
              return false;
            }
            // Don't show size-dependent toppings when no variant is selected
            return false;
          }
          // If topping is not size-dependent, always show it (unless you want to filter by base price)
          return true;
        }).toList();

        // Only show this extra group if there are toppings to display
        if (filteredToppings.isEmpty) {
          return const SizedBox.shrink(); // Return empty widget
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Text(extraGroup.Ename, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                  if (minRequired > 0 || maxAllowed > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '(${minRequired > 0 ? 'Min: $minRequired' : ''}${minRequired > 0 && maxAllowed > 0 ? ', ' : ''}${maxAllowed > 0 ? 'Max: $maxAllowed' : ''})',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
            if (maxAllowed > 0 && currentCount >= maxAllowed)
              Padding(
                padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                child: Text(
                  'Maximum selection reached',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange[700], fontWeight: FontWeight.w500),
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

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    // Topping name and price
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(topping.name, style: GoogleFonts.poppins(fontSize: 14)),
                          Text('Rs. ${displayPrice.toStringAsFixed(2)}',
                               style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),

                    // Quantity controls
                    Row(
                      children: [
                        // Minus button
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline, color: currentQuantity > 0 ? primarycolor : Colors.grey[400]),
                          onPressed: currentQuantity > 0 ? () {
                            setState(() {
                              _extraQuantities[topping.name] = currentQuantity - 1;
                              _recalculateTotal();
                            });
                          } : null,
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),

                        // Quantity display
                        Container(
                          width: 40,
                          alignment: Alignment.center,
                          child: Text(
                            currentQuantity.toString(),
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),

                        // Plus button
                        IconButton(
                          icon: Icon(Icons.add_circle_outline, color: canIncrement ? primarycolor : Colors.grey[400]),
                          onPressed: canIncrement ? () {
                            setState(() {
                              _extraQuantities[topping.name] = currentQuantity + 1;
                              _recalculateTotal();
                            });
                          } : null,
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
            const Divider()

          ],
        );

      }).toList()
    );


  }

}