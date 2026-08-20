import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_return_item_model_175.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_return_model_174.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/screens/retail/purchase_return_list_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// A single purchase return: what went back, and where the supplier's credit
/// note stands.
///
/// No ledger actions here on purpose — damaged units were never billed, so
/// recording the credit note closes the paper trail without moving money. See
/// [DamagedGoodsStore] for why.
class PurchaseReturnDetailScreen extends StatefulWidget {
  final PurchaseReturnModel purchaseReturn;

  const PurchaseReturnDetailScreen({super.key, required this.purchaseReturn});

  @override
  State<PurchaseReturnDetailScreen> createState() =>
      _PurchaseReturnDetailScreenState();
}

class _PurchaseReturnDetailScreenState
    extends State<PurchaseReturnDetailScreen> {
  late PurchaseReturnModel _model;
  List<PurchaseReturnItemModel> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _model = widget.purchaseReturn;
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await damagedGoodsStore.getReturnItems(_model.returnId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    final date = DateTime.tryParse(iso);
    return date == null ? iso : DateFormat('dd MMM yyyy').format(date);
  }

  void _refreshFromStore() {
    final updated = damagedGoodsStore.purchaseReturns
        .where((r) => r.returnId == _model.returnId)
        .firstOrNull;
    if (updated != null) setState(() => _model = updated);
  }

  // ==================== CREDIT NOTE ====================

  Future<void> _recordCreditNote() async {
    final numberController = TextEditingController();
    final amountController = TextEditingController(
      text: _model.totalAmount > 0 ? _model.totalAmount.toStringAsFixed(2) : '',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => DialogDisposeScope(
        disposables: [numberController, amountController],
        child: MoneyScope(
          child: AppDialogShell(
            title: 'Record Credit Note',
            subtitle: _model.returnNumber,
            accent: AppColors.success,
            icon: Icons.receipt_long_rounded,
            body: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: numberController,
                  label: 'Credit Note Number',
                  required: true,
                  icon: Icons.confirmation_number_outlined,
                  textCapitalization: TextCapitalization.characters,
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: amountController,
                  label: 'Credit Amount',
                  icon: Icons.account_balance_wallet_outlined,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Recording a credit note closes the return. It does not change '
                  'the supplier balance — damaged units were never billed.',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              appDialogCancelButton(dialogContext),
              const SizedBox(width: 12),
              appDialogPrimaryButton(
                label: 'Save',
                color: AppColors.success,
                onPressed: () async {
                  final number = numberController.text.trim();
                  if (number.isEmpty) {
                    NotificationService.instance.showError(
                      'Credit note number is required',
                    );
                    return;
                  }

                  final ok = await damagedGoodsStore.recordCreditNote(
                    returnId: _model.returnId,
                    creditNoteNumber: number,
                    amount: double.tryParse(amountController.text.trim()),
                  );

                  if (!dialogContext.mounted) return;
                  if (!ok) {
                    NotificationService.instance.showError(
                      'Could not record the credit note',
                    );
                    return;
                  }

                  Navigator.pop(dialogContext);
                  _refreshFromStore();
                  NotificationService.instance.showSuccess(
                    'Credit note recorded',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelReturn() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Cancel ${_model.returnNumber}?',
      message:
          'The return stays on record as Cancelled and stops counting towards '
          'what has been sent back for its GRN.',
      confirmLabel: 'Cancel Return',
      cancelLabel: 'Keep',
      accent: AppColors.danger,
      icon: Icons.block,
    );
    if (!confirmed || !mounted) return;

    final ok = await damagedGoodsStore.cancelPurchaseReturn(_model.returnId);
    if (!mounted) return;

    if (!ok) {
      NotificationService.instance.showError(
        'Only a pending return can be cancelled',
      );
      return;
    }
    _refreshFromStore();
    NotificationService.instance.showSuccess('Return cancelled');
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: _model.returnNumber),
      body: MoneyScope(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppResponsive.padding(context).left,
                  AppResponsive.mediumSpacing(context),
                  AppResponsive.padding(context).left,
                  AppResponsive.largeSpacing(context),
                ),
                child: _capped(
                  context,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderCard(),
                      SizedBox(height: AppResponsive.largeSpacing(context)),
                      _buildSourceCard(),
                      SizedBox(height: AppResponsive.largeSpacing(context)),
                      _buildItemsCard(),
                      if (_model.creditNoteNumber != null) ...[
                        SizedBox(height: AppResponsive.largeSpacing(context)),
                        _buildCreditNoteCard(),
                      ],
                      SizedBox(
                        height: AppResponsive.extraLargeSpacing(context),
                      ),
                      _buildActions(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  /// Caps content width on large screens so a stack of detail cards doesn't
  /// stretch across a laptop.
  Widget _capped(BuildContext context, Widget child) {
    final maxWidth = AppResponsive.maxCardWidth(context);
    if (maxWidth == double.infinity) return child;
    return Align(
      // topCenter, not Center: Center aligns on BOTH axes, so a
      // shrink-wrapping child floats in the vertical middle.
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }

  Widget _buildHeaderCard() {
    final color = purchaseReturnStatusColor(_model.statusEnum);

    return Container(
      padding: AppResponsive.cardPadding(context),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _model.supplierName ?? 'Unknown supplier',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _model.statusDisplay,
                  maxLines: 1,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          // Expanded thirds, not fixed 24px gaps — "Value ₹12,345.00" plus a
          // date needed more than a 320px phone had, and the Row overflowed.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _headerStat('Quantity', '${_model.totalQty}')),
              Expanded(
                child: _headerStat('Value', formatMoney(_model.totalAmount)),
              ),
              Expanded(
                child: _headerStat('Raised', _formatDate(_model.returnDate)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.captionFontSize(context),
            color: AppColors.white.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSourceCard() {
    return _card(
      title: 'Source Documents',
      icon: Icons.link_rounded,
      children: [
        _row('Purchase Order', _model.poNumber),
        _row('GRN', _model.grnNumber),
        _row('Supplier', _model.supplierName ?? '—'),
        if (_model.notes?.isNotEmpty ?? false) _row('Notes', _model.notes!),
      ],
    );
  }

  Widget _buildItemsCard() {
    return _card(
      title: 'Returned Items',
      icon: Icons.inventory_2_outlined,
      children: [
        if (_items.isEmpty)
          Text(
            'No line items recorded.',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
        for (final item in _items)
          Padding(
            padding: EdgeInsets.only(
              bottom: AppResponsive.smallSpacing(context),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName ?? 'Unknown product',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.smallFontSize(context),
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (item.variantInfo?.isNotEmpty ?? false)
                        Text(
                          item.variantInfo!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.captionFontSize(context),
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${item.returnedQty} pcs',
                      maxLines: 1,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (item.totalAmount != null)
                      Text(
                        formatMoney(item.totalAmount!),
                        maxLines: 1,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.captionFontSize(context),
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCreditNoteCard() {
    return _card(
      title: 'Supplier Credit Note',
      icon: Icons.verified_outlined,
      iconColor: AppColors.success,
      children: [
        _row('Number', _model.creditNoteNumber ?? '—'),
        _row('Date', _formatDate(_model.creditNoteDate)),
        _row(
          'Amount',
          _model.creditNoteAmount != null
              ? formatMoney(_model.creditNoteAmount!)
              : '—',
        ),
      ],
    );
  }

  Widget _buildActions() {
    // Only a pending return can move — a cancelled or credited one is closed.
    if (!_model.isOpen) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
        decoration: BoxDecoration(
          color: AppColors.surfaceMedium,
          borderRadius: BorderRadius.circular(
            AppResponsive.smallBorderRadius(context),
          ),
        ),
        child: Text(
          'This return is ${_model.statusDisplay.toLowerCase()} — no further action available.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    final btnRadius = BorderRadius.circular(
      AppResponsive.smallBorderRadius(context),
    );
    final btnPad = EdgeInsets.symmetric(
      vertical: AppResponsive.getValue(
        context,
        mobile: 13.0,
        tablet: 15.0,
        desktop: 17.0,
      ),
    );

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _cancelReturn,
            icon: Icon(Icons.block, size: AppResponsive.smallIconSize(context)),
            label: Text(
              'Cancel',
              maxLines: 1,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              padding: btnPad,
              shape: RoundedRectangleBorder(borderRadius: btnRadius),
            ),
          ),
        ),
        SizedBox(width: AppResponsive.mediumSpacing(context)),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _recordCreditNote,
            icon: Icon(
              Icons.receipt_long_rounded,
              size: AppResponsive.smallIconSize(context),
            ),
            label: Text(
              'Record Credit Note',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.white,
              elevation: 0,
              padding: btnPad,
              shape: RoundedRectangleBorder(borderRadius: btnRadius),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== SHARED BITS ====================

  Widget _card({
    required String title,
    required IconData icon,
    Color? iconColor,
    required List<Widget> children,
  }) {
    final side = AppResponsive.padding(context).left;
    final vGap = AppResponsive.mediumSpacing(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(side, vGap, side, vGap),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: AppResponsive.iconSize(context),
                  color: iconColor ?? AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: EdgeInsets.fromLTRB(side, vGap, side, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Capped label column: wide enough for the longest label, but it stops
          // growing on a laptop so every extra pixel goes to the value.
          SizedBox(
            width: AppResponsive.getValue(
              context,
              mobile: 110.0,
              tablet: 130.0,
              desktop: 150.0,
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
