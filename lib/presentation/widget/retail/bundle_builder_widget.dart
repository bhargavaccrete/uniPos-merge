import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/bundle_component_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';

/// Embeddable Bundle/Repack component builder for retail's Add/Edit Product
/// screen. Mirrors restaurant's `RecipeBuilderWidget`
/// (`lib/presentation/widget/componets/restaurant/recipe_builder_widget.dart`)
/// but adapted to retail's variant-centric model: components are picked
/// across ALL products (not a single item's ingredient list), restricted to
/// `standard`-stockMode variants only — no bundle-of-bundles, one level deep,
/// the same guardrail restaurant's recipe ingredient picker enforces — and
/// quantities are whole units (`int`), matching retail's no-weight-selling
/// convention. See docs/retail_inventory_system_plan.md §3.2.
///
/// Emits the current `List<BundleComponentModel>` via [onChanged] every time
/// a row changes (add/replace/remove/qty edit).
class BundleBuilderWidget extends StatefulWidget {
  /// The product currently being built/edited — excluded from the component
  /// picker so a bundle/repack can never contain itself. In create mode this
  /// is the draft id minted before the product is actually saved.
  final String? currentProductId;

  /// `'bundle'` or `'repack'` — only changes label copy, not behavior.
  final String stockMode;

  final List<BundleComponentModel> initialComponents;

  /// The bundle/repack product's own selling price, for the margin readout.
  /// Null hides the margin chip.
  final double? sellingPrice;

  final ValueChanged<List<BundleComponentModel>> onChanged;

  const BundleBuilderWidget({
    super.key,
    required this.currentProductId,
    required this.stockMode,
    required this.initialComponents,
    required this.onChanged,
    this.sellingPrice,
  });

  @override
  State<BundleBuilderWidget> createState() => _BundleBuilderWidgetState();
}

class _ComponentRow {
  String componentVariantId;
  final TextEditingController qtyController;

  _ComponentRow({
    required this.componentVariantId,
    required this.qtyController,
  });

  void dispose() => qtyController.dispose();
}

class _BundleBuilderWidgetState extends State<BundleBuilderWidget> {
  final List<_ComponentRow> _rows = [];

  @override
  void initState() {
    super.initState();
    for (final c in widget.initialComponents) {
      _rows.add(_ComponentRow(
        componentVariantId: c.componentVariantId,
        qtyController: TextEditingController(text: c.quantity.toString()),
      ));
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  bool get _isRepack => widget.stockMode == 'repack';
  String get _sectionTitle => _isRepack ? 'Repack Components' : 'Bundle Components';
  String get _costLabel => _isRepack ? 'Estimated Repack Cost' : 'Estimated Bundle Cost';

  VarianteModel? _variantById(String id) {
    for (final v in productStore.variants) {
      if (v.varianteId == id) return v;
    }
    return null;
  }

  double _lineCost(_ComponentRow row) {
    final variant = _variantById(row.componentVariantId);
    final qty = int.tryParse(row.qtyController.text.trim()) ?? 0;
    return (variant?.costPrice ?? 0) * qty;
  }

  double get _totalCost => _rows.fold(0.0, (sum, row) => sum + _lineCost(row));

  void _emit() {
    final components = <BundleComponentModel>[];
    for (final row in _rows) {
      if (row.componentVariantId.isEmpty) continue;
      final qty = int.tryParse(row.qtyController.text.trim()) ?? 0;
      if (qty <= 0) continue;
      components.add(BundleComponentModel(
        componentVariantId: row.componentVariantId,
        quantity: qty,
      ));
    }
    widget.onChanged(components);
  }

  void _onFieldChanged() => setState(_emit);

  /// Candidate variants for the picker — `standard`-stockMode products only
  /// (never a bundle/repack itself), excluding the product being built and
  /// variants already used by another row.
  List<VarianteModel> _candidates({String? excludeVariantId}) {
    final used = _rows.map((r) => r.componentVariantId).toSet();
    if (excludeVariantId != null) used.remove(excludeVariantId);

    return productStore.variants.where((v) {
      if (used.contains(v.varianteId)) return false;
      final product = productStore.getProductById(v.productId);
      if (product == null || !product.isStandardStock) return false;
      if (widget.currentProductId != null &&
          product.productId == widget.currentProductId) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<VarianteModel?> _pickComponent({String? excludeVariantId}) {
    return showModalBottomSheet<VarianteModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ComponentPickerSheet(
        candidates: _candidates(excludeVariantId: excludeVariantId),
      ),
    );
  }

  Future<void> _addComponent() async {
    final picked = await _pickComponent();
    if (picked == null) return;
    setState(() {
      _rows.add(_ComponentRow(
        componentVariantId: picked.varianteId,
        qtyController: TextEditingController(text: '1'),
      ));
    });
    _emit();
  }

  Future<void> _replaceComponent(_ComponentRow row) async {
    final picked =
        await _pickComponent(excludeVariantId: row.componentVariantId);
    if (picked == null) return;
    setState(() => row.componentVariantId = picked.varianteId);
    _emit();
  }

  void _removeRow(_ComponentRow row) {
    setState(() {
      _rows.remove(row);
      row.dispose();
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _rows.length,
                  itemBuilder: (context, index) =>
                      _buildComponentRow(_rows[index]),
                ),
                if (_rows.isEmpty) _buildEmptyRowsHint(),
                const SizedBox(height: 8),
                _buildAddComponentButton(),
              ],
            ),
          ),
          _buildCostFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _isRepack ? Icons.build_circle_outlined : Icons.widgets_rounded,
              color: AppColors.secondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sectionTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _rows.isEmpty
                      ? 'No components yet'
                      : '${_rows.length} component${_rows.length == 1 ? '' : 's'}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRowsHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined,
              color: AppColors.textSecondary.withValues(alpha: 0.6), size: 26),
          const SizedBox(height: 6),
          Text(
            _isRepack
                ? 'Add the standard products this repack is assembled from'
                : 'Add the standard products that make up this bundle',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentRow(_ComponentRow row) {
    final variant = _variantById(row.componentVariantId);
    final product =
        variant == null ? null : productStore.getProductById(variant.productId);
    final label = (product == null || variant == null)
        ? 'Select a product…'
        : (variant.hasAttributes
            ? '${product.productName} (${variant.variantDescription})'
            : product.productName);
    final lineCost = _lineCost(row);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _replaceComponent(row),
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: product == null
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _removeRow(row),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline_rounded,
                      color: AppColors.danger, size: 19),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: AppTextField(
                  controller: row.qtyController,
                  label: 'Qty',
                  hint: '1',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => _onFieldChanged(),
                ),
              ),
              const SizedBox(width: 8),
              if (variant != null)
                Expanded(
                  flex: 2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppColors.info.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${variant.stockQty}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.info,
                          ),
                        ),
                        Text(
                          'in stock',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: AppColors.info.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(lineCost)}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'line cost',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: AppColors.accent.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddComponentButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _addComponent,
        icon: Icon(Icons.add_circle_outline_rounded,
            color: AppColors.secondary, size: 18),
        label: Text(
          'Add Component',
          style: GoogleFonts.poppins(
            color: AppColors.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildCostFooter() {
    final sellingPrice = widget.sellingPrice;
    double? marginPercent;
    if (sellingPrice != null && sellingPrice > 0) {
      marginPercent = ((sellingPrice - _totalCost) / sellingPrice) * 100;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(
            top: BorderSide(color: AppColors.success.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.savings_rounded, color: AppColors.success, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _costLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalCost)}',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          if (marginPercent != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (marginPercent >= 0 ? AppColors.success : AppColors.danger)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Margin',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${marginPercent.toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: marginPercent >= 0 ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Search + select bottom sheet for component picking — mirrors restaurant's
/// ingredient picker sheet and retail's `add_purchase_order_screen.dart`
/// product-search interaction (search by product name / SKU / barcode).
class _ComponentPickerSheet extends StatefulWidget {
  final List<VarianteModel> candidates;

  const _ComponentPickerSheet({required this.candidates});

  @override
  State<_ComponentPickerSheet> createState() => _ComponentPickerSheetState();
}

class _ComponentPickerSheetState extends State<_ComponentPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.toLowerCase();
    final filtered = query.isEmpty
        ? widget.candidates
        : widget.candidates.where((v) {
            final product = productStore.getProductById(v.productId);
            final name = product?.productName.toLowerCase() ?? '';
            final sku = v.sku?.toLowerCase() ?? '';
            final barcode = v.barcode?.toLowerCase() ?? '';
            final desc = v.variantDescription.toLowerCase();
            return name.contains(query) ||
                sku.contains(query) ||
                barcode.contains(query) ||
                desc.contains(query);
          }).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                'Select Component',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppTextField(
                controller: _searchController,
                hint: 'Search by product, SKU, barcode…',
                icon: Icons.search_rounded,
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(30),
                      child: Text(
                        widget.candidates.isEmpty
                            ? 'No standard-stock products available yet'
                            : 'No matching products',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final variant = filtered[index];
                        final product =
                            productStore.getProductById(variant.productId);
                        return ListTile(
                          leading: const Icon(Icons.inventory_2_outlined,
                              color: AppColors.secondary),
                          title: Text(
                            product?.productName ?? 'Unknown',
                            style: GoogleFonts.poppins(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            variant.hasAttributes
                                ? variant.variantDescription
                                : (variant.sku ?? 'Default'),
                            style: GoogleFonts.poppins(
                                fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                          trailing: Text(
                            'Stock: ${variant.stockQty}',
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                          onTap: () => Navigator.pop(context, variant),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
