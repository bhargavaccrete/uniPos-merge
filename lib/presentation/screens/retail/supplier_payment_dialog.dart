import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/plan/plan_guard.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_ledger_entry_model_179.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_model_205.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Payment modes offered when paying a supplier. Plain strings rather than an
/// enum — they are stored verbatim on the ledger row and only ever displayed.
const _paymentModes = ['Cash', 'UPI', 'Bank', 'Cheque'];

/// Record a payment to a supplier, or post a correction.
///
/// Two modes on purpose. A **payment** is money that left the business and
/// carries a mode and a reference; an **adjustment** is a correction to a
/// balance that was wrong. Recording the second as the first would put fictional
/// money in the payment totals, so the Overview tab keeps them in separate
/// buckets and this dialog keeps them behind separate entry points.
///
/// Returns `true` when something was recorded.
Future<bool?> showSupplierPaymentDialog({
  required BuildContext context,
  required SupplierModel supplier,
  bool isAdjustment = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) =>
        _SupplierPaymentDialog(supplier: supplier, isAdjustment: isAdjustment),
  );
}

class _SupplierPaymentDialog extends StatefulWidget {
  final SupplierModel supplier;
  final bool isAdjustment;

  const _SupplierPaymentDialog({
    required this.supplier,
    required this.isAdjustment,
  });

  @override
  State<_SupplierPaymentDialog> createState() => _SupplierPaymentDialogState();
}

class _SupplierPaymentDialogState extends State<_SupplierPaymentDialog> {
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _noteController = TextEditingController();

  String _mode = _paymentModes.first;
  DateTime _date = DateTime.now();

  /// Adjustments only: does this correction increase or decrease what is owed?
  bool _increasesPayable = false;

  bool _saving = false;

  bool get _isAdjustment => widget.isAdjustment;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!PlanGuard.allowedOr(
      context,
      RetailEntKeys.suppliersEdit,
      featureName: _isAdjustment ? 'Balance Adjustment' : 'Supplier Payments',
    )) {
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      NotificationService.instance.showError('Please enter a valid amount');
      return;
    }

    // A payment always reduces what is owed. An adjustment can go either way,
    // which is why it asks.
    final signed = _isAdjustment
        ? (_increasesPayable ? amount : -amount)
        : -amount;

    final reference = _referenceController.text.trim();
    final note = _noteController.text.trim();

    setState(() => _saving = true);
    try {
      await supplierStore.recordBalanceMovement(
        supplierId: widget.supplier.supplierId,
        amount: signed,
        type: _isAdjustment
            ? SupplierLedgerType.adjustment
            : SupplierLedgerType.payment,
        description: _isAdjustment
            ? 'Balance adjustment'
            : 'Payment made ($_mode)',
        paymentMode: _isAdjustment ? null : _mode,
        referenceNo: reference.isEmpty ? null : reference,
        note: note.isEmpty ? null : note,
        date: _date.toIso8601String(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      NotificationService.instance.showError('Could not record: $e');
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, true);
    NotificationService.instance.showSuccess(
      _isAdjustment ? 'Adjustment posted' : 'Payment recorded',
    );
  }

  @override
  Widget build(BuildContext context) {
    final outstanding = widget.supplier.currentBalance;

    return DialogDisposeScope(
      disposables: [_amountController, _referenceController, _noteController],
      child: MoneyScope(
        child: AppDialogShell(
          title: _isAdjustment ? 'Post Adjustment' : 'Record Payment',
          subtitle: outstanding < 0
              ? '${widget.supplier.name} • ${formatMoney(outstanding.abs())} advance'
              : '${widget.supplier.name} • ${formatMoney(outstanding)} outstanding',
          accent: AppColors.primary,
          icon: _isAdjustment ? Icons.tune_rounded : Icons.payments_outlined,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: _amountController,
                label: 'Amount',
                required: true,
                icon: Icons.currency_rupee_rounded,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                autofocus: true,
              ),
              SizedBox(height: AppResponsive.mediumSpacing(context)),

              if (_isAdjustment) ...[
                _sectionLabel('DIRECTION'),
                SizedBox(height: AppResponsive.smallSpacing(context)),
                _choiceTile(
                  label: 'Reduce what we owe',
                  caption: 'The recorded balance was too high',
                  selected: !_increasesPayable,
                  onTap: () => setState(() => _increasesPayable = false),
                ),
                const SizedBox(height: 6),
                _choiceTile(
                  label: 'Increase what we owe',
                  caption: 'The recorded balance was too low',
                  selected: _increasesPayable,
                  onTap: () => setState(() => _increasesPayable = true),
                ),
              ] else ...[
                _sectionLabel('PAID BY'),
                SizedBox(height: AppResponsive.smallSpacing(context)),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final mode in _paymentModes)
                      _modeChip(mode, mode == _mode),
                  ],
                ),
              ],

              SizedBox(height: AppResponsive.mediumSpacing(context)),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(
                  AppResponsive.smallBorderRadius(context),
                ),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: AppResponsive.mediumSpacing(context),
                    vertical: AppResponsive.smallSpacing(context) + 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      AppResponsive.smallBorderRadius(context),
                    ),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: AppResponsive.smallIconSize(context),
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: AppResponsive.smallSpacing(context)),
                      Text(
                        DateFormat('dd MMM yyyy').format(_date),
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.smallFontSize(context),
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (!_isAdjustment) ...[
                SizedBox(height: AppResponsive.mediumSpacing(context)),
                AppTextField(
                  controller: _referenceController,
                  label: 'Reference No',
                  hint: 'UTR, cheque no, transaction id',
                  icon: Icons.confirmation_number_outlined,
                  textCapitalization: TextCapitalization.characters,
                ),
              ],

              SizedBox(height: AppResponsive.mediumSpacing(context)),
              AppTextField(
                controller: _noteController,
                label: 'Note',
                hint: _isAdjustment ? 'Why the balance was wrong' : 'Optional',
                icon: Icons.sticky_note_2_outlined,
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            appDialogCancelButton(context),
            SizedBox(width: AppResponsive.mediumSpacing(context)),
            appDialogPrimaryButton(
              label: _saving
                  ? 'Saving…'
                  : (_isAdjustment ? 'Post Adjustment' : 'Record Payment'),
              onPressed: _saving ? () {} : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: GoogleFonts.poppins(
      fontSize: AppResponsive.captionFontSize(context),
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: AppColors.textSecondary,
    ),
  );

  Widget _modeChip(String label, bool selected) {
    return InkWell(
      onTap: () => setState(() => _mode = label),
      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.mediumSpacing(context),
          vertical: AppResponsive.smallSpacing(context),
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(
            AppResponsive.borderRadius(context),
          ),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// Same radio-tile look the receiving screen uses for damaged handling — the
  /// choice changes what gets recorded, so it is spelled out rather than hidden
  /// in a dropdown.
  Widget _choiceTile({
    required String label,
    required String caption,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final radius = AppResponsive.smallBorderRadius(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.mediumSpacing(context),
          vertical: AppResponsive.smallSpacing(context),
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: AppResponsive.iconSize(context),
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            SizedBox(width: AppResponsive.smallSpacing(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    caption,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
