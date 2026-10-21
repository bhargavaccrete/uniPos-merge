import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

import '../../../../core/config/tax_feature.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../domain/services/common/notification_service.dart';
import '../../../../domain/services/retail/quick_item_service.dart';

/// Money input: digits plus at most two decimal places. Same rule as
/// `price_override_dialog` and `line_discount_dialog`.
final _priceFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
  LengthLimitingTextInputFormatter(10),
];

/// Whole-number quantity, capped at four digits — the same typo guard
/// `CartQuantityField` uses, mirroring `kMaxCartLineQuantity`.
///
/// Digits ONLY, deliberately: a quick item has no variant to carry the
/// `isDecimalQuantity` flag, so it sells in whole units. `digitsOnly` also means
/// the decimal point cannot be typed at all, rather than being silently
/// swallowed — the bug `stock_adjustment_dialog` documents, where "13.50" became
/// 1350.
final _qtyFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(4),
];

/// Sell something the catalogue does not carry, by typing it at the POS.
///
/// Collects only what a sale line genuinely needs — name, price, tax and
/// quantity. No barcode, SKU, category, UOM, expiry or attributes: this is an
/// ad-hoc line, not a product, and **nothing here is written to the catalogue**.
///
/// Pops `true` when a line was added. Unlike the override and discount dialogs
/// this one is NOT admin-gated — selling an unlisted item is ordinary cashier
/// work, and the price is typed rather than moved off a settled figure.
class QuickItemDialog extends StatefulWidget {
  /// The store's default GST rate as a percentage, resolved by the CALLER.
  ///
  /// Passed in rather than fetched here because `DropdownButtonFormField` seeds
  /// its field state from `initialValue` on the FIRST build only — a rate that
  /// arrived later from an async lookup would never appear as the selection.
  final double defaultGstRate;

  /// Money formatter supplied by the caller, which already sits inside a
  /// MoneyScope. Injected rather than calling `formatMoney` here so this dialog
  /// cannot render a different currency symbol from the screen behind it.
  final String Function(double) money;

  /// Adds the line; returns an error message, or null on success. Injected so
  /// the widget stays store-free — the POS passes `addQuickItemToTab`.
  final Future<String?> Function({
    required String name,
    required double price,
    required double gstRate,
    required int qty,
  }) onApply;

  const QuickItemDialog({
    super.key,
    required this.defaultGstRate,
    required this.money,
    required this.onApply,
  });

  @override
  State<QuickItemDialog> createState() => _QuickItemDialogState();
}

class _QuickItemDialogState extends State<QuickItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');

  /// The chosen rate as a percentage (18 means 18%), matching
  /// `CartItemModel.gstRate`.
  ///
  /// Seeded from the store default so the common case is one tap; the cashier
  /// can still pick any other configured rate, because a quick item may be a
  /// completely different tax class from whatever the store usually sells.
  late double _gstRate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // A business not registered for tax bills at 0 regardless — the same gate
    // `CartStore._getEffectiveGstRate` applies.
    _gstRate = TaxFeature.enabled ? widget.defaultGstRate : 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  double? get _typedPrice => double.tryParse(_priceController.text.trim());

  int? get _typedQty => int.tryParse(_qtyController.text.trim());

  /// Every distinct configured rate, plus 0. Built from `taxStore.taxes` — the
  /// same source `add_product_screen` uses — so no rate is ever hardcoded here.
  /// Zero is always offered because "no tax" is the absence of a rate, not a
  /// rate someone has to have configured.
  List<double> get _availableRates {
    final rates = <double>{0};
    for (final tax in taxStore.taxes) {
      final pct = tax.taxperecentage;
      if (pct != null && pct > 0) rates.add(pct);
    }
    // The store default may not correspond to any named Tax row; it still has
    // to be in the list, or preselecting it would silently fall back to 0.
    rates.add(_gstRate);
    final sorted = rates.toList()..sort();
    return sorted;
  }

  /// Label for a rate: the configured tax's name when one matches, else the bare
  /// percentage.
  String _rateLabel(double rate) {
    if (rate == 0) return 'No tax (0%)';
    for (final tax in taxStore.taxes) {
      if (tax.taxperecentage == rate) {
        return '${tax.taxname} ($rate%)';
      }
    }
    return '$rate%';
  }

  /// Gross for the line as typed, so the cashier sees the value before adding.
  /// Tax is deliberately excluded — whether it is added on top or extracted
  /// depends on the store's inclusive/exclusive mode, and the cart is the one
  /// place that decides that.
  double get _lineTotal => (_typedPrice ?? 0) * (_typedQty ?? 0);

  Future<void> _apply() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final price = _typedPrice;
    final qty = _typedQty;

    // Belt and braces: the field validators above already cover these, but the
    // service is the single definition of what a valid quick item is.
    final problem = QuickItemService.validateName(name) ??
        QuickItemService.validatePrice(price) ??
        QuickItemService.validateQty(qty);
    if (problem != null) {
      NotificationService.instance.showError(problem);
      return;
    }

    setState(() => _saving = true);
    final error = await widget.onApply(
      name: name,
      price: price!,
      gstRate: _gstRate,
      qty: qty!,
    );
    if (!mounted) return;

    if (error != null) {
      setState(() => _saving = false);
      NotificationService.instance.showError(error);
      return;
    }

    Navigator.pop(context, true);
    NotificationService.instance.showSuccess('$name added to cart');
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      title: 'Quick Item',
      subtitle: 'Sell something not in the catalogue',
      accent: AppColors.primary,
      icon: Icons.add_shopping_cart_outlined,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              controller: _nameController,
              label: 'Item Name',
              hint: 'Local Bread',
              icon: Icons.inventory_2_outlined,
              required: true,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              maxLength: 60,
              onChanged: (_) => setState(() {}),
              validator: (v) => QuickItemService.validateName(v),
            ),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            AppTextField(
              controller: _priceController,
              label: 'Selling Price',
              hint: '0.00',
              icon: Icons.sell_outlined,
              required: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: _priceFormatters,
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final text = v?.trim() ?? '';
                if (text.isEmpty) return 'Required';
                final parsed = double.tryParse(text);
                if (parsed == null) return 'Enter a valid amount';
                return QuickItemService.validatePrice(parsed);
              },
            ),
            if (TaxFeature.enabled) ...[
              SizedBox(height: AppResponsive.mediumSpacing(context)),
              _buildTaxDropdown(context),
            ],
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            AppTextField(
              controller: _qtyController,
              label: 'Quantity',
              hint: '1',
              icon: Icons.numbers_rounded,
              required: true,
              keyboardType: TextInputType.number,
              inputFormatters: _qtyFormatters,
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final text = v?.trim() ?? '';
                if (text.isEmpty) return 'Required';
                return QuickItemService.validateQty(int.tryParse(text));
              },
            ),
            if (_lineTotal > 0) ...[
              SizedBox(height: AppResponsive.mediumSpacing(context)),
              _buildLineTotal(context),
            ],
          ],
        ),
      ),
      actions: [
        appDialogCancelButton(context),
        const SizedBox(width: 12),
        appDialogPrimaryButton(
          label: _saving ? 'Adding...' : 'Add to Cart',
          onPressed: _saving ? () {} : _apply,
        ),
      ],
    );
  }

  Widget _buildTaxDropdown(BuildContext context) {
    final rates = _availableRates;
    return DropdownButtonFormField<double>(
      initialValue: rates.contains(_gstRate) ? _gstRate : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Tax Rate',
        labelStyle: GoogleFonts.poppins(
          fontSize: AppResponsive.smallFontSize(context),
          color: AppColors.textSecondary,
        ),
        prefixIcon: Icon(
          Icons.percent_rounded,
          size: AppResponsive.smallIconSize(context),
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
      style: GoogleFonts.poppins(
        fontSize: AppResponsive.bodyFontSize(context),
        color: AppColors.textPrimary,
      ),
      dropdownColor: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      menuMaxHeight: 320,
      items: rates
          .map((r) => DropdownMenuItem(value: r, child: Text(_rateLabel(r))))
          .toList(),
      onChanged: (value) => setState(() => _gstRate = value ?? 0),
    );
  }

  Widget _buildLineTotal(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Line Total',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            widget.money(_lineTotal),
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
