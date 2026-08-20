import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

import '../../../../data/models/retail/hive_model/variante_model_201.dart';
import '../../../../domain/services/common/notification_service.dart';
import '../../../../domain/services/retail/stock_adjustment_reason.dart';
import '../../../../domain/services/retail/stock_adjustment_service.dart';

/// Whole-number quantity input.
final _qtyFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(6),
];

/// Read-only stock display for the Edit Variant form.
///
/// Styled like a disabled field so the form still reads consistently, but it
/// carries no controller — stock is not editable here by design. See
/// [StockAdjustmentService] for why.
class ReadOnlyStockTile extends StatelessWidget {
  final int stock;

  const ReadOnlyStockTile({super.key, required this.stock});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.mediumSpacing(context),
        vertical: AppResponsive.smallSpacing(context),
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: AppResponsive.smallIconSize(context),
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stock Quantity',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '$stock pcs',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: Text(
              'Use Adjust Stock',
              textAlign: TextAlign.end,
              maxLines: 2,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Admin-only dialog that corrects a variant's stock through
/// [StockAdjustmentService].
///
/// The user enters the **counted** quantity, not a delta — that is what a
/// physical count produces, and it removes the "did I mean plus 3 or minus 3"
/// ambiguity. The resulting change is shown live so the effect is never a
/// surprise.
class StockAdjustmentDialog extends StatefulWidget {
  final VarianteModel variant;
  final String productName;

  const StockAdjustmentDialog({
    super.key,
    required this.variant,
    required this.productName,
  });

  /// Opens the dialog, refusing non-admins before anything is shown.
  /// Returns true when an adjustment was saved.
  static Future<bool> show(
    BuildContext context, {
    required VarianteModel variant,
    required String productName,
  }) async {
    if (!StockAdjustmentService.canAdjust) {
      NotificationService.instance
          .showError('Only the admin can adjust stock.');
      return false;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StockAdjustmentDialog(
        variant: variant,
        productName: productName,
      ),
    );
    return saved ?? false;
  }

  @override
  State<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _countedController;
  final _noteController = TextEditingController();

  StockAdjustmentReason? _reason;
  bool _saving = false;

  int get _currentStock => widget.variant.stockQty;

  int? get _counted => int.tryParse(_countedController.text.trim());

  /// Null until a valid, different quantity is typed.
  int? get _delta {
    final counted = _counted;
    if (counted == null || counted == _currentStock) return null;
    return counted - _currentStock;
  }

  /// The reason list depends on direction — "Found extra stock" makes no sense
  /// on a decrease, and no loss reason makes sense on an increase.
  List<StockAdjustmentReason> get _reasonOptions {
    final delta = _delta;
    if (delta == null) return StockAdjustmentReason.all;
    return delta > 0
        ? StockAdjustmentReason.increaseReasons
        : StockAdjustmentReason.decreaseReasons;
  }

  @override
  void initState() {
    super.initState();
    _countedController = TextEditingController(text: _currentStock.toString());
  }

  @override
  void dispose() {
    _countedController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Direction can flip while typing, which may strand a reason that no longer
  /// applies. Drop it rather than submit something the service would reject.
  void _onCountedChanged(String _) {
    setState(() {
      final reason = _reason;
      if (reason != null && !_reasonOptions.any((r) => r.code == reason.code)) {
        _reason = null;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final reason = _reason;
    if (reason == null) {
      NotificationService.instance.showError('Select a reason.');
      return;
    }

    setState(() => _saving = true);

    final result = await StockAdjustmentService.adjust(
      variant: widget.variant,
      newStock: _counted!,
      reason: reason,
      note: _noteController.text,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() => _saving = false);
      NotificationService.instance
          .showError(result.errorMessage ?? 'Adjustment failed.');
      return;
    }

    Navigator.pop(context, true);
    final loss = result.lossNumber;
    NotificationService.instance.showSuccess(
      loss == null
          ? 'Stock adjusted to ${result.balanceAfter}'
          : 'Stock adjusted to ${result.balanceAfter} - loss $loss recorded',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      title: 'Adjust Stock',
      subtitle: widget.variant.hasAttributes
          ? '${widget.productName} - ${widget.variant.variantDescription}'
          : widget.productName,
      accent: AppColors.primary,
      icon: Icons.tune_rounded,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentAndDelta(context),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            AppTextField(
              controller: _countedController,
              label: 'Counted Quantity',
              hint: '0',
              icon: Icons.inventory_2_outlined,
              required: true,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: _qtyFormatters,
              onChanged: _onCountedChanged,
              validator: (v) {
                final text = v?.trim() ?? '';
                if (text.isEmpty) return 'Required';
                final parsed = int.tryParse(text);
                if (parsed == null) return 'Enter a number';
                if (parsed == _currentStock) return 'Same as current stock';
                return null;
              },
            ),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            _buildReasonDropdown(context),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            AppTextField(
              controller: _noteController,
              label:
                  (_reason?.requiresNote ?? false) ? 'Note' : 'Note (Optional)',
              hint: 'What happened?',
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
            if (_reason?.isLoss ?? false) ...[
              SizedBox(height: AppResponsive.smallSpacing(context)),
              _buildLossHint(context),
            ],
          ],
        ),
      ),
      actions: [
        appDialogCancelButton(context),
        const SizedBox(width: 12),
        appDialogPrimaryButton(
          label: _saving ? 'Saving...' : 'Adjust Stock',
          onPressed: _saving ? () {} : _save,
        ),
      ],
    );
  }

  Widget _buildCurrentAndDelta(BuildContext context) {
    final delta = _delta;
    final isIncrease = (delta ?? 0) > 0;
    final deltaColor = delta == null
        ? AppColors.textSecondary
        : (isIncrease ? AppColors.success : AppColors.danger);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          _stat(context, 'Current', '$_currentStock', AppColors.textPrimary),
          Icon(
            Icons.arrow_forward_rounded,
            size: AppResponsive.smallIconSize(context),
            color: AppColors.textSecondary,
          ),
          _stat(
            context,
            'Change',
            delta == null ? '-' : (isIncrease ? '+$delta' : '$delta'),
            deltaColor,
          ),
          Icon(
            Icons.arrow_forward_rounded,
            size: AppResponsive.smallIconSize(context),
            color: AppColors.textSecondary,
          ),
          _stat(
            context,
            'New',
            delta == null ? '-' : '${_counted!}',
            AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _stat(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonDropdown(BuildContext context) {
    return DropdownButtonFormField<StockAdjustmentReason>(
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
      items: _reasonOptions
          .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
          .toList(),
      onChanged: (value) => setState(() => _reason = value),
      validator: (value) => value == null ? 'Select a reason' : null,
    );
  }

  /// Spells out the financial consequence before the user commits — a loss row
  /// affects the profit report, a miscount correction does not.
  Widget _buildLossHint(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.trending_down_rounded,
            size: AppResponsive.smallIconSize(context),
            color: AppColors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This also records an inventory loss, so the cost appears in your '
              'loss and profit reports.',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
