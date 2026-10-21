import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

import '../../../../domain/services/retail/stock_adjustment_reason.dart';

/// What the user chose at the commit prompt.
class StockTakeCommitChoice {
  final StockAdjustmentReason reason;
  final String? note;

  const StockTakeCommitChoice({required this.reason, this.note});
}

/// Confirms a stock take before it moves any stock, and picks the reason.
///
/// **One reason for the whole take, not one per line.** A shopkeeper counting a
/// shelf knows why the shelf is off; they rarely know why each individual SKU
/// is. Asking per line would produce either a wall of dropdowns or, more
/// likely, the same value repeated without thought.
///
/// The reason list is the full set, including loss-bearing ones, because a take
/// usually has variances in both directions. `StockAdjustmentService` only
/// records a loss on lines that actually went *down*, so picking "Theft" on a
/// mixed take books losses for the shortages and leaves the excesses as plain
/// corrections.
class StockTakeCommitDialog extends StatefulWidget {
  final int varianceLines;
  final double shortageQty;
  final double excessQty;
  final double netValue;

  const StockTakeCommitDialog({
    super.key,
    required this.varianceLines,
    required this.shortageQty,
    required this.excessQty,
    required this.netValue,
  });

  static Future<StockTakeCommitChoice?> show(
    BuildContext context, {
    required int varianceLines,
    required double shortageQty,
    required double excessQty,
    required double netValue,
  }) {
    return showDialog<StockTakeCommitChoice>(
      context: context,
      builder: (_) => StockTakeCommitDialog(
        varianceLines: varianceLines,
        shortageQty: shortageQty,
        excessQty: excessQty,
        netValue: netValue,
      ),
    );
  }

  @override
  State<StockTakeCommitDialog> createState() => _StockTakeCommitDialogState();
}

class _StockTakeCommitDialogState extends State<StockTakeCommitDialog> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();

  /// Defaults to the honest answer: a count found a discrepancy, and unless the
  /// shop says otherwise that is a bookkeeping correction rather than a loss.
  StockAdjustmentReason _reason = StockAdjustmentReason.stockCount;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final note = _noteController.text.trim();
    Navigator.pop(
      context,
      StockTakeCommitChoice(
        reason: _reason,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booksLoss = _reason.isLoss && widget.shortageQty > 0;

    return AppDialogShell(
      title: 'Apply Count',
      subtitle: '${widget.varianceLines} line'
          '${widget.varianceLines == 1 ? '' : 's'} will adjust stock',
      accent: AppColors.primary,
      icon: Icons.playlist_add_check_rounded,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummary(context),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            _buildReasonDropdown(context),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            AppTextField(
              controller: _noteController,
              label: _reason.requiresNote ? 'Note' : 'Note (Optional)',
              hint: 'Added to every adjustment from this count',
              icon: Icons.notes_outlined,
              required: _reason.requiresNote,
              maxLines: 2,
              minLines: 2,
              validator: (v) {
                if (!_reason.requiresNote) return null;
                return (v == null || v.trim().isEmpty)
                    ? 'Required for this reason'
                    : null;
              },
            ),
            SizedBox(height: AppResponsive.smallSpacing(context)),
            _buildConsequence(context, booksLoss),
          ],
        ),
      ),
      actions: [
        appDialogCancelButton(context),
        const SizedBox(width: 12),
        appDialogPrimaryButton(label: 'Apply', onPressed: _submit),
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
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
          _stat(
            context,
            'Missing',
            '${widget.shortageQty}',
            widget.shortageQty > 0
                ? AppColors.danger
                : AppColors.textSecondary,
          ),
          _stat(
            context,
            'Extra',
            '${widget.excessQty}',
            widget.excessQty > 0 ? AppColors.success : AppColors.textSecondary,
          ),
          _stat(
            context,
            'Net Value',
            formatMoney(widget.netValue),
            widget.netValue < 0 ? AppColors.danger : AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _stat(
      BuildContext context, String label, String value, Color color) {
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
        labelText: 'Reason for variances *',
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
      items: StockAdjustmentReason.all
          .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
          .toList(),
      onChanged: (value) {
        if (value != null) setState(() => _reason = value);
      },
    );
  }

  /// States plainly what Apply is about to do, including that it cannot be
  /// undone — the adjustments become facts in the movement log.
  Widget _buildConsequence(BuildContext context, bool booksLoss) {
    final color = booksLoss ? AppColors.danger : AppColors.textSecondary;
    final text = booksLoss
        ? 'Shortages will be recorded as inventory losses, so their cost '
            'reaches your loss and profit reports. This cannot be undone — '
            'correct a mistake with a new stock take.'
        : 'Stock will be corrected without recording a loss. This cannot be '
            'undone — correct a mistake with a new stock take.';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            booksLoss
                ? Icons.trending_down_rounded
                : Icons.info_outline_rounded,
            size: AppResponsive.smallIconSize(context),
            color: color,
          ),
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
