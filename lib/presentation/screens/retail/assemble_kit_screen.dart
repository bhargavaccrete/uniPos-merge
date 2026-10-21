import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/bundle_component_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/bundle_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/kit_assembly_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/domain/services/retail/inventory_service.dart';
import 'package:billberrylite/domain/services/retail/stock_adjustment_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Which direction this screen is currently operating in — see
/// [_AssembleKitScreenState._mode].
enum _KitMode { assemble, disassemble }

/// Retail's counterpart to restaurant's Production screen: pick a `repack`
/// (kit) product, enter a batch quantity, see whether current component
/// stock covers it, and confirm. Supports both directions — assembling a
/// batch from components ([RetailInventoryService.assembleKit]) and
/// reversing one back into components
/// ([RetailInventoryService.disassembleKit]), toggled via [_mode] — this
/// screen is presentation only. See docs/retail_inventory_system_plan.md
/// §3.2 / Phase 5.
class AssembleKitScreen extends StatefulWidget {
  const AssembleKitScreen({super.key});

  @override
  State<AssembleKitScreen> createState() => _AssembleKitScreenState();
}

class _AssembleKitScreenState extends State<AssembleKitScreen> {
  ProductModel? _selectedProduct;

  /// The kit variant being assembled. Kept as an id and resolved live from
  /// productStore, so stock shown here refreshes after every batch. Each
  /// variant of a repack product has its own component list.
  String? _selectedVariantId;

  List<VarianteModel> get _kitVariants => _selectedProduct == null
      ? const []
      : productStore.variantsFor(_selectedProduct!.productId);

  VarianteModel? get _selectedVariant {
    for (final v in _kitVariants) {
      if (v.varianteId == _selectedVariantId) return v;
    }
    return null;
  }
  final TextEditingController _batchQtyController = TextEditingController();
  bool _submitting = false;
  _KitMode _mode = _KitMode.assemble;

  @override
  void dispose() {
    _batchQtyController.dispose();
    super.dispose();
  }

  /// Repack/kit products only — bundles cascade at sale time and have no
  /// "assemble" action of their own.
  List<ProductModel> get _repackProducts =>
      productStore.products.where((p) => p.isRepack).toList()
        ..sort((a, b) => a.productName.compareTo(b.productName));

  RetailBundleModel? get _bundle => _selectedVariant == null
      ? null
      : bundleRepository.getBundleForVariant(_selectedVariant!.varianteId);

  int get _batchQty => int.tryParse(_batchQtyController.text.trim()) ?? 0;

  bool get _canSubmit =>
      _selectedProduct != null &&
      _selectedVariant != null &&
      _bundle != null &&
      _bundle!.hasComponents &&
      _batchQty > 0;

  void _selectProduct(ProductModel product) {
    setState(() {
      _selectedProduct = product;
      _selectedVariantId =
          productStore.primaryVariantFor(product.productId)?.varianteId;
      _batchQtyController.clear();
    });
  }

  void _selectVariant(String variantId) {
    if (variantId == _selectedVariantId) return;
    setState(() {
      _selectedVariantId = variantId;
      _batchQtyController.clear();
    });
  }

  void _pickProduct() async {
    final products = _repackProducts;
    if (products.isEmpty) return;
    final selected = await showDialog<ProductModel>(
      context: context,
      builder: (_) => _RepackPickerDialog(products: products),
    );
    if (selected != null) {
      _selectProduct(selected);
    }
  }

  bool get _isDisassemble => _mode == _KitMode.disassemble;

  Future<void> _confirm() async {
    final product = _selectedProduct;
    final variant = _selectedVariant;
    final qty = _batchQty;
    if (product == null || variant == null || qty <= 0) return;
    // Both directions write stock; the service itself carries no role check.
    if (!StockAdjustmentService.canAdjust) {
      NotificationService.instance.showError(
        'Only an admin or manager can assemble or disassemble kits',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = _isDisassemble
          ? await RetailInventoryService.disassembleKit(
              kitProduct: product,
              kitVariantId: variant.varianteId,
              batchQty: qty,
            )
          : await RetailInventoryService.assembleKit(
              kitProduct: product,
              kitVariantId: variant.varianteId,
              batchQty: qty,
            );
      if (!mounted) return;
      _batchQtyController.clear();
      final verb = _isDisassemble ? 'Disassembled' : 'Assembled';
      NotificationService.instance.showSuccess(
        '$verb ${result.batchQty} unit'
        '${result.batchQty == 1 ? '' : 's'} of ${product.productName}'
        '${_kitVariants.length > 1 && variant.hasAttributes ? ' (${variant.variantDescription})' : ''}',
      );
    } catch (e) {
      if (!mounted) return;
      NotificationService.instance.showError(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: _isDisassemble ? 'Disassemble Kit' : 'Assemble Kit',
      ),
      body: Observer(
        builder: (_) {
          final repackProducts = _repackProducts;

          if (repackProducts.isEmpty) {
            return const AppEmptyState(
              icon: Icons.inventory_rounded,
              title: 'No repack/kit products yet',
              message: 'Mark a product Repack/Kit to assemble it here.',
            );
          }

          return SingleChildScrollView(
            padding: AppResponsive.padding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildModeToggle(context),
                SizedBox(height: AppResponsive.mediumSpacing(context)),
                _buildProductPicker(context),
                if (_kitVariants.length > 1) ...[
                  SizedBox(height: AppResponsive.mediumSpacing(context)),
                  _buildVariantPicker(context),
                ],
                if (_selectedProduct != null && _selectedVariant != null) ...[
                  SizedBox(height: AppResponsive.largeSpacing(context)),
                  _buildBundleCard(context),
                  SizedBox(height: AppResponsive.largeSpacing(context)),
                  _buildRecentAssemblies(context),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// Switches the screen between the forward flow (components consumed, kit
  /// stock credited — [RetailInventoryService.assembleKit]) and the reverse
  /// flow (kit stock consumed, components credited back —
  /// [RetailInventoryService.disassembleKit]).
  Widget _buildModeToggle(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<_KitMode>(
        segments: const [
          ButtonSegment(
            value: _KitMode.assemble,
            label: Text('Assemble'),
            icon: Icon(Icons.inventory_rounded),
          ),
          ButtonSegment(
            value: _KitMode.disassemble,
            label: Text('Disassemble'),
            icon: Icon(Icons.undo_rounded),
          ),
        ],
        selected: {_mode},
        onSelectionChanged: (selection) {
          setState(() {
            _mode = selection.first;
            _batchQtyController.clear();
          });
        },
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor:
              (_isDisassemble ? AppColors.orange : AppColors.secondary)
                  .withValues(alpha: 0.12),
          selectedForegroundColor: _isDisassemble
              ? AppColors.orange
              : AppColors.secondary,
        ),
      ),
    );
  }

  Widget _buildProductPicker(BuildContext context) {
    return InkWell(
      onTap: _pickProduct,
      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
      child: Container(
        padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(
            AppResponsive.borderRadius(context),
          ),
          border: Border.all(
            color: _selectedProduct != null
                ? AppColors.primary
                : AppColors.divider,
            width: _selectedProduct != null ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(
                  AppResponsive.smallBorderRadius(context),
                ),
              ),
              child: Icon(
                Icons.inventory_rounded,
                color: AppColors.secondary,
                size: AppResponsive.iconSize(context),
              ),
            ),
            SizedBox(width: AppResponsive.mediumSpacing(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Repack/Kit product',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedProduct?.productName ??
                        'Select a product to assemble',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: _selectedProduct != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  /// Shown only for a multi-variant kit — each variant has its own recipe.
  Widget _buildVariantPicker(BuildContext context) {
    return Wrap(
      spacing: AppResponsive.smallSpacing(context),
      runSpacing: AppResponsive.smallSpacing(context),
      children: [
        for (final v in _kitVariants)
          ChoiceChip(
            label: Text(
              v.hasAttributes ? v.variantDescription : (v.sku ?? 'Variant'),
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            selected: v.varianteId == _selectedVariantId,
            onSelected: (_) => _selectVariant(v.varianteId),
            selectedColor: AppColors.primary.withValues(alpha: 0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
      ],
    );
  }

  Widget _buildBundleCard(BuildContext context) {
    final product = _selectedProduct!;
    final variant = _selectedVariant!;
    final bundle = _bundle;
    final isDisassemble = _isDisassemble;
    final modeColor = isDisassemble ? AppColors.orange : AppColors.secondary;

    if (bundle == null || !bundle.hasComponents) {
      return Container(
        padding: AppResponsive.cardPadding(context),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(
            AppResponsive.borderRadius(context),
          ),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.danger),
            SizedBox(width: AppResponsive.mediumSpacing(context)),
            Expanded(
              child: Text(
                '${product.productName} has no components configured. Add them '
                'from the Bundles screen before '
                '${isDisassemble ? 'disassembling' : 'assembling'} a batch.',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: AppColors.danger,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          controller: _batchQtyController,
          label: 'Batch Quantity',
          hint: isDisassemble
              ? 'How many units of ${product.productName} to break down'
              : 'How many units of ${product.productName} to assemble',
          icon: Icons.numbers_rounded,
          required: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
        ),
        if (_batchQty > 0) ...[
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.mediumSpacing(context),
              vertical: AppResponsive.smallSpacing(context),
            ),
            decoration: BoxDecoration(
              color: modeColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(
                AppResponsive.smallBorderRadius(context),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isDisassemble ? Icons.undo_rounded : Icons.inventory_rounded,
                  size: AppResponsive.smallIconSize(context),
                  color: modeColor,
                ),
                SizedBox(width: AppResponsive.smallSpacing(context)),
                Expanded(
                  child: Text(
                    isDisassemble
                        ? '$_batchQty pcs will be removed from ${product.productName} '
                              'stock; components restored.'
                        : '$_batchQty pcs will be added to ${product.productName} '
                              'stock; components consumed.',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: modeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: AppResponsive.largeSpacing(context)),
        if (isDisassemble) ...[
          Text(
            'Available To Disassemble',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          _buildStockStatusRow(
            context,
            name: product.productName,
            required: _batchQty.toDouble(),
            available: variant.stockQty,
            exists: true,
          ),
          SizedBox(height: AppResponsive.largeSpacing(context)),
          Text(
            'Components To Be Restored',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          ...bundle.components.map(
            (line) => _buildRestoreRow(context, line, _batchQty),
          ),
        ] else ...[
          Text(
            'Components Required',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          ...bundle.components.map(
            (line) => _buildComponentRow(context, line, _batchQty),
          ),
        ],
        SizedBox(height: AppResponsive.largeSpacing(context)),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_canSubmit && !_submitting) ? _confirm : null,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Icon(
                    isDisassemble
                        ? Icons.undo_rounded
                        : Icons.inventory_rounded,
                  ),
            label: Text(
              _submitting
                  ? (isDisassemble ? 'Disassembling...' : 'Assembling...')
                  : (isDisassemble ? 'Disassemble' : 'Assemble'),
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: modeColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.divider,
              padding: EdgeInsets.symmetric(
                vertical: AppResponsive.mediumSpacing(context),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComponentRow(
    BuildContext context,
    BundleComponentModel line,
    int batchQty,
  ) {
    final componentVariant = _componentVariant(line.componentVariantId);
    final componentName = _componentName(
      line.componentVariantId,
      componentVariant,
    );
    final required = (line.quantity * batchQty).toDouble();
    final available = componentVariant?.stockQty ?? 0;

    return _buildStockStatusRow(
      context,
      name: componentName,
      required: required,
      available: available,
      exists: componentVariant != null,
    );
  }

  /// Disassemble-mode counterpart to [_buildComponentRow]: components only
  /// ever gain stock on a disassembly (the kit-side shortage check in
  /// [_buildStockStatusRow] above already covers the one way this operation
  /// can fail), so this is purely informational — no "Short"/"Sufficient"
  /// verdict, just what each component's balance will become.
  Widget _buildRestoreRow(
    BuildContext context,
    BundleComponentModel line,
    int batchQty,
  ) {
    final componentVariant = _componentVariant(line.componentVariantId);
    final componentName = _componentName(
      line.componentVariantId,
      componentVariant,
    );
    final restoreQty = line.quantity * batchQty;
    final available = componentVariant?.stockQty ?? 0;
    final projected = available + restoreQty;

    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  componentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Restores $restoreQty pcs  ·  Have $available pcs  ·  Will be $projected pcs',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.smallSpacing(context),
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(
                AppResponsive.smallBorderRadius(context),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.add_circle_outline_rounded,
                  size: 13,
                  color: AppColors.info,
                ),
                SizedBox(width: 5),
                Text(
                  'Restored',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    fontWeight: FontWeight.w700,
                    color: AppColors.info,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Shared "need X, have Y" card used both for [_buildComponentRow] (assemble
  /// mode — component stock vs. what the batch needs) and the kit-availability
  /// check in disassemble mode (the kit variant's own stock vs. the batch
  /// being broken down) — same visual language, different subject.
  Widget _buildStockStatusRow(
    BuildContext context, {
    required String name,
    required double required,
    required double available,
    required bool exists,
  }) {
    final hasEnough = exists && available >= required;
    final Color color = !exists
        ? AppColors.textSecondary
        : (hasEnough ? AppColors.success : AppColors.danger);

    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Need $required pcs  ·  Have $available pcs',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.smallSpacing(context),
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(
                AppResponsive.smallBorderRadius(context),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  !exists
                      ? Icons.help_outline_rounded
                      : (hasEnough
                            ? Icons.check_circle_rounded
                            : Icons.warning_rounded),
                  size: 13,
                  color: color,
                ),
                SizedBox(width: 5),
                Text(
                  !exists ? 'Missing' : (hasEnough ? 'Sufficient' : 'Short'),
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  VarianteModel? _componentVariant(String componentVariantId) {
    try {
      return productStore.variants.firstWhere(
        (v) => v.varianteId == componentVariantId,
      );
    } catch (_) {
      return null;
    }
  }

  String _componentName(
    String componentVariantId,
    VarianteModel? componentVariant,
  ) {
    String componentName = componentVariant?.sku ?? componentVariantId;
    if (componentVariant != null) {
      try {
        final componentProduct = productStore.products.firstWhere(
          (p) => p.productId == componentVariant.productId,
        );
        componentName = componentVariant.hasAttributes
            ? '${componentProduct.productName} (${componentVariant.variantDescription})'
            : componentProduct.productName;
      } catch (_) {}
    }
    return componentName;
  }

  /// One combined, time-sorted history for this variant — forward assemblies
  /// and disassemblies both write [RetailKitAssemblyModel] rows to the same
  /// box and [KitAssemblyRepository.getAssembliesForVariant] already returns
  /// them newest-first regardless of direction, so there's no natural split
  /// point; [_buildAssemblyTile] distinguishes the two via [_KitMode]-style
  /// badges instead of separate lists.
  Widget _buildRecentAssemblies(BuildContext context) {
    final assemblies = kitAssemblyRepository.getAssembliesForVariant(
      _selectedVariant!.varianteId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: AppResponsive.smallSpacing(context)),
        if (assemblies.isEmpty)
          Container(
            width: double.infinity,
            padding: AppResponsive.cardPadding(context),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(
                AppResponsive.borderRadius(context),
              ),
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(
              'No batches assembled or disassembled yet.',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          ...assemblies.map((a) => _buildAssemblyTile(context, a)),
      ],
    );
  }

  Widget _buildAssemblyTile(BuildContext context, RetailKitAssemblyModel a) {
    final isReversal = a.isReversal;
    final Color color = isReversal ? AppColors.orange : AppColors.success;
    final IconData icon = isReversal
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;
    final String sign = isReversal ? '-' : '+';
    final String badgeLabel = isReversal ? 'Disassembled' : 'Assembled';

    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(
                AppResponsive.smallBorderRadius(context),
              ),
            ),
            child: Icon(
              icon,
              size: AppResponsive.smallIconSize(context),
              color: color,
            ),
          ),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$sign${a.batchQty} pcs',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    SizedBox(width: AppResponsive.smallSpacing(context)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeLabel,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.captionFontSize(context),
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM yyyy · hh:mm a').format(a.assembledTime),
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (a.assembledBy != null && a.assembledBy!.isNotEmpty)
            Text(
              a.assembledBy!,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Simple searchable list dialog limited to repack/kit products — same shape
/// as restaurant's Semi-Finished picker in `production_screen.dart`.
class _RepackPickerDialog extends StatefulWidget {
  final List<ProductModel> products;

  const _RepackPickerDialog({required this.products});

  @override
  State<_RepackPickerDialog> createState() => _RepackPickerDialogState();
}

class _RepackPickerDialogState extends State<_RepackPickerDialog> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.products
        : widget.products
              .where(
                (p) =>
                    p.productName.toLowerCase().contains(_query.toLowerCase()),
              )
              .toList();

    return AppDialogShell(
      title: 'Select Repack/Kit Product',
      accent: AppColors.secondary,
      icon: Icons.inventory_rounded,
      body: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.5,
        child: Column(
          children: [
            AppTextField(
              controller: _searchController,
              hint: 'Search repack/kit products...',
              icon: Icons.search_rounded,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
            ),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            Expanded(
              child: filtered.isEmpty
                  ? const AppEmptyState(
                      dense: true,
                      icon: Icons.search_off_rounded,
                      title: 'No products found',
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = filtered[index];
                        final variant = productStore.primaryVariantFor(
                          product.productId,
                        );
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            product.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: AppResponsive.bodyFontSize(context),
                            ),
                          ),
                          subtitle: Text(
                            'Stock: ${variant?.stockQty ?? 0} pcs',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.smallFontSize(context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                          onTap: () => Navigator.pop(context, product),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [appDialogCancelButton(context, label: 'Close')],
    );
  }
}
