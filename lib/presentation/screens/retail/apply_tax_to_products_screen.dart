import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/common/taxmodel_314.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Bulk-assigns one named tax rate to many products — retail's counterpart of
/// restaurant's `ApplyTaxScreen`. Mainly for a shop that turned tax on after
/// setup, when every product created in the meantime has no rate.
class RetailApplyTaxScreen extends StatefulWidget {
  final Tax tax;
  const RetailApplyTaxScreen({super.key, required this.tax});

  @override
  State<RetailApplyTaxScreen> createState() => _RetailApplyTaxScreenState();
}

class _RetailApplyTaxScreenState extends State<RetailApplyTaxScreen> {
  final Set<String> _selectedIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _categoryId; // null = all categories
  bool _isWorking = false;

  double get _rate => widget.tax.taxperecentage ?? 0;

  @override
  void initState() {
    super.initState();
    categoryStore.loadCategories();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// The one filtered list both the checklist and "Select All" use, so select
  /// all only ever touches what the user can see.
  List<ProductModel> _visible(List<ProductModel> all) => all.where((p) {
        if (_categoryId != null && p.category != _categoryId) return false;
        if (_query.isNotEmpty && !p.productName.toLowerCase().contains(_query)) {
          return false;
        }
        return true;
      }).toList();

  bool _hasTax(ProductModel p) => p.taxId != null || (p.gstRate ?? 0) > 0;

  String _fmt(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toString();

  String _taxLabel(ProductModel p) {
    if (p.taxId != null) {
      for (final t in taxStore.taxes) {
        if (t.id == p.taxId) {
          return '${t.taxname} ${_fmt(t.taxperecentage ?? 0)}%';
        }
      }
    }
    final rate = p.gstRate ?? 0;
    return rate > 0 ? 'Tax ${_fmt(rate)}%' : 'No tax set';
  }

  void _toggleAll(bool selectAll, List<ProductModel> visible) {
    setState(() {
      final ids = visible.map((p) => p.productId);
      selectAll ? _selectedIds.addAll(ids) : _selectedIds.removeAll(ids);
    });
  }

  Future<void> _apply() async {
    if (_selectedIds.isEmpty || _isWorking) return;
    setState(() => _isWorking = true);
    try {
      final count = await productStore.applyTaxToProducts(
        _selectedIds.toList(),
        taxId: widget.tax.id,
        rate: _rate,
      );
      if (!mounted) return;
      setState(() => _selectedIds.clear());
      NotificationService.instance.showSuccess(
        '${widget.tax.taxname} (${_fmt(_rate)}%) applied to $count product(s).',
      );
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _clear() async {
    if (_selectedIds.isEmpty || _isWorking) return;
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Clear tax?',
      message:
          'The selected products and their variants lose their tax rate and '
          'bill at the default rate set in Tax Settings.',
      confirmLabel: 'Clear Tax',
      accent: AppColors.danger,
      icon: Icons.remove_circle_outline_rounded,
    );
    if (!confirmed || !mounted) return;
    setState(() => _isWorking = true);
    try {
      final count =
          await productStore.clearTaxFromProducts(_selectedIds.toList());
      if (!mounted) return;
      setState(() => _selectedIds.clear());
      NotificationService.instance.showSuccess(
        'Tax cleared from $count product(s).',
      );
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Apply ${widget.tax.taxname}',
        actions: [
          Observer(
            builder: (_) {
              final visible = _visible(productStore.products.toList());
              final allSelected = visible.isNotEmpty &&
                  visible.every((p) => _selectedIds.contains(p.productId));
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    allSelected ? 'Deselect All' : 'Select All',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w500,
                      color: AppColors.white,
                    ),
                  ),
                  Checkbox(
                    value: allSelected,
                    onChanged: visible.isEmpty
                        ? null
                        : (v) => _toggleAll(v == true, visible),
                    activeColor: AppColors.white,
                    checkColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.white),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Observer(
        builder: (_) {
          final all = productStore.products.toList();
          if (all.isEmpty) {
            return const AppEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No products yet',
              message: 'Add products first, then apply tax to them here.',
            );
          }

          final visible = _visible(all);
          final hasTaxedSelection = all.any(
            (p) => _selectedIds.contains(p.productId) && _hasTax(p),
          );

          return Column(
            children: [
              _buildFilterStrip(context),
              Expanded(
                child: AppResponsive.constrainedContent(
                  context: context,
                  maxWidth: AppResponsive.maxContentWidth(context),
                  alignment: Alignment.topCenter,
                  child: visible.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'No products match',
                          message: 'Try a different search or category.',
                          dense: true,
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(
                            AppResponsive.gridSpacing(context),
                          ),
                          itemCount: visible.length,
                          itemBuilder: (context, index) =>
                              _buildProductRow(context, visible[index]),
                        ),
                ),
              ),
              _buildActionBar(context, hasTaxedSelection),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterStrip(BuildContext context) {
    final categories = categoryStore.categories;
    return Container(
      color: AppColors.white,
      padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
      child: AppResponsive.constrainedContent(
        context: context,
        maxWidth: AppResponsive.maxContentWidth(context),
        heightFactor: 1,
        child: Column(
          children: [
            AppTextField(
              controller: _searchController,
              hint: 'Search products…',
              icon: Icons.search_rounded,
            ),
            if (categories.isNotEmpty) ...[
              SizedBox(height: AppResponsive.smallSpacing(context)),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _categoryChip(context, label: 'All', id: null),
                    ...categories.map(
                      (c) => _categoryChip(context, label: c.name, id: c.id),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(
    BuildContext context, {
    required String label,
    required String? id,
  }) {
    final selected = _categoryId == id;
    return Padding(
      padding: EdgeInsets.only(right: AppResponsive.smallSpacing(context)),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => setState(() => _categoryId = id),
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surfaceLight,
        labelStyle: GoogleFonts.poppins(
          color: selected ? AppColors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w500,
          fontSize: AppResponsive.bodyFontSize(context),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
      ),
    );
  }

  Widget _buildProductRow(BuildContext context, ProductModel product) {
    final selected = _selectedIds.contains(product.productId);
    final taxed = _hasTax(product);
    final variantCount = productStore.variantCountFor(product.productId);
    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.divider,
          width: selected ? 2 : 1,
        ),
      ),
      child: CheckboxListTile(
        value: selected,
        onChanged: (v) => setState(() {
          v == true
              ? _selectedIds.add(product.productId)
              : _selectedIds.remove(product.productId);
        }),
        activeColor: AppColors.primary,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          product.productName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          variantCount > 1
              ? '${_taxLabel(product)} · $variantCount variants'
              : _taxLabel(product),
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: taxed ? FontWeight.w500 : FontWeight.w400,
            color: taxed ? AppColors.success : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, bool hasTaxedSelection) {
    final noSelection = _selectedIds.isEmpty || _isWorking;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    final padding = EdgeInsets.symmetric(
      vertical: AppResponsive.mediumSpacing(context),
    );
    final labelStyle = GoogleFonts.poppins(
      fontSize: AppResponsive.bodyFontSize(context),
      fontWeight: FontWeight.w600,
    );

    return Container(
      color: AppColors.white,
      padding: EdgeInsets.all(AppResponsive.gridSpacing(context)),
      child: SafeArea(
        top: false,
        child: AppResponsive.constrainedContent(
          context: context,
          maxWidth: AppResponsive.maxContentWidth(context),
          heightFactor: 1,
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: noSelection ? null : _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    padding: padding,
                    shape: shape,
                  ),
                  icon: Icon(
                    Icons.check_circle_rounded,
                    size: AppResponsive.smallIconSize(context),
                  ),
                  label: Text(
                    _selectedIds.isEmpty
                        ? 'Apply ${_fmt(_rate)}%'
                        : 'Apply ${_fmt(_rate)}% (${_selectedIds.length})',
                    style: labelStyle,
                  ),
                ),
              ),
              SizedBox(width: AppResponsive.mediumSpacing(context)),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      (noSelection || !hasTaxedSelection) ? null : _clear,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(
                      color: (noSelection || !hasTaxedSelection)
                          ? AppColors.divider
                          : AppColors.danger,
                    ),
                    padding: padding,
                    shape: shape,
                  ),
                  icon: Icon(
                    Icons.remove_circle_outline_rounded,
                    size: AppResponsive.smallIconSize(context),
                  ),
                  label: Text('Clear Tax', style: labelStyle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
