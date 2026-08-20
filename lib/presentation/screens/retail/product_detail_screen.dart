import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/screens/retail/add_product_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/config/tax_feature.dart';
import '../../../data/models/common/taxmodel_314.dart';
import '../../../data/models/retail/hive_model/attribute_model_219.dart';
import '../../../data/models/retail/hive_model/product_model_200.dart';
import '../../../data/models/retail/hive_model/variante_model_201.dart';
import '../../../domain/services/common/notification_service.dart';
import '../../../domain/services/retail/simple_product_fields_service.dart';
import '../../../domain/services/retail/variant_attribute_mapper.dart';
import '../../../domain/store/retail/product_store.dart';
import 'package:billberrylite/core/plan/plan_guard.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';

/// Money input — digits with at most two decimals, the same rule the checkout,
/// expense and add-product screens apply.
final _moneyFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
];

/// Whole-number input (stock counts).
final _qtyFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
];

/// Everything about one product in one place: its details at the top, then every
/// variant with the stock it carries and what it sells for.
///
/// Reached from the Products tab by tapping a product. This is the only screen
/// for a product — the details form is a dialog-style side trip from here, not
/// a separate destination.
class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  /// Configured descriptor fields (Settings → Simple Product Fields). The first
  /// one becomes the grouping axis for the list.
  List<AttributeModel> _fields = [];

  /// Group key for variants with no value for the grouping field.
  static const String _ungroupedKey = '__ungrouped__';

  @override
  void initState() {
    super.initState();
    // The list itself comes from the store's observables — this only makes sure
    // they are populated when the screen is reached without going via Inventory.
    productStore.loadVariants();
    _loadFields();
  }

  Future<void> _loadFields() async {
    final fields = await SimpleProductFieldsService().resolveFields();
    if (!mounted) return;
    setState(() => _fields = fields);
  }

  /// The field variants are grouped by — the first configured descriptor field,
  /// not hardcoded colour. Null when nothing is configured.
  AttributeModel? get _groupingField => _fields.isEmpty ? null : _fields.first;

  /// Only show the colour swatch when the grouping field is actually a colour —
  /// grouping by Flavour or Capacity should not render colour dots.
  bool get _isColourLike {
    final name = _groupingField?.name.toLowerCase() ?? '';
    return name.contains('color') || name.contains('colour');
  }

  /// This variant's value for the grouping field.
  String _groupValueFor(VarianteModel variant) {
    final field = _groupingField;
    if (field == null) return '';
    return attributeStore.attributesOf(variant)[field.name] ?? '';
  }

  /// The live product, not the snapshot this screen was pushed with — editing
  /// the details must be reflected here without a reopen. Falls back to the
  /// snapshot only while the store is still loading.
  ///
  /// MUST be read inside an Observer to stay current.
  ProductModel get _product =>
      productStore.getProductById(widget.product.productId) ?? widget.product;

  /// Resolves the product's category name once, used as the SKU prefix when
  /// auto-generating for new variants added from this screen.
  String? _categoryName() {
    for (final c in categoryStore.categories) {
      if (c.id == widget.product.category) return c.name;
    }
    return null;
  }

  // ==================== ACTIONS ====================
  void _openAddVariant() {
    showDialog(
      context: context,
      builder: (_) => _AddVariantDialog(
        productId: widget.product.productId,
        categoryName: _categoryName(),
      ),
    );
  }

  void _openBulkAdd() {
    showDialog(
      context: context,
      builder: (_) => _BulkAddVariantDialog(
        productId: widget.product.productId,
        categoryName: _categoryName(),
      ),
    );
  }

  void _openEditVariant(VarianteModel variant) {
    showDialog(
      context: context,
      builder: (_) => _EditVariantDialog(variant: variant),
    );
  }

  Future<void> _deleteVariant(VarianteModel variant) async {
    if (!PlanGuard.allowedOr(
      context,
      RetailEntKeys.catalogVariantsDelete,
      featureName: 'Delete Variants',
    )) {
      return;
    }
    // A product with no variants still shows in the list but the POS refuses
    // it ("No variants available"), so it would be invisible stock.
    if (productStore.variantCountFor(widget.product.productId) <= 1) {
      NotificationService.instance.showError(
        'A product needs at least one variant. Delete the product instead.',
      );
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete Variant?',
      message:
          'Delete "${variant.shortDescription}"? '
          'Its stock and pricing are removed with it.',
      confirmLabel: 'Delete',
      accent: AppColors.danger,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;

    await productStore.deleteVariant(variant.varianteId);
    NotificationService.instance.showSuccess('Variant deleted');
  }

  void _editDetails() => openEditProductScreen(context, _product);

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        // Observed, so renaming the product updates the bar without a reopen.
        titleWidget: Observer(
          builder: (_) => Text(
            _product.productName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 20 : 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        // Variant actions above the divider, the product itself below it.
        // Deleting the whole product stays on its card in the Products list.
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Actions',
            // M3 tints menu surfaces by default; keep them plain white.
            color: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              switch (value) {
                case 'add':
                  _openAddVariant();
                  break;
                case 'bulk':
                  _openBulkAdd();
                  break;
                case 'edit':
                  _editDetails();
                  break;
              }
            },
            itemBuilder: (context) => [
              _menuItem('add', Icons.add, 'Add Variant'),
              _menuItem(
                'bulk',
                Icons.library_add_outlined,
                'Bulk Add Variants',
              ),
              const PopupMenuDivider(),
              _menuItem('edit', Icons.edit_outlined, 'Edit Details'),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: MoneyScope(
          child: AppResponsive.constrainedContent(
            context: context,
            alignment: Alignment.topCenter,
            child: Observer(
              builder: (context) {
                final variants = productStore.variantsFor(
                  widget.product.productId,
                );
                return Column(
                  children: [
                    // Product details stay visible whether or not any variants
                    // exist — this is the product's screen, not just a list.
                    _buildInfoStrip(),
                    Expanded(
                      child: variants.isEmpty
                          ? _buildEmptyState()
                          : _buildVariantList(variants),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, [
    Color? color,
  ]) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== INFO STRIP ====================
  /// Category · brand · HSN · tax. Read-only — editing lives in the AppBar
  /// menu, so it is offered in exactly one place.
  Widget _buildInfoStrip() {
    final product = _product;
    final categoryName =
        categoryStore.categoryNameById[product.category] ?? product.category;

    final bits = <String>[
      if (categoryName.isNotEmpty) categoryName,
      if (product.brandName?.isNotEmpty ?? false) product.brandName!,
      if (product.hsnCode?.isNotEmpty ?? false) 'HSN ${product.hsnCode}',
      if (product.gstRate != null) 'GST ${product.gstRate}%',
    ];

    return Container(
      margin: EdgeInsets.fromLTRB(
        AppResponsive.screenPadding(context).left,
        AppResponsive.screenPadding(context).top,
        AppResponsive.screenPadding(context).right,
        0,
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sell_outlined,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              bits.isEmpty ? 'No details set' : bits.join('  ·  '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return AppEmptyState(
      icon: Icons.layers_outlined,
      title: 'No variants yet',
      message: 'Add a variant for each option you stock.',
      action: appEmptyStateAction(
        label: 'Add First Variant',
        onPressed: _openAddVariant,
      ),
    );
  }

  // ==================== LIST ====================
  Widget _buildVariantList(List<VarianteModel> variants) {
    // Group by the first configured field (was hardcoded to colour).
    final grouped = <String, List<VarianteModel>>{};
    for (final variant in variants) {
      final value = _groupValueFor(variant);
      grouped
          .putIfAbsent(value.isEmpty ? _ungroupedKey : value, () => [])
          .add(variant);
    }

    return Column(
      children: [
        _buildSummaryCard(variants),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
              AppResponsive.screenPadding(context).left,
              0,
              AppResponsive.screenPadding(context).right,
              AppResponsive.screenPadding(context).bottom,
            ),
            itemCount: grouped.length,
            itemBuilder: (context, index) => _buildGroup(
              grouped.keys.elementAt(index),
              grouped.values.elementAt(index),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== SUMMARY ====================
  Widget _buildSummaryCard(List<VarianteModel> variants) {
    final totalStock = variants.fold<int>(0, (sum, v) => sum + v.stockQty);
    // Averages what the shop actually charges, not what it paid.
    final avgPrice = variants.isEmpty
        ? 0.0
        : variants.fold<double>(0, (sum, v) => sum + v.effectivePrice) /
              variants.length;

    return Container(
      // Top spacing comes from the info strip directly above.
      margin: EdgeInsets.fromLTRB(
        AppResponsive.screenPadding(context).left,
        12,
        AppResponsive.screenPadding(context).right,
        AppResponsive.screenPadding(context).bottom,
      ),
      padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildSummaryTile(
            icon: Icons.layers_rounded,
            value: '${variants.length}',
            label: 'Total Variants',
          ),
          _buildSummaryTile(
            icon: Icons.inventory_2_rounded,
            value: '$totalStock',
            label: 'Total Stock',
          ),
          _buildSummaryTile(
            icon: Icons.sell_rounded,
            value: formatMoney(avgPrice),
            label: 'Avg Price',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTile({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.subheadingFontSize(context),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== GROUP ====================
  Widget _buildGroup(String groupKey, List<VarianteModel> groupVariants) {
    final isUngrouped = groupKey == _ungroupedKey;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                if (_isColourLike && !isUngrouped) ...[
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _colorForName(groupKey),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.divider),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    isUngrouped ? 'Not set' : groupKey,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${groupVariants.length} variant'
                  '${groupVariants.length == 1 ? '' : 's'}',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ...groupVariants.map(_buildVariantRow),
        ],
      ),
    );
  }

  // ==================== ROW ====================
  Widget _buildVariantRow(VarianteModel variant) {
    // Derived in the store so this screen and Inventory can never disagree.
    final status = productStore.stockStatusForVariant(variant);
    final isLowStock = status != RetailStockStatus.inStock;
    final isSellable = productStore.isSellable(variant);
    final description = attributeStore.describeAttributes(
      attributeStore.attributesOf(variant),
    );

    return InkWell(
      onTap: () => _openEditVariant(variant),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.surfaceMedium)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          description.isEmpty ? 'Default' : description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            fontWeight: FontWeight.w600,
                            color: isSellable
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (!isSellable) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMedium,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Inactive',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.captionFontSize(context),
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Stock: ${variant.stockQty}',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.captionFontSize(context),
                          color: isLowStock
                              ? AppColors.danger
                              : AppColors.textSecondary,
                          fontWeight: isLowStock
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      if (isLowStock) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.warning_rounded,
                          color: AppColors.danger,
                          size: 13,
                        ),
                      ],
                    ],
                  ),
                  if (variant.sku != null && variant.sku!.isNotEmpty)
                    Text(
                      'SKU: ${variant.sku}',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // The selling price is what the POS actually charges.
                Text(
                  formatMoney(variant.effectivePrice),
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
                if (variant.mrp != null)
                  Text(
                    'MRP: ${formatMoney(variant.mrp!)}',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: AppColors.textSecondary,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                if (variant.costPrice != null)
                  Text(
                    'Cost: ${formatMoney(variant.costPrice!)}',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            // Edit/delete stay behind the overflow menu — never extra icons.
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                color: AppColors.textSecondary,
                size: 20,
              ),
              // M3 tints menu surfaces by default; keep them plain white.
              color: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) {
                if (value == 'edit') {
                  _openEditVariant(variant);
                } else if (value == 'delete') {
                  _deleteVariant(variant);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Edit',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Delete',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          color: AppColors.danger,
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
    );
  }

  /// Fallback swatch for a colour named in free text. Attribute values can also
  /// carry a real colorCode — wiring that up is a separate change.
  Color _colorForName(String name) {
    switch (name.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'yellow':
        return Colors.yellow;
      case 'black':
        return Colors.black;
      case 'white':
        return Colors.white;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      case 'pink':
        return Colors.pink;
      case 'brown':
        return Colors.brown;
      default:
        return AppColors.surfaceMedium;
    }
  }
}

// ============================================================================
// ADD VARIANT
// ============================================================================
class _AddVariantDialog extends StatefulWidget {
  final String productId;
  final String? categoryName;

  const _AddVariantDialog({required this.productId, this.categoryName});

  @override
  State<_AddVariantDialog> createState() => _AddVariantDialogState();
}

class _AddVariantDialogState extends State<_AddVariantDialog> {
  final _formKey = GlobalKey<FormState>();

  /// Descriptor fields from Settings → Simple Product Fields, replacing the
  /// previously hardcoded Size / Color / Weight inputs.
  List<AttributeModel> _fields = [];
  final Map<String, TextEditingController> _fieldControllers = {};

  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();
  String? _selectedTaxId;

  final List<_CustomAttrData> _customAttributes = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    taxStore.loadTaxes();
    _loadFields();
  }

  Future<void> _loadFields() async {
    final fields = await SimpleProductFieldsService().resolveFields();
    if (!mounted) return;
    setState(() => _fields = fields);
  }

  TextEditingController _fieldController(String attributeId) =>
      _fieldControllers.putIfAbsent(attributeId, () => TextEditingController());

  @override
  void dispose() {
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    _skuController.dispose();
    _barcodeController.dispose();
    _sellingPriceController.dispose();
    _costPriceController.dispose();
    _mrpController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    for (final attr in _customAttributes) {
      attr.dispose();
    }
    super.dispose();
  }

  /// Hint from the attribute's own defined values, so a grocery shop sees
  /// "e.g. 500ml" rather than a hardcoded apparel example.
  String? _hintForAttribute(AttributeModel attribute) {
    final values = attributeStore.getValues(attribute.attributeId);
    return values.isEmpty ? null : 'e.g. ${values.first.value}';
  }

  Future<void> _save() async {
    if (!PlanGuard.allowedOr(
      context,
      RetailEntKeys.catalogVariantsAdd,
      featureName: 'Add Variants',
    )) {
      return;
    }
    if (!_formKey.currentState!.validate() || _saving) return;

    final barcode = _barcodeController.text.trim();
    if (productStore.isBarcodeTaken(barcode)) {
      NotificationService.instance.showError(
        'Barcode "$barcode" is already used by another variant',
      );
      return;
    }

    setState(() => _saving = true);

    // Auto-generate only when left blank — never overwrite what was typed.
    final sku = _skuController.text.trim().isEmpty
        ? await skuGeneratorService.generate(widget.categoryName)
        : _skuController.text.trim();

    final variantId =
        '${widget.productId}_${DateTime.now().millisecondsSinceEpoch}';

    // Configured fields + any one-off rows, projected onto the legacy columns
    // by the one shared rule so receipts and reports keep working.
    final entered = <String, String>{
      for (final attribute in _fields)
        if ((_fieldControllers[attribute.attributeId]?.text.trim() ?? '')
            .isNotEmpty)
          attribute.name: _fieldControllers[attribute.attributeId]!.text.trim(),
    };
    final attributes = mergeVariantAttributes(
      entered,
      extraCustomAttributes: _customAttributesMap(_customAttributes),
    );

    final variant = VarianteModel.create(
      varianteId: variantId,
      productId: widget.productId,
      sku: sku,
      barcode: barcode.isEmpty ? null : barcode,
      // sellingPrice is what the POS bills — it must be set here, or the cart
      // falls back to MRP (cart_store.dart: sellingPrice ?? mrp ?? 0).
      sellingPrice: double.tryParse(_sellingPriceController.text.trim()) ?? 0.0,
      costPrice: _costPriceController.text.trim().isEmpty
          ? null
          : double.tryParse(_costPriceController.text.trim()),
      mrp: _mrpController.text.trim().isEmpty
          ? null
          : double.tryParse(_mrpController.text.trim()),
      stockQty: int.tryParse(_stockController.text.trim()) ?? 0,
      minStock: _minStockController.text.trim().isEmpty
          ? null
          : int.tryParse(_minStockController.text.trim()),
      taxRate: _taxRateFor(_selectedTaxId),
      taxId: _selectedTaxId,
      customAttributes: attributes,
    );

    await productStore.addVariant(variant);
    if (!mounted) return;
    Navigator.pop(context);
    NotificationService.instance.showSuccess('Variant added');
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      title: 'Add Variant',
      subtitle: 'A single variant with its own stock and barcode',
      accent: AppColors.primary,
      icon: Icons.layers_rounded,
      body: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final attribute in _fields) ...[
              AppTextField(
                controller: _fieldController(attribute.attributeId),
                label: attribute.name,
                hint: _hintForAttribute(attribute),
                icon: Icons.label_outline_rounded,
              ),
              const SizedBox(height: 12),
            ],
            AppTextField(
              controller: _sellingPriceController,
              label: 'Selling Price',
              hint: '0.00',
              icon: Icons.sell_outlined,
              required: true,
              keyboardType: TextInputType.number,
              inputFormatters: _moneyFormatters,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _costPriceController,
              label: 'Cost Price (Optional)',
              hint: '0.00',
              icon: Icons.payments_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: _moneyFormatters,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _mrpController,
              label: 'MRP (Optional)',
              hint: '0.00',
              icon: Icons.local_offer_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: _moneyFormatters,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _stockController,
              label: 'Stock Quantity',
              hint: '0',
              icon: Icons.inventory_2_outlined,
              required: true,
              keyboardType: TextInputType.number,
              inputFormatters: _qtyFormatters,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _minStockController,
              label: 'Min Stock (Optional)',
              hint: '0',
              icon: Icons.warning_amber_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: _qtyFormatters,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _barcodeController,
              label: 'Barcode (Optional)',
              hint: 'Scan or enter',
              icon: Icons.qr_code_rounded,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _skuController,
              label: 'SKU (Optional)',
              hint: 'Generated when left blank',
              icon: Icons.tag_rounded,
            ),
            if (TaxFeature.enabled) ...[
              const SizedBox(height: 12),
              _taxDropdown(
                context,
                _selectedTaxId,
                (value) => setState(() => _selectedTaxId = value),
              ),
            ],
            _CustomAttributesSection(
              attributes: _customAttributes,
              emptyHint: 'Add custom attributes like Material, Flavor, etc.',
              onChanged: () => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        appDialogCancelButton(context),
        const SizedBox(width: 12),
        appDialogPrimaryButton(label: 'Add', onPressed: _save),
      ],
    );
  }
}

// ============================================================================
// EDIT VARIANT
// ============================================================================
class _EditVariantDialog extends StatefulWidget {
  final VarianteModel variant;

  const _EditVariantDialog({required this.variant});

  @override
  State<_EditVariantDialog> createState() => _EditVariantDialogState();
}

class _EditVariantDialogState extends State<_EditVariantDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _mrpController;
  late final TextEditingController _stockController;
  late final TextEditingController _minStockController;

  /// False parks the variant: it keeps its stock and history but disappears
  /// from the POS, so a line can be pulled from sale without being deleted.
  late bool _active;

  final List<_CustomAttrData> _customAttributes = [];

  @override
  void initState() {
    super.initState();
    final v = widget.variant;
    _active = productStore.isSellable(v);
    _sellingPriceController = TextEditingController(
      text: v.sellingPrice?.toString() ?? '',
    );
    _costPriceController = TextEditingController(
      text: v.costPrice?.toString() ?? '',
    );
    _mrpController = TextEditingController(text: v.mrp?.toString() ?? '');
    _stockController = TextEditingController(text: v.stockQty.toString());
    _minStockController = TextEditingController(
      text: v.minStock?.toString() ?? '',
    );

    for (final entry
        in (v.customAttributes ?? const <String, String>{}).entries) {
      final attr = _CustomAttrData();
      attr.keyController.text = entry.key;
      attr.valueController.text = entry.value;
      _customAttributes.add(attr);
    }
  }

  @override
  void dispose() {
    _sellingPriceController.dispose();
    _costPriceController.dispose();
    _mrpController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    for (final attr in _customAttributes) {
      attr.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!PlanGuard.allowedOr(
      context,
      RetailEntKeys.catalogVariantsEdit,
      featureName: 'Edit Variants',
    )) {
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final mrpText = _mrpController.text.trim();
    final minStockText = _minStockController.text.trim();

    // MUST go through copyWith. Hand-building a VarianteModel here is how
    // sellingPrice, hsnCode, attributeValueIds, imagePath, isDefault and status
    // used to get silently wiped on every edit.
    final updated = widget.variant.copyWith(
      sellingPrice: double.tryParse(_sellingPriceController.text.trim()) ?? 0.0,
      costPrice: _costPriceController.text.trim().isEmpty
          ? null
          : double.tryParse(_costPriceController.text.trim()),
      mrp: mrpText.isEmpty ? null : double.tryParse(mrpText),
      clearMrp: mrpText.isEmpty,
      stockQty: int.tryParse(_stockController.text.trim()) ?? 0,
      minStock: minStockText.isEmpty ? null : int.tryParse(minStockText),
      clearMinStock: minStockText.isEmpty,
      status: _active ? kActiveVariantStatus : kInactiveVariantStatus,
      // An empty map rather than null, so removing every row actually clears
      // them instead of falling back to the old values.
      customAttributes:
          _customAttributesMap(_customAttributes) ?? const <String, String>{},
    );

    await productStore.updateVariant(updated);
    if (!mounted) return;
    Navigator.pop(context);
    NotificationService.instance.showSuccess('Variant updated');
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      title: 'Edit Variant',
      subtitle: widget.variant.hasAttributes
          ? widget.variant.variantDescription
          : null,
      accent: AppColors.primary,
      icon: Icons.edit_outlined,
      body: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              controller: _sellingPriceController,
              label: 'Selling Price',
              hint: '0.00',
              icon: Icons.sell_outlined,
              required: true,
              keyboardType: TextInputType.number,
              inputFormatters: _moneyFormatters,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _costPriceController,
              label: 'Cost Price (Optional)',
              hint: '0.00',
              icon: Icons.payments_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: _moneyFormatters,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _mrpController,
              label: 'MRP (Optional)',
              hint: '0.00',
              icon: Icons.local_offer_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: _moneyFormatters,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _stockController,
              label: 'Stock Quantity',
              hint: '0',
              icon: Icons.inventory_2_outlined,
              required: true,
              keyboardType: TextInputType.number,
              inputFormatters: _qtyFormatters,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _minStockController,
              label: 'Min Stock (Optional)',
              hint: '0',
              icon: Icons.warning_amber_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: _qtyFormatters,
            ),
            const SizedBox(height: 4),
            SwitchListTile.adaptive(
              value: _active,
              onChanged: (value) => setState(() => _active = value),
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeThumbColor: AppColors.primary,
              title: Text(
                'Available for sale',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                _active
                    ? 'Shows on the billing screen'
                    : 'Hidden from billing — stock and history are kept',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            _CustomAttributesSection(
              attributes: _customAttributes,
              emptyHint: 'No custom attributes',
              onChanged: () => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        appDialogCancelButton(context),
        const SizedBox(width: 12),
        appDialogPrimaryButton(label: 'Update', onPressed: _save),
      ],
    );
  }
}

// ============================================================================
// BULK ADD VARIANTS
// ============================================================================
class _BulkAddVariantDialog extends StatefulWidget {
  final String productId;
  final String? categoryName;

  const _BulkAddVariantDialog({required this.productId, this.categoryName});

  @override
  State<_BulkAddVariantDialog> createState() => _BulkAddVariantDialogState();
}

class _BulkAddVariantDialogState extends State<_BulkAddVariantDialog> {
  final _formKey = GlobalKey<FormState>();

  // Shared across every generated variant.
  final _costPriceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _minStockController = TextEditingController();
  final _baseBarcodeController = TextEditingController();
  String? _selectedTaxId;

  /// Configured descriptor fields (Settings → Simple Product Fields).
  List<AttributeModel> _fields = [];

  /// The attribute that VARIES across the generated variants — one variant per
  /// selected value. Replaces the old hardcoded "sizes" axis.
  AttributeModel? _varyingAttribute;

  /// Selected values of [_varyingAttribute], from its defined values plus any
  /// typed in here.
  final Set<String> _selectedValues = {};
  final List<String> _customValues = [];
  final _customValueController = TextEditingController();

  /// Per-variant price and stock, keyed by value. Created the moment a value is
  /// picked and disposed the moment it is dropped — a row must never outlive
  /// its value, or it would render an already-disposed controller.
  final Map<String, _BulkRow> _rows = {};

  /// Fixed values applied to EVERY generated variant (the other fields).
  final Map<String, TextEditingController> _fixedControllers = {};

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    taxStore.loadTaxes();
    _loadFields();
  }

  Future<void> _loadFields() async {
    final fields = await SimpleProductFieldsService().resolveFields();
    if (!mounted) return;
    setState(() {
      _fields = fields;
      // Default the varying axis to the first configured field.
      _varyingAttribute = fields.isEmpty ? null : fields.first;
    });
  }

  @override
  void dispose() {
    _customValueController.dispose();
    for (final controller in _fixedControllers.values) {
      controller.dispose();
    }
    for (final row in _rows.values) {
      row.dispose();
    }
    _costPriceController.dispose();
    _mrpController.dispose();
    _minStockController.dispose();
    _baseBarcodeController.dispose();
    super.dispose();
  }

  TextEditingController _fixedController(String attributeId) =>
      _fixedControllers.putIfAbsent(attributeId, () => TextEditingController());

  /// Values offered for the varying attribute: its defined values.
  List<String> get _availableValues {
    final attribute = _varyingAttribute;
    if (attribute == null) return const [];
    return attributeStore
        .getValues(attribute.attributeId)
        .map((v) => v.value)
        .toList();
  }

  /// Everything that will become a variant, in a stable display order:
  /// preset values in their defined order, then anything typed in.
  List<String> get _chosenValues => [
    ..._availableValues.where(_selectedValues.contains),
    ..._customValues,
  ];

  _BulkRow _rowFor(String value) => _rows.putIfAbsent(value, () => _BulkRow());

  void _dropRow(String value) => _rows.remove(value)?.dispose();

  void _clearRows() {
    for (final row in _rows.values) {
      row.dispose();
    }
    _rows.clear();
  }

  void _addCustomValue() {
    final value = _customValueController.text.trim();
    if (value.isEmpty ||
        _customValues.contains(value) ||
        _availableValues.contains(value)) {
      return;
    }
    setState(() {
      _customValues.add(value);
      _rowFor(value);
      _customValueController.clear();
    });
  }

  /// Copies the first row's price and quantity down the rest — the common case
  /// is "same price for all sizes, tweak one or two".
  void _fillDown() {
    final values = _chosenValues;
    if (values.length < 2) return;
    final first = _rows[values.first];
    if (first == null) return;
    for (final value in values.skip(1)) {
      final row = _rowFor(value);
      row.priceController.text = first.priceController.text;
      row.stockController.text = first.stockController.text;
    }
    setState(() {});
  }

  Future<void> _save() async {
    if (!PlanGuard.allowedOr(
      context,
      RetailEntKeys.catalogVariantsAdd,
      featureName: 'Add Variants',
    )) {
      return;
    }
    if (!_formKey.currentState!.validate() || _saving) return;

    final values = _chosenValues;
    final varying = _varyingAttribute;

    if (varying == null || values.isEmpty) {
      NotificationService.instance.showError(
        varying == null
            ? 'Add a field in Settings → Simple Product Fields first'
            : 'Select at least one ${varying.name.toLowerCase()}',
      );
      return;
    }

    // Every barcode this run would produce, checked before writing any of
    // them — a half-saved batch is worse than a rejected one.
    final baseBarcodeText = _baseBarcodeController.text.trim();
    if (baseBarcodeText.isNotEmpty) {
      for (var i = 1; i <= values.length; i++) {
        final candidate = '$baseBarcodeText${i.toString().padLeft(3, '0')}';
        if (productStore.isBarcodeTaken(candidate)) {
          NotificationService.instance.showError(
            'Barcode "$candidate" is already used by another variant',
          );
          return;
        }
      }
    }

    setState(() => _saving = true);

    // Values typed once and applied to every generated variant.
    final fixedValues = <String, String>{
      for (final attribute in _fields)
        if (attribute.attributeId != varying.attributeId &&
            (_fixedControllers[attribute.attributeId]?.text.trim() ?? '')
                .isNotEmpty)
          attribute.name: _fixedControllers[attribute.attributeId]!.text.trim(),
    };

    final costPrice = _costPriceController.text.trim().isEmpty
        ? null
        : double.tryParse(_costPriceController.text.trim());
    final mrp = _mrpController.text.trim().isEmpty
        ? null
        : double.tryParse(_mrpController.text.trim());
    final minStock = _minStockController.text.trim().isEmpty
        ? null
        : int.tryParse(_minStockController.text.trim());
    final baseBarcode = _baseBarcodeController.text.trim();
    final taxRate = _taxRateFor(_selectedTaxId);

    // One variant per selected value, each with its own price and stock.
    var counter = 1;
    for (final value in values) {
      final row = _rows[value];
      final variantId =
          '${widget.productId}_${DateTime.now().millisecondsSinceEpoch}_$counter';

      final barcode = baseBarcode.isEmpty
          ? null
          : '$baseBarcode${counter.toString().padLeft(3, '0')}';

      // Bulk-created variants have no manual SKU input, so every one gets an
      // auto-generated SKU (each call advances the shared global sequence).
      final sku = await skuGeneratorService.generate(widget.categoryName);

      await productStore.addVariant(
        VarianteModel.create(
          varianteId: variantId,
          productId: widget.productId,
          customAttributes: mergeVariantAttributes({
            ...fixedValues,
            varying.name: value,
          }),
          sku: sku,
          barcode: barcode,
          // sellingPrice is what the POS bills — see cart_store.dart.
          sellingPrice:
              double.tryParse(row?.priceController.text.trim() ?? '') ?? 0.0,
          costPrice: costPrice,
          mrp: mrp,
          stockQty: int.tryParse(row?.stockController.text.trim() ?? '') ?? 0,
          minStock: minStock,
          taxRate: taxRate,
          taxId: _selectedTaxId,
        ),
      );
      counter++;

      // Small delay to keep the timestamp-based ids unique.
      await Future.delayed(const Duration(milliseconds: 10));
    }

    if (!mounted) return;
    Navigator.pop(context);
    NotificationService.instance.showSuccess('${values.length} variants added');
  }

  @override
  Widget build(BuildContext context) {
    final values = _chosenValues;

    return AppDialogShell(
      title: 'Bulk Add Variants',
      subtitle: 'One variant per selected value, priced individually',
      // Blue rather than the usual primary, so this never reads as the plain
      // Add Variant form at a glance.
      accent: AppColors.info,
      icon: Icons.bolt_rounded,
      body: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. What varies ────────────────────────────────────────────
            if (_fields.length > 1)
              _styledDropdown<String>(
                context,
                label: 'Create one variant per',
                value: _varyingAttribute?.attributeId,
                items: _fields
                    .map(
                      (a) => DropdownMenuItem(
                        value: a.attributeId,
                        child: Text(
                          a.name,
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(context),
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  if (id == null) return;
                  setState(() {
                    _varyingAttribute = _fields.firstWhere(
                      (a) => a.attributeId == id,
                    );
                    _selectedValues.clear();
                    _customValues.clear();
                    _clearRows();
                  });
                },
              )
            else
              _sectionLabel(
                context,
                _varyingAttribute == null
                    ? 'No fields configured'
                    : 'One variant per ${_varyingAttribute!.name}',
              ),
            const SizedBox(height: 12),

            // ── 2. Pick the values ────────────────────────────────────────
            if (_availableValues.isEmpty && _customValues.isEmpty)
              Text(
                _varyingAttribute == null
                    ? 'Add a field in Settings → Simple Product Fields.'
                    : 'No preset values — type them below.',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            if (_availableValues.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableValues.map((value) {
                  final isSelected = _selectedValues.contains(value);
                  return FilterChip(
                    label: Text(
                      value,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(context),
                        color: isSelected
                            ? AppColors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _selectedValues.add(value);
                        _rowFor(value);
                      } else {
                        _selectedValues.remove(value);
                        _dropRow(value);
                      }
                    }),
                    selectedColor: AppColors.info,
                    checkmarkColor: AppColors.white,
                    backgroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppColors.divider),
                    ),
                  );
                }).toList(),
              ),
            if (_customValues.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _customValues
                    .map(
                      (value) => Chip(
                        label: Text(
                          value,
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            color: AppColors.white,
                          ),
                        ),
                        deleteIcon: const Icon(
                          Icons.close,
                          size: 16,
                          color: AppColors.white,
                        ),
                        onDeleted: () => setState(() {
                          _customValues.remove(value);
                          _dropRow(value);
                        }),
                        backgroundColor: AppColors.info,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _customValueController,
                    label: _varyingAttribute == null
                        ? 'Value'
                        : 'Add ${_varyingAttribute!.name}',
                    hint: 'Type a value and press +',
                    icon: Icons.label_outline_rounded,
                    enabled: _varyingAttribute != null,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _addCustomValue(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.info),
                  onPressed: _varyingAttribute == null ? null : _addCustomValue,
                ),
              ],
            ),

            // ── 3. Live preview ───────────────────────────────────────────
            if (values.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildPreviewBanner(context, values),
            ],

            // ── 4. Per-variant price and stock ────────────────────────────
            if (values.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(color: AppColors.divider),
              Row(
                children: [
                  Expanded(child: _sectionLabel(context, 'Per variant')),
                  if (values.length > 1)
                    TextButton.icon(
                      onPressed: _fillDown,
                      icon: const Icon(Icons.south_rounded, size: 15),
                      label: Text(
                        'Fill down',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.info,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                ],
              ),
              for (final value in values) _buildVariantRow(context, value),
            ],

            // ── 5. Everything shared ──────────────────────────────────────
            const SizedBox(height: 12),
            const Divider(color: AppColors.divider),
            _sectionLabel(
              context,
              values.isEmpty
                  ? 'Applies to all variants'
                  : 'Applies to all ${values.length} variant'
                        '${values.length == 1 ? '' : 's'}',
            ),
            const SizedBox(height: 12),
            for (final attribute in _fields)
              if (attribute.attributeId != _varyingAttribute?.attributeId) ...[
                AppTextField(
                  controller: _fixedController(attribute.attributeId),
                  label: attribute.name,
                  hint: 'Same for all variants',
                  icon: Icons.label_outline_rounded,
                ),
                const SizedBox(height: 12),
              ],
            AppTextField(
              controller: _costPriceController,
              label: 'Cost Price (Optional)',
              hint: '0.00',
              icon: Icons.payments_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: _moneyFormatters,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _mrpController,
              label: 'MRP (Optional)',
              hint: '0.00',
              icon: Icons.local_offer_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: _moneyFormatters,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _minStockController,
              label: 'Min Stock (Optional)',
              hint: '0',
              icon: Icons.warning_amber_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: _qtyFormatters,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _baseBarcodeController,
              label: 'Base Barcode (Optional)',
              hint: 'e.g. 789456 → 789456001, 789456002 …',
              icon: Icons.qr_code_rounded,
            ),
            if (TaxFeature.enabled) ...[
              const SizedBox(height: 12),
              _taxDropdown(
                context,
                _selectedTaxId,
                (value) => setState(() => _selectedTaxId = value),
              ),
            ],
          ],
        ),
      ),
      actions: [
        appDialogCancelButton(context),
        const SizedBox(width: 12),
        appDialogPrimaryButton(
          label: values.isEmpty ? 'Add' : 'Add ${values.length}',
          onPressed: _save,
          color: AppColors.info,
        ),
      ],
    );
  }

  Widget _buildPreviewBanner(BuildContext context, List<String> values) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.info.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.playlist_add_check_rounded,
            size: 18,
            color: AppColors.info,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${values.length} variant${values.length == 1 ? '' : 's'} '
              'will be created: ${values.join(', ')}',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: AppColors.info,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantRow(BuildContext context, String value) {
    final row = _rowFor(value);
    return Padding(
      // Keyed by value so removing a middle row never shifts another row's
      // state onto the wrong controller.
      key: ValueKey('bulk_row_$value'),
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: AppTextField(
              controller: row.priceController,
              label: 'Price',
              hint: '0.00',
              required: true,
              keyboardType: TextInputType.number,
              inputFormatters: _moneyFormatters,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: AppTextField(
              controller: row.stockController,
              label: 'Qty',
              hint: '0',
              keyboardType: TextInputType.number,
              inputFormatters: _qtyFormatters,
            ),
          ),
        ],
      ),
    );
  }
}

/// Price and stock for one generated variant.
class _BulkRow {
  final TextEditingController priceController = TextEditingController();
  final TextEditingController stockController = TextEditingController(
    text: '0',
  );

  void dispose() {
    priceController.dispose();
    stockController.dispose();
  }
}

// ============================================================================
// SHARED PIECES
// ============================================================================

/// Custom key/value rows, shared by the Add and Edit dialogs.
class _CustomAttributesSection extends StatelessWidget {
  final List<_CustomAttrData> attributes;
  final String emptyHint;
  final VoidCallback onChanged;

  const _CustomAttributesSection({
    required this.attributes,
    required this.emptyHint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Divider(color: AppColors.divider),
        Row(
          children: [
            Expanded(child: _sectionLabel(context, 'Custom Attributes')),
            TextButton.icon(
              onPressed: () {
                attributes.add(_CustomAttrData());
                onChanged();
              },
              icon: const Icon(Icons.add, size: 16),
              label: Text(
                'Add',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        if (attributes.isEmpty)
          Text(
            emptyHint,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
        for (var index = 0; index < attributes.length; index++)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: AppTextField(
                    // Keyed by identity so removing a middle row never hands a
                    // disposed controller to the next field.
                    key: ValueKey(attributes[index]),
                    controller: attributes[index].keyController,
                    label: 'Attribute',
                    hint: 'e.g. Material',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppTextField(
                    key: ValueKey('${attributes[index].hashCode}_value'),
                    controller: attributes[index].valueController,
                    label: 'Value',
                    hint: 'e.g. Cotton',
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: AppColors.danger,
                    size: 20,
                  ),
                  onPressed: () {
                    attributes[index].dispose();
                    attributes.removeAt(index);
                    onChanged();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Widget _sectionLabel(BuildContext context, String text) {
  return Text(
    text,
    style: GoogleFonts.poppins(
      fontSize: AppResponsive.smallFontSize(context),
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
  );
}

/// Dropdown styled to match [AppTextField] — there is no shared dropdown
/// component, so the decoration is mirrored here rather than hand-rolled twice.
Widget _styledDropdown<T>(
  BuildContext context, {
  required String label,
  required T? value,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
}) {
  return DropdownButtonFormField<T>(
    initialValue: value,
    isExpanded: true,
    style: GoogleFonts.poppins(
      fontSize: AppResponsive.bodyFontSize(context),
      color: AppColors.textPrimary,
    ),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(
        fontSize: AppResponsive.smallFontSize(context),
        color: AppColors.textSecondary,
      ),
      filled: true,
      fillColor: AppColors.surfaceLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    items: items,
    onChanged: onChanged,
  );
}

/// Tax picker shared by the Add and Bulk dialogs.
Widget _taxDropdown(
  BuildContext context,
  String? selectedTaxId,
  ValueChanged<String?> onChanged,
) {
  return Observer(
    builder: (_) {
      final taxes = taxStore.taxes;
      return _styledDropdown<String>(
        context,
        label: 'Tax Rate (Optional)',
        value: taxes.any((t) => t.id == selectedTaxId) ? selectedTaxId : null,
        items: [
          DropdownMenuItem(
            value: null,
            child: Text(
              'No tax',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
              ),
            ),
          ),
          ...taxes.map(
            (tax) => DropdownMenuItem(
              value: tax.id,
              child: Text(
                '${tax.taxname} (${tax.taxperecentage ?? 0}%)',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                ),
              ),
            ),
          ),
        ],
        onChanged: onChanged,
      );
    },
  );
}

/// Percentage behind a tax id, or null when nothing is picked.
double? _taxRateFor(String? taxId) {
  if (taxId == null) return null;
  return taxStore.taxes
      .firstWhere(
        (t) => t.id == taxId,
        orElse: () => Tax(id: '', taxname: '', taxperecentage: null),
      )
      .taxperecentage;
}

/// Non-empty key/value pairs, or null when there are none.
Map<String, String>? _customAttributesMap(List<_CustomAttrData> attributes) {
  final map = <String, String>{};
  for (final attr in attributes) {
    final key = attr.keyController.text.trim();
    final value = attr.valueController.text.trim();
    if (key.isNotEmpty && value.isNotEmpty) map[key] = value;
  }
  return map.isEmpty ? null : map;
}

/// Controller pair for one custom attribute row.
class _CustomAttrData {
  final TextEditingController keyController = TextEditingController();
  final TextEditingController valueController = TextEditingController();

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}
