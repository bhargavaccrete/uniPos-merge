import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import '../../../core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_model_211.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_model_213.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_item_model_214.dart';
import 'package:billberrylite/core/plan/plan_guard.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';

class MaterialReceivingScreen extends StatefulWidget {
  final PurchaseOrderModel purchaseOrder;

  const MaterialReceivingScreen({super.key, required this.purchaseOrder});

  @override
  State<MaterialReceivingScreen> createState() =>
      _MaterialReceivingScreenState();
}

class _MaterialReceivingScreenState extends State<MaterialReceivingScreen> {
  // Empty until reserved — see _loadPOItems. Generation writes a Hive counter,
  // so it can't run synchronously in initState.
  String _grnNumber = '';
  DateTime _receivedDate = DateTime.now();
  final TextEditingController _invoiceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final List<ReceivingItemData> _receivingItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPOItems();
  }

  Future<void> _loadPOItems() async {
    // Reserved alongside the item load — the screen already shows a spinner
    // until this finishes, so the number is in place before anything reads it.
    _grnNumber = await purchaseOrderStore.generateGRNNumber();

    await purchaseOrderStore.loadPOItems(widget.purchaseOrder.poId);

    // Prepare receiving items from PO items, accounting for already received qty
    final items = <ReceivingItemData>[];
    for (var poItem in purchaseOrderStore.currentPOItems) {
      final variant = await productStore.getVariantById(poItem.variantId);

      // Get already received quantity for this PO item
      final alreadyReceived = await purchaseOrderStore.getReceivedQtyForPOItem(
        poItem.poItemId,
      );
      final remainingQty = poItem.orderedQty - alreadyReceived;

      // Only add items that still have remaining quantity to receive
      if (remainingQty > 0) {
        items.add(
          ReceivingItemData(
            poItemId: poItem.poItemId,
            variantId: poItem.variantId,
            productId: poItem.productId,
            productName: poItem.productName ?? 'Unknown Product',
            variantInfo: poItem.variantInfo,
            orderedQty: remainingQty, // Show only remaining quantity
            receivedQty: remainingQty, // Default to full receipt of remaining
            damagedQty: 0,
            costPrice: poItem.estimatedPrice ?? variant?.costPrice ?? 0,
          ),
        );
      }
    }

    setState(() {
      _receivingItems.addAll(items);
      _isLoading = false;
    });
  }

  Future<void> _selectReceivedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _receivedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _receivedDate = picked;
      });
    }
  }

  void _showEditItemDialog(int index) {
    final item = _receivingItems[index];
    final receivedController = TextEditingController(
      text: item.receivedQty.toString(),
    );
    final damagedController = TextEditingController(
      text: item.damagedQty.toString(),
    );
    final priceController = TextEditingController(
      text: item.costPrice.toStringAsFixed(2),
    );
    DamagedHandling selectedHandling = item.damagedHandling;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => DialogDisposeScope(
        disposables: [receivedController, damagedController, priceController],
        child: MoneyScope(
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final received = int.tryParse(receivedController.text) ?? 0;
              final damaged = int.tryParse(damagedController.text) ?? 0;
              final accepted = received - damaged;
              final price = double.tryParse(priceController.text) ?? 0;
              final overDamaged = damaged > received;

              return AppDialogShell(
                title: item.productName,
                subtitle: item.variantInfo?.isNotEmpty == true
                    ? '${item.variantInfo} • Ordered ${item.orderedQty}'
                    : 'Ordered ${item.orderedQty}',
                accent: AppColors.primary,
                icon: Icons.inventory_2_outlined,
                body: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      controller: receivedController,
                      label: 'Received Quantity',
                      hint: 'Total physically received',
                      icon: Icons.local_shipping_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: damagedController,
                      label: 'Damaged Quantity',
                      hint: 'Received but unusable',
                      icon: Icons.report_gmailerrorred_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setDialogState(() {}),
                      // Surfaced inline as well as on save — the summary below
                      // would otherwise show a negative accepted count.
                      validator: (_) => overDamaged
                          ? 'Cannot exceed received quantity'
                          : null,
                    ),
                    if (damaged > 0) ...[
                      const SizedBox(height: 14),
                      Text(
                        'WHAT HAPPENS TO THE DAMAGED UNITS',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.captionFontSize(context),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Radio-style tiles instead of a dropdown: each option
                      // creates a different document, so the consequence is
                      // worth spelling out rather than hiding in a menu.
                      _handlingTile(
                        handling: DamagedHandling.returnToSupplier,
                        selected: selectedHandling,
                        label: 'Return to Supplier',
                        caption: 'Raises a purchase return',
                        color: AppColors.info,
                        onTap: (v) =>
                            setDialogState(() => selectedHandling = v),
                      ),
                      const SizedBox(height: 6),
                      _handlingTile(
                        handling: DamagedHandling.keepForClaim,
                        selected: selectedHandling,
                        label: 'Keep for Claim',
                        caption: 'Opens a supplier claim',
                        color: AppColors.warning,
                        onTap: (v) =>
                            setDialogState(() => selectedHandling = v),
                      ),
                      const SizedBox(height: 6),
                      _handlingTile(
                        handling: DamagedHandling.writeOff,
                        selected: selectedHandling,
                        label: 'Write Off as Loss',
                        caption: 'Records an inventory loss',
                        color: AppColors.danger,
                        onTap: (v) =>
                            setDialogState(() => selectedHandling = v),
                      ),
                    ],
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: priceController,
                      label: 'Cost Price per Unit',
                      icon: Icons.sell_outlined,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 16),
                    _editSummary(
                      accepted: accepted,
                      damaged: damaged,
                      price: price,
                      overDamaged: overDamaged,
                    ),
                  ],
                ),
                actions: [
                  appDialogCancelButton(dialogContext),
                  const SizedBox(width: 12),
                  appDialogPrimaryButton(
                    label: 'Save',
                    onPressed: () {
                      if (damaged > received) {
                        NotificationService.instance.showError(
                          'Damaged quantity cannot exceed received quantity',
                        );
                        return;
                      }

                      setState(() {
                        _receivingItems[index] = item.copyWith(
                          receivedQty: received,
                          damagedQty: damaged,
                          damagedHandling: damaged > 0
                              ? selectedHandling
                              : DamagedHandling.none,
                          costPrice: price,
                        );
                      });
                      Navigator.pop(dialogContext);
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// One damaged-handling choice. Selecting it is what decides whether a
  /// purchase return, a supplier claim or an inventory loss gets created when
  /// the GRN is confirmed.
  Widget _handlingTile({
    required DamagedHandling handling,
    required DamagedHandling selected,
    required String label,
    required String caption,
    required Color color,
    required ValueChanged<DamagedHandling> onTap,
  }) {
    final isSelected = selected == handling;

    return InkWell(
      onTap: () => onTap(handling),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.07)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 19,
              color: isSelected ? color : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : AppColors.textPrimary,
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

  Widget _editSummary({
    required int accepted,
    required int damaged,
    required double price,
    required bool overDamaged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: overDamaged
            ? AppColors.danger.withValues(alpha: 0.06)
            : AppColors.surfaceMedium,
        borderRadius: BorderRadius.circular(10),
        border: overDamaged
            ? Border.all(color: AppColors.danger.withValues(alpha: 0.4))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            overDamaged ? 'Check the quantities' : 'Summary',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: FontWeight.w600,
              color: overDamaged ? AppColors.danger : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _summaryLine(
            'Accepted (to stock)',
            '$accepted items',
            overDamaged ? AppColors.danger : AppColors.success,
          ),
          if (damaged > 0)
            _summaryLine(
              'Damaged',
              '$damaged items (${formatMoney(damaged * price)})',
              AppColors.danger,
            ),
          _summaryLine(
            'Stock Value',
            formatMoney((accepted < 0 ? 0 : accepted) * price),
            AppColors.info,
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndConfirmGRN() async {
    if (!PlanGuard.allowedOr(
      context,
      RetailEntKeys.purchaseReceive,
      featureName: 'Goods Receipt',
    )) {
      return;
    }
    // Validation
    final hasReceivedItems = _receivingItems.any(
      (item) => item.receivedQty > 0,
    );
    if (!hasReceivedItems) {
      NotificationService.instance.showError(
        'Please enter received quantities for at least one item',
      );
      return;
    }

    // Check if damaged handling is selected for items with damage
    final itemsWithUnhandledDamage = _receivingItems
        .where(
          (item) =>
              item.damagedQty > 0 &&
              item.damagedHandling == DamagedHandling.none,
        )
        .toList();

    if (itemsWithUnhandledDamage.isNotEmpty) {
      NotificationService.instance.showError(
        'Please select handling method for damaged items',
      );
      return;
    }

    // Calculate totals
    final totalOrdered = _receivingItems.fold<int>(
      0,
      (sum, item) => sum + item.orderedQty,
    );
    final totalReceived = _receivingItems.fold<int>(
      0,
      (sum, item) => sum + item.receivedQty,
    );
    final totalAccepted = _receivingItems.fold<int>(
      0,
      (sum, item) => sum + item.acceptedQty,
    );
    final totalDamaged = _receivingItems.fold<int>(
      0,
      (sum, item) => sum + item.damagedQty,
    );
    final totalAcceptedAmount = _receivingItems.fold<double>(
      0.0,
      (sum, item) => sum + item.acceptedAmount,
    );
    final totalDamagedAmount = _receivingItems.fold<double>(
      0.0,
      (sum, item) => sum + item.damagedAmount,
    );

    // Count items by handling method
    final returnToSupplierItems = _receivingItems
        .where(
          (item) => item.damagedHandling == DamagedHandling.returnToSupplier,
        )
        .toList();
    final keepForClaimItems = _receivingItems
        .where((item) => item.damagedHandling == DamagedHandling.keepForClaim)
        .toList();
    final writeOffItems = _receivingItems
        .where((item) => item.damagedHandling == DamagedHandling.writeOff)
        .toList();

    // Create GRN
    final grn = GRNModel.create(
      grnNumber: _grnNumber,
      poId: widget.purchaseOrder.poId,
      poNumber: widget.purchaseOrder.poNumber,
      supplierId: widget.purchaseOrder.supplierId,
      supplierName: widget.purchaseOrder.supplierName,
      receivedDate: _receivedDate.toIso8601String(),
      totalOrderedQty: totalOrdered,
      totalReceivedQty: totalReceived,
      totalAmount:
          totalAcceptedAmount, // Only accepted amount goes to stock value
      invoiceNumber: _invoiceController.text.isEmpty
          ? null
          : _invoiceController.text.trim(),
      notes: _notesController.text.isEmpty
          ? null
          : _notesController.text.trim(),
    );

    // Create GRN Items with acceptedQty and damagedHandling
    final grnItems = _receivingItems
        .where((item) => item.receivedQty > 0)
        .map(
          (item) => GRNItemModel.create(
            grnId: grn.grnId,
            poItemId: item.poItemId,
            variantId: item.variantId,
            productId: item.productId,
            productName: item.productName,
            variantInfo: item.variantInfo,
            orderedQty: item.orderedQty,
            receivedQty: item.receivedQty,
            acceptedQty: item.acceptedQty, // Only good items
            damagedQty: item.damagedQty > 0 ? item.damagedQty : null,
            damagedHandling: item.damagedQty > 0 ? item.damagedHandling : null,
            costPrice: item.costPrice,
          ),
        )
        .toList();

    // Show confirmation dialog with detailed breakdown
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => MoneyScope(
        child: AppDialogShell(
          title: 'Confirm Receipt',
          subtitle: '$_grnNumber • ${widget.purchaseOrder.poNumber}',
          accent: AppColors.primary,
          icon: Icons.fact_check_outlined,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _confirmSection(
                'Goes into stock',
                Icons.inventory_2_rounded,
                AppColors.success,
              ),
              _buildConfirmItem('$totalAccepted items added to inventory'),
              _buildConfirmItem(
                'Stock value ${formatMoney(totalAcceptedAmount)}',
              ),
              _buildConfirmItem(
                'Supplier billed ${formatMoney(totalAcceptedAmount)}',
              ),

              if (totalDamaged > 0) ...[
                const SizedBox(height: 14),
                _confirmSection(
                  'Damaged — never enters stock',
                  Icons.report_gmailerrorred_rounded,
                  AppColors.danger,
                ),
                _buildConfirmItem(
                  '$totalDamaged damaged (${formatMoney(totalDamagedAmount)}), not billed',
                  color: AppColors.danger,
                ),
                if (returnToSupplierItems.isNotEmpty)
                  _buildConfirmItem(
                    '${returnToSupplierItems.fold<int>(0, (s, i) => s + i.damagedQty)} → purchase return raised',
                    color: AppColors.info,
                  ),
                if (keepForClaimItems.isNotEmpty)
                  _buildConfirmItem(
                    '${keepForClaimItems.fold<int>(0, (s, i) => s + i.damagedQty)} → supplier claim opened',
                    color: AppColors.warning,
                  ),
                if (writeOffItems.isNotEmpty)
                  _buildConfirmItem(
                    '${writeOffItems.fold<int>(0, (s, i) => s + i.damagedQty)} → written off as loss',
                    color: AppColors.textSecondary,
                  ),
              ],

              if (totalReceived < totalOrdered) ...[
                const SizedBox(height: 14),
                _confirmSection(
                  'Still outstanding',
                  Icons.hourglass_top_rounded,
                  AppColors.warning,
                ),
                _buildConfirmItem(
                  '${totalOrdered - totalReceived} items not received — the order stays open',
                  color: AppColors.warning,
                ),
              ],

              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Confirming moves stock and updates the supplier balance. This cannot be undone.',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            appDialogCancelButton(dialogContext),
            const SizedBox(width: 12),
            appDialogPrimaryButton(
              label: 'Confirm & Update Stock',
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    // Save GRN
    await purchaseOrderStore.createGRN(grn, grnItems);

    // Confirm GRN (this updates PO status)
    final confirmedItems = await purchaseOrderStore.confirmGRN(grn.grnId);

    // Update stock for each item - ONLY acceptedQty goes to stock
    // Use goodQty as fallback for backward compatibility with old data
    for (var item in confirmedItems) {
      final qtyToAdd = item.acceptedQty > 0 ? item.acceptedQty : item.goodQty;
      if (qtyToAdd > 0) {
        final variant = await productStore.getVariantById(item.variantId);
        if (variant != null) {
          final newStock = variant.stockQty + qtyToAdd;
          await productStore.updateVariantStock(item.variantId, newStock);

          // Also update cost price if provided
          if (item.costPrice != null && item.costPrice! > 0) {
            await productStore.updateVariantCostPrice(
              item.variantId,
              item.costPrice!,
            );
          }
        }
      }
    }

    // Update supplier balance - only for accepted items value
    await supplierStore.updateSupplierBalance(
      widget.purchaseOrder.supplierId,
      totalAcceptedAmount,
    );

    // Turn the damaged-handling choices into real documents. Runs last and
    // never throws: stock and the supplier balance are already committed, so a
    // failure here must not make a confirmed GRN look failed.
    final damagedOutcome = await damagedGoodsStore.recordFromGRN(
      grn: grn,
      items: confirmedItems,
    );

    if (mounted) {
      Navigator.pop(context, true);

      String message = 'Added $totalAccepted items to stock';
      if (totalDamaged > 0) {
        message += ' ($totalDamaged damaged)';
      }
      if (!damagedOutcome.isEmpty) {
        message += ' • ${damagedOutcome.summary}';
      }

      NotificationService.instance.showSuccess(message);
    }
  }

  /// Heading above a group of confirmation lines.
  Widget _confirmSection(String label, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: AppResponsive.smallIconSize(context), color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmItem(String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5, left: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color ?? AppColors.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                height: 1.35,
                color: color ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Caps content width on large screens. Backgrounds still span edge to edge —
  /// only what you read is constrained.
  Widget _capped(BuildContext context, Widget child) {
    final maxWidth = AppResponsive.maxContentWidth(context);
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

  @override
  Widget build(BuildContext context) {
    final totalOrdered = _receivingItems.fold<int>(
      0,
      (sum, item) => sum + item.orderedQty,
    );
    final totalReceived = _receivingItems.fold<int>(
      0,
      (sum, item) => sum + item.receivedQty,
    );
    final totalAccepted = _receivingItems.fold<int>(
      0,
      (sum, item) => sum + item.acceptedQty,
    );
    final totalDamaged = _receivingItems.fold<int>(
      0,
      (sum, item) => sum + item.damagedQty,
    );
    final totalAcceptedAmount = _receivingItems.fold<double>(
      0.0,
      (sum, item) => sum + item.acceptedAmount,
    );
    final shortage = totalOrdered - totalReceived;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Material Receiving',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.subheadingFontSize(context),
                fontWeight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),
            Text(
              _grnNumber.isEmpty
                  ? widget.purchaseOrder.poNumber
                  : '$_grnNumber  •  ${widget.purchaseOrder.poNumber}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w500,
                color: AppColors.white.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _receivingItems.isEmpty
          ? Center(
              child: Padding(
                padding: AppResponsive.padding(context),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: AppResponsive.getValue(
                        context,
                        mobile: 80.0,
                        tablet: 92.0,
                        desktop: 104.0,
                      ),
                      color: Colors.green[300],
                    ),
                    SizedBox(height: AppResponsive.largeSpacing(context)),
                    Text(
                      'All items received!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppResponsive.subheadingFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: AppResponsive.smallSpacing(context)),
                    Text(
                      'No pending items to receive for this PO',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppResponsive.bodyFontSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: AppResponsive.extraLargeSpacing(context)),
                    SizedBox(
                      height: AppResponsive.buttonHeight(context),
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // Header Info
                Container(
                  color: Colors.white,
                  padding: AppResponsive.padding(context),
                  child: _capped(
                    context,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _grnNumber,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize:
                                          AppResponsive.subheadingFontSize(
                                            context,
                                          ),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'PO: ${widget.purchaseOrder.poNumber}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: AppResponsive.smallFontSize(
                                        context,
                                      ),
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _selectReceivedDate,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppResponsive.mediumSpacing(
                                    context,
                                  ),
                                  vertical: AppResponsive.smallSpacing(context),
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.divider),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: AppResponsive.smallIconSize(
                                        context,
                                      ),
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDate(_receivedDate),
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: AppResponsive.smallFontSize(
                                          context,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppResponsive.mediumSpacing(context)),
                        Row(
                          children: [
                            Icon(
                              Icons.storefront,
                              size: AppResponsive.smallIconSize(context),
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.purchaseOrder.supplierName ??
                                    'Unknown Supplier',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: AppResponsive.bodyFontSize(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppResponsive.mediumSpacing(context)),
                        AppTextField(
                          controller: _invoiceController,
                          label: 'Supplier Invoice Number (Optional)',
                          icon: Icons.receipt_long_outlined,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.next,
                        ),
                      ],
                    ),
                  ),
                ),

                // Summary
                Container(
                  color: Colors.white,
                  margin: EdgeInsets.only(
                    top: AppResponsive.smallSpacing(context),
                  ),
                  padding: AppResponsive.padding(context),
                  child: _capped(
                    context,
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryItem(
                                'Ordered',
                                totalOrdered.toString(),
                                AppColors.textSecondary,
                              ),
                            ),
                            Expanded(
                              child: _buildSummaryItem(
                                'Received',
                                totalReceived.toString(),
                                AppColors.success,
                              ),
                            ),
                            Expanded(
                              child: _buildSummaryItem(
                                'To Stock',
                                totalAccepted.toString(),
                                AppColors.info,
                              ),
                            ),
                            Expanded(
                              child: _buildSummaryItem(
                                'Damaged',
                                totalDamaged.toString(),
                                totalDamaged > 0
                                    ? AppColors.danger
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        if (totalDamaged > 0 || shortage > 0) ...[
                          SizedBox(
                            height: AppResponsive.mediumSpacing(context),
                          ),
                          Container(
                            padding: EdgeInsets.all(
                              AppResponsive.mediumSpacing(context),
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AppResponsive.smallBorderRadius(context),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: AppResponsive.smallIconSize(context),
                                  color: AppColors.warning,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    totalDamaged > 0 && shortage > 0
                                        ? '$totalDamaged damaged, $shortage not received'
                                        : totalDamaged > 0
                                        ? '$totalDamaged items damaged'
                                        : '$shortage items not received',
                                    style: TextStyle(
                                      fontSize: AppResponsive.smallFontSize(
                                        context,
                                      ),
                                      color: AppColors.orange,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formatMoney(totalAcceptedAmount),
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: AppResponsive.bodyFontSize(
                                      context,
                                    ),
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.info,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (totalDamaged == 0 && shortage == 0) ...[
                          SizedBox(height: AppResponsive.smallSpacing(context)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  'Stock Value: ${formatMoney(totalAcceptedAmount)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: AppResponsive.bodyFontSize(
                                      context,
                                    ),
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.info,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Items Header
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppResponsive.padding(context).left,
                    vertical: AppResponsive.mediumSpacing(context),
                  ),
                  child: _capped(
                    context,
                    Row(
                      children: [
                        Text(
                          'Items',
                          style: TextStyle(
                            fontSize: AppResponsive.subheadingFontSize(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Tap item to edit',
                          style: TextStyle(
                            fontSize: AppResponsive.smallFontSize(context),
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Items List
                Expanded(
                  child: _capped(
                    context,
                    ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppResponsive.padding(context).left,
                      ),
                      itemCount: _receivingItems.length,
                      itemBuilder: (context, index) {
                        return _buildReceivingItemCard(index);
                      },
                    ),
                  ),
                ),

                // Notes
                Container(
                  color: Colors.white,
                  padding: AppResponsive.padding(context),
                  child: _capped(
                    context,
                    AppTextField(
                      controller: _notesController,
                      label: 'Notes (Optional)',
                      hint: 'e.g., 5 shirts damaged during shipping',
                      icon: Icons.notes_rounded,
                      maxLines: 2,
                      minLines: 2,
                    ),
                  ),
                ),

                // Action Button
                Container(
                  color: Colors.white,
                  padding: AppResponsive.padding(context),
                  child: _capped(
                    context,
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveAndConfirmGRN,
                        icon: Icon(
                          Icons.check_circle,
                          size: AppResponsive.iconSize(context),
                        ),
                        label: const Text('Confirm Receipt & Update Stock'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: AppResponsive.largeSpacing(context),
                          ),
                          textStyle: TextStyle(
                            fontSize: AppResponsive.subheadingFontSize(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          style: TextStyle(
            fontSize: AppResponsive.subheadingFontSize(context),
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: AppResponsive.captionFontSize(context),
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildReceivingItemCard(int index) {
    final item = _receivingItems[index];
    final isShortage = item.receivedQty < item.orderedQty;
    final hasDamage = item.damagedQty > 0;

    final radius = AppResponsive.smallBorderRadius(context);

    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isShortage || hasDamage
              ? AppColors.warning
              : AppColors.divider,
          width: isShortage || hasDamage ? 1.5 : 0.5,
        ),
      ),
      child: InkWell(
        onTap: () => _showEditItemDialog(index),
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppResponsive.bodyFontSize(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.variantInfo != null)
                          Text(
                            item.variantInfo!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppResponsive.smallFontSize(context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.edit,
                    size: AppResponsive.smallIconSize(context),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              SizedBox(height: AppResponsive.mediumSpacing(context)),
              // Wrap, not Row+Spacer: three chips plus the amount need ~285px,
              // which overflows a 320px phone once padding is taken out. A
              // Spacer contributes zero when there's no slack, so it can't save
              // the row — the amount just ran off the edge.
              Wrap(
                spacing: AppResponsive.smallSpacing(context),
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildQtyChip(
                    'Ordered',
                    item.orderedQty,
                    AppColors.textSecondary,
                  ),
                  _buildQtyChip(
                    'Received',
                    item.receivedQty,
                    AppColors.success,
                  ),
                  if (hasDamage)
                    _buildQtyChip('Damaged', item.damagedQty, AppColors.danger),
                  Text(
                    formatMoney(item.receivedQty * item.costPrice),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              if (isShortage || hasDamage)
                Padding(
                  padding: EdgeInsets.only(
                    top: AppResponsive.smallSpacing(context),
                  ),
                  child: Wrap(
                    spacing: AppResponsive.smallSpacing(context),
                    runSpacing: 4,
                    children: [
                      if (isShortage)
                        Text(
                          'Shortage: ${item.orderedQty - item.receivedQty}',
                          style: TextStyle(
                            fontSize: AppResponsive.smallFontSize(context),
                            color: AppColors.warning,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (hasDamage &&
                          item.damagedHandling != DamagedHandling.none)
                        Text(
                          _getDamagedHandlingText(item.damagedHandling),
                          style: TextStyle(
                            fontSize: AppResponsive.smallFontSize(context),
                            color: _getDamagedHandlingColor(
                              item.damagedHandling,
                            ),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQtyChip(String label, int qty, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $qty',
        maxLines: 1,
        style: TextStyle(
          fontSize: AppResponsive.captionFontSize(context),
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  String _getDamagedHandlingText(DamagedHandling handling) {
    switch (handling) {
      case DamagedHandling.keepForClaim:
        return 'Keep for Claim';
      case DamagedHandling.returnToSupplier:
        return 'Return to Supplier';
      case DamagedHandling.writeOff:
        return 'Write Off';
      default:
        return '';
    }
  }

  Color _getDamagedHandlingColor(DamagedHandling handling) {
    switch (handling) {
      case DamagedHandling.keepForClaim:
        return AppColors.info;
      case DamagedHandling.returnToSupplier:
        return AppColors.warning;
      case DamagedHandling.writeOff:
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }
}

// Data class for receiving items
class ReceivingItemData {
  final String poItemId;
  final String variantId;
  final String productId;
  final String productName;
  final String? variantInfo;
  final int orderedQty;
  final int receivedQty;
  final int damagedQty;
  final DamagedHandling damagedHandling;
  final double costPrice;

  ReceivingItemData({
    required this.poItemId,
    required this.variantId,
    required this.productId,
    required this.productName,
    this.variantInfo,
    required this.orderedQty,
    required this.receivedQty,
    required this.damagedQty,
    this.damagedHandling = DamagedHandling.none,
    required this.costPrice,
  });

  /// Accepted quantity = received - damaged (only good items go to stock)
  int get acceptedQty => receivedQty - damagedQty;

  /// Amount for accepted items only
  double get acceptedAmount => acceptedQty * costPrice;

  /// Amount for damaged items (for claims/returns)
  double get damagedAmount => damagedQty * costPrice;

  ReceivingItemData copyWith({
    String? poItemId,
    String? variantId,
    String? productId,
    String? productName,
    String? variantInfo,
    int? orderedQty,
    int? receivedQty,
    int? damagedQty,
    DamagedHandling? damagedHandling,
    double? costPrice,
  }) {
    return ReceivingItemData(
      poItemId: poItemId ?? this.poItemId,
      variantId: variantId ?? this.variantId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      variantInfo: variantInfo ?? this.variantInfo,
      orderedQty: orderedQty ?? this.orderedQty,
      receivedQty: receivedQty ?? this.receivedQty,
      damagedQty: damagedQty ?? this.damagedQty,
      damagedHandling: damagedHandling ?? this.damagedHandling,
      costPrice: costPrice ?? this.costPrice,
    );
  }
}
