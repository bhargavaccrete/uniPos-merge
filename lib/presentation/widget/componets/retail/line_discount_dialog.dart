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
import '../../../../domain/services/retail/line_discount_reason.dart';
import '../../../../domain/services/retail/line_discount_service.dart';
import '../../../../domain/services/retail/retail_billing_service.dart'
    show DiscountType;

/// Discount input: digits plus at most two decimal places.
final _discountFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
  LengthLimitingTextInputFormatter(10),
];

/// Discount one cart line, by percentage or a flat amount.
///
/// Mirrors `PriceOverrideDialog` on purpose: same shell, same mandatory reason
/// dropdown, same conditional note, same below-cost confirmation. Both exist for
/// the same reason — a manual figure that moves money needs a machine-readable
/// "why".
///
/// Stacks ON TOP of any price override: the override sets what the line charges,
/// this takes a further cut, and the below-cost check runs on the price after
/// both.
///
/// Pops `true` when the line was changed. Admin-only; the caller must HIDE the
/// entry point when `LineDiscountService.canDiscount` is false rather than
/// showing it and refusing.
class LineDiscountDialog extends StatefulWidget {
  final CartItemModel item;
  final VarianteModel variant;

  /// Money formatter supplied by the caller, which already sits inside a
  /// MoneyScope. Injected rather than calling `formatMoney` here so this dialog
  /// cannot render a different currency symbol from the screen behind it.
  final String Function(double) money;

  /// Applies the change; returns an error message, or null on success. Injected
  /// so the widget stays store-free — the POS passes `setLineDiscountInTab`.
  final Future<String?> Function({
    required DiscountType type,
    required double value,
    required String reason,
    String? note,
  }) onApply;

  const LineDiscountDialog({
    super.key,
    required this.item,
    required this.variant,
    required this.money,
    required this.onApply,
  });

  @override
  State<LineDiscountDialog> createState() => _LineDiscountDialogState();
}

class _LineDiscountDialogState extends State<LineDiscountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _valueController;
  final _noteController = TextEditingController();

  late DiscountType _type;
  LineDiscountReason? _reason;
  bool _saving = false;

  /// Charged unit price — already carries any price override.
  double get _unitPrice => widget.item.price;

  double get _qty => widget.item.qty;

  double get _gross => _unitPrice * _qty;

  double? get _typedValue => double.tryParse(_valueController.text.trim());

  /// True when the field is empty or zero, i.e. the user is clearing it.
  bool get _isClearing => (_typedValue ?? 0) <= 0;

  LineDiscountValidation? get _validation {
    final typed = _typedValue;
    if (typed == null) return null;
    return LineDiscountService.validate(
      variant: widget.variant,
      type: _type,
      value: typed,
      chargedUnitPrice: _unitPrice,
      qty: _qty,
    );
  }

  @override
  void initState() {
    super.initState();
    // Re-opening a discounted line shows what was chosen rather than a blank
    // form, matching PriceOverrideDialog.
    _type = widget.item.lineDiscountType == DiscountType.percentage.name
        ? DiscountType.percentage
        : DiscountType.amount;
    final existing = widget.item.lineDiscountValue;
    _valueController = TextEditingController(
      text: existing != null && existing > 0 ? _trimZeros(existing) : '',
    );
    _reason = LineDiscountReason.byCode(widget.item.lineDiscountReason);
    _noteController.text = widget.item.lineDiscountNote ?? '';
  }

  @override
  void dispose() {
    _valueController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  static String _trimZeros(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Future<void> _apply() async {
    if (!_formKey.currentState!.validate()) return;

    final typed = _typedValue ?? 0;

    // Clearing needs no reason — there is nothing left to explain, and the store
    // nulls all five fields for exactly this case.
    if (!_isClearing) {
      final validation = _validation!;
      if (validation.isBlocked) {
        NotificationService.instance.showError(validation.message!);
        return;
      }

      if (_reason == null) {
        NotificationService.instance.showError('Select a reason.');
        return;
      }

      // Selling under cost is allowed, but never silently.
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
    }

    setState(() => _saving = true);

    final error = await widget.onApply(
      type: _type,
      value: typed,
      reason: _reason?.code ?? LineDiscountReason.managerApproved.code,
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
      _isClearing
          ? 'Discount removed'
          : 'Discount applied — ${widget.money(_validation!.effectiveUnitPrice)} per unit',
    );
  }

  @override
  Widget build(BuildContext context) {
    final validation = _validation;

    return AppDialogShell(
      title: 'Line Discount',
      subtitle: widget.variant.hasAttributes
          ? '${widget.item.productName} - ${widget.variant.variantDescription}'
          : widget.item.productName,
      accent: AppColors.primary,
      icon: Icons.percent_rounded,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReferencePrices(context),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            _buildTypeToggle(context),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            AppTextField(
              controller: _valueController,
              label: _type == DiscountType.percentage
                  ? 'Discount %'
                  : 'Discount Amount',
              hint: _type == DiscountType.percentage ? '10' : '0.00',
              icon: _type == DiscountType.percentage
                  ? Icons.percent_rounded
                  : Icons.remove_circle_outline,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: _discountFormatters,
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final text = v?.trim() ?? '';
                // Empty means "clear the discount", which is valid.
                if (text.isEmpty) return null;
                final parsed = double.tryParse(text);
                if (parsed == null) return 'Enter a valid number';
                if (parsed == 0) return null;
                final result = LineDiscountService.validate(
                  variant: widget.variant,
                  type: _type,
                  value: parsed,
                  chargedUnitPrice: _unitPrice,
                  qty: _qty,
                );
                return result.isBlocked ? result.message : null;
              },
            ),
            if (_isClearing && widget.item.hasLineDiscount) ...[
              SizedBox(height: AppResponsive.smallSpacing(context)),
              _buildHint(
                context,
                icon: Icons.restart_alt_rounded,
                color: AppColors.success,
                text: 'Leaving this blank removes the discount from this line.',
              ),
            ] else if (!_isClearing) ...[
              SizedBox(height: AppResponsive.mediumSpacing(context)),
              _buildReasonDropdown(context),
              SizedBox(height: AppResponsive.mediumSpacing(context)),
              AppTextField(
                controller: _noteController,
                label: (_reason?.requiresNote ?? false)
                    ? 'Note'
                    : 'Note (Optional)',
                hint: 'Why this discount?',
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
            if (validation != null &&
                !_isClearing &&
                !validation.isBlocked) ...[
              SizedBox(height: AppResponsive.mediumSpacing(context)),
              _buildFinalPrice(context, validation),
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
              : (_isClearing && widget.item.hasLineDiscount
                  ? 'Remove Discount'
                  : 'Apply Discount'),
          onPressed: _saving ? () {} : _apply,
        ),
      ],
    );
  }

  /// Current selling price and the line it applies to, so the decision is made
  /// with the numbers in view. Cost is shown because this dialog is admin-only.
  Widget _buildReferencePrices(BuildContext context) {
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
          _priceRow(
            context,
            widget.item.isPriceOverridden
                ? 'Selling Price (overridden)'
                : 'Selling Price',
            _unitPrice,
            bold: true,
            valueColor:
                widget.item.isPriceOverridden ? AppColors.warning : null,
          ),
          if (widget.item.isPriceOverridden) ...[
            SizedBox(height: AppResponsive.smallSpacing(context)),
            _priceRow(context, 'Catalogue Price', widget.item.originalPrice!),
          ],
          if (cost != null && cost > 0) ...[
            SizedBox(height: AppResponsive.smallSpacing(context)),
            _priceRow(context, 'Cost Price', cost),
          ],
          SizedBox(height: AppResponsive.smallSpacing(context)),
          _priceRow(context, 'Line Total ($_qty x)', _gross),
        ],
      ),
    );
  }

  /// The resolved outcome — the number the cashier and the customer care about.
  Widget _buildFinalPrice(
    BuildContext context,
    LineDiscountValidation validation,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _priceRow(context, 'Discount', -validation.amount,
              valueColor: AppColors.danger),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          _priceRow(context, 'Final Unit Price', validation.effectiveUnitPrice,
              bold: true, valueColor: AppColors.primary),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          _priceRow(context, 'Final Line Total', _gross - validation.amount,
              bold: true),
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
          value < 0 ? '- ${widget.money(value.abs())}' : widget.money(value),
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  /// Percentage / Amount switch, reusing the shared [DiscountType] enum rather
  /// than inventing a second vocabulary.
  Widget _buildTypeToggle(BuildContext context) {
    Widget option(DiscountType type, String label) {
      final selected = _type == type;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _type = type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              vertical: AppResponsive.smallSpacing(context),
            ),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.divider,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option(DiscountType.percentage, 'Percentage'),
        const SizedBox(width: 10),
        option(DiscountType.amount, 'Amount'),
      ],
    );
  }

  Widget _buildReasonDropdown(BuildContext context) {
    return DropdownButtonFormField<LineDiscountReason>(
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
      items: LineDiscountReason.all
          .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
          .toList(),
      onChanged: (value) => setState(() => _reason = value),
      validator: (value) =>
          (_isClearing || value != null) ? null : 'Select a reason',
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
