import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:lottie/lottie.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/data/models/restaurant/db/toppingmodel_304.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/util/images.dart';
import '../../../../../data/models/restaurant/db/variantmodel_305.dart';
import '../../../../../domain/services/restaurant/notification_service.dart';
import '../../../../../util/restaurant/restaurant_session.dart';
import 'package:uuid/uuid.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/core/plan/plan_guard.dart';
import 'package:billberrylite/core/plan/entitlement_keys.dart';
import '../../../../../data/models/restaurant/db/extramodel_303.dart';

class ExtraTab extends StatefulWidget {
  const ExtraTab({super.key});

  @override
  State<ExtraTab> createState() => _ExtraTabState();
}

class _ExtraTabState extends State<ExtraTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  String? editingId;
  int? editingToppingIndex;

  bool get _canEdit => RestaurantSession.isAdmin || RestaurantSession.staffRole == 'Manager';
  // Plan entitlements layered on the role check (manage_menu.extras.*).
  // Topping operations are edits to the parent extra, so they use extras.edit.
  // Visibility = role only; entitlement enforced on action (handlers below).
  bool get _canAddExtra => _canEdit;
  bool get _canEditExtra => _canEdit;
  bool get _canDeleteExtra => _canEdit;

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
    if (!PlanGuard.allowedOr(
        context,
        extra == null
            ? EntKeys.manageMenuExtrasAdd
            : EntKeys.manageMenuExtrasEdit,
        featureName: extra == null ? 'Add Extras' : 'Edit Extras')) {
      return;
    }
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

    final isWide = !AppResponsive.isMobile(context);
    if (isWide) {
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
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
    // Toppings are part of an extra → gated by the extras "edit" entitlement.
    if (!PlanGuard.allowedOr(context, EntKeys.manageMenuExtrasEdit, featureName: 'Edit Extras')) return;
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

    final isWide = !AppResponsive.isMobile(context);
    if (isWide) {
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
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
    if (trimmedName.isEmpty) {
      NotificationService.instance.showError('Extra name is required');
      return;
    }

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
    if (_toppingController.text.trim().isEmpty) {
      NotificationService.instance.showError('Topping name is required');
      return;
    }

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
    if (!PlanGuard.allowedOr(context, EntKeys.manageMenuExtrasEdit, featureName: 'Edit Extras')) return;
    final topping = extra.topping![toppingIndex];
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete "${topping.name}"?',
      message: 'This topping will be removed from ${extra.Ename}.',
      confirmLabel: 'Delete',
      accent: AppColors.danger,
      icon: Icons.delete_outline,
    );
    if (confirmed) {
      try { await extraStore.removeTopping(extra.Id, toppingIndex); } catch (e) { NotificationService.instance.showError('Error: $e'); }
    }
  }

  Future<void> _deleteExtra(Extramodel extra) async {
    if (!PlanGuard.allowedOr(context, EntKeys.manageMenuExtrasDelete, featureName: 'Delete Extras')) return;
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete "${extra.Ename}"?',
      message: 'This extra and its ${extra.topping?.length ?? 0} toppings will be removed.',
      confirmLabel: 'Delete',
      accent: AppColors.danger,
      icon: Icons.delete_outline,
    );
    if (confirmed) {
      try { await extraStore.deleteExtra(extra.Id); } catch (e) { NotificationService.instance.showError('Error deleting extra: $e'); }
    }
  }


  @override
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final size = MediaQuery.of(context).size;
    final isTablet = !AppResponsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Column(
        children: [
          // Modern Search Bar
          Padding(
            padding: AppResponsive.padding(context),
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

          if (_canAddExtra) _buildAddButton(),
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
          padding: AppResponsive.padding(context),
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

        // Masonry layout: each card keeps its natural height so ALL toppings
        // are visible (a fixed-aspect grid clips long lists). Reuses the full
        // mobile card and distributes cards round-robin across columns.
        final columns =
            AppResponsive.gridColumns(context, mobile: 2, tablet: 2, desktop: 3);
        final colLists = List.generate(columns, (_) => <Widget>[]);
        for (var i = 0; i < filteredExtras.length; i++) {
          colLists[i % columns].add(_buildExpandableExtraCard(filteredExtras[i]));
        }
        final spacing = AppResponsive.gridSpacing(context);

        return SingleChildScrollView(
          padding: AppResponsive.padding(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) SizedBox(width: spacing),
                Expanded(child: Column(children: colLists[c])),
              ],
            ],
          ),
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
    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: AppResponsive.shadowBlurRadius(context),
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                  ),
                  child: Icon(Icons.star_outline, color: AppColors.primary, size: AppResponsive.iconSize(context)),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(extra.Ename, style: GoogleFonts.poppins(fontSize: AppResponsive.bodyFontSize(context), fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text('${extra.topping?.length ?? 0} toppings', style: GoogleFonts.poppins(fontSize: AppResponsive.smallFontSize(context), color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (_canEditExtra)
                  InkWell(onTap: () => _openExtraBottomSheet(extra: extra), child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.edit_outlined, size: AppResponsive.smallIconSize(context), color: AppColors.primary))),
                if (_canDeleteExtra)
                  InkWell(onTap: () => _deleteExtra(extra), child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.delete_outline, size: AppResponsive.smallIconSize(context), color: Colors.red))),
              ],
            ),
          ),
          // Toppings list
          if (extra.topping != null && extra.topping!.isNotEmpty)
            ...extra.topping!.asMap().entries.map((entry) {
              final toppingIndex = entry.key;
              final topping = entry.value;
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: topping.isveg ? Colors.green : Colors.red, shape: BoxShape.circle)),
                    SizedBox(width: 10),
                    Expanded(child: Text(topping.name, style: GoogleFonts.poppins(fontSize: 13))),
                    Text('${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(topping.price)}', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                    if (_canEditExtra) ...[
                      InkWell(onTap: () => _openToppingBottomSheet(extra: extra, toppingIndex: toppingIndex), child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.edit_outlined, size: 14, color: AppColors.primary))),
                      InkWell(onTap: () => _deleteTopping(extra, toppingIndex), child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.close, size: 14, color: Colors.red))),
                    ],
                  ],
                ),
              );
            }),
          // Add topping — Admin/Manager only
          if (_canEditExtra)
            InkWell(
              onTap: () => _openToppingBottomSheet(extra: extra),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: AppColors.primary, size: 16),
                    SizedBox(width: 4),
                    Text('Add Topping', style: GoogleFonts.poppins(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Dropdown-style extra card (matches the Choices tab): collapsed shows the
  /// topping count; expanding reveals every topping. Used in the tablet/desktop
  /// masonry so long topping lists are fully reachable without clipping.
  Widget _buildExpandableExtraCard(Extramodel extra) {
    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: AppResponsive.shadowBlurRadius(context),
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: EdgeInsets.only(bottom: 8),
          leading: Container(
            padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
            ),
            child: Icon(Icons.star_outline, color: AppColors.primary, size: AppResponsive.iconSize(context)),
          ),
          title: Text(extra.Ename,
              style: GoogleFonts.poppins(fontSize: AppResponsive.bodyFontSize(context), fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${extra.topping?.length ?? 0} toppings',
              style: GoogleFonts.poppins(fontSize: AppResponsive.smallFontSize(context), color: AppColors.textSecondary)),
          trailing: (_canEditExtra || _canDeleteExtra)
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  if (_canEditExtra)
                    InkWell(onTap: () => _openExtraBottomSheet(extra: extra), child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.edit_outlined, size: AppResponsive.smallIconSize(context), color: AppColors.primary))),
                  if (_canDeleteExtra)
                    InkWell(onTap: () => _deleteExtra(extra), child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.delete_outline, size: AppResponsive.smallIconSize(context), color: Colors.red))),
                ])
              : null,
          children: [
            if (extra.topping == null || extra.topping!.isEmpty)
              Padding(
                padding: EdgeInsets.all(14),
                child: Text('No toppings', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
              )
            else
              ...extra.topping!.asMap().entries.map((entry) {
                final toppingIndex = entry.key;
                final topping = entry.value;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: topping.isveg ? Colors.green : Colors.red, shape: BoxShape.circle)),
                      SizedBox(width: 10),
                      Expanded(child: Text(topping.name, style: GoogleFonts.poppins(fontSize: 13))),
                      Text('${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(topping.price)}', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                      if (_canEditExtra) ...[
                        InkWell(onTap: () => _openToppingBottomSheet(extra: extra, toppingIndex: toppingIndex), child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.edit_outlined, size: 14, color: AppColors.primary))),
                        InkWell(onTap: () => _deleteTopping(extra, toppingIndex), child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.close, size: 14, color: Colors.red))),
                      ],
                    ],
                  ),
                );
              }),
            if (_canEditExtra)
              InkWell(
                onTap: () => _openToppingBottomSheet(extra: extra),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: AppColors.primary, size: 16),
                      SizedBox(width: 4),
                      Text('Add Topping', style: GoogleFonts.poppins(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      padding: AppResponsive.padding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _openExtraBottomSheet,
            icon: Icon(Icons.add, size: AppResponsive.iconSize(context)),
            label: Text('Add Extra', style: GoogleFonts.poppins(fontSize: AppResponsive.bodyFontSize(context), fontWeight: FontWeight.w500)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(vertical: AppResponsive.mediumSpacing(context)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ),
    );
  }
}