import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/data/models/restaurant/db/variantmodel_305.dart';
import 'package:uuid/uuid.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import '../../../../util/common/app_responsive.dart';
import '../../../widget/componets/common/app_text_field.dart';
import '../../../widget/componets/common/primary_app_bar.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';

class VariantSelectionScreen extends StatefulWidget {
  final List<Map<String, dynamic>> selectedVariants;
  /// When true (item tracks inventory), show a stock field per variant.
  final bool trackInventory;

  const VariantSelectionScreen({
    super.key,
    required this.selectedVariants,
    this.trackInventory = false,
  });

  @override
  State<VariantSelectionScreen> createState() => _VariantSelectionScreenState();
}

class _VariantSelectionScreenState extends State<VariantSelectionScreen> {
  List<VariantModel> availableVariants = [];
  Map<String, bool> selectedVariantIds = {};
  Map<String, TextEditingController> priceControllers = {};
  Map<String, TextEditingController> stockControllers = {};

  /// Existing selections are applied once (first load), not on every reload —
  /// re-applying would re-add just-deleted variants and re-touch controllers.
  bool _initialized = false;

  TextEditingController _stockCtrl(String id) =>
      stockControllers.putIfAbsent(id, () => TextEditingController());

  // Quick-add preset sets — one tap creates (if missing) and selects all.
  static const Map<String, List<String>> _presets = {
    'Small / Medium / Large': ['Small', 'Medium', 'Large'],
    'Half / Full': ['Half', 'Full'],
    'Regular / Large': ['Regular', 'Large'],
  };

  /// Create any missing variants from a preset set and select them all.
  Future<void> _applyPreset(List<String> names) async {
    for (final name in names) {
      VariantModel? existing;
      for (final v in availableVariants) {
        if (v.name.toLowerCase() == name.toLowerCase()) {
          existing = v;
          break;
        }
      }
      String id;
      if (existing != null) {
        id = existing.id;
      } else {
        final newVariant = VariantModel(id: const Uuid().v4(), name: name);
        await variantStore.addVariant(newVariant);
        id = newVariant.id;
      }
      selectedVariantIds[id] = true;
      priceControllers.putIfAbsent(id, () => TextEditingController());
    }
    _loadVariants();
  }

  /// Confirm and remove a variant from the catalog.
  Future<void> _confirmDeleteVariant(VariantModel variant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove "${variant.name}"?',
          style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This variant will be removed from the list. Items already saved with it are not affected.',
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Remove',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final removedPrice = priceControllers.remove(variant.id);
      final removedStock = stockControllers.remove(variant.id);
      selectedVariantIds.remove(variant.id);
      await variantStore.deleteVariant(variant.id);
      _loadVariants();
      // Dispose after the rebuild removes the row, never while it's mounted.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        removedPrice?.dispose();
        removedStock?.dispose();
      });
    }
  }

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

    // Ensure a controller exists for every variant (reuse if already present).
    for (var variant in variants) {
      priceControllers.putIfAbsent(variant.id, () => TextEditingController());
      selectedVariantIds.putIfAbsent(variant.id, () => false);
    }

    if (mounted) {
      setState(() {
        availableVariants = variants;
      });
      // Apply the item's existing selections only on the first load.
      if (!_initialized) {
        _initializeSelections();
        _initialized = true;
      }
    }
  }


  void _initializeSelections() {
    // Initialize from existing selections.
    // Reuse any controller already in the map (set its text) instead of
    // replacing it — replacing leaks the old controller and orphans the
    // EditableText still bound to it, which destabilises the element tree.
    for (var selectedVariant in widget.selectedVariants) {
      final id = selectedVariant['variantId'];
      selectedVariantIds[id] = true;

      final price = selectedVariant['price'];
      priceControllers.putIfAbsent(id, () => TextEditingController());
      priceControllers[id]!.text = price?.toString() ?? '';

      final existingStock = selectedVariant['stockQuantity'];
      stockControllers.putIfAbsent(id, () => TextEditingController());
      stockControllers[id]!.text = (existingStock == null || existingStock == 0)
          ? ''
          : (existingStock % 1 == 0
              ? existingStock.toInt().toString()
              : existingStock.toString());
    }

    // Ensure controllers exist for every available variant.
    for (var variant in availableVariants) {
      priceControllers.putIfAbsent(variant.id, () => TextEditingController());
      selectedVariantIds.putIfAbsent(variant.id, () => false);
    }
  }

  @override
  void dispose() {
    for (var controller in priceControllers.values) {
      controller.dispose();
    }
    for (var controller in stockControllers.values) {
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
          final stock = widget.trackInventory
              ? (double.tryParse(stockControllers[variantId]?.text ?? '') ?? 0.0)
              : 0.0;
          result.add({
            'variantId': variantId,
            'price': price,
            'name': variant.name,
            'stockQuantity': stock,
          });
        }
      }
    });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Add Variants',
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Empty state shows a prominent centred button instead, so the
          // app-bar action only appears once at least one variant exists.
          if (availableVariants.isNotEmpty)
            IconButton(
              icon: Icon(Icons.add_circle_outline),
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

  /// Empty state — matches the Choice/Extra selection screens: the single add
  /// control lives in the app bar, so the empty state just guides the user to it.
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
              color: AppColors.divider,
            ),
            SizedBox(height: 20),
            Text(
              'No Variants Available',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Create your first variant to get started',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
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
            'Select variants and set prices',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 20),

          ...availableVariants.map<Widget>((variant) {
            final isSelected = selectedVariantIds[variant.id] ?? false;
            final controller = priceControllers[variant.id]!;

            return Container(
              key: ValueKey(variant.id),
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.divider,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
                color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : AppColors.white,
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
                              _stockCtrl(variant.id).clear();
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
                            color: isSelected ? Colors.black : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 20, color: AppColors.danger.withValues(alpha: 0.8)),
                        onPressed: () => _confirmDeleteVariant(variant),
                        tooltip: 'Remove variant',
                        splashRadius: 20,
                      ),
                    ],
                  ),
                  if (isSelected)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8, bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: controller,
                              label: 'Price',
                              hint: '0.00',
                              prefixWidget: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                child: Text(CurrencyHelper.currentSymbol,
                                    style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary)),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          if (widget.trackInventory) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppTextField(
                                controller: _stockCtrl(variant.id),
                                label: 'Stock',
                                hint: '0',
                                icon: Icons.inventory_2_outlined,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
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
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.textSecondary.withValues(alpha: 0.1),
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
              bgcolor: AppColors.white,
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
                final selected = _getSelectedVariants();
                if (selected.isEmpty) {
                  Navigator.pop(context, selected);
                  return;
                }
                final hasInvalidPrice = selected.any((v) => (v['price'] as double) <= 0);
                if (hasInvalidPrice) {
                  NotificationService.instance.showError('Please enter a price greater than 0 for all selected variants');
                  return;
                }
                Navigator.pop(context, selected);
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

    final hInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2).clamp(40.0, 200.0)
        : 24.0;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
          title: Text(
            'Add New Variant',
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
                  'Enter variant name (e.g., Small, Medium, Large)',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 15),
                AppTextField(
                  controller: variantNameController,
                  label: 'Variant Name',
                  hint: 'e.g. Small, Medium, Large',
                  icon: Icons.tune_rounded,
                ),
                const SizedBox(height: 20),
                Text(
                  'Suggestions',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presets.entries.map((e) {
                    return OutlinedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _applyPreset(e.value);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        e.key,
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final String name = variantNameController.text.trim();

                if (name.isEmpty) {
                  NotificationService.instance.showError('Please enter a variant name');
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
          NotificationService.instance.showSuccess('Variant "$variantName" added successfully');
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
                AppTextField(
                  controller: variantNameController,
                  label: 'Variant Name',
                  hint: 'e.g. Small, Medium, Large',
                  icon: Icons.tune_rounded,
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
                  NotificationService.instance.showError('Please enter a variant name');
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
                  NotificationService.instance.showError('Please enter a variant name');
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
                  NotificationService.instance.showSuccess('Variant "${newVariant.name}" added successfully');
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
                NotificationService.instance.showSuccess('Variant added successfully');
              });
            }    });

    // variantNameController.dispose();


  }
 */
}

/// Public entry point so other screens (e.g. item edit) can open the SAME
/// "Add Variant" dialog used in the Add-Item flow. [onAdded] fires after a
/// variant is created so the caller can refresh its list.
Future<void> showAddVariantDialog(BuildContext context,
    {required VoidCallback onAdded}) {
  return showDialog(
    context: context,
    builder: (_) => _AddVariantDialog(onAdded: onAdded),
  );
}

class _AddVariantDialog extends StatefulWidget {
  final VoidCallback onAdded;
  const _AddVariantDialog({required this.onAdded});

  @override
  State<_AddVariantDialog> createState() => _AddVariantDialogState();
}

class _AddVariantDialogState extends State<_AddVariantDialog> {
  final _nameController = TextEditingController();

  static const Map<String, List<String>> _presetSets = {
    'Small / Medium / Large': ['Small', 'Medium', 'Large'],
    'Half / Full': ['Half', 'Full'],
    'Regular / Large': ['Regular', 'Large'],
  };

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Create any missing variants from a preset set (existing names are skipped).
  Future<void> _applyPreset(List<String> names) async {
    final existing = variantStore.variants.toList();
    for (final name in names) {
      final already =
          existing.any((v) => v.name.toLowerCase() == name.toLowerCase());
      if (!already) {
        await variantStore.addVariant(VariantModel(id: const Uuid().v4(), name: name));
      }
    }
    widget.onAdded();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _addSingle() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      NotificationService.instance.showError('Please enter a variant name');
      return;
    }
    await variantStore.addVariant(VariantModel(id: const Uuid().v4(), name: name));
    widget.onAdded();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2)
            .clamp(40.0, 200.0)
        : 24.0;
    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
      title: Text('Add New Variant',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter variant name (e.g., Small, Medium, Large)',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 15),
            AppTextField(
              controller: _nameController,
              label: 'Variant Name',
              hint: 'e.g. Small, Medium, Large',
              icon: Icons.tune_rounded,
            ),
            const SizedBox(height: 20),
            Text('Suggestions',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presetSets.entries.map((e) {
                return OutlinedButton(
                  onPressed: () => _applyPreset(e.value),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(e.key,
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w500)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: GoogleFonts.poppins(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _addSingle,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: Text('Add', style: GoogleFonts.poppins(color: Colors.white)),
        ),
      ],
    );
  }
}