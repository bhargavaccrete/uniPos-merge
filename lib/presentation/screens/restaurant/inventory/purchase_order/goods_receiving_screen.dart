import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_model.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// One receiving line's editable state, seeded from the PO's ordered line.
class _ReceiveLine {
  final RestaurantPurchaseOrderItemModel poItem;
  double receivedQty;
  double damagedQty;
  double costPrice;

  _ReceiveLine({
    required this.poItem,
    required this.receivedQty,
    required this.damagedQty,
    required this.costPrice,
  });

  double get acceptedQty => (receivedQty - damagedQty).clamp(0.0, receivedQty);
}

/// Goods Receiving (GRN) screen for a restaurant Purchase Order — per-line
/// received/damaged/accepted qty + cost price, then confirms the GRN which
/// atomically moves stock (see `RestaurantPurchaseOrderStore.confirmGRN`).
/// See docs/inventory_recipe_system_plan.md §6.2.
class GoodsReceivingScreen extends StatefulWidget {
  final RestaurantPurchaseOrderModel purchaseOrder;

  const GoodsReceivingScreen({super.key, required this.purchaseOrder});

  @override
  State<GoodsReceivingScreen> createState() => _GoodsReceivingScreenState();
}

class _GoodsReceivingScreenState extends State<GoodsReceivingScreen> {
  bool _loading = true;
  bool _saving = false;
  final List<_ReceiveLine> _lines = [];
  DateTime _receivedDate = DateTime.now();
  final _invoiceController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLines();
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadLines() {
    final poItems = restaurantPurchaseOrderItemRepository
        .getItemsByPOId(widget.purchaseOrder.poId);

    final lines = <_ReceiveLine>[];
    for (final poItem in poItems) {
      final alreadyReceived =
          restaurantGrnItemRepository.getTotalReceivedQtyForPOItem(poItem.poItemId);
      final remainingQty = poItem.orderedQty - alreadyReceived;
      if (remainingQty <= 0) continue;

      lines.add(_ReceiveLine(
        poItem: poItem,
        receivedQty: remainingQty,
        damagedQty: 0,
        costPrice: poItem.estimatedPrice ?? 0,
      ));
    }

    setState(() {
      _lines.addAll(lines);
      _loading = false;
    });
  }

  Future<void> _pickReceivedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _receivedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _receivedDate = picked);
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  void _editLine(int index) {
    final line = _lines[index];
    final receivedController =
        TextEditingController(text: _fmt(line.receivedQty));
    final damagedController = TextEditingController(text: _fmt(line.damagedQty));
    final priceController = TextEditingController(text: line.costPrice.toStringAsFixed(2));

    showDialog<void>(
      context: context,
      builder: (dialogContext) => DialogDisposeScope(
        disposables: [receivedController, damagedController, priceController],
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            final received = double.tryParse(receivedController.text) ?? 0;
            final damaged = double.tryParse(damagedController.text) ?? 0;
            final accepted = (received - damaged).clamp(0.0, received);
            final overDamaged = damaged > received;

            return AppDialogShell(
              title: line.poItem.itemName ?? 'Unknown Item',
              subtitle: 'Ordered ${_fmt(line.poItem.orderedQty)}',
              accent: AppColors.primary,
              icon: Icons.inventory_2_outlined,
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    controller: receivedController,
                    label: 'Received Quantity',
                    icon: Icons.local_shipping_outlined,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: damagedController,
                    label: 'Damaged Quantity',
                    icon: Icons.report_gmailerrorred_outlined,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    onChanged: (_) => setDialogState(() {}),
                    validator: (_) =>
                        overDamaged ? 'Cannot exceed received quantity' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: priceController,
                    label: 'Cost Price per Unit',
                    icon: Icons.sell_outlined,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: overDamaged
                          ? AppColors.danger.withValues(alpha: 0.06)
                          : AppColors.surfaceMedium,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Accepted (to stock): ${_fmt(accepted)}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: overDamaged ? AppColors.danger : AppColors.success,
                      ),
                    ),
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
                          'Damaged quantity cannot exceed received quantity');
                      return;
                    }
                    setState(() {
                      line.receivedQty = received;
                      line.damagedQty = damaged;
                      line.costPrice = double.tryParse(priceController.text) ?? 0;
                    });
                    Navigator.pop(dialogContext);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _fmt(double v) =>
      v.truncateToDouble() == v ? v.toInt().toString() : v.toString();

  Future<void> _confirm() async {
    final hasReceived = _lines.any((l) => l.receivedQty > 0);
    if (!hasReceived) {
      NotificationService.instance
          .showError('Please enter received quantities for at least one item');
      return;
    }

    setState(() => _saving = true);
    try {
      await restaurantPurchaseOrderStore.confirmGRN(
        poId: widget.purchaseOrder.poId,
        poNumber: widget.purchaseOrder.poNumber,
        supplierId: widget.purchaseOrder.supplierId,
        supplierName: widget.purchaseOrder.supplierName,
        receivedDate: _receivedDate.toIso8601String(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        invoiceNumber: _invoiceController.text.trim().isEmpty
            ? null
            : _invoiceController.text.trim(),
        lines: [
          for (final line in _lines.where((l) => l.receivedQty > 0))
            (
              poItemId: line.poItem.poItemId,
              itemId: line.poItem.itemId,
              itemName: line.poItem.itemName ?? 'Unknown Item',
              orderedQty: line.poItem.orderedQty,
              receivedQty: line.receivedQty,
              acceptedQty: line.acceptedQty,
              damagedQty: line.damagedQty > 0 ? line.damagedQty : null,
              costPrice: line.costPrice > 0 ? line.costPrice : null,
            ),
        ],
      );

      if (!mounted) return;
      Navigator.pop(context, true);
      NotificationService.instance.showSuccess('Goods received and stock updated');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalOrdered =
        _lines.fold<double>(0, (sum, l) => sum + l.poItem.orderedQty);
    final totalReceived = _lines.fold<double>(0, (sum, l) => sum + l.receivedQty);
    final totalAccepted = _lines.fold<double>(0, (sum, l) => sum + l.acceptedQty);
    final totalDamaged = _lines.fold<double>(0, (sum, l) => sum + l.damagedQty);

    return MoneyScope(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: buildPrimaryAppBar(
          titleWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Goods Receiving',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              Text(widget.purchaseOrder.poNumber,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.white.withValues(alpha: 0.75))),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _lines.isEmpty
                ? const AppEmptyState(
                    icon: Icons.check_circle,
                    title: 'All items received!',
                    message: 'No pending items to receive for this PO.',
                  )
                : Column(
                    children: [
                      Container(
                        color: AppColors.white,
                        padding: AppResponsive.padding(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.storefront,
                                    size: AppResponsive.smallIconSize(context),
                                    color: AppColors.textSecondary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.purchaseOrder.supplierName ??
                                        'Unknown Supplier',
                                    style: TextStyle(
                                        fontSize:
                                            AppResponsive.bodyFontSize(context)),
                                  ),
                                ),
                                InkWell(
                                  onTap: _pickReceivedDate,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: AppColors.divider),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.calendar_today,
                                            size: 14, color: AppColors.textSecondary),
                                        const SizedBox(width: 6),
                                        Text(_formatDate(_receivedDate),
                                            style: const TextStyle(fontSize: 12)),
                                      ],
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
                            ),
                          ],
                        ),
                      ),
                      Container(
                        color: AppColors.white,
                        margin: EdgeInsets.only(
                            top: AppResponsive.smallSpacing(context)),
                        padding: AppResponsive.padding(context),
                        child: Row(
                          children: [
                            Expanded(
                                child: _summaryItem('Ordered', totalOrdered,
                                    AppColors.textSecondary)),
                            Expanded(
                                child: _summaryItem(
                                    'Received', totalReceived, AppColors.success)),
                            Expanded(
                                child: _summaryItem(
                                    'To Stock', totalAccepted, AppColors.info)),
                            Expanded(
                              child: _summaryItem(
                                'Damaged',
                                totalDamaged,
                                totalDamaged > 0
                                    ? AppColors.danger
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: AppResponsive.padding(context),
                          itemCount: _lines.length,
                          itemBuilder: (context, index) =>
                              _buildLineCard(index),
                        ),
                      ),
                      Container(
                        color: AppColors.white,
                        padding: AppResponsive.padding(context),
                        child: AppTextField(
                          controller: _notesController,
                          label: 'Notes (Optional)',
                          icon: Icons.notes_rounded,
                          maxLines: 2,
                          minLines: 2,
                        ),
                      ),
                      Container(
                        color: AppColors.white,
                        padding: AppResponsive.padding(context),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _confirm,
                            icon: const Icon(Icons.check_circle),
                            label: Text(
                                _saving ? 'Saving...' : 'Confirm Receipt & Update Stock'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                  vertical: AppResponsive.largeSpacing(context)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _summaryItem(String label, double value, Color color) {
    return Column(
      children: [
        Text(_fmt(value),
            style: TextStyle(
                fontSize: AppResponsive.subheadingFontSize(context),
                fontWeight: FontWeight.w600,
                color: color)),
        Text(label,
            style: TextStyle(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildLineCard(int index) {
    final line = _lines[index];
    final isShortage = line.receivedQty < line.poItem.orderedQty;
    final hasDamage = line.damagedQty > 0;
    final radius = AppResponsive.smallBorderRadius(context);

    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isShortage || hasDamage ? AppColors.warning : AppColors.divider,
          width: isShortage || hasDamage ? 1.5 : 0.5,
        ),
      ),
      child: InkWell(
        onTap: () => _editLine(index),
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      line.poItem.itemName ?? 'Unknown Item',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: AppResponsive.bodyFontSize(context),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.edit,
                      size: AppResponsive.smallIconSize(context),
                      color: AppColors.textSecondary),
                ],
              ),
              SizedBox(height: AppResponsive.mediumSpacing(context)),
              Wrap(
                spacing: AppResponsive.smallSpacing(context),
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _qtyChip('Ordered', line.poItem.orderedQty, AppColors.textSecondary),
                  _qtyChip('Received', line.receivedQty, AppColors.success),
                  if (hasDamage)
                    _qtyChip('Damaged', line.damagedQty, AppColors.danger),
                  Text(formatMoney(line.acceptedQty * line.costPrice),
                      style: TextStyle(
                          fontSize: AppResponsive.bodyFontSize(context),
                          fontWeight: FontWeight.w600,
                          color: AppColors.success)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qtyChip(String label, double qty, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('$label: ${_fmt(qty)}',
          style: TextStyle(
              fontSize: AppResponsive.captionFontSize(context),
              fontWeight: FontWeight.w500,
              color: color)),
    );
  }
}
