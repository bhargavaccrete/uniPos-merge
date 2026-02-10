import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/data/models/restaurant/db/extramodel_303.dart';
import 'package:unipos/data/models/restaurant/db/toppingmodel_304.dart';
import 'package:unipos/data/models/restaurant/db/variantmodel_305.dart';
import 'package:uuid/uuid.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/restaurant/responsive_helper.dart';
import '../../../../util/common/app_responsive.dart';
import '../../../widget/componets/restaurant/componets/Textform.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';

class ExtraSelectionScreen extends StatefulWidget {
  final List<String> selectedExtraIds;

  const ExtraSelectionScreen({
    super.key,
    required this.selectedExtraIds,
  });

  @override
  State<ExtraSelectionScreen> createState() => _ExtraSelectionScreenState();
}

class _ExtraSelectionScreenState extends State<ExtraSelectionScreen> {
  List<Extramodel> availableExtras = [];
  Set<String> selectedExtraIds = {};

  @override
  void initState() {
    super.initState();
    _loadExtras();
    _initializeSelections();
  }

  void _loadExtras() {
    setState(() {
      availableExtras = extraStore.extras.toList();
    });
  }

  void _initializeSelections() {
    selectedExtraIds = Set<String>.from(widget.selectedExtraIds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add Extras',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: AppColors.primary),
            onPressed: () => _showAddExtraDialog(),
            tooltip: 'Add New Extra',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: availableExtras.isEmpty
                ? _buildEmptyState()
                : _buildExtraList(),
          ),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 80,
              color: Colors.grey[300],
            ),
            SizedBox(height: 20),
            Text(
              'No Extras Available',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Create your first extra category to get started',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            CommonButton(
              onTap: () => _showAddExtraDialog(),
              bgcolor: AppColors.primary,
              bordercircular: 10,
              height: 50,
              width: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Add Extra',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtraList() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select extra categories for this item:',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 20),

          ...availableExtras.map<Widget>((extra) {
            final isSelected = selectedExtraIds.contains(extra.Id);
            final toppingCount = extra.topping?.length ?? 0;

            return Container(
              margin: EdgeInsets.only(bottom: 15),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
                color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
              ),
              child: CheckboxListTile(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value ?? false) {
                      selectedExtraIds.add(extra.Id);
                    } else {
                      selectedExtraIds.remove(extra.Id);
                    }
                  });
                },
                activeColor: AppColors.primary,
                title: Text(
                  extra.Ename,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.black : Colors.grey[700],
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 5),
                    Text(
                      '$toppingCount topping${toppingCount != 1 ? 's' : ''} available',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                    if (extra.topping != null && extra.topping!.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: extra.topping!.take(3).map((topping) {
                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: topping.isveg ? Colors.green[100] : Colors.red[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: topping.isveg ? Colors.green : Colors.red,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  topping.name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList()
                          ..add(
                            extra.topping!.length > 3
                                ? Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '+${extra.topping!.length - 3}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            )
                                : Container(),
                          ),
                      ),
                    ],
                    SizedBox(height: 5),
                  ],
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: CommonButton(
              onTap: () => Navigator.pop(context),
              bgcolor: Colors.white,
              bordercolor: AppColors.primary,
              bordercircular: 10,
              height: AppResponsive.height(context, 0.06),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          SizedBox(width: 15),
          Expanded(
            child: CommonButton(
              onTap: () {
                Navigator.pop(context, selectedExtraIds.toList());
              },
              bordercircular: 10,
              height: AppResponsive.height(context, 0.06),
              child: Text(
                'Save',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddExtraDialog() {
    final extraNameController = TextEditingController();
    // Load variants for "Contains Size" feature
    final availableVariants = variantStore.variants.toList();

    // Data structure to hold topping inputs including variant prices
    final List<Map<String, dynamic>> toppingData = [
      {
        'nameController': TextEditingController(),
        'priceController': TextEditingController(),
        'isVeg': true,
        'hasSize': false,
        'variantPriceControllers': <String, TextEditingController>{}, // map variantId -> controller
        'selectedVariants': <String>{}, // set of selected variant IDs
      }
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Add New Extra',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter extra category name and toppings',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 15),
                    CommonTextForm(
                      controller: extraNameController,
                      labelText: 'Category Name (e.g., Add-ons)',
                      obsecureText: false,
                      borderc: 8,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Toppings:',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 10),
                    ...List.generate(toppingData.length, (index) {
                      final data = toppingData[index];
                      final bool hasSize = data['hasSize'];
                      final Map<String, TextEditingController> variantControllers = data['variantPriceControllers'];
                      final Set<String> selectedVariants = data['selectedVariants'];

                      return Container(
                        margin: EdgeInsets.only(bottom: 15),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Topping ${index + 1}',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                                if (toppingData.length > 1)
                                  IconButton(
                                    icon: Icon(Icons.remove_circle, color: Colors.red, size: 20),
                                    onPressed: () {
                                      setDialogState(() {
                                        data['nameController'].dispose();
                                        data['priceController'].dispose();
                                        // Dispose variant controllers
                                        variantControllers.values.forEach((c) => c.dispose());
                                        toppingData.removeAt(index);
                                      });
                                    },
                                  ),
                              ],
                            ),
                            SizedBox(height: 8),
                            CommonTextForm(
                              controller: data['nameController'],
                              labelText: 'Topping Name',
                              obsecureText: false,
                              borderc: 8,
                            ),
                            SizedBox(height: 10),
                            // Veg/Non-Veg Selection
                            Row(
                              children: [
                                Text(
                                  'Type:',
                                  style: GoogleFonts.poppins(fontSize: 13),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Radio<bool>(
                                        value: true,
                                        groupValue: data['isVeg'],
                                        onChanged: (value) {
                                          setDialogState(() {
                                            data['isVeg'] = value!;
                                          });
                                        },
                                        activeColor: Colors.green,
                                      ),
                                      Icon(Icons.circle, color: Colors.green, size: 12),
                                      SizedBox(width: 4),
                                      Text('Veg', style: GoogleFonts.poppins(fontSize: 12)),
                                      SizedBox(width: 15),
                                      Radio<bool>(
                                        value: false,
                                        groupValue: data['isVeg'],
                                        onChanged: (value) {
                                          setDialogState(() {
                                            data['isVeg'] = value!;
                                          });
                                        },
                                        activeColor: Colors.red,
                                      ),
                                      Icon(Icons.circle, color: Colors.red, size: 12),
                                      SizedBox(width: 4),
                                      Text('Non-Veg', style: GoogleFonts.poppins(fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            // Contains Size Checkbox
                            if (availableVariants.isNotEmpty)
                              Row(
                                children: [
                                  Checkbox(
                                    value: hasSize,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        data['hasSize'] = value!;
                                        if (value) {
                                          // Initialize variant controllers if needed
                                          if (selectedVariants.isEmpty) {
                                            // Auto-select all or none? Let's leave empty and let user select
                                          }
                                        } else {
                                          // Clear logic if unchecked? Keep data for now or clear?
                                        }
                                      });
                                    },
                                    activeColor: AppColors.primary,
                                  ),
                                  Text(
                                    'Contains Size (Variant Pricing)',
                                    style: GoogleFonts.poppins(fontSize: 13),
                                  ),
                                ],
                              ),

                            // Price Input (Show if NO size or used as base price)
                            if (!hasSize) ...[
                              SizedBox(height: 10),
                              CommonTextForm(
                                controller: data['priceController'],
                                labelText: 'Price',
                                obsecureText: false,
                                borderc: 8,
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                              ),
                            ] else ...[
                              // Variant Pricing Section
                              Padding(
                                padding: const EdgeInsets.only(left: 10, top: 5),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Select Variants & Set Prices:',
                                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    SizedBox(height: 5),
                                    ...availableVariants.map((variant) {
                                      final isSelected = selectedVariants.contains(variant.id);
                                      // Ensure controller exists if selected
                                      if (isSelected && !variantControllers.containsKey(variant.id)) {
                                        variantControllers[variant.id] = TextEditingController();
                                      }

                                      return Row(
                                        children: [
                                          Checkbox(
                                            value: isSelected,
                                            onChanged: (val) {
                                              setDialogState(() {
                                                if (val == true) {
                                                  selectedVariants.add(variant.id);
                                                  if (!variantControllers.containsKey(variant.id)) {
                                                    variantControllers[variant.id] = TextEditingController();
                                                  }
                                                } else {
                                                  selectedVariants.remove(variant.id);
                                                }
                                              });
                                            },
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              variant.name,
                                              style: GoogleFonts.poppins(fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isSelected)
                                            Expanded(
                                              flex: 3,
                                              child: SizedBox(
                                                height: 40,
                                                child: TextField(
                                                  controller: variantControllers[variant.id],
                                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                                  decoration: InputDecoration(
                                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                                    prefixText: '₹',
                                                    hintText: '0',
                                                  ),
                                                  style: GoogleFonts.poppins(fontSize: 12),
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () {
                        setDialogState(() {
                          toppingData.add({
                            'nameController': TextEditingController(),
                            'priceController': TextEditingController(),
                            'isVeg': true,
                            'hasSize': false,
                            'variantPriceControllers': <String, TextEditingController>{},
                            'selectedVariants': <String>{},
                          });
                        });
                      },
                      icon: Icon(Icons.add_circle_outline, color: AppColors.primary),
                      label: Text(
                        'Add Topping',
                        style: GoogleFonts.poppins(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    for (var data in toppingData) {
                      data['nameController'].dispose();
                      data['priceController'].dispose();
                      (data['variantPriceControllers'] as Map<String, TextEditingController>).values.forEach((c) => c.dispose());
                    }
                    extraNameController.dispose();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (extraNameController.text.trim().isEmpty) {
                      NotificationService.instance.showError('Please enter an extra category name');
                      return;
                    }

                    // Collect all valid toppings
                    final toppings = <Topping>[];
                    for (var data in toppingData) {
                      final name = data['nameController'].text.trim();
                      final bool hasSize = data['hasSize'];
                      final Map<String, TextEditingController> variantControllers = data['variantPriceControllers'];
                      final Set<String> selectedVariants = data['selectedVariants'];

                      if (name.isEmpty) continue;

                      double basePrice = 0.0;
                      Map<String, double>? variantPrices;

                      if (hasSize) {
                        variantPrices = {};
                        if (selectedVariants.isEmpty) {
                          // Skip if contains size but no variants selected?
                          // Or allow with 0 prices? Let's skip invalid ones or warn
                          // For now, continuing
                        }
                        for (var variantId in selectedVariants) {
                          final priceText = variantControllers[variantId]?.text.trim() ?? '0';
                          final price = double.tryParse(priceText) ?? 0.0;
                          variantPrices[variantId] = price;
                          // Set base price to first variant's price as fallback
                          if (basePrice == 0.0) basePrice = price;
                        }
                      } else {
                        final priceText = data['priceController'].text.trim();
                        basePrice = double.tryParse(priceText) ?? 0.0;
                      }

                      toppings.add(Topping(
                        name: name,
                        isveg: data['isVeg'],
                        price: basePrice,
                        isContainSize: hasSize,
                        variantPrices: variantPrices,
                      ));
                    }

                    if (toppings.isEmpty) {
                      NotificationService.instance.showError('Please add at least one valid topping');
                      return;
                    }

                    final newExtra = Extramodel(
                      Id: Uuid().v4(),
                      Ename: extraNameController.text.trim(),
                      isEnabled: true,
                      topping: toppings,
                    );

                    await extraStore.addExtra(newExtra);

                    // Unfocus keyboard first
                    FocusScope.of(context).unfocus();

                    // Close the dialog
                    Navigator.of(context).pop();

                    // After dialog is closed, dispose controllers
                    await Future.delayed(Duration(milliseconds: 100));
                    for (var data in toppingData) {
                      data['nameController'].dispose();
                      data['priceController'].dispose();
                      (data['variantPriceControllers'] as Map<String, TextEditingController>).values.forEach((c) => c.dispose());
                    }
                    extraNameController.dispose();

                    // Reload extras in parent widget
                    if (mounted) {
                      _loadExtras();
                    }

                    // Show success message
                    NotificationService.instance.showSuccess('Extra "${newExtra.Ename}" added with ${toppings.length} toppings');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: Text(
                    'Add',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}