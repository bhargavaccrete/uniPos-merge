import 'dart:typed_data';

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
import '../../../../util/restaurant/decimal_settings.dart';
import '../../../../util/restaurant/currency_helper.dart';

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

class _ItemOptionsDialogState extends State<ItemOptionsDialog> with SingleTickerProviderStateMixin {
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

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();

    _prepareVariants();
    _prepareChoices();
    _prepareExtra();
    _recalculateTotal();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Minimum Requirements',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Text(
            'Please select the minimum required extras for this item.',
            style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: primarycolor.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('OK', style: GoogleFonts.poppins(color: primarycolor, fontWeight: FontWeight.w600)),
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
        imagePath:Uint8List(0),
        quantity: 1,
        categoryName: widget.categoryName,
        variantName:  _selectedVariant?.name,
        variantPrice: _selectedVariant?.price,
        choiceNames: _selectedChoices.map((c) => c.name).toList(),
        taxRate: widget.item.taxRate,
        extras: _selectedExtra.map((e) {
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: primarycolor.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with improved design
                      _buildHeader(),

                      const SizedBox(height: 20),

                      // Content sections
                      if (_displayVariants.isNotEmpty) ...[
                        _buildVariantSection(),
                        const SizedBox(height: 16),
                      ],

                      if (_displayChoiceGroups.isNotEmpty) ...[
                        _buildChoiceSection(),
                        const SizedBox(height: 16),
                      ],

                      if(_displayExtra.isNotEmpty) ...[
                        _buildExtraSection(),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),

              // Sticky bottom button
              _buildBottomButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item.name,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primarycolor,
                  height: 1.2,
                ),
              ),
              if (widget.categoryName != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primarycolor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.categoryName!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: primarycolor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.close, size: 24),
            color: primarycolor,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  Widget _buildVariantSection() {
    return Container(
      decoration: BoxDecoration(
        color: primarycolor.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primarycolor.withOpacity(0.1), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primarycolor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.straighten, color: primarycolor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Select Size',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: primarycolor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._displayVariants.asMap().entries.map((entry) {
            final index = entry.key;
            final variant = entry.value;
            final isSelected = _selectedVariant == variant;

            return Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedVariant = variant;
                    _selectedExtra.removeWhere((topping) {
                      if (topping.isContainSize == true && topping.variantPrices != null) {
                        return !topping.variantPrices!.containsKey(_selectedVariant?.id);
                      }
                      return false;
                    });
                    _recalculateTotal();
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? primarycolor : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? primarycolor : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: primarycolor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ] : [],
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? Colors.white : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.grey.shade400,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primarycolor,
                            ),
                          ),
                        )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          variant.name,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white.withOpacity(0.2) : primarycolor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(variant.price)}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : primarycolor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChoiceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _displayChoiceGroups.asMap().entries.map((groupEntry) {
        final groupIndex = groupEntry.key;
        final choiceGroup = groupEntry.value;

        return Container(
          margin: EdgeInsets.only(top: groupIndex == 0 ? 0 : 16),
          decoration: BoxDecoration(
            color: Colors.green.shade50.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.shade200.withOpacity(0.3), width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.checklist, color: Colors.green.shade700, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      choiceGroup.name,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...choiceGroup.choiceOption.asMap().entries.map((optionEntry) {
                final optionIndex = optionEntry.key;
                final option = optionEntry.value;
                final isSelected = _selectedChoices.contains(option);

                return Padding(
                  padding: EdgeInsets.only(top: optionIndex == 0 ? 0 : 8),
                  child: GestureDetector(
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
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.green.shade600 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.green.shade600 : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: isSelected ? Colors.white : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.grey.shade400,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? Icon(Icons.check, size: 16, color: Colors.green.shade600)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option.name,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExtraSection(){
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _displayExtra.asMap().entries.map((groupEntry) {
        final groupIndex = groupEntry.key;
        final extraGroup = groupEntry.value;

        final constraints = widget.item.extraConstraints?[extraGroup.Id];
        final minRequired = constraints?['min'] ?? 0;
        final maxAllowed = constraints?['max'] ?? 0;
        final currentCount = _getExtraCategoryCount(extraGroup.Id);

        final filteredToppings = extraGroup.topping!.where((topping) {
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

        if (filteredToppings.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: EdgeInsets.only(top: groupIndex == 0 ? 0 : 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.shade50.withOpacity(0.3),
                Colors.amber.shade50.withOpacity(0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.shade200.withOpacity(0.3), width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.add_circle_outline, color: Colors.orange.shade700, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          extraGroup.Ename,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange.shade900,
                          ),
                        ),
                        if (minRequired > 0 || maxAllowed > 0)
                          Text(
                            '${minRequired > 0 ? 'Min: $minRequired' : ''}${minRequired > 0 && maxAllowed > 0 ? ' • ' : ''}${maxAllowed > 0 ? 'Max: $maxAllowed' : ''}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (minRequired > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: currentCount >= minRequired
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            currentCount >= minRequired ? Icons.check_circle : Icons.info,
                            size: 14,
                            color: currentCount >= minRequired
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$currentCount/$minRequired',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: currentCount >= minRequired
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              if (maxAllowed > 0 && currentCount >= maxAllowed)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Maximum selection reached',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              ...filteredToppings.asMap().entries.map((toppingEntry) {
                final toppingIndex = toppingEntry.key;
                final topping = toppingEntry.value;

                double displayPrice = topping.price;
                if (_selectedVariant != null && topping.isContainSize == true && topping.variantPrices != null) {
                  displayPrice = topping.getPriceForVariant(_selectedVariant!.id);
                }

                final currentQuantity = _extraQuantities[topping.name] ?? 0;
                final canIncrement = maxAllowed == 0 || currentCount < maxAllowed;

                return Container(
                  margin: EdgeInsets.only(top: toppingIndex == 0 ? 0 : 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: currentQuantity > 0
                        ? Colors.white
                        : Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: currentQuantity > 0
                          ? Colors.orange.shade400
                          : Colors.grey.shade300,
                      width: currentQuantity > 0 ? 2 : 1,
                    ),
                    boxShadow: currentQuantity > 0 ? [
                      BoxShadow(
                        color: Colors.orange.shade200.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ] : [],
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
                                fontWeight: currentQuantity > 0 ? FontWeight.w600 : FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: primarycolor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(displayPrice)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: primarycolor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Quantity controls with improved design
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
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
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.remove,
                                    color: currentQuantity > 0 ? primarycolor : Colors.grey.shade400,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),

                            Container(
                              constraints: const BoxConstraints(minWidth: 36),
                              alignment: Alignment.center,
                              child: Text(
                                currentQuantity.toString(),
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: primarycolor,
                                ),
                              ),
                            ),

                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
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
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.add,
                                    color: canIncrement ? primarycolor : Colors.grey.shade400,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primarycolor, primarycolor.withOpacity(0.8)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primarycolor.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _confirmAndAddItem,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Total Amount',
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalPrice)}',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'Add to Cart',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}