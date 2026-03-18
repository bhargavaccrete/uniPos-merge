import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:lottie/lottie.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';
import 'package:unipos/data/models/restaurant/db/toppingmodel_304.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/util/images.dart';
import '../../../../../data/models/restaurant/db/variantmodel_305.dart';
import '../../../../../domain/services/restaurant/notification_service.dart';
import 'package:uuid/uuid.dart';
import 'package:unipos/util/common/currency_helper.dart';
import '../../../../../data/models/restaurant/db/extramodel_303.dart';

class ExtraTab extends StatefulWidget {
  const ExtraTab({super.key});

  @override
  State<ExtraTab> createState() => _ExtraTabState();
}

class _ExtraTabState extends State<ExtraTab> {
  String? editingId;
  int? editingToppingIndex;

  final _extrasController = TextEditingController();
  final _toppingController = TextEditingController();
  final _priceController = TextEditingController();
  final _minimumController = TextEditingController();
  final _maximumController = TextEditingController();
  final _searchController = TextEditingController();

  String query = '';
  bool isveg = false, hasSize = false;
  Map<String, TextEditingController> _variantPriceControllers = {};
  List<VariantModel> _availableVariants = [];
  Set<String> _selectedVariants = {};

  @override
  void initState() {
    super.initState();
    _loadAvailableVariants();
    _searchController.addListener(() {
      setState(() {
        query = _searchController.text;
      });
    });
  }

  void _loadAvailableVariants() {
    _availableVariants = variantStore.variants.toList();
  }

  @override
  void dispose() {
    _extrasController.dispose();
    _toppingController.dispose();
    _priceController.dispose();
    _minimumController.dispose();
    _maximumController.dispose();
    _searchController.dispose();
    _variantPriceControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  void _openExtraBottomSheet({Extramodel? extra}) {
    if (extra != null) {
      _extrasController.text = extra.Ename;
      _minimumController.text = extra.minimum?.toString() ?? '';
      _maximumController.text = extra.maximum?.toString() ?? '';
      editingId = extra.Id;
    } else {
      _extrasController.clear();
      _minimumController.clear();
      _maximumController.clear();
      editingId = null;
    }

    final isWide = MediaQuery.of(context).size.width >= 850;
    if (isWide) {
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: MediaQuery.of(ctx).size.height * 0.88,
            ),
            child: _buildExtraBottomSheet(isDialog: true),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _buildExtraBottomSheet(isDialog: false),
        ),
      );
    }
  }

  Widget _buildExtraBottomSheet({bool isDialog = false}) {
    final isEditing = editingId != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isDialog
            ? BorderRadius.circular(20)
            : const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ────────────────────────────────────────────
          if (!isDialog)
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

          // ── Header ─────────────────────────────────────────────────
          Padding(
            padding:
                EdgeInsets.fromLTRB(20, isDialog ? 20 : 12, 12, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isEditing ? Icons.edit_rounded : Icons.star_outline_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing
                            ? 'Edit Extra Category'
                            : 'Add Extra Category',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        isEditing
                            ? 'Update extra group details'
                            : 'Group related toppings together',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.grey.shade500),
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),

          // ── Form body ───────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category name
                  AppTextField(
                    controller: _extrasController,
                    label: 'Category Name',
                    hint: 'e.g. Sauces, Toppings, Sides',
                    icon: Icons.star_outline_rounded,
                    required: true,
                  ),
                  const SizedBox(height: 14),

                  // Min / Max row
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _minimumController,
                          label: 'Min Selection',
                          hint: '0',
                          icon: Icons.remove_circle_outline_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          controller: _maximumController,
                          label: 'Max Selection',
                          hint: '0',
                          icon: Icons.add_circle_outline_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 13),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Cancel',
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _addOrEditExtra,
                          icon: Icon(
                            isEditing
                                ? Icons.check_rounded
                                : Icons.add_circle_outline_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: Text(
                            isEditing ? 'Update' : 'Add Extra',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding:
                                const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openToppingBottomSheet({required Extramodel extra, int? toppingIndex}) {
    _loadAvailableVariants(); // Always refresh before opening
    if (toppingIndex != null) {
      final topping = extra.topping![toppingIndex];
      _toppingController.text = topping.name;
      _priceController.text = topping.price.toString();
      isveg = topping.isveg;
      hasSize = topping.isContainSize ?? false;
      editingToppingIndex = toppingIndex;

      _variantPriceControllers.clear();
      _selectedVariants.clear();
      if (hasSize && topping.variantPrices != null) {
        for (var variant in _availableVariants) {
          if (topping.variantPrices!.containsKey(variant.id)) {
            _selectedVariants.add(variant.id);
            _variantPriceControllers[variant.id] = TextEditingController(
                text: topping.variantPrices![variant.id]?.toString() ??
                    topping.price.toString());
          }
        }
      }
    } else {
      _toppingController.clear();
      _priceController.clear();
      isveg = true;
      hasSize = false;
      editingToppingIndex = null;
      _variantPriceControllers.clear();
      _selectedVariants.clear();
    }

    final isWide = MediaQuery.of(context).size.width >= 850;
    if (isWide) {
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: MediaQuery.of(ctx).size.height * 0.88,
            ),
            child: _buildToppingBottomSheet(extra, isDialog: true),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _buildToppingBottomSheet(extra, isDialog: false),
        ),
      );
    }
  }

  Widget _buildToppingBottomSheet(Extramodel extra, {bool isDialog = false}) {
    return StatefulBuilder(
      builder: (context, setModalState) {
        final isEditing = editingToppingIndex != null;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: isDialog
                ? BorderRadius.circular(20)
                : const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle ──────────────────────────────────────────
              if (!isDialog)
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),

              // ── Header ────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                    20, isDialog ? 20 : 12, 12, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isEditing
                            ? Icons.edit_rounded
                            : Icons.add_circle_outline_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit Topping' : 'Add Topping',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(Icons.folder_outlined,
                                  size: 12, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                extra.Ename,
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon:
                          Icon(Icons.close, color: Colors.grey.shade500),
                      splashRadius: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade100),

              // ── Scrollable body ───────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Topping Name
                      AppTextField(
                        controller: _toppingController,
                        label: 'Topping Name',
                        hint: 'e.g. Extra Cheese, Mushrooms',
                        icon: Icons.local_pizza_outlined,
                        required: true,
                      ),
                      const SizedBox(height: 14),

                      // Veg / Non-Veg
                      Text('Type',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600)),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                                child: _buildVegOption(
                                    true, setModalState,
                                    isLeft: true)),
                            Container(
                                width: 1,
                                height: 52,
                                color: AppColors.divider),
                            Expanded(
                                child: _buildVegOption(
                                    false, setModalState,
                                    isLeft: false)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Contains Size toggle
                      InkWell(
                        onTap: () {
                          setModalState(() {
                            hasSize = !hasSize;
                            if (hasSize) {
                              _variantPriceControllers.clear();
                              _selectedVariants.clear();
                              for (var v in _availableVariants) {
                                _variantPriceControllers[v.id] =
                                    TextEditingController(
                                        text: _priceController.text
                                                .isEmpty
                                            ? '0'
                                            : _priceController.text);
                              }
                            } else {
                              for (var c in _variantPriceControllers
                                  .values) {
                                c.dispose();
                              }
                              _variantPriceControllers.clear();
                              _selectedVariants.clear();
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: hasSize
                                ? AppColors.primary
                                    .withValues(alpha: 0.07)
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: hasSize
                                  ? AppColors.primary
                                  : AppColors.divider,
                              width: hasSize ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.straighten_rounded,
                                size: 20,
                                color: hasSize
                                    ? AppColors.primary
                                    : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('Contains Size',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: hasSize
                                              ? AppColors.primary
                                              : Colors.black87,
                                        )),
                                    Text(
                                        'Topping has different size prices',
                                        style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color:
                                                Colors.grey.shade500)),
                                  ],
                                ),
                              ),
                              Switch(
                                value: hasSize,
                                activeColor: AppColors.primary,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                onChanged: (v) {
                                  setModalState(() {
                                    hasSize = v;
                                    if (hasSize) {
                                      _variantPriceControllers.clear();
                                      _selectedVariants.clear();
                                      for (var vr in _availableVariants) {
                                        _variantPriceControllers[vr.id] =
                                            TextEditingController(
                                                text: _priceController
                                                        .text.isEmpty
                                                    ? '0'
                                                    : _priceController
                                                        .text);
                                      }
                                    } else {
                                      for (var c
                                          in _variantPriceControllers
                                              .values) {
                                        c.dispose();
                                      }
                                      _variantPriceControllers.clear();
                                      _selectedVariants.clear();
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Price or variant prices
                      if (!hasSize) ...[
                        AppTextField(
                          controller: _priceController,
                          label: 'Price',
                          hint: '0.00',
                          icon: Icons.currency_rupee_rounded,
                          keyboardType: TextInputType.number,
                          prefixWidget: Padding(
                            padding: const EdgeInsets.only(left: 12, right: 4),
                            child: Text(
                              CurrencyHelper.currentSymbol,
                              style: GoogleFonts.poppins(
                                  fontSize: 13, color: Colors.black87),
                            ),
                          ),
                        ),
                      ],

                      if (hasSize)
                        _buildVariantPricesSection(setModalState),

                      const SizedBox(height: 20),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 13),
                                side: BorderSide(
                                    color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                              child: Text('Cancel',
                                  style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () => _saveTopping(extra),
                              icon: Icon(
                                isEditing
                                    ? Icons.check_rounded
                                    : Icons.add_circle_outline_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              label: Text(
                                isEditing
                                    ? 'Update Topping'
                                    : 'Save Topping',
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 13),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVegOption(bool isVegOption, StateSetter setModalState,
      {required bool isLeft}) {
    final isSelected = isveg == isVegOption;
    final dotColor = isVegOption ? Colors.green : Colors.red;

    return InkWell(
      onTap: () => setModalState(() => isveg = isVegOption),
      borderRadius: BorderRadius.horizontal(
        left: isLeft ? const Radius.circular(11) : Radius.zero,
        right: isLeft ? Radius.zero : const Radius.circular(11),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? dotColor.withValues(alpha: 0.07)
              : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: isLeft ? const Radius.circular(11) : Radius.zero,
            right: isLeft ? Radius.zero : const Radius.circular(11),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.circle,
                color: dotColor,
                size: isSelected ? 12 : 10),
            const SizedBox(width: 8),
            Text(
              isVegOption ? 'Veg' : 'Non-Veg',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
                color:
                    isSelected ? dotColor : Colors.grey.shade600,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                    color: dotColor, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    size: 11, color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVariantPricesSection(StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Size-based Pricing',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
            const Spacer(),
            Text('Select sizes to enable',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.grey.shade400)),
          ],
        ),
        const SizedBox(height: 8),
        ..._availableVariants.map((variant) {
          final isSelected = _selectedVariants.contains(variant.id);
          final controller = _variantPriceControllers[variant.id];

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.05)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isSelected ? AppColors.primary : AppColors.divider,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // Checkbox
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: isSelected,
                    activeColor: AppColors.primary,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    onChanged: (v) {
                      setModalState(() {
                        if (v == true) {
                          _selectedVariants.add(variant.id);
                          _variantPriceControllers[variant.id] =
                              TextEditingController(
                                  text: _priceController.text.isEmpty
                                      ? '0'
                                      : _priceController.text);
                        } else {
                          _selectedVariants.remove(variant.id);
                          _variantPriceControllers[variant.id]
                              ?.dispose();
                          _variantPriceControllers
                              .remove(variant.id);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Text(
                    variant.name,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? Colors.black87
                          : Colors.grey.shade500,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: AppTextField(
                    controller: controller,
                    enabled: isSelected,
                    hint: '0.00',
                    keyboardType: TextInputType.number,
                    prefixWidget: Padding(
                      padding: const EdgeInsets.only(left: 10, right: 4),
                      child: Text(CurrencyHelper.currentSymbol, style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87)),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Future<void> _addOrEditExtra() async {
    final trimmedName = _extrasController.text.trim();
    if (trimmedName.isEmpty) return;

    try {
      if (editingId != null) {
        final currentExtra = extraStore.extras.firstWhere((e) => e.Id == editingId);

        final updatedExtra = Extramodel(
          Id: currentExtra.Id,
          Ename: trimmedName,
          topping: currentExtra.topping,
          minimum: int.tryParse(_minimumController.text.trim()),
          maximum: int.tryParse(_maximumController.text.trim()),
        );
        await extraStore.updateExtra(updatedExtra);
      } else {
        final newExtra = Extramodel(
          Id: const Uuid().v4(),
          Ename: trimmedName,
          minimum: int.tryParse(_minimumController.text.trim()),
          maximum: int.tryParse(_maximumController.text.trim()),
        );
        await extraStore.addExtra(newExtra);
      }

      _extrasController.clear();
      editingId = null;
      Navigator.pop(context);
    } catch (e) {
      NotificationService.instance.showError('Error: $e');
    }
  }

  Future<void> _saveTopping(Extramodel extra) async {
    if (_toppingController.text.trim().isEmpty) return;

    Map<String, double>? variantPrices;
    double basePrice = 0.0;

    if (hasSize && _variantPriceControllers.isNotEmpty) {
      variantPrices = {};
      for (var entry in _variantPriceControllers.entries) {
        final price = double.tryParse(entry.value.text) ?? 0.0;
        variantPrices[entry.key] = price;
        if (basePrice == 0.0) basePrice = price;
      }
    } else {
      basePrice = double.tryParse(_priceController.text) ?? 0.0;
    }

    final topping = Topping(
      name: _toppingController.text.trim(),
      price: basePrice,
      isveg: isveg,
      isContainSize: hasSize,
      variantPrices: variantPrices,
    );

    try {
      if (editingToppingIndex != null) {
        await extraStore.updateTopping(extra.Id, editingToppingIndex!, topping);
      } else {
        await extraStore.addTopping(extra.Id, topping);
      }

      editingToppingIndex = null;
      Navigator.pop(context);
    } catch (e) {
      NotificationService.instance.showError('Error: $e');
    }
  }

  Future<void> _deleteTopping(Extramodel extra, int toppingIndex) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Delete Topping', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this topping?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await extraStore.removeTopping(extra.Id, toppingIndex);
      } catch (e) {
        NotificationService.instance.showError('Error: $e');
      }
    }
  }

  Future<void> _deleteExtra(Extramodel extra) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Delete Extra',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this extra?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await extraStore.deleteExtra(extra.Id);
      } catch (e) {
        NotificationService.instance.showError('Error deleting extra: $e');
      }
    }
  }

  int _getGridColumns(double width) {
    if (width > 1200) return 3;
    else if (width > 800) return 2;
    else return 2;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Modern Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppTextField(
              controller: _searchController,
              hint: 'Search extras…',
              icon: Icons.search_rounded,
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
            ),
          ),

          // Extras List
          Expanded(
            child: isTablet ? _buildTabletLayout(size) : _buildMobileLayout(size),
          ),

          // Add Extra Button
          _buildAddButton(),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(Size size) {
    return Observer(
      builder: (_) {
        final filteredExtras = _getFilteredExtras();

        if (filteredExtras.isEmpty) {
          return _buildEmptyState(size.height);
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: filteredExtras.length,
          itemBuilder: (context, index) {
            final extra = filteredExtras[index];
            return _buildMobileExtraCard(extra);
          },
        );
      },
    );
  }

  Widget _buildTabletLayout(Size size) {
    return Observer(
      builder: (_) {
        final filteredExtras = _getFilteredExtras();

        if (filteredExtras.isEmpty) {
          return _buildEmptyState(size.height);
        }

        return GridView.builder(
          padding: EdgeInsets.all(24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _getGridColumns(size.width),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2,
          ),
          itemCount: filteredExtras.length,
          itemBuilder: (context, index) {
            final extra = filteredExtras[index];
            return _buildGridExtraCard(extra);
          },
        );
      },
    );
  }

  List<Extramodel> _getFilteredExtras() {
    final allExtras = extraStore.extras.toList();
    return query.isEmpty
        ? allExtras
        : allExtras.where((extra) {
            final name = extra.Ename.toLowerCase();
            final queryLower = query.toLowerCase();
            return name.contains(queryLower);
          }).toList();
  }

  Widget _buildEmptyState(double height) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(AppImages.notfoundanimation, height: height * 0.25),
          SizedBox(height: 16),
          Text(
            query.isEmpty ? 'No Extras Found' : 'No matching extras',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          if (query.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Add extras to enhance your menu',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileExtraCard(Extramodel extra) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Extra Header
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.star, color: Colors.green.shade700, size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        extra.Ename,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_pizza, size: 12, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text(
                              '${extra.topping?.length ?? 0} toppings',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _openExtraBottomSheet(extra: extra),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                      ),
                    ),
                    SizedBox(width: 8),
                    InkWell(
                      onTap: () => _deleteExtra(extra),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Toppings List (Mobile)
          if (extra.topping != null && extra.topping!.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
              ),
              child: Column(
                children: extra.topping!.asMap().entries.map((entry) {
                  final toppingIndex = entry.key;
                  final topping = entry.value;
                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: topping.isveg ? Colors.green : Colors.red,
                              width: 2,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.circle,
                            color: topping.isveg ? Colors.green : Colors.red,
                            size: 10,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                topping.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(topping.price)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () =>
                              _openToppingBottomSheet(extra: extra, toppingIndex: toppingIndex),
                          child: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.edit, color: Colors.blue, size: 16),
                          ),
                        ),
                        SizedBox(width: 8),
                        InkWell(
                          onTap: () => _deleteTopping(extra, toppingIndex),
                          child: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.delete, color: Colors.red, size: 16),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          // Add Topping Button
          Padding(
            padding: EdgeInsets.all(16),
            child: InkWell(
              onTap: () => _openToppingBottomSheet(extra: extra),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Add Topping',
                      style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridExtraCard(Extramodel extra) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.star, color: Colors.green.shade700, size: 20),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            extra.Ename,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${extra.topping?.length ?? 0} toppings',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Toppings Preview (Grid)
          if (extra.topping != null && extra.topping!.isNotEmpty)
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 14),
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListView(
                  children: [
                    ...extra.topping!.take(3).map((topping) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(1.5),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: topping.isveg ? Colors.green : Colors.red,
                                  width: 1.5,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.circle,
                                color: topping.isveg ? Colors.green : Colors.red,
                                size: 7,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                topping.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (extra.topping!.length > 3)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          '+${extra.topping!.length - 3} more',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Action Buttons
          Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              children: [
                InkWell(
                  onTap: () => _openToppingBottomSheet(extra: extra),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, color: AppColors.primary, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Add Topping',
                          style: GoogleFonts.poppins(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _openExtraBottomSheet(extra: extra),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.edit_outlined, size: 16, color: Colors.blue),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _deleteExtra(extra),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _openExtraBottomSheet,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.add, color: AppColors.primary, size: 20),
              ),
              SizedBox(width: 10),
              Text(
                'Add Extra',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}