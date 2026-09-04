import 'package:flutter/material.dart';
import 'package:billberrylite/presentation/widget/componets/retail/expiry_date_field.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/screens/retail/add_product_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/row_action_button.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/util/common/currency_helper.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/config/tariff_code_rule.dart';
import '../../../data/models/retail/hive_model/attribute_model_219.dart';
import '../../../data/models/retail/hive_model/attribute_value_model_220.dart';
import '../../../data/models/retail/hive_model/product_model_200.dart';
import '../../../data/models/retail/hive_model/variante_model_201.dart';
import '../../../domain/services/common/notification_service.dart';
import '../../../domain/services/retail/simple_product_fields_service.dart';
import '../../../domain/services/retail/stock_adjustment_service.dart';
import '../../../domain/services/retail/variant_attribute_mapper.dart';
import '../../../domain/services/retail/variant_generator_service.dart';
import '../../../domain/store/retail/product_store.dart';
import 'package:billberrylite/presentation/widget/componets/retail/stock_adjustment_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/retail/stock_history_dialog.dart';
import 'package:billberrylite/core/plan/plan_guard.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';
import 'package:billberrylite/presentation/screens/retail/attributes_screen.dart';
import 'package:billberrylite/presentation/screens/retail/scanner_screen.dart';
import 'package:billberrylite/domain/services/retail/barcode_generator_service.dart';
import 'package:billberrylite/domain/services/retail/catalog_permission.dart';
import 'package:billberrylite/presentation/widget/componets/retail/print_labels_sheet.dart';

/// Money input — digits with at most two decimals, the same rule the checkout,
/// expense and add-product screens apply.
final _moneyFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
];

/// Whole-number input (stock counts) — what a piece product uses.
final _qtyFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
];

/// Fractional stock input for loose goods, at most 2 decimals. Reached only
/// when the product's variants are flagged `isDecimalQuantity`.
final _decimalQtyFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
];

/// Prompts a soft warning confirmation when selling price < cost price.
/// Returns true if confirmed or if selling price >= cost price.
Future<bool> confirmLossIfSellingBelowCost({
  required BuildContext context,
  required double sellingPrice,
  required double? costPrice,
}) async {
  if (costPrice == null || costPrice <= 0 || sellingPrice >= costPrice) {
    return true; // No loss, proceed directly
  }

  final loss = costPrice - sellingPrice;
  final lossPct = ((loss / costPrice) * 100).toStringAsFixed(1);
  final sym = CurrencyHelper.currentSymbol;

  return await showAppConfirmDialog(
    context: context,
    title: 'Selling Below Cost Price?',
    message: 'Selling Price ($sym${DecimalSettings.formatAmount(sellingPrice)}) '
        'is lower than Cost Price ($sym${DecimalSettings.formatAmount(costPrice)}).\n\n'
        'You will incur a loss of $sym${DecimalSettings.formatAmount(loss)} (-$lossPct% margin) per unit.',
    confirmLabel: 'Continue & Save',
    cancelLabel: 'Fix Price',
    accent: AppColors.warning,
    icon: Icons.warning_amber_rounded,
  );
}

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

  /// Why this product's stock is what it is — adjustments only.
  ///
  /// Deliberately NOT a full stock ledger: sales and receipts already have
  /// their own reports, and mixing them in here would imply this is the
  /// complete movement history when it is only the manual corrections.
  void _openStockHistory() {
    showDialog(
      context: context,
      builder: (_) => StockHistoryDialog(
        productId: widget.product.productId,
        productName: widget.product.productName,
      ),
    );
  }

  /// The one sanctioned way to change stock from this screen. Gated on
  /// `retail.inventory` because an adjustment is an inventory operation, not a
  /// catalog edit — editing the variant and correcting its stock are different
  /// privileges.
  /// Print a label for ONE variant. Opens the shared sheet with that variant
  /// pre-selected, so both entry points share one code path.
  Future<void> _openPrintLabel(VarianteModel variant) async {
    if (!BarcodeLabelPermission.canPrint) return;
    await showPrintLabelsSheet(
      context: context,
      product: _product,
      variants: [variant],
      money: formatMoney,
      preselectAll: true,
    );
  }

  /// Print labels for the product. Opens the same sheet with EVERY variant
  /// listed and none selected -- the admin picks, sets counts and sees the total
  /// before anything prints.
  ///
  /// The list comes from the store observable, so a barcode generated inside the
  /// sheet is reflected here without a manual reload.
  Future<void> _openPrintLabels() async {
    if (!BarcodeLabelPermission.canPrint) return;
    final variants = productStore.variantsFor(widget.product.productId);
    if (variants.isEmpty) {
      NotificationService.instance.showWarning(
        'Add a variant before printing labels.',
      );
      return;
    }
    await showPrintLabelsSheet(
      context: context,
      product: _product,
      variants: variants,
      money: formatMoney,
    );
  }

  Future<void> _openAdjustStock(VarianteModel variant) async {
    if (!PlanGuard.allowedOr(
      context,
      RetailEntKeys.inventory,
      featureName: 'Stock Adjustment',
    )) {
      return;
    }

    await StockAdjustmentDialog.show(
      context,
      variant: variant,
      productName: widget.product.productName,
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
                case 'history':
                  _openStockHistory();
                  break;
                case 'labels':
                  _openPrintLabels();
                  break;
              }
            },
            itemBuilder: (context) => [
              // Catalogue mutations drop out for a cashier; Stock History is
              // read-only and stays for every role.
              if (CatalogPermission.canEdit) ...[
                _menuItem('add', Icons.add, 'Add Variant'),
                _menuItem(
                  'bulk',
                  Icons.library_add_outlined,
                  'Bulk Add Variants',
                ),
                const PopupMenuDivider(),
                _menuItem('edit', Icons.edit_outlined, 'Edit Details'),
              ],
              _menuItem('history', Icons.history_rounded, 'Stock History'),
              if (BarcodeLabelPermission.canPrint)
                _menuItem('labels', Icons.qr_code_2_rounded, 'Print Labels'),
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
      if (product.hsnCode?.isNotEmpty ?? false)
        '${TariffCodeRule.shortLabel} ${product.hsnCode}',
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
      action: CatalogPermission.canEdit
          ? appEmptyStateAction(
              label: 'Add First Variant',
              onPressed: _openAddVariant,
            )
          : null,
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
    final totalStock = variants.fold<double>(0.0, (sum, v) => sum + v.stockQty);
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
                          // Two lines on a narrow screen: 'Size: XL • Color:
                          // Navy Blue' is the row's identity — losing its tail
                          // to an ellipsis makes two variants indistinguishable.
                          maxLines: 2,
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
                  // Renders nothing unless this variant is expiring/expired.
                  if (variant.hasExpiry) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ExpiryStatusPill(
                          status: productStore.expiryStatusForVariant(variant),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          kExpiryDateFormat.format(variant.expiryDateTime!),
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.captionFontSize(context),
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Capped: a Column sizes to its widest child, and the text column
            // beside it is Expanded — so without a ceiling a long "MRP:"/"Cost:"
            // string would keep taking width from the variant description
            // rather than ellipsizing itself.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 104),
              child: Column(
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
            ),
            const SizedBox(width: 6),
            // Edit and Delete are visible buttons on the row, matching the
            // product and category rows. The two permission-gated extras stay
            // behind an overflow that hides itself when neither is allowed.
            if (CatalogPermission.canEdit) ...[
              RowActionButton(
                icon: Icons.edit_outlined,
                color: AppColors.primary,
                tooltip: 'Edit Variant',
                onTap: () => _openEditVariant(variant),
              ),
              const SizedBox(width: 6),
              RowActionButton(
                icon: Icons.delete_outline_rounded,
                color: AppColors.danger,
                tooltip: 'Delete Variant',
                onTap: () => _deleteVariant(variant),
              ),
            ],
            _buildVariantExtrasMenu(variant),
          ],
        ),
      ),
    );
  }

  /// Adjust Stock / Print Label for a variant.
  ///
  /// Both are admin-only and were already hidden individually rather than
  /// shown-and-refused, so a cashier is never told about a control they can't
  /// use. With Edit and Delete now living on the row itself, the menu has
  /// nothing left to show for that user — so it renders nothing at all instead
  /// of an empty popup.
  Widget _buildVariantExtrasMenu(VarianteModel variant) {
    final canAdjust = StockAdjustmentService.canAdjust;
    final canPrint = BarcodeLabelPermission.canPrint;
    if (!canAdjust && !canPrint) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert,
        color: AppColors.textSecondary,
        size: 20,
      ),
      // M3 tints menu surfaces by default; keep them plain white.
      color: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'adjust') {
          _openAdjustStock(variant);
        } else if (value == 'label') {
          _openPrintLabel(variant);
        }
      },
      itemBuilder: (context) => [
        if (canAdjust)
          PopupMenuItem<String>(
            value: 'adjust',
            child: Row(
              children: [
                const Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Adjust Stock',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        if (canPrint)
          PopupMenuItem<String>(
            value: 'label',
            child: Row(
              children: [
                const Icon(
                  Icons.qr_code_2_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Print Label',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
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

  /// This variant's descriptors, seeded from Settings → Simple Product Fields
  /// and then owned by the user — they can drop one or add any attribute from
  /// the catalogue. See [_AttributesSection].
  final List<_AttrRow> _attrRows = [];
  bool _rowsSeeded = false;

  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();

  /// An existing sibling variant, purely to inherit the product's unit of
  /// measure. They all agree, so the first one speaks for the product — the
  /// same rule the Add/Edit Product screen uses when seeding its UoM control.
  VarianteModel? get _siblingUnitSource =>
      productStore.variantsFor(widget.productId).firstOrNull;

  /// Whether this product's variants are stocked in fractional amounts.
  bool get _allowDecimal => _siblingUnitSource?.isDecimalQuantity ?? false;

  bool _saving = false;

  /// Min Stock and Tax Rate start folded — see the [_MoreOptions] block below.
  bool _showMoreOptions = false;

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  Future<void> _loadFields() async {
    final fields = await SimpleProductFieldsService().resolveFields();
    if (!mounted) return;
    setState(() {
      // Seed once. Re-seeding on a later rebuild would resurrect a row the user
      // had just removed.
      if (!_rowsSeeded) {
        _attrRows.addAll(_seedRowsFromFields(fields));
        _rowsSeeded = true;
      }
    });
  }

  @override
  void dispose() {
    for (final row in _attrRows) {
      row.dispose();
    }
    _skuController.dispose();
    _barcodeController.dispose();
    _sellingPriceController.dispose();
    _costPriceController.dispose();
    _mrpController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  /// Push the shared scanner and drop the result into the field. Mirrors the
  /// Add Product form and the Edit Variant dialog, both of which could already
  /// scan while this one could not.
  Future<void> _scanBarcode() async {
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const ScannerScreen()));
    if (code == null || !mounted) return;
    setState(() => _barcodeController.text = code.trim());
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

    final sellingPrice = double.tryParse(_sellingPriceController.text.trim()) ?? 0.0;
    final costPrice = _costPriceController.text.trim().isEmpty
        ? null
        : double.tryParse(_costPriceController.text.trim());

    if (!await confirmLossIfSellingBelowCost(
      context: context,
      sellingPrice: sellingPrice,
      costPrice: costPrice,
    )) {
      return;
    }

    setState(() => _saving = true);

    // Auto-generate only when left blank — never overwrite what was typed.
    final sku = _skuController.text.trim().isEmpty
        ? await skuGeneratorService.generate(widget.categoryName)
        : _skuController.text.trim();

    final variantId =
        '${widget.productId}_${DateTime.now().millisecondsSinceEpoch}';

    // Catalogue attributes and one-off pairs are the same flat map to the
    // model, so one call covers both.
    final attributes = _attrRowsMap(_attrRows);

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
      stockQty: double.tryParse(_stockController.text.trim()) ?? 0,
      minStock: _minStockController.text.trim().isEmpty
          ? null
          : double.tryParse(_minStockController.text.trim()),
      // Tax is a PRODUCT-level decision and is deliberately not set here:
      // cart_store's _getEffectiveGstRate already resolves Variant → Product →
      // default, so leaving these null makes the variant inherit the product's
      // rate. A per-variant override could be created here but changed nowhere
      // — Edit Variant has no tax field — so it could never be corrected.
      // Unit of measure is a PRODUCT-level decision stored per variant, so a
      // variant added here must inherit it. Without this a new variant of a
      // loose-goods product silently defaulted to whole pieces, and its stock
      // field would refuse a decimal.
      isDecimalQuantity: _siblingUnitSource?.isDecimalQuantity ?? false,
      unit: _siblingUnitSource?.unit,
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
            // First, not buried: what this variant IS comes before what it
            // costs. Descriptors used to render unlabelled here and a generic
            // "One-off details" box sat at the very bottom under More options.
            _AttributesSection(
              rows: _attrRows,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 8),
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
              label: 'Cost Price',
              hint: '0.00',
              icon: Icons.payments_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: _moneyFormatters,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _mrpController,
              label: 'MRP',
              hint: '0.00',
              icon: Icons.local_offer_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: _moneyFormatters,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _stockController,
              label: _allowDecimal
                  ? 'Stock Quantity (${_siblingUnitSource!.effectiveUnit})'
                  : 'Stock Quantity',
              hint: '0',
              icon: Icons.inventory_2_outlined,
              required: true,
              keyboardType: _allowDecimal
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.number,
              inputFormatters: _allowDecimal
                  ? _decimalQtyFormatters
                  : _qtyFormatters,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _barcodeController,
              label: 'Barcode',
              hint: 'Scan or enter',
              // helperText, not hint: Material hides the hint behind the
              // resting label, so this only appeared once the user had already
              // tapped in and started wondering.
              helperText: 'Generated automatically if left blank',
              icon: Icons.qr_code_rounded,
              // The Add Product form and Edit Variant both scan; only this
              // dialog made you type a barcode by hand.
              suffixIcon: IconButton(
                tooltip: 'Scan barcode',
                icon: const Icon(Icons.qr_code_scanner, size: 20),
                onPressed: _scanBarcode,
              ),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _skuController,
              label: 'SKU',
              helperText: 'Generated automatically if left blank',
              icon: Icons.tag_rounded,
            ),

            // Min Stock and Tax Rate are real, live settings — variant minStock
            // overrides the global alert threshold and taxId is read at billing
            // — but neither is needed to create a variant, and above the fold
            // they made this dialog look like it wanted twice the Add Product
            // form. Folded away, not removed; Edit Variant shows them outright.
            _MoreOptions(
              expanded: _showMoreOptions,
              onToggle: () =>
                  setState(() => _showMoreOptions = !_showMoreOptions),
              children: [
                AppTextField(
                  controller: _minStockController,
                  label: 'Min Stock',
                  hint: '0',
                  icon: Icons.warning_amber_outlined,
                  keyboardType: _allowDecimal
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.number,
                  inputFormatters: _allowDecimal
                      ? _decimalQtyFormatters
                      : _qtyFormatters,
                ),
              ],
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
  /// This variant's own unit of measure decides whether its quantity fields
  /// accept a fraction.
  bool get _allowDecimal => widget.variant.isDecimalQuantity;

  /// Per-variant expiry. Null = does not expire.
  DateTime? _expiryDate;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _mrpController;
  late final TextEditingController _minStockController;

  /// The variant's barcode. Editable HERE and nowhere else — without this field
  /// a duplicate barcode could be created but never repaired.
  late final TextEditingController _barcodeController;

  /// False parks the variant: it keeps its stock and history but disappears
  /// from the POS, so a line can be pulled from sale without being deleted.
  late bool _active;

  /// Same section as Add Variant, so the form you edit in matches the form you
  /// created in.
  final List<_AttrRow> _attrRows = [];

  @override
  void initState() {
    super.initState();
    final v = widget.variant;
    _active = productStore.isSellable(v);
    _sellingPriceController = TextEditingController(
      text: v.sellingPrice == null
          ? ''
          : DecimalSettings.formatAmount(v.sellingPrice!),
    );
    _costPriceController = TextEditingController(
      text: v.costPrice == null
          ? ''
          : DecimalSettings.formatAmount(v.costPrice!),
    );
    _mrpController = TextEditingController(
      text: v.mrp == null ? '' : DecimalSettings.formatAmount(v.mrp!),
    );
    _minStockController = TextEditingController(
      text: v.minStock?.toString() ?? '',
    );
    _barcodeController = TextEditingController(text: v.barcode ?? '');
    // Seed from the variant, or saving would silently clear an existing expiry
    // (the save path treats a null `_expiryDate` as an explicit clear).
    _expiryDate = v.expiryDateTime;

    // Keys that match a catalogue attribute become real attribute rows, so an
    // existing Size keeps its value picker instead of being demoted to a
    // free-text pair the moment you open the editor.
    _attrRows.addAll(_seedRowsFromAttributes(v.customAttributes));
  }

  @override
  void dispose() {
    _sellingPriceController.dispose();
    _costPriceController.dispose();
    _mrpController.dispose();
    _minStockController.dispose();
    _barcodeController.dispose();
    for (final row in _attrRows) {
      row.dispose();
    }
    super.dispose();
  }

  /// Push the shared scanner and drop the result into the field. Mirrors the
  /// Add Product form's scan button.
  Future<void> _scanBarcode() async {
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const ScannerScreen()));
    if (code == null || !mounted) return;
    setState(() => _barcodeController.text = code.trim());
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

    final oldBarcode = widget.variant.barcode?.trim() ?? '';
    final newBarcode = _barcodeController.text.trim();

    // Changing or clearing a barcode strands every label already printed with
    // the old value, so it is never silent. Only asked when there WAS one.
    //
    // The wording depends on WHERE the old code came from. Since a barcode is
    // now generated automatically on create, most variants carry an internal
    // "BB..." code that may never have been printed — warning about printed
    // labels there would cry wolf on the routine act of pasting a real
    // manufacturer barcode over it. A code the user entered themselves gets the
    // firmer message.
    if (oldBarcode.isNotEmpty && newBarcode != oldBarcode) {
      final wasGenerated = BarcodeGeneratorService.isGenerated(oldBarcode);

      final String message;
      if (newBarcode.isEmpty) {
        message = wasGenerated
            ? 'This variant will have no barcode and will stop scanning until '
                  'one is set. If you already printed labels with "$oldBarcode", '
                  'they will no longer identify it.'
            : 'Labels already printed with "$oldBarcode" will no longer '
                  'identify this variant, and it will stop scanning until a new '
                  'barcode is set.';
      } else {
        message = wasGenerated
            ? 'This variant will use "$newBarcode" instead of the '
                  'auto-generated "$oldBarcode". If you already printed labels '
                  'with the old code, they will no longer identify it.'
            : 'Labels already printed with "$oldBarcode" will no longer '
                  'identify this variant.';
      }

      final confirmed = await showAppConfirmDialog(
        context: context,
        title: newBarcode.isEmpty ? 'Remove barcode?' : 'Change barcode?',
        message: message,
        confirmLabel: newBarcode.isEmpty ? 'Remove' : 'Change',
        icon: Icons.qr_code_2_rounded,
        // An internal code that may never have printed is a softer decision
        // than overwriting one the shop deliberately recorded.
        accent: wasGenerated ? AppColors.primary : AppColors.danger,
      );
      if (!confirmed) return;
      if (!mounted) return;
    }

    // Pre-flight so the user sees the reason on the field they typed in; the
    // repository is the backstop.
    if (newBarcode.isNotEmpty &&
        productStore.isBarcodeTaken(
          newBarcode,
          exceptVariantId: widget.variant.varianteId,
        )) {
      NotificationService.instance.showError(
        'Barcode "$newBarcode" is already used by another variant',
      );
      return;
    }

    final sellingPrice = double.tryParse(_sellingPriceController.text.trim()) ?? 0.0;
    final costPrice = _costPriceController.text.trim().isEmpty
        ? null
        : double.tryParse(_costPriceController.text.trim());

    if (!await confirmLossIfSellingBelowCost(
      context: context,
      sellingPrice: sellingPrice,
      costPrice: costPrice,
    )) {
      return;
    }

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
      minStock: minStockText.isEmpty ? null : double.tryParse(minStockText),
      clearMinStock: minStockText.isEmpty,
      status: _active ? kActiveVariantStatus : kInactiveVariantStatus,
      // An empty map rather than null, so removing every row actually clears
      // them instead of falling back to the old values.
      customAttributes: _attrRowsMap(_attrRows) ?? const <String, String>{},
      // `barcode ?? this.barcode` cannot null the field, so removing one needs
      // the explicit flag — same reason as clearMrp above.
      barcode: newBarcode.isEmpty ? null : newBarcode,
      clearBarcode: newBarcode.isEmpty,
      expiryDate: _expiryDate?.toIso8601String(),
      clearExpiryDate: _expiryDate == null,
    );

    final result = await productStore.updateVariant(updated);
    if (!mounted) return;
    if (!result.success) {
      NotificationService.instance.showError(
        result.errorMessage ?? 'Could not save the variant.',
      );
      return;
    }
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
            // The ONLY place a variant's barcode can be corrected. Without it a
            // Descriptors first, matching Add Variant.
            _AttributesSection(
              rows: _attrRows,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 8),
            // The ONLY place a variant's barcode can be corrected. Without this
            // a duplicate or a typo was permanent short of deleting the variant.
            AppTextField(
              controller: _barcodeController,
              label: 'Barcode',
              hint: 'Scan or enter',
              icon: Icons.qr_code_2_rounded,
              suffixIcon: IconButton(
                tooltip: 'Scan barcode',
                icon: const Icon(Icons.qr_code_scanner, size: 20),
                onPressed: _scanBarcode,
              ),
            ),
            const SizedBox(height: 12),
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
              label: 'Cost Price',
              hint: '0.00',
              icon: Icons.payments_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: _moneyFormatters,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _mrpController,
              label: 'MRP',
              hint: '0.00',
              icon: Icons.local_offer_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: _moneyFormatters,
            ),
            const SizedBox(height: 12),
            // Stock is deliberately NOT editable here. Typing over it left no
            // reason, no audit row and no before/after, which is exactly what
            // made stock discrepancies unexplainable. Changes go through
            // Adjust Stock in the variant's overflow menu instead.
            ReadOnlyStockTile(
              stock: widget.variant.stockQty,
              unit: widget.variant.isDecimalQuantity
                  ? widget.variant.effectiveUnit
                  : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _minStockController,
              label: 'Min Stock',
              hint: '0',
              icon: Icons.warning_amber_outlined,
              keyboardType: _allowDecimal
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.number,
              inputFormatters: _allowDecimal
                  ? _decimalQtyFormatters
                  : _qtyFormatters,
            ),
            const SizedBox(height: 12),
            // Per-variant: a 500ml and a 1L of the same product are stocked
            // separately, so they expire separately.
            ExpiryDateField(
              value: _expiryDate,
              onPick: (picked) => setState(() => _expiryDate = picked),
              onClear: () => setState(() => _expiryDate = null),
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

  /// Existing sibling variant, purely to inherit the product's unit of measure
  /// onto every generated row.
  VarianteModel? get _siblingUnitSource =>
      productStore.variantsFor(widget.productId).firstOrNull;

  bool get _allowDecimal => _siblingUnitSource?.isDecimalQuantity ?? false;

  // Shared across every generated variant.
  final _costPriceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _minStockController = TextEditingController();
  final _baseBarcodeController = TextEditingController();

  /// Configured descriptor fields (Settings → Simple Product Fields).
  ///
  /// These become the "same for all variants" boxes ONLY. They are a display
  /// choice — which boxes a single variant's form renders — and are deliberately
  /// not the source of the varying axes; see [_attributes].
  List<AttributeModel> _fields = [];

  /// Every attribute in the catalogue (Settings → Product Attributes), which is
  /// what a variant can actually be generated from.
  List<AttributeModel> _attributes = [];

  bool _loading = true;

  /// The attributes that VARY, in display order. Plural on purpose: this used to
  /// be a single `_varyingAttribute`, so choosing Size cleared Colour and a
  /// shop could never bulk-create a Colour × Size grid — the one thing bulk add
  /// is for.
  final List<AttributeModel> _axes = [];

  /// Selected value ids per axis, keyed by attributeId.
  final Map<String, Set<String>> _selectedValueIds = {};

  /// "Add a value" input per axis.
  final Map<String, TextEditingController> _newValueControllers = {};

  /// Per-variant price and stock, keyed by [_comboKey]. Created when a
  /// combination appears and disposed the moment it stops existing — a row must
  /// never outlive its combination, or it would render a disposed controller.
  final Map<String, _BulkRow> _rows = {};

  /// Combination keys the user has explicitly UNTICKED.
  ///
  /// Tracks the OFF set rather than the ON set on purpose: a combination that
  /// appears later — because another value was just ticked — then defaults to
  /// selected, which is what "create these" implies. Tracking the ON set would
  /// silently exclude every newly appearing row.
  final Set<String> _skipped = {};

  /// Fixed values applied to EVERY generated variant (the non-axis fields).
  final Map<String, TextEditingController> _fixedControllers = {};

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  Future<void> _loadFields() async {
    // resolveFields() already seeds this store type's defaults and populates the
    // attribute cache, so read the catalogue after it rather than loading twice.
    final fields = await SimpleProductFieldsService().resolveFields();
    if (!mounted) return;

    final attributes = attributeStore.attributes.toList();
    setState(() {
      _fields = fields;
      _attributes = attributes;
      _loading = false;
      // Open on one axis so the dialog is immediately usable; the shop's first
      // configured field is the one they think about most, falling back to the
      // catalogue when they have configured none.
      final first = fields.isNotEmpty
          ? fields.first
          : (attributes.isEmpty ? null : attributes.first);
      if (first != null) _axes.add(first);
    });
  }

  @override
  void dispose() {
    for (final controller in _newValueControllers.values) {
      controller.dispose();
    }
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

  TextEditingController _newValueController(String attributeId) =>
      _newValueControllers.putIfAbsent(
        attributeId,
        () => TextEditingController(),
      );

  /// Catalogue attributes not already used as an axis.
  List<AttributeModel> get _unusedAttributes {
    final used = _axes.map((a) => a.attributeId).toSet();
    return _attributes.where((a) => !used.contains(a.attributeId)).toList();
  }

  /// Every combination the current selection produces, via the SAME service the
  /// Add Product screen's generator uses — the Cartesian product is not worth a
  /// second implementation, and reusing it means bulk variants also carry
  /// `attributeValueIds` (the real taxonomy link) rather than name strings only.
  ///
  /// An axis with nothing selected is skipped rather than collapsing the whole
  /// result to empty, so adding a second axis does not blank the preview before
  /// its first value is ticked.
  List<VariantCombination> get _combinations {
    final specs = <AttributeWithValues>[];
    for (final axis in _axes) {
      final selected = _selectedValueIds[axis.attributeId];
      if (selected == null || selected.isEmpty) continue;
      final values = attributeStore.getValues(axis.attributeId);
      specs.add(
        AttributeWithValues(
          attribute: axis,
          availableValues: values,
          selectedValues: values
              .where((v) => selected.contains(v.valueId))
              .toList(),
        ),
      );
    }
    if (specs.isEmpty) return const [];
    return variantGeneratorService.generateCombinations(
      attributesWithValues: specs,
    );
  }

  /// Stable identity for a combination — its value ids, in axis order.
  String _comboKey(VariantCombination combo) =>
      combo.attributeValuePairs.map((p) => p.value.valueId).join('|');

  /// The combinations that will actually be created.
  List<VariantCombination> get _activeCombinations =>
      _combinations.where((c) => !_skipped.contains(_comboKey(c))).toList();

  _BulkRow _rowFor(String key) => _rows.putIfAbsent(key, () => _BulkRow());

  /// Drop rows whose combination no longer exists. Called after every selection
  /// change; without it, unticking a value would leak its controllers and a
  /// re-tick would resurrect stale prices.
  void _pruneRows() {
    final live = _combinations.map(_comboKey).toSet();
    for (final key in _rows.keys.toList()) {
      if (!live.contains(key)) _rows.remove(key)?.dispose();
    }
    // Drop stale skips too, or a combination that comes back would return
    // mysteriously unticked.
    _skipped.removeWhere((key) => !live.contains(key));
  }

  void _toggleCombo(String key, bool active) {
    setState(() {
      if (active) {
        _skipped.remove(key);
      } else {
        _skipped.add(key);
      }
    });
  }

  /// Tick or clear every value on one axis.
  void _toggleAllValues(AttributeModel axis, List<AttributeValueModel> values) {
    setState(() {
      final set = _selectedValueIds.putIfAbsent(axis.attributeId, () => {});
      final all = values.map((v) => v.valueId).toSet();
      if (set.length >= all.length) {
        set.clear();
      } else {
        set
          ..clear()
          ..addAll(all);
      }
      _pruneRows();
    });
  }

  /// Create a brand new attribute without leaving the dialog, then use it as an
  /// axis straight away — creating one from here is only ever a step towards
  /// using it.
  ///
  /// Reuses the Attributes screen's own prompt so the wording and duplicate
  /// handling stay in one place. That function returns void, so the newcomer is
  /// found by diffing the store rather than by return value.
  Future<void> _createAttribute() async {
    final before = attributeStore.attributes
        .map((a) => a.attributeId)
        .toSet();

    await showAddAttributeDialog(context);
    if (!mounted) return;

    final all = attributeStore.attributes.toList();
    setState(() {
      _attributes = all;
      for (final attribute in all) {
        if (!before.contains(attribute.attributeId)) _axes.add(attribute);
      }
      _pruneRows();
    });
  }

  void _toggleValue(AttributeModel axis, String valueId, bool selected) {
    setState(() {
      final set = _selectedValueIds.putIfAbsent(axis.attributeId, () => {});
      if (selected) {
        set.add(valueId);
      } else {
        set.remove(valueId);
      }
      _pruneRows();
    });
  }

  void _addAxis(AttributeModel attribute) {
    setState(() {
      _axes.add(attribute);
      _pruneRows();
    });
  }

  void _removeAxis(AttributeModel attribute) {
    setState(() {
      _axes.remove(attribute);
      _selectedValueIds.remove(attribute.attributeId);
      _newValueControllers.remove(attribute.attributeId)?.dispose();
      _pruneRows();
    });
  }

  /// Add a value to an axis and tick it.
  ///
  /// The value is SAVED to the attribute (Settings → Product Attributes) rather
  /// than kept for this batch only, so a shop typing S/M/L here does not retype
  /// them next time. It must be a real `AttributeValueModel` — the combination
  /// service works on value ids, so a batch-local string could not take part in
  /// a Cartesian product at all.
  Future<void> _addValue(AttributeModel axis) async {
    final controller = _newValueController(axis.attributeId);
    final value = controller.text.trim();
    if (value.isEmpty) return;

    final saved = await attributeStore.addValue(axis.attributeId, value);
    if (!mounted) return;

    if (!saved) {
      NotificationService.instance.showError(
        attributeStore.errorMessage ?? 'Could not add "$value"',
      );
      return;
    }

    final added = attributeStore
        .getValues(axis.attributeId)
        .where((v) => v.value.toLowerCase() == value.toLowerCase())
        .firstOrNull;

    setState(() {
      if (added != null) {
        _selectedValueIds
            .putIfAbsent(axis.attributeId, () => {})
            .add(added.valueId);
      }
      controller.clear();
      _pruneRows();
    });
  }

  /// Copies the first row's price and quantity down the rest — the common case
  /// is "same price for every colour, tweak one or two".
  void _fillDown() {
    final combos = _activeCombinations;
    if (combos.length < 2) return;
    final first = _rows[_comboKey(combos.first)];
    if (first == null) return;
    for (final combo in combos.skip(1)) {
      final row = _rowFor(_comboKey(combo));
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

    final combos = _activeCombinations;
    if (combos.isEmpty) {
      NotificationService.instance.showError(
        _combinations.isEmpty
            ? 'Select at least one value to create variants from'
            : 'Every combination is unticked — tick at least one to create',
      );
      return;
    }

    // Every barcode this run would produce, checked before writing any of
    // them — a half-saved batch is worse than a rejected one.
    final baseBarcodeText = _baseBarcodeController.text.trim();
    if (baseBarcodeText.isNotEmpty) {
      for (var i = 1; i <= combos.length; i++) {
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

    // Values typed once and applied to every generated variant. Axes are
    // excluded — they vary, so they cannot also be fixed.
    final axisIds = _axes.map((a) => a.attributeId).toSet();
    final fixedValues = <String, String>{
      for (final attribute in _fields)
        if (!axisIds.contains(attribute.attributeId) &&
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
        : double.tryParse(_minStockController.text.trim());
    final baseBarcode = _baseBarcodeController.text.trim();

    var counter = 1;
    for (final combo in combos) {
      final row = _rows[_comboKey(combo)];
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
            for (final pair in combo.attributeValuePairs)
              pair.attribute.name: pair.value.value,
          }),
          // The authoritative link into the taxonomy. Bulk add wrote only the
          // name strings before, so renaming an attribute later stranded every
          // variant it had created.
          attributeValueIds: {
            for (final pair in combo.attributeValuePairs)
              pair.attribute.attributeId: pair.value.valueId,
          },
          sku: sku,
          barcode: barcode,
          // sellingPrice is what the POS bills — see cart_store.dart.
          sellingPrice:
              double.tryParse(row?.priceController.text.trim() ?? '') ?? 0.0,
          costPrice: costPrice,
          mrp: mrp,
          stockQty:
              double.tryParse(row?.stockController.text.trim() ?? '') ?? 0,
          minStock: minStock,
          // Tax deliberately unset — the variant inherits the product's rate
          // through cart_store's Variant → Product → default resolution.
          // Inherit the product's unit of measure, same as the single-add
          // dialog — otherwise bulk-added rows default to whole pieces.
          isDecimalQuantity: _siblingUnitSource?.isDecimalQuantity ?? false,
          unit: _siblingUnitSource?.unit,
        ),
      );
      counter++;

      // Small delay to keep the timestamp-based ids unique.
      await Future.delayed(const Duration(milliseconds: 10));
    }

    if (!mounted) return;
    Navigator.pop(context);
    NotificationService.instance.showSuccess('${combos.length} variants added');
  }

  /// Shown instead of the form while attributes load, and in place of it when
  /// the shop has none — with the one action that actually unblocks them.
  Widget _buildUnavailable(BuildContext context) {
    return AppDialogShell(
      title: 'Bulk Add Variants',
      subtitle: 'One variant per combination, priced individually',
      accent: AppColors.info,
      icon: Icons.bolt_rounded,
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No attributes yet',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.subheadingFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Bulk add creates one variant per value of an attribute '
                    '— Size, Colour, Material. Set one up and its values, then '
                    'come back.',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
      ),
      actions: _loading
          ? [appDialogCancelButton(context, label: 'Close')]
          : [
              appDialogCancelButton(context),
              const SizedBox(width: 12),
              appDialogPrimaryButton(
                label: 'Set up attributes',
                color: AppColors.info,
                onPressed: () {
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  navigator.push(
                    MaterialPageRoute(builder: (_) => const AttributesScreen()),
                  );
                },
              ),
            ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Entrance guard. Bulk add generates one variant per attribute VALUE, so
    // with no attributes there is nothing to generate from. Gate the way in.
    if (_loading || _attributes.isEmpty) return _buildUnavailable(context);

    final combos = _combinations;
    final active = _activeCombinations;

    return AppDialogShell(
      title: 'Bulk Add Variants',
      subtitle: 'One variant per combination, priced individually',
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
            // ── 1. What varies — one section per axis ─────────────────────
            Row(
              children: [
                Expanded(child: _sectionLabel(context, 'Attributes')),
                _buildAddAxisButton(context),
              ],
            ),
            if (_axes.isEmpty)
              Text(
                'Add an attribute to vary, then tick the values to create.',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            for (final axis in _axes) _buildAxis(context, axis),

            // ── 2. Live preview ───────────────────────────────────────────
            if (combos.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildPreviewBanner(context, combos),
            ],

            // ── 3. Per-variant price and stock ────────────────────────────
            if (combos.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(color: AppColors.divider),
              Row(
                children: [
                  Expanded(
                    child: _sectionLabel(
                      context,
                      combos.length == active.length
                          ? 'Per variant'
                          : 'Per variant · ${active.length} of ${combos.length} selected',
                    ),
                  ),
                  if (combos.length > 1)
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
              for (final combo in combos) _buildVariantRow(context, combo),
            ],

            // ── 4. Everything shared ──────────────────────────────────────
            const SizedBox(height: 12),
            const Divider(color: AppColors.divider),
            _sectionLabel(
              context,
              active.isEmpty
                  ? 'Applies to all variants'
                  : 'Applies to all ${active.length} variant'
                        '${active.length == 1 ? '' : 's'}',
            ),
            const SizedBox(height: 12),
            for (final attribute in _fields)
              if (!_axes.any(
                (a) => a.attributeId == attribute.attributeId,
              )) ...[
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
              label: 'Cost Price',
              hint: '0.00',
              icon: Icons.payments_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: _moneyFormatters,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _mrpController,
              label: 'MRP',
              hint: '0.00',
              icon: Icons.local_offer_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: _moneyFormatters,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _minStockController,
              label: 'Min Stock',
              hint: '0',
              icon: Icons.warning_amber_outlined,
              keyboardType: _allowDecimal
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.number,
              inputFormatters: _allowDecimal
                  ? _decimalQtyFormatters
                  : _qtyFormatters,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _baseBarcodeController,
              label: 'Base Barcode',
              // helperText, not hint: this is a PREFIX, not a shared value —
              // each variant gets its own sequential code — and Material hid
              // that explanation behind the resting label until focus.
              helperText: '789456 → 789456001, 789456002 …',
              icon: Icons.qr_code_rounded,
            ),
            const SizedBox(height: 10),
            Text(
              'Cost, MRP and Min Stock are the same for every variant here. '
              'Need one to differ? Add them, then open that variant and edit it.',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
      actions: [
        appDialogCancelButton(context),
        const SizedBox(width: 12),
        appDialogPrimaryButton(
          label: active.isEmpty ? 'Add' : 'Add ${active.length}',
          onPressed: _save,
          color: AppColors.info,
        ),
      ],
    );
  }

  /// "+ Add" for a further axis. A menu anchored to the button, matching the
  /// Add/Edit Variant attribute picker rather than a bottom sheet.
  Widget _buildAddAxisButton(BuildContext context) {
    final available = _unusedAttributes;

    return PopupMenuButton<Object>(
      tooltip: 'Add attribute',
      color: AppColors.white,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      constraints: const BoxConstraints(maxHeight: 320, minWidth: 220),
      onSelected: (picked) {
        if (picked is AttributeModel) {
          _addAxis(picked);
        } else {
          _createAttribute();
        }
      },
      itemBuilder: (_) => [
        for (final attribute in available)
          PopupMenuItem<Object>(
            value: attribute,
            child: Row(
              children: [
                const Icon(
                  Icons.label_outline_rounded,
                  size: 18,
                  color: AppColors.info,
                ),
                const SizedBox(width: 10),
                Text(
                  attribute.name,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                  ),
                ),
              ],
            ),
          ),
        // Only a separator when there is something above to separate from.
        if (available.isNotEmpty) const PopupMenuDivider(),
        PopupMenuItem<Object>(
          value: 'new',
          child: Row(
            children: [
              const Icon(
                Icons.add_circle_outline_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                'New attribute…',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 16, color: AppColors.info),
            const SizedBox(width: 4),
            Text(
              'Add',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w600,
                color: AppColors.info,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One axis: its name, its value chips, and an inline "add a value" box.
  Widget _buildAxis(BuildContext context, AttributeModel axis) {
    final values = attributeStore.getValues(axis.attributeId);
    final selected = _selectedValueIds[axis.attributeId] ?? const <String>{};

    return Padding(
      key: ValueKey('bulk_axis_${axis.attributeId}'),
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  axis.name,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (values.isNotEmpty)
                TextButton(
                  onPressed: () => _toggleAllValues(axis, values),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.info,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    selected.length >= values.length
                        ? 'Clear all'
                        : 'Select all',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              // Only offer removal while a second axis exists — dropping the
              // last one leaves nothing to generate from.
              if (_axes.length > 1)
                IconButton(
                  tooltip: 'Remove ${axis.name}',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.textSecondary,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _removeAxis(axis),
                ),
            ],
          ),
          if (values.isEmpty)
            Text(
              'No values yet — add them below.',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.textSecondary,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: values.map((value) {
                final isSelected = selected.contains(value.valueId);
                return FilterChip(
                  label: Text(
                    value.value,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      color: isSelected
                          ? AppColors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (on) => _toggleValue(axis, value.valueId, on),
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
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _newValueController(axis.attributeId),
                  label: 'Add ${axis.name}',
                  hint: 'Type a value and press +',
                  icon: Icons.label_outline_rounded,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _addValue(axis),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Add this value to ${axis.name}',
                icon: const Icon(Icons.add_circle, color: AppColors.info),
                onPressed: () => _addValue(axis),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewBanner(
    BuildContext context,
    List<VariantCombination> combos,
  ) {
    // Naming every combination is unreadable past a handful, and a 4 × 5 grid
    // is entirely normal here.
    const maxNamed = 6;
    final named = combos.take(maxNamed).map((c) => c.displayName).join(', ');
    final extra = combos.length - maxNamed;

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
              '${combos.length} variant${combos.length == 1 ? '' : 's'} '
              'will be created: $named${extra > 0 ? ' and $extra more' : ''}',
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

  Widget _buildVariantRow(BuildContext context, VariantCombination combo) {
    final key = _comboKey(combo);
    final row = _rowFor(key);
    final active = !_skipped.contains(key);

    return Padding(
      // Keyed by the combination so unticking a middle value never shifts
      // another row's state onto the wrong controller.
      key: ValueKey('bulk_row_$key'),
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          // Skip a single combination without losing the value that produced
          // it — a 4 x 5 grid almost always has a few pairs the shop does not
          // stock.
          SizedBox(
            width: 32,
            child: Checkbox(
              value: active,
              onChanged: (on) => _toggleCombo(key, on ?? false),
              activeColor: AppColors.info,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          SizedBox(
            width: 78,
            child: Text(
              combo.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w600,
                color: active ? AppColors.textPrimary : AppColors.textSecondary,
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
              required: active,
              enabled: active,
              keyboardType: TextInputType.number,
              inputFormatters: _moneyFormatters,
              // An unticked row is not being created, so it must not block the
              // form. Without this the Add button would refuse over a price the
              // shop deliberately skipped.
              validator: (v) {
                if (_skipped.contains(key)) return null;
                return (v == null || v.trim().isEmpty) ? 'Required' : null;
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: AppTextField(
              controller: row.stockController,
              label: 'Qty',
              hint: '0',
              enabled: active,
              keyboardType: _allowDecimal
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.number,
              inputFormatters: _allowDecimal
                  ? _decimalQtyFormatters
                  : _qtyFormatters,
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

/// A folded "More options" group for settings that are real but not needed to
/// create the thing you are creating.
///
/// Used by Add Variant to keep Min Stock and Tax Rate off the first screenful,
/// so the dialog opens showing the same fields as the Add Product form. Edit
/// Variant deliberately does NOT use it — by then you came specifically to
/// change something, and hiding fields would cost a tap for no gain.
class _MoreOptions extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _MoreOptions({
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'More options',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        // maintainState so a value typed here survives folding the group away —
        // it is still submitted, so it must not be silently discarded.
        Visibility(
          visible: expanded,
          maintainState: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [const SizedBox(height: 4), ...children],
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

/// One descriptor on a variant.
///
/// [attribute] non-null → a catalogue attribute (Settings → Product
/// Attributes): the name is fixed and the value is picked from its defined
/// values. Null → a one-off pair the shop invented right here, where the name
/// is typed too.
///
/// One class for both because they are the same thing to `VarianteModel`, which
/// stores a flat `{name: value}` map either way. Only the input differs.
class _AttrRow {
  final AttributeModel? attribute;
  final TextEditingController nameController;
  final TextEditingController valueController;

  _AttrRow({this.attribute, String? name, String? value})
    : nameController = TextEditingController(text: name ?? ''),
      valueController = TextEditingController(text: value ?? '');

  bool get isCustom => attribute == null;

  String get name => (attribute?.name ?? nameController.text).trim();

  String get value => valueController.text.trim();

  void dispose() {
    nameController.dispose();
    valueController.dispose();
  }
}

/// Rows → the map `VarianteModel.customAttributes` stores. Incomplete rows drop
/// out silently, so a half-typed row can never write a blank descriptor.
Map<String, String>? _attrRowsMap(List<_AttrRow> rows) =>
    mergeVariantAttributes({
      for (final row in rows)
        if (row.name.isNotEmpty && row.value.isNotEmpty) row.name: row.value,
    });

/// Seed rows for a NEW variant from the shop's configured descriptor fields, so
/// the common case still opens pre-filled with Size / Colour.
List<_AttrRow> _seedRowsFromFields(List<AttributeModel> fields) =>
    fields.map((a) => _AttrRow(attribute: a)).toList();

/// Seed rows for an EXISTING variant from its stored map.
///
/// A key matching a catalogue attribute by name becomes a real attribute row
/// (with its value picker); anything else stays a one-off pair. Without the
/// match, editing a variant would demote every Size/Colour it already had into
/// free text.
List<_AttrRow> _seedRowsFromAttributes(Map<String, String>? stored) {
  final rows = <_AttrRow>[];
  stored?.forEach((key, value) {
    final attribute = attributeStore.getAttributeByName(key);
    rows.add(
      attribute != null
          ? _AttrRow(attribute: attribute, value: value)
          : _AttrRow(name: key, value: value),
    );
  });
  return rows;
}

/// The variant's descriptors — Size, Colour, Material — as one clearly labelled
/// section, shared by the Add and Edit dialogs.
///
/// Replaces a split that made attributes hard to find: configured fields were
/// rendered unlabelled at the very top (and vanished entirely whenever the shop
/// had no Simple Product Fields configured), while a generic "One-off details"
/// box sat at the very bottom under More options. Neither said "attributes",
/// and neither offered the catalogue.
class _AttributesSection extends StatelessWidget {
  final List<_AttrRow> rows;
  final VoidCallback onChanged;

  const _AttributesSection({required this.rows, required this.onChanged});

  /// Catalogue attributes not already on this variant — adding one twice would
  /// write a single key and silently lose the other value.
  List<AttributeModel> _unused() {
    final used = rows
        .map((r) => r.name.toLowerCase())
        .where((n) => n.isNotEmpty)
        .toSet();
    return attributeStore.attributes
        .where((a) => !used.contains(a.name.toLowerCase()))
        .toList();
  }

  /// The "+ Add" control: a dropdown anchored to the button itself.
  ///
  /// Deliberately NOT a bottom sheet. This section lives inside a dialog, so a
  /// sheet rising from the bottom of the screen while the dialog sits centred
  /// reads as an unrelated surface. A menu opens at the control you pressed,
  /// and matches the value picker on the rows below it.
  Widget _addButton(BuildContext context) {
    final available = _unused();

    return PopupMenuButton<Object>(
      tooltip: 'Add attribute',
      color: AppColors.white,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // A shop with a long catalogue gets a scrolling menu rather than one that
      // runs off the dialog.
      constraints: const BoxConstraints(maxHeight: 320, minWidth: 200),
      onSelected: (picked) {
        rows.add(
          picked is AttributeModel ? _AttrRow(attribute: picked) : _AttrRow(),
        );
        onChanged();
      },
      itemBuilder: (_) => [
        for (final attribute in available)
          PopupMenuItem<Object>(
            value: attribute,
            child: Row(
              children: [
                const Icon(
                  Icons.label_outline_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  attribute.name,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                  ),
                ),
              ],
            ),
          ),
        // Only a separator when there is something above to separate from.
        if (available.isNotEmpty) const PopupMenuDivider(),
        PopupMenuItem<Object>(
          value: 'custom',
          child: Row(
            children: [
              const Icon(
                Icons.add_circle_outline_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                'Custom detail',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              'Add',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionLabel(context, 'Attributes')),
            _addButton(context),
          ],
        ),
        if (rows.isEmpty)
          Text(
            'Add Size, Colour or a custom detail for this variant.',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
        for (final row in rows) ...[
          const SizedBox(height: 8),
          _buildRow(context, row),
        ],
        const SizedBox(height: 12),
        const Divider(color: AppColors.divider),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildRow(BuildContext context, _AttrRow row) {
    final remove = IconButton(
      tooltip: 'Remove',
      icon: const Icon(Icons.close_rounded, size: 18),
      color: AppColors.textSecondary,
      onPressed: () {
        rows.remove(row);
        row.dispose();
        onChanged();
      },
    );

    if (row.isCustom) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppTextField(
              controller: row.nameController,
              label: 'Detail',
              hint: 'e.g. Material',
              icon: Icons.label_outline_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppTextField(
              controller: row.valueController,
              label: 'Value',
              hint: 'e.g. Cotton',
            ),
          ),
          remove,
        ],
      );
    }

    final values = attributeStore.getValues(row.attribute!.attributeId);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppTextField(
            controller: row.valueController,
            label: row.attribute!.name,
            hint: values.isEmpty ? null : 'e.g. ${values.first.value}',
            icon: Icons.label_outline_rounded,
            // Pick from the attribute's own values instead of retyping them —
            // the same PopupMenuButton the Add Product form has always had.
            // Typing stays allowed: a value the shop has not defined yet must
            // not be blocked mid-flow.
            suffixIcon: values.isEmpty
                ? null
                : PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: AppColors.textSecondary,
                    ),
                    tooltip: 'Choose ${row.attribute!.name}',
                    color: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      row.valueController.text = value;
                      onChanged();
                    },
                    itemBuilder: (_) => values
                        .map(
                          (v) => PopupMenuItem<String>(
                            value: v.value,
                            child: Text(
                              v.value,
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.bodyFontSize(context),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ),
        remove,
      ],
    );
  }
}
