import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_ledger_entry_model.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/currency_helper.dart';

const _paymentModes = ['Cash', 'UPI', 'Bank', 'Cheque'];

/// Record a payment to a supplier, or a manual adjustment to their balance.
///
/// **This settles a payable — nothing else.** It must never touch the cash
/// drawer, POS payment totals, sales, EOD sales, tax, or P&L expense; the GRN
/// already recognised the purchase when the goods arrived. Retail's supplier
/// payment behaves identically, deliberately.
///
/// Returns true when something was recorded.
Future<bool?> showRestaurantSupplierPaymentDialog({
  required BuildContext context,
  required RestaurantSupplierModel supplier,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _RestaurantSupplierPaymentDialog(supplier: supplier),
  );
}

class _RestaurantSupplierPaymentDialog extends StatefulWidget {
  final RestaurantSupplierModel supplier;

  const _RestaurantSupplierPaymentDialog({required this.supplier});

  @override
  State<_RestaurantSupplierPaymentDialog> createState() =>
      _RestaurantSupplierPaymentDialogState();
}

class _RestaurantSupplierPaymentDialogState
    extends State<_RestaurantSupplierPaymentDialog> {
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _noteController = TextEditingController();

  String _mode = _paymentModes.first;
  DateTime _date = DateTime.now();
  bool _isAdjustment = false;

  /// Adjustments only: whether this correction increases what is owed.
  bool _increasesPayable = false;
  bool _saving = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      NotificationService.instance.showError('Please enter a valid amount');
      return;
    }

    setState(() => _saving = true);
    final navigator = Navigator.of(context);

    // Sign convention: positive owes the supplier more, negative owes less.
    // A payment always reduces the payable; an adjustment can go either way.
    final signed = _isAdjustment
        ? (_increasesPayable ? amount : -amount)
        : -amount;

    try {
      await restaurantSupplierStore.recordBalanceMovement(
        supplierId: widget.supplier.supplierId,
        amount: signed,
        type: _isAdjustment
            ? RestaurantSupplierLedgerType.adjustment
            : RestaurantSupplierLedgerType.payment,
        description: _isAdjustment
            ? 'Balance adjustment'
            : 'Payment to supplier',
        paymentMode: _isAdjustment ? null : _mode,
        referenceNo: _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        date: _date.toIso8601String(),
      );
      NotificationService.instance.showSuccess(
        _isAdjustment ? 'Adjustment recorded' : 'Payment recorded',
      );
      navigator.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        NotificationService.instance.showError('Could not record the entry');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final symbol = CurrencyHelper.currentSymbol;

    return DialogDisposeScope(
      disposables: [_amountController, _referenceController, _noteController],
      child: AppDialogShell(
        title: _isAdjustment ? 'Adjust Balance' : 'Record Payment',
        subtitle: widget.supplier.name,
        accent: _isAdjustment ? AppColors.orange : AppColors.success,
        icon: _isAdjustment
            ? Icons.tune_rounded
            : Icons.account_balance_wallet_rounded,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _outstandingRow(symbol),
            const SizedBox(height: 16),
            _paymentOrAdjustmentToggle(),
            const SizedBox(height: 16),
            AppTextField(
              controller: _amountController,
              label: 'Amount ($symbol)',
              icon: Icons.currency_rupee_rounded,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
            ),
            const SizedBox(height: 14),
            if (_isAdjustment) ...[
              _adjustmentDirection(),
              const SizedBox(height: 14),
            ] else ...[
              Text(
                'Payment mode',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mode in _paymentModes)
                    _choiceChip(
                      label: mode,
                      selected: _mode == mode,
                      onTap: () => setState(() => _mode = mode),
                    ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            _dateRow(),
            const SizedBox(height: 14),
            AppTextField(
              controller: _referenceController,
              label: 'Reference',
              hint: 'Cheque no., UTR, txn id (optional)',
              icon: Icons.tag_rounded,
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _noteController,
              label: 'Note',
              hint: 'Optional',
              icon: Icons.notes_rounded,
              maxLines: 2,
              minLines: 1,
            ),
          ],
        ),
        actions: [
          appDialogCancelButton(context),
          const SizedBox(width: 8),
          appDialogPrimaryButton(
            label: _saving ? 'Saving…' : 'Record',
            onPressed: _saving ? () {} : _save,
            color: _isAdjustment ? AppColors.orange : AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _outstandingRow(String symbol) {
    final balance = widget.supplier.currentBalance;
    final isAdvance = balance < 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            isAdvance ? 'Advance paid' : 'Currently owed',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            '$symbol${balance.abs().toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w600,
              color: isAdvance ? AppColors.info : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentOrAdjustmentToggle() {
    return Row(
      children: [
        Expanded(
          child: _segment(
            label: 'Payment',
            selected: !_isAdjustment,
            onTap: () => setState(() => _isAdjustment = false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _segment(
            label: 'Adjustment',
            selected: _isAdjustment,
            onTap: () => setState(() => _isAdjustment = true),
          ),
        ),
      ],
    );
  }

  Widget _adjustmentDirection() {
    return Row(
      children: [
        Expanded(
          child: _segment(
            label: 'Reduce payable',
            selected: !_increasesPayable,
            onTap: () => setState(() => _increasesPayable = false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _segment(
            label: 'Increase payable',
            selected: _increasesPayable,
            onTap: () => setState(() => _increasesPayable = true),
          ),
        ),
      ],
    );
  }

  Widget _dateRow() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Text(
              'Date',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              '${_date.day.toString().padLeft(2, '0')}/'
              '${_date.month.toString().padLeft(2, '0')}/${_date.year}',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _choiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
