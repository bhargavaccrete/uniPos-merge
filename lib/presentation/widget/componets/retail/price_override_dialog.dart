import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

import '../../../../data/models/retail/hive_model/cart_model_202.dart';
import '../../../../data/models/retail/hive_model/variante_model_201.dart';
import '../../../../domain/services/common/notification_service.dart';
import '../../../../domain/services/retail/price_override_reason.dart';
import '../../../../domain/services/retail/price_override_service.dart';

/// Money input: digits plus at most two decimal places.
final _priceFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
  LengthLimitingTextInputFormatter(10),
];

/// Change the charged unit price of one cart line.
///
/// Mirrors `StockAdjustmentDialog` on purpose: same shell, same mandatory
/// reason dropdown, same conditional note. Both exist for the same reason - a
/// manual figure that moves money needs a machine-readable "why".
///
/// Pops `true` when the line was changed. Admin-only; the caller must HIDE the
/// entry point when `PriceOverrideService.canOverride` is false rather than
/// showing it and refusing.
class PriceOverrideDialog extends StatefulWidget {
  final CartItemModel item;
  final VarianteModel variant;

  /// Money formatter supplied by the caller, which already sits inside a
  /// MoneyScope. Injected rather than calling `formatMoney` here so this dialog
  /// cannot render a different currency symbol from the screen behind it.
  final String Function(double) money;

  /// Applies the change; returns an error message, or null on success. Injected
  /// so the widget stays store-free - the POS passes `overrideLinePrice`.
  final Future<String?> Function({
    required double newPrice,
    required String reason,
    String? note,
  }) onApply;

  const PriceOverrideDialog({
    super.key,
    required this.item,
    required this.variant,
    required this.money,
    required this.onApply,
  });

  @override
  State<PriceOverrideDialog> createState() => _PriceOverrideDialogState();
}

class _PriceOverrideDialogState extends State<PriceOverrideDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _priceController;
  final _noteController = TextEditingController();

  PriceOverrideReason? _reason;
  bool _saving = false;

  /// What the catalogue says. Read from the VARIANT, never from the line - a
  /// second edit of an already-overridden line must still compare against list.
  double get _cataloguePrice => widget.variant.effectivePrice;

  double? get _typedPrice => double.tryParse(_priceController.text.trim());

  bool get _isRevert => _typedPrice != null && _typedPrice == _cataloguePrice;

  PriceOverrideValidation? get _validation {
    final typed = _typedPrice;
    if (typed == null) return null;
    return PriceOverrideService.validate(
      variant: widget.variant,
      newPrice: typed,
      currentPrice: widget.item.price,
    );
  }

  @override
  void initState() {
    super.initState();
    _priceController =
        TextEditingController(text: _trimZeros(widget.item.price));
    // Pre-select the existing reason so re-opening an overridden line shows
    // what was chosen rather than an empty dropdown.
    _reason = PriceOverrideReason.byCode(widget.item.overrideReason);
    _noteController.text = widget.item.overrideNote ?? '';
  }

  @override
  void dispose() {
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  static String _trimZeros(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Future<void> _apply() async {
    if (!_formKey.currentState!.validate()) return;

    final typed = _typedPrice!;
    final validation = _validation!;
    if (validation.isBlocked) {
      NotificationService.instance.showError(validation.message!);
      return;
    }

    // Reverting to list price needs no reason - there is nothing to explain,
    // and the store clears the audit fields for exactly this case.
    final reason = _reason;
    if (!_isRevert && reason == null) {
      NotificationService.instance.showError('Select a reason.');
      return;
    }

    // Selling under cost is allowed, but never silently. A separate explicit
    // step, because the cashier may not know the cost of what they discounted.
    if (validation.needsConfirmation) {
      final confirmed = await showAppConfirmDialog(
        context: context,
        title: 'Sell below cost?',
        message: '${validation.message} Continue anyway?',
        confirmLabel: 'Sell at a loss',
        icon: Icons.trending_down_rounded,
        accent: AppColors.danger,
      );
      if (!confirmed) return;
      if (!mounted) return;
    }

    setState(() => _saving = true);

    final error = await widget.onApply(
      newPrice: typed,
      reason: reason?.code ?? PriceOverrideReason.pricingCorrection.code,
      note: _noteController.text,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() => _saving = false);
      NotificationService.instance.showError(error);
      return;
    }

    Navigator.pop(context, true);
    NotificationService.instance.showSuccess(
      _isRevert
          ? 'Price restored to ${widget.money(_cataloguePrice)}'
          : 'Price set to ${widget.money(typed)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final validation = _validation;

    return AppDialogShell(
      title: 'Override Price',
      subtitle: widget.variant.hasAttributes
          ? '${widget.item.productName} - ${widget.variant.variantDescription}'
          : widget.item.productName,
      accent: AppColors.primary,
      icon: Icons.sell_outlined,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReferencePrices(context),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            AppTextField(
              controller: _priceController,
              label: 'Override Price',
              hint: '0.00',
              icon: Icons.sell_outlined,
              required: true,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: _priceFormatters,
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final text = v?.trim() ?? '';
                if (text.isEmpty) return 'Required';
                final parsed = double.tryParse(text);
                if (parsed == null) return 'Enter a valid amount';
                final result = PriceOverrideService.validate(
                  variant: widget.variant,
                  newPrice: parsed,
                  currentPrice: widget.item.price,
                );
                return result.isBlocked ? result.message : null;
              },
            ),
            if (_isRevert) ...[
              SizedBox(height: AppResponsive.smallSpacing(context)),
              _buildHint(
                context,
                icon: Icons.restart_alt_rounded,
                color: AppColors.success,
                text: 'This restores the catalogue price and clears the '
                    'override from this line.',
              ),
            ] else ...[
              SizedBox(height: AppResponsive.mediumSpacing(context)),
              _buildReasonDropdown(context),
              SizedBox(height: AppResponsive.mediumSpacing(context)),
              AppTextField(
                controller: _noteController,
                label: (_reason?.requiresNote ?? false)
                    ? 'Note'
                    : 'Note (Optional)',
                hint: 'Why this price?',
                icon: Icons.notes_outlined,
                required: _reason?.requiresNote ?? false,
                maxLines: 2,
                minLines: 2,
                validator: (v) {
                  if (!(_reason?.requiresNote ?? false)) return null;
                  return (v == null || v.trim().isEmpty)
                      ? 'Required for this reason'
                      : null;
                },
              ),
            ],
            if (validation?.needsConfirmation ?? false) ...[
              SizedBox(height: AppResponsive.smallSpacing(context)),
              _buildHint(
                context,
                icon: Icons.trending_down_rounded,
                color: AppColors.danger,
                text: validation!.message!,
              ),
            ],
          ],
        ),
      ),
      actions: [
        appDialogCancelButton(context),
        const SizedBox(width: 12),
        appDialogPrimaryButton(
          label: _saving
              ? 'Applying...'
              : (_isRevert ? 'Restore Price' : 'Apply Price'),
          onPressed: _saving ? () {} : _apply,
        ),
      ],
    );
  }

  /// Catalogue / MRP / cost, so the decision is made with the numbers in view.
  /// Cost is shown because this dialog is admin-only - a cashier never reaches
  /// it.
  Widget _buildReferencePrices(BuildContext context) {
    final mrp = widget.variant.mrp;
    final cost = widget.variant.costPrice;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          _priceRow(context, 'Catalogue Price', _cataloguePrice, bold: true),
          if (mrp != null && mrp > 0) ...[
            SizedBox(height: AppResponsive.smallSpacing(context)),
            _priceRow(context, 'MRP (ceiling)', mrp),
          ],
          if (cost != null && cost > 0) ...[
            SizedBox(height: AppResponsive.smallSpacing(context)),
            _priceRow(context, 'Cost Price', cost),
          ],
          if (widget.item.isPriceOverridden) ...[
            SizedBox(height: AppResponsive.smallSpacing(context)),
            _priceRow(context, 'Currently charging', widget.item.price,
                valueColor: AppColors.warning),
          ],
        ],
      ),
    );
  }

  Widget _priceRow(
    BuildContext context,
    String label,
    double value, {
    bool bold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.captionFontSize(context),
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          widget.money(value),
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildReasonDropdown(BuildContext context) {
    return DropdownButtonFormField<PriceOverrideReason>(
      initialValue: _reason,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Reason *',
        labelStyle: GoogleFonts.poppins(
          fontSize: AppResponsive.smallFontSize(context),
          color: AppColors.textSecondary,
        ),
        prefixIcon: Icon(
          Icons.help_outline_rounded,
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
      items: PriceOverrideReason.all
          .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
          .toList(),
      onChanged: (value) => setState(() => _reason = value),
      validator: (value) =>
          (_isRevert || value != null) ? null : 'Select a reason',
    );
  }

  Widget _buildHint(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: AppResponsive.smallIconSize(context), color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
