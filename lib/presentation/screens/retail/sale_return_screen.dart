import 'package:flutter/material.dart';
import 'package:billberrylite/util/common/quantity_format.dart';
import 'package:billberrylite/util/common/short_ref.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/presentation/widget/componets/retail/cart_quantity_field.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/plan/plan_enforcement.dart';
import '../../../core/plan/retail_entitlement_keys.dart';
import '../../../domain/services/retail/return_math.dart';
import '../../../domain/services/retail/return_service.dart';
import '../../../domain/services/retail/sale_return_reason.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/util/restaurant/staticswitch.dart';

class SaleReturnScreen extends StatefulWidget {
  final String saleId;

  const SaleReturnScreen({super.key, required this.saleId});

  @override
  State<SaleReturnScreen> createState() => _SaleReturnScreenState();
}

class _SaleReturnScreenState extends State<SaleReturnScreen> {
  final ReturnService _returnService = ReturnService();

  SaleModel? _sale;
  List<SaleItemModel> _saleItems = [];

  /// Units of each variant that may STILL be returned, after any earlier
  /// returns. Every quantity control on this screen is capped by it.
  Map<String, double> _remaining = {};

  bool _isLoading = true;
  bool _isProcessing = false;

  // For partial return
  final Map<String, double> _selectedItems = {}; // variantId -> quantity to return

  String _refundMethod = 'cash';
  String _returnType = 'full'; // full or partial

  /// Why the goods are coming back. Required — the Sales Refund report is only
  /// worth pulling if every row can answer it, so there is no sensible default.
  SaleReturnReason? _returnReason;
  final TextEditingController _returnNoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSaleData();
  }

  @override
  void dispose() {
    _returnNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadSaleData() async {
    setState(() => _isLoading = true);

    try {
      final sale = await saleStore.getSaleById(widget.saleId);
      final items = await saleStore.getItemsForSale(widget.saleId);
      final remaining = await _returnService.remainingReturnable(widget.saleId);

      setState(() {
        _sale = sale;
        _saleItems = items;
        _remaining = remaining;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        NotificationService.instance.showError('Error loading sale: $e');
      }
    }
  }

  double _remainingFor(SaleItemModel item) =>
      _remaining[item.varianteId] ?? 0;

  /// The catalogue variant behind a sale line, looked up synchronously for
  /// build-time decisions.
  VarianteModel? _variantFor(String variantId) {
    for (final v in productStore.variants) {
      if (v.varianteId == variantId) return v;
    }
    return null;
  }

  bool _isDecimalLine(SaleItemModel item) =>
      _variantFor(item.varianteId)?.isDecimalQuantity ?? false;

  /// The quantity a line starts at when it is ticked.
  ///
  /// Loose goods default to the WHOLE remaining amount: 1.75 L of milk was one
  /// purchase, so "1 of 1.75" is not a quantity anyone meant — and a whole-unit
  /// stepper could never reach 1.75 anyway. A piece line starts at 1, except
  /// when less than one unit is left (only reachable on a decimal line).
  double _defaultQtyFor(SaleItemModel item) {
    final remaining = _remainingFor(item);
    if (_isDecimalLine(item)) return remaining;
    return remaining < 1 ? remaining : 1;
  }

  /// Lines that still have something left to give back.
  List<SaleItemModel> get _returnableItems =>
      _saleItems.where((i) => _remainingFor(i) > 0).toList();

  /// True once an earlier return already took some of this sale.
  bool get _hasEarlierReturn =>
      _saleItems.any((i) => _remainingFor(i) < i.qty);

  /// What the current selection actually returns.
  ///
  /// A full return means everything STILL outstanding — not the original
  /// quantities, which would refund earlier returns a second time.
  Map<String, double> get _effectiveSelection {
    if (_returnType == 'full') {
      return {
        for (final item in _saleItems)
          if (_remainingFor(item) > 0) item.varianteId: _remainingFor(item),
      };
    }
    return _selectedItems;
  }

  /// The refund, computed by the SAME pure helper the service uses when it
  /// writes. Calling it here rather than repeating the arithmetic is what stops
  /// the figure shown to the cashier drifting from the figure actually paid.
  ReturnFigures get _figures {
    final sale = _sale;
    if (sale == null) return ReturnFigures.empty;
    return RetailReturnMath.compute(
      sale: sale,
      soldLines: _saleItems,
      returnQtyByVariantId: _effectiveSelection,
    );
  }

  /// How the refund splits when the original invoice is still unpaid: the due
  /// is written down first and only the excess leaves the till.
  ({double appliedToDue, double refunded}) get _split {
    final total = _figures.totalAmount;
    final due = _sale?.dueAmount ?? 0;
    if (due <= 0) return (appliedToDue: 0, refunded: total);
    final applied = total < due ? total : due;
    return (appliedToDue: applied, refunded: total - applied);
  }

  Future<void> _processReturn() async {
    if (_sale == null) return;

    // Plan gate — returns/refunds must be included in the plan (mirrors
    // restaurant `billing.returns`). No-op until a retail manifest is present.
    if (!PlanEnforce.allows(RetailEntKeys.billingReturns)) {
      NotificationService.instance.showError(
        'Returns aren’t included in your current plan.',
      );
      return;
    }

    final isFull = _returnType == 'full';

    if (_effectiveSelection.isEmpty) {
      NotificationService.instance.showError(
        isFull
            ? 'This sale has already been fully returned.'
            : 'Select at least one item to return.',
      );
      return;
    }

    if (_returnReason == null) {
      NotificationService.instance.showError('Select a return reason.');
      return;
    }

    if (_returnReason!.requiresNote &&
        _returnNoteController.text.trim().isEmpty) {
      NotificationService.instance.showError(
        'A note is required for that reason.',
      );
      return;
    }

    if (!AppSettings.refundsEnabled) {
      NotificationService.instance.showError('Refunds are disabled in Settings');
      return;
    }

    final windowMinutes = AppSettings.refundWindowMinutes;
    if (_sale != null && windowMinutes > 0) {
      final saleDate = DateTime.tryParse(_sale!.date);
      if (saleDate != null) {
        final elapsed = DateTime.now().difference(saleDate).inMinutes;
        if (elapsed > windowMinutes) {
          NotificationService.instance.showError('Refund window has passed for this sale');
          return;
        }
      }
    }

    final split = _split;

    // Spell out the credit offset. The cashier must not expect to hand over
    // cash that is being written off a debt instead.
    final message = split.appliedToDue > 0
        ? '${formatMoney(split.appliedToDue)} comes off the outstanding due'
              '${split.refunded > 0 ? ', and ${formatMoney(split.refunded)} is refunded via ${_refundMethod.toUpperCase()}' : ' — nothing is paid out'}. '
              'Stock goes back in. This cannot be undone.'
        : 'Refund ${formatMoney(split.refunded)} via '
              '${_refundMethod.toUpperCase()}. Stock goes back in. '
              'This cannot be undone.';

    final confirmed = await showAppConfirmDialog(
      context: context,
      title: isFull ? 'Return whole sale?' : 'Return selected items?',
      message: message,
      confirmLabel: 'Confirm Return',
      accent: AppColors.danger,
      icon: Icons.assignment_return_rounded,
    );

    if (!confirmed || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      String returnSaleId;

      if (_returnType == 'full') {
        returnSaleId = await _returnService.processFullReturn(
          originalSaleId: widget.saleId,
          refundMethod: _refundMethod,
          returnReason: _returnReason!.code,
          returnNote: _returnNote,
        );
      } else {
        if (_selectedItems.isEmpty) {
          throw Exception('Please select items to return');
        }

        returnSaleId = await _returnService.processPartialReturn(
          originalSaleId: widget.saleId,
          itemsToReturn: _selectedItems,
          refundMethod: _refundMethod,
          returnReason: _returnReason!.code,
          returnNote: _returnNote,
        );
      }

      if (mounted) {
        Navigator.pop(context, true); // Return to previous screen
        NotificationService.instance.showSuccess(
          'Return processed • ${saleRef(returnSaleId)}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      NotificationService.instance.showError('Error processing return: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Process Return',
        titleFontSize: AppResponsive.subheadingFontSize(context),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sale == null
          ? _buildErrorView()
          : SingleChildScrollView(
              child: _capped(
                context,
                Column(
                  children: [
                    _buildOriginalSaleCard(),
                    _buildReturnTypeSelector(),
                    _buildRefundMethodSelector(),
                    _buildReturnReasonSelector(),
                    if (_returnType == 'partial') _buildItemsList(),
                    _buildSummaryCard(),
                    SizedBox(height: AppResponsive.largeSpacing(context)),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _sale != null && !_isLoading
          ? _buildProcessButton()
          : null,
    );
  }

  /// Caps content width on large screens so this form doesn't stretch across a
  /// laptop. Applied once around the scrolling column.
  Widget _capped(BuildContext context, Widget child) {
    final maxWidth = AppResponsive.maxCardWidth(context);
    if (maxWidth == double.infinity) return child;
    return Align(
      // topCenter + heightFactor: without both, Align fills its constraints —
      // which made this eat the whole screen when used as a bottom bar.
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: AppResponsive.padding(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: AppResponsive.getValue(
                context,
                mobile: 64.0,
                tablet: 76.0,
                desktop: 88.0,
              ),
              color: Colors.red,
            ),
            SizedBox(height: AppResponsive.largeSpacing(context)),
            Text(
              'Sale not found or cannot be returned',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: AppResponsive.bodyFontSize(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOriginalSaleCard() {
    return Container(
      margin: AppResponsive.padding(context),
      padding: AppResponsive.padding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Original Sale',
            style: TextStyle(
              fontSize: AppResponsive.subheadingFontSize(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          _buildInfoRow('Sale ID', saleRef(_sale!.saleId)),
          _buildInfoRow('Total Items', '${_sale!.totalItems}'),
          _buildInfoRow('Total Amount', formatMoney(_sale!.totalAmount)),
          _buildInfoRow('Payment Type', _sale!.paymentType.toUpperCase()),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppResponsive.bodyFontSize(context),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: AppResponsive.bodyFontSize(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnTypeSelector() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppResponsive.padding(context).left,
      ),
      padding: AppResponsive.padding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Return Type',
            style: TextStyle(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          // Selectable tiles rather than RadioListTile — Flutter deprecated
          // Radio's groupValue/onChanged in favour of a RadioGroup ancestor,
          // and these match the tiles used in Material Receiving.
          Row(
            children: [
              Expanded(
                child: _returnTypeTile(
                  value: 'full',
                  label: 'Full Return',
                  // After an earlier return, "full" means everything still
                  // outstanding — say so rather than implying all items.
                  caption: _hasEarlierReturn
                      ? 'Return what is left'
                      : 'Return all items',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _returnTypeTile(
                  value: 'partial',
                  label: 'Partial Return',
                  caption: 'Select items',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _returnTypeTile({
    required String value,
    required String label,
    required String caption,
  }) {
    final selected = _returnType == value;

    return InkWell(
      onTap: () => setState(() {
        _returnType = value;
        // Switching back to a full return clears any partial picks, so the
        // refund total can't be computed from a stale selection.
        if (value == 'full') _selectedItems.clear();
      }),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.07)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
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
              size: 18,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
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

  Widget _buildRefundMethodSelector() {
    return Container(
      margin: AppResponsive.padding(context),
      padding: AppResponsive.padding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Refund Method',
            style: TextStyle(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('💵 Cash'),
                labelStyle: TextStyle(
                  fontSize: AppResponsive.bodyFontSize(context),
                ),
                selected: _refundMethod == 'cash',
                onSelected: (selected) =>
                    setState(() => _refundMethod = 'cash'),
              ),
              ChoiceChip(
                label: const Text('💳 Card'),
                labelStyle: TextStyle(
                  fontSize: AppResponsive.bodyFontSize(context),
                ),
                selected: _refundMethod == 'card',
                onSelected: (selected) =>
                    setState(() => _refundMethod = 'card'),
              ),
              ChoiceChip(
                label: const Text('📱 UPI'),
                labelStyle: TextStyle(
                  fontSize: AppResponsive.bodyFontSize(context),
                ),
                selected: _refundMethod == 'upi',
                onSelected: (selected) => setState(() => _refundMethod = 'upi'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Trimmed note, or null when blank — an empty string in Hive reads as
  /// "a note was given" everywhere downstream.
  String? get _returnNote {
    final text = _returnNoteController.text.trim();
    return text.isEmpty ? null : text;
  }

  Widget _buildReturnReasonSelector() {
    return Container(
      margin: AppResponsive.padding(context),
      padding: AppResponsive.padding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Return Reason',
            style: TextStyle(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final reason in SaleReturnReason.all)
                ChoiceChip(
                  label: Text(reason.label),
                  labelStyle: TextStyle(
                    fontSize: AppResponsive.bodyFontSize(context),
                  ),
                  selected: _returnReason?.code == reason.code,
                  onSelected: (_) => setState(() => _returnReason = reason),
                ),
            ],
          ),
          if (_returnReason?.requiresNote ?? false) ...[
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            AppTextField(
              controller: _returnNoteController,
              label: 'Note',
              hint: 'Why is this coming back?',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppResponsive.padding(context).left,
      ),
      padding: AppResponsive.padding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Items to Return',
            style: TextStyle(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          // Fully-returned lines are dropped rather than shown disabled: there
          // is nothing left to pick, and the "already returned" caption on the
          // remaining lines carries the history.
          ..._returnableItems.map((item) => _buildItemTile(item)),
        ],
      ),
    );
  }

  Widget _buildItemTile(SaleItemModel item) {
    final isSelected = _selectedItems.containsKey(item.varianteId);
    final remaining = _remainingFor(item);
    final alreadyReturned = item.qty - remaining;
    final isDecimal = _isDecimalLine(item);
    // Cap at what is left, never at the originally sold quantity — that is the
    // guard that stops the same units being refunded twice.
    //
    // NOT `.clamp(1, remaining)`: `num.clamp` throws when the lower limit
    // exceeds the upper one, so a part-returned loose line with 0.75 left
    // crashed this screen on build. Only an upper cap is needed.
    final storedQty = _selectedItems[item.varianteId] ?? _defaultQtyFor(item);
    final returnQty = storedQty > remaining ? remaining : storedQty;

    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
      padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.warning.withValues(alpha: 0.1)
            : AppColors.surfaceMedium,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.orange : AppColors.divider,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedItems[item.varianteId] = _defaultQtyFor(item);
                    } else {
                      _selectedItems.remove(item.varianteId);
                    }
                  });
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName ?? 'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (attributeStore
                        .describeAttributes(
                          item.attributes,
                          size: item.size,
                          color: item.color,
                          labelled: false,
                        )
                        .isNotEmpty)
                      Text(
                        attributeStore.describeAttributes(
                          item.attributes,
                          size: item.size,
                          color: item.color,
                          labelled: false,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppResponsive.smallFontSize(context),
                          color: AppColors.textSecondary,
                        ),
                      ),
                    // Say what is left, so a part-returned line explains itself
                    // rather than just refusing at a lower number.
                    if (alreadyReturned > 0)
                      Text(
                        '${formatQty(alreadyReturned)} of '
                        '${formatQty(item.qty)} already returned',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppResponsive.captionFontSize(context),
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                formatMoney(item.total),
                style: TextStyle(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (isSelected) ...[
            const Divider(height: 16),
            Row(
              children: [
                Text(
                  'Quantity: ',
                  style: TextStyle(
                    fontSize: AppResponsive.bodyFontSize(context),
                  ),
                ),
                if (isDecimal) ...[
                  // Typed, not stepped — a stepper cannot reach 1.75. Keyed by
                  // variant so a controller is never carried from one line onto
                  // another when the returnable list changes.
                  CartQuantityField(
                    key: ValueKey(item.varianteId),
                    qty: returnQty,
                    allowDecimal: true,
                    onSubmitted: (qty) async {
                      if (qty <= 0) {
                        // Zero means "not returning this line" — untick it
                        // rather than sending a zero-quantity return.
                        setState(() => _selectedItems.remove(item.varianteId));
                        return true;
                      }
                      if (qty > remaining) {
                        // Rejected: returning false snaps the field back to the
                        // truth instead of leaving an impossible figure on it.
                        NotificationService.instance.showWarning(
                          'Only ${formatQty(remaining)} left to return',
                        );
                        return false;
                      }
                      setState(() => _selectedItems[item.varianteId] = qty);
                      return true;
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'of ${formatQty(remaining)}',
                    style: TextStyle(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else ...[
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: returnQty > 1
                        ? () => setState(
                            () =>
                                _selectedItems[item.varianteId] = returnQty - 1,
                          )
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  Text(
                    '${formatQty(returnQty)} / ${formatQty(remaining)}',
                    style: TextStyle(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    // Compares the RESULT against the cap — `returnQty <
                    // remaining` let a line with 1.75 left step from 1 to 2.
                    onPressed: returnQty + 1 <= remaining
                        ? () => setState(
                            () =>
                                _selectedItems[item.varianteId] = returnQty + 1,
                          )
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final split = _split;
    // Headline the figure that actually leaves the till. On an unpaid invoice
    // most or all of the return writes down the debt instead.
    final returnAmount = split.refunded;

    return Container(
      margin: AppResponsive.padding(context),
      padding: AppResponsive.padding(context),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.red, AppColors.danger],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
      ),
      child: Column(
        children: [
          Text(
            split.appliedToDue > 0 ? 'Cash Back to Customer' : 'Refund Amount',
            style: TextStyle(
              color: Colors.white70,
              fontSize: AppResponsive.bodyFontSize(context),
            ),
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          // scaleDown so a large refund keeps one line at the display size.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatMoney(returnAmount),
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontSize: AppResponsive.getValue(
                  context,
                  mobile: 32.0,
                  tablet: 36.0,
                  desktop: 40.0,
                ),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (split.appliedToDue > 0) ...[
            SizedBox(height: AppResponsive.smallSpacing(context)),
            Text(
              '${formatMoney(_figures.totalAmount)} returned · '
              '${formatMoney(split.appliedToDue)} off the outstanding due',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: AppResponsive.smallFontSize(context),
              ),
            ),
          ],
          if (_returnType == 'partial') ...[
            SizedBox(height: AppResponsive.smallSpacing(context)),
            Text(
              '${formatQty(_effectiveSelection.values.fold(0.0, (sum, qty) => sum + qty))} items selected',
              maxLines: 1,
              style: TextStyle(
                color: Colors.white70,
                fontSize: AppResponsive.smallFontSize(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProcessButton() {
    return Container(
      padding: AppResponsive.padding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: _capped(
        context,
        ElevatedButton(
          onPressed: _isProcessing ? null : _processReturn,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              vertical: AppResponsive.largeSpacing(context),
            ),
            minimumSize: Size(
              double.infinity,
              AppResponsive.buttonHeight(context) + 2,
            ),
          ),
          child: _isProcessing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'Process Return',
                  style: TextStyle(
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
