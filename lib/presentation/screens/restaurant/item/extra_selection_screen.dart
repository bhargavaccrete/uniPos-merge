import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/data/models/restaurant/db/extramodel_303.dart';
import 'package:unipos/data/models/restaurant/db/toppingmodel_304.dart';
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
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Add Extras',
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline),
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
              color: AppColors.divider,
            ),
            SizedBox(height: 20),
            Text(
              'No Extras Available',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Create your first extra category to get started',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
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
              color: AppColors.textSecondary,
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
                  color: isSelected ? AppColors.primary : AppColors.divider,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
                color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : AppColors.white,
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
                    color: isSelected ? Colors.black : AppColors.textSecondary,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          '$toppingCount topping${toppingCount != 1 ? 's' : ''} available',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (extra.minimum != null || extra.maximum != null) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.teal.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.tune, size: 11, color: Colors.teal.shade700),
                                SizedBox(width: 3),
                                Text(
                                  '${extra.minimum ?? 0}–${extra.maximum ?? '∞'}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.teal.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
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
                                    color: AppColors.textSecondary,
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
                                color: AppColors.divider,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '+${extra.topping!.length - 3}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
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
    showDialog(
      context: context,
      builder: (_) => _AddExtraDialog(
        onAdded: () {
          if (mounted) _loadExtras();
        },
      ),
    );
  }
}

/// Dialog for creating a new Extra category with toppings.
///
/// Owns its [TextEditingController]s and disposes them in [dispose], which the
/// framework guarantees runs AFTER the dialog's exit animation completes. This
/// avoids the `_dependents.isEmpty` crash that occurred when controllers were
/// disposed (via a Future.delayed timer) while their TextFields were still
/// mounted and animating out.
class _AddExtraDialog extends StatefulWidget {
  final VoidCallback onAdded;

  const _AddExtraDialog({required this.onAdded});

  @override
  State<_AddExtraDialog> createState() => _AddExtraDialogState();
}

class _AddExtraDialogState extends State<_AddExtraDialog> {
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

  @override
  void dispose() {
    extraNameController.dispose();
    for (var data in toppingData) {
      data['nameController'].dispose();
      data['priceController'].dispose();
      (data['variantPriceControllers'] as Map<String, TextEditingController>)
          .values
          .forEach((c) => c.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void setDialogState(VoidCallback fn) => setState(fn);
    final hInset = !AppResponsive.isMobile(context)
                ? ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2).clamp(40.0, 200.0)
                : 24.0;
            return AlertDialog(
              insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
              title: Text(
                'Add Extra Category',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      controller: extraNameController,
                      label: 'Category Name',
                      hint: 'e.g. Pizza Toppings',
                      icon: Icons.add_circle_outline,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Toppings',
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
                          border: Border.all(color: AppColors.divider),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (toppingData.length > 1)
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
                                  IconButton(
                                    icon: Icon(Icons.remove_circle, color: Colors.red, size: 20),
                                    onPressed: () {
                                      final removed = toppingData[index];
                                      setDialogState(() => toppingData.removeAt(index));
                                      // Dispose AFTER the rebuild removes the
                                      // fields, so we never dispose a controller
                                      // still attached to a mounted TextField.
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        removed['nameController'].dispose();
                                        removed['priceController'].dispose();
                                        (removed['variantPriceControllers'] as Map<String, TextEditingController>)
                                            .values
                                            .forEach((c) => c.dispose());
                                      });
                                    },
                                  ),
                                ],
                              ),
                            SizedBox(height: 8),
                            AppTextField(
                              controller: data['nameController'],
                              label: 'Topping Name',
                              hint: 'e.g. Extra Cheese',
                              icon: Icons.local_pizza_outlined,
                            ),
                            // Price (shown when not priced by size)
                            if (!hasSize) ...[
                              SizedBox(height: 10),
                              AppTextField(
                                controller: data['priceController'],
                                label: 'Price',
                                hint: '0.00',
                                prefixWidget: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  child: Text(CurrencyHelper.currentSymbol, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                              ),
                            ],
                            SizedBox(height: 12),
                            // Type (Veg / Non-Veg) segmented toggle
                            Text('Type', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                            SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: _vegToggle(
                                    label: 'Veg',
                                    color: Colors.green,
                                    selected: data['isVeg'] == true,
                                    onTap: () => setDialogState(() => data['isVeg'] = true),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: _vegToggle(
                                    label: 'Non-Veg',
                                    color: Colors.red,
                                    selected: data['isVeg'] == false,
                                    onTap: () => setDialogState(() => data['isVeg'] = false),
                                  ),
                                ),
                              ],
                            ),
                            // Different prices by size
                            if (availableVariants.isNotEmpty) ...[
                              SizedBox(height: 12),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setDialogState(() => data['hasSize'] = !hasSize),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: hasSize,
                                      onChanged: (value) => setDialogState(() => data['hasSize'] = value!),
                                      activeColor: AppColors.primary,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    Text(
                                      'Different prices by size',
                                      style: GoogleFonts.poppins(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            // Variant pricing (when priced by size)
                            if (hasSize) ...[
                              SizedBox(height: 6),
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
                                                child: AppTextField(
                                                  controller: variantControllers[variant.id],
                                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                                  hint: '0',
                                                  prefixWidget: Text(CurrencyHelper.currentSymbol),
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
                        'Add Another Topping',
                        style: GoogleFonts.poppins(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  // Controllers are disposed in [dispose]; just close here.
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(color: AppColors.textSecondary),
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

                    // Notify parent to reload, then close. Controllers are
                    // disposed safely in [dispose] once the route is gone.
                    widget.onAdded();
                    if (mounted) Navigator.of(context).pop();

                    NotificationService.instance.showSuccess('Extra "${newExtra.Ename}" added with ${toppings.length} toppings');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: Text(
                    'Save',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ),
              ],
            );
  }

  /// A single Veg / Non-Veg segmented toggle button.
  Widget _vegToggle({
    required String label,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.circle, size: 10, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}