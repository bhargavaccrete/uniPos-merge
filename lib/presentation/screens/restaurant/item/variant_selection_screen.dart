import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/data/models/restaurant/db/variantmodel_305.dart';
import 'package:uuid/uuid.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/restaurant/responsive_helper.dart';
import '../../../../util/common/app_responsive.dart';
import '../../../widget/componets/restaurant/componets/Textform.dart';
import 'package:unipos/core/di/service_locator.dart';

class VariantSelectionScreen extends StatefulWidget {
  final List<Map<String, dynamic>> selectedVariants;

  const VariantSelectionScreen({
    super.key,
    required this.selectedVariants,
  });

  @override
  State<VariantSelectionScreen> createState() => _VariantSelectionScreenState();
}

class _VariantSelectionScreenState extends State<VariantSelectionScreen> {
  List<VariantModel> availableVariants = [];
  Map<String, bool> selectedVariantIds = {};
  Map<String, TextEditingController> priceControllers = {};

  @override
  void initState() {
    super.initState();
    _loadVariants();
    // _initializeSelections();
  }

  // void _loadVariants() {
  //   final variantBox = Hive.box<VariantModel>('variante');
  //   if (mounted) {
  //     setState(() {
  //       availableVariants = variantBox.values.toList();
  //       // Initialize controllers for any new variants
  //       for (var variant in availableVariants) {
  //         if (!priceControllers.containsKey(variant.id)) {
  //           priceControllers[variant.id] = TextEditingController();
  //         }
  //         if (!selectedVariantIds.containsKey(variant.id)) {
  //           selectedVariantIds[variant.id] = false;
  //         }
  //       }
  //     });
  //   }
  // }

  // void _loadVariants() {
  //   final variantBox = Hive.box<VariantModel>('variante');
  //   final variants = variantBox.values.toList();
  //
  //   // Create controllers BEFORE setState
  //   for (var variant in variants) {
  //
  //     priceControllers.putIfAbsent(
  //       variant.id,
  //           () => TextEditingController(),
  //     );
  //     selectedVariantIds.putIfAbsent(variant.id, () => false);
  //   }
  //
  //   if (!mounted) return;
  //
  //   setState(() {
  //     availableVariants = variants;
  //   });
  //   _initializeSelections();
  //
  // }

  void _loadVariants() {
    final variants = variantStore.variants.toList();

    // Ensure we don't leak controllers
    for (var variant in variants) {
      if (!priceControllers.containsKey(variant.id)) {
        priceControllers[variant.id] = TextEditingController();
      }
      selectedVariantIds.putIfAbsent(variant.id, () => false);
    }

    if (mounted) {
      setState(() {
        availableVariants = variants;
      });
      _initializeSelections();
    }
  }


  void _initializeSelections() {
    // Initialize from existing selections
    for (var selectedVariant in widget.selectedVariants) {
      selectedVariantIds[selectedVariant['variantId']] = true;
      priceControllers[selectedVariant['variantId']] = TextEditingController(
        text: selectedVariant['price'].toString(),
      );
    }

    // Initialize controllers for all variants
    for (var variant in availableVariants) {
      if (!priceControllers.containsKey(variant.id)) {
        priceControllers[variant.id] = TextEditingController();
      }
      if (!selectedVariantIds.containsKey(variant.id)) {
        selectedVariantIds[variant.id] = false;
      }
    }
  }

  @override
  void dispose() {
    for (var controller in priceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> _getSelectedVariants() {
    List<Map<String, dynamic>> result = [];

    selectedVariantIds.forEach((variantId, isSelected) {
      if (isSelected) {
        final variant = availableVariants.firstWhere(
              (v) => v.id == variantId,
          orElse: () => VariantModel(id: '', name: ''),
        );

        if (variant.id.isNotEmpty) {
          final price = double.tryParse(priceControllers[variantId]?.text ?? '') ?? 0.0;
          result.add({
            'variantId': variantId,
            'price': price,
            'name': variant.name,
          });
        }
      }
    });

    return result;
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
          'Add Variants',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: AppColors.primary),
            onPressed: () => _showAddVariantDialog(),
            tooltip: 'Add New Variant',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: availableVariants.isEmpty
                ? _buildEmptyState()
                : _buildVariantList(),
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
              Icons.straighten_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            SizedBox(height: 20),
            Text(
              'No Variants Available',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Create your first variant to get started',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            CommonButton(
              onTap: () => _showAddVariantDialog(),
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
                    'Add Variant',
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

  Widget _buildVariantList() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select variants for this item and set their prices:',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 20),

          ...availableVariants.map<Widget>((variant) {
            final isSelected = selectedVariantIds[variant.id] ?? false;
            final controller = priceControllers[variant.id]!;

            return Container(
              margin: EdgeInsets.only(bottom: 15),
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
                color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            selectedVariantIds[variant.id] = value ?? false;
                            if (!(value ?? false)) {
                              controller.clear();
                            }
                          });
                        },
                        activeColor: AppColors.primary,
                      ),
                      Expanded(
                        child: Text(
                          variant.name,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.black : Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (isSelected) ...[
                    SizedBox(height: 10),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Price for ${variant.name}',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ],
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
                final selectedVariants = _getSelectedVariants();
                Navigator.pop(context, selectedVariants);
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

  void _showAddVariantDialog() {
    final variantNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'Add New Variant',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter variant name (e.g., Small, Medium, Large)',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 15),
                CommonTextForm(
                  controller: variantNameController,
                  labelText: 'Variant Name',
                  obsecureText: false,
                  borderc: 8,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final String name = variantNameController.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a variant name'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }

                // Create and save the variant using store
                final newVariant = VariantModel(
                  id: const Uuid().v4(),
                  name: name,
                );

                await variantStore.addVariant(newVariant);

                // Reload the list to show the new variant
                _loadVariants();

                // Close dialog and pass the variant name for success message
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(name);
                }
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
    ).then((variantName) {
      // CRITICAL: Dispose controller AFTER dialog is completely closed
      // Wait one frame to ensure dialog animation is complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        variantNameController.dispose();
      });

      // Handle success case
      if (variantName != null && variantName is String) {
        // Wait for dialog to fully close before updating UI
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;

          // Reload variants
          _loadVariants();

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Variant "$variantName" added successfully'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        });
      }
    });
  }

 /* void _showAddVariantDialog() {
    final variantNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'Add New Variant',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter variant name (e.g., Small, Medium, Large)',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 15),
                CommonTextForm(
                  controller: variantNameController,
                  labelText: 'Variant Name',
                  obsecureText: false,
                  borderc: 8,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            ),

            ElevatedButton(
              onPressed: () async {
                final String name = variantNameController.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a variant name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Create the model
                final newVariant = VariantModel(
                  id: const Uuid().v4(),
                  name: name,
                );

                // Save to Hive
                final variantBox = Hive.box<VariantModel>('variante');
                await variantBox.put(newVariant.id, newVariant);

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true); // Pass 'true' to indicate success
                }
                // Controller will be disposed in .then() callback

                // 1. Capture the "Screen" context before popping the dialog
                // final screenContext = this.context;

                // 2. Pop the dialog first
                // Navigator.pop(context);

        // WidgetsBinding.instance.addPostFrameCallback((_) {
        // if (!mounted) return;
        //
        //
        //         // 3. Use a microtask to ensure the snackbar and refresh happen
        //         // after the dialog is completely removed from the widget tree
        //         // Future.microtask(() {
        //         //   if (!mounted) return;
        //
        //           // Refresh the list on the main screen
        //           _loadVariants();
        //
        //           // Use the screenContext to show the success message
        //           // ScaffoldMessenger.of(screenContext).showSnackBar(
        //           //   SnackBar(
        //           //     content: Text('Variant "$name" added successfully'),
        //           //     backgroundColor: Colors.green,
        //           //     duration: const Duration(seconds: 2),
        //           //   ),
        //           // );
        //         });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: Text(
                'Add',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            )
            *//*ElevatedButton(
              onPressed: () async {
                if (variantNameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a variant name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final newVariant = VariantModel(
                  id: Uuid().v4(),
                  name: variantNameController.text.trim(),
                );

                final variantBox = Hive.box<VariantModel>('variante');
                await variantBox.put(newVariant.id, newVariant);

                Navigator.pop(context);

                _loadVariants();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Variant "${newVariant.name}" added successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: Text(
                'Add',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),*//*
          ],
        );
      },
    ).then((wasAdded) {
      // Dispose controller immediately
      variantNameController.dispose();

      // Use postFrameCallback to ensure widget tree is stable
      if (wasAdded == true && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          _loadVariants();

          // Show success message on SCREEN context
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Variant added successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        });
      }
    });

    // variantNameController.dispose();


  }
 */
}