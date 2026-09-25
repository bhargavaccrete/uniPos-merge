import 'package:flutter/material.dart';
import 'package:billberrylite/core/config/tax_id_rule.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/core/config/phone_rule.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_model.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/row_action_button.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

/// Create or edit a restaurant Purchase Order — supplier,
/// expected delivery date, and a dynamic list of order lines (qty +
/// estimated price). See docs/inventory_recipe_system_plan.md §6.2.
///
/// Pass [purchaseOrder] to edit an existing order. Only DRAFT orders are ever
/// passed in — the store re-checks and refuses anything else.
class AddPurchaseOrderScreen extends StatefulWidget {
  final RestaurantPurchaseOrderModel? purchaseOrder;

  const AddPurchaseOrderScreen({super.key, this.purchaseOrder});

  @override
  State<AddPurchaseOrderScreen> createState() => _AddPurchaseOrderScreenState();
}

class _POLine {
  final Items item;
  final double qty;
  final double? price;

  _POLine({required this.item, required this.qty, this.price});
}

class _AddPurchaseOrderScreenState extends State<AddPurchaseOrderScreen> {
  RestaurantSupplierModel? _selectedSupplier;
  DateTime _expectedDeliveryDate = DateTime.now().add(const Duration(days: 3));
  final TextEditingController _notesController = TextEditingController();
  final List<_POLine> _lines = [];
  bool _saving = false;
  bool _loadingExisting = false;

  bool get isEditing => widget.purchaseOrder != null;

  @override
  void initState() {
    super.initState();
    // RestaurantSupplierStore never self-loads, so the picker would be empty
    // when this screen is reached without the Suppliers list having been
    // opened first. Cheap: a Hive read off an already-open box.
    restaurantSupplierStore.loadSuppliers();

    if (isEditing) {
      _loadingExisting = true;
      _loadExistingPO();
    }
  }

  /// Rebuilds the form from a saved PO. Nothing here writes to Hive — the
  /// original rows stay untouched until Save, so backing out is lossless.
  Future<void> _loadExistingPO() async {
    final po = widget.purchaseOrder!;

    await restaurantSupplierStore.loadSuppliers();
    final supplier = restaurantSupplierStore.suppliers
        .where((s) => s.supplierId == po.supplierId)
        .firstOrNull;

    // itemStore.loadItems() genuinely awaits a repository read, so items can
    // still be empty on a cold start. ensureLoaded is the sanctioned wait.
    await itemStore.ensureLoaded();

    final rows = restaurantPurchaseOrderItemRepository.getItemsByPOId(po.poId);
    final lines = <_POLine>[];
    final missing = <String>[];
    for (final row in rows) {
      final item = itemStore.getItemById(row.itemId);
      if (item == null) {
        // The item was deleted since the PO was written. Drop the line
        // rather than blocking the edit — the order must stay fixable — and
        // name it from the denormalized itemName, which is what that column is
        // for. Nothing is persisted until the user presses Save.
        missing.add(row.itemName ?? row.itemId);
        continue;
      }
      lines.add(
        _POLine(item: item, qty: row.orderedQty, price: row.estimatedPrice),
      );
    }

    if (!mounted) return;
    setState(() {
      _selectedSupplier = supplier;
      _expectedDeliveryDate =
          DateTime.tryParse(po.expectedDeliveryDate) ?? _expectedDeliveryDate;
      _notesController.text = po.notes ?? '';
      _lines
        ..clear()
        ..addAll(lines);
      _loadingExisting = false;
    });

    if (missing.isNotEmpty) {
      NotificationService.instance.showError(
        '${missing.length} line(s) removed — ${missing.join(', ')} no longer exist',
      );
    }
    if (supplier == null) {
      NotificationService.instance.showError(
        "This order's supplier no longer exists — pick a supplier before saving",
      );
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDeliveryDate() async {
    final now = DateTime.now();
    // An edited draft can carry a delivery date that has already passed, and
    // showDatePicker asserts when initialDate < firstDate. Widen the floor to
    // the loaded date instead of clamping it forward, so the picker opens on
    // the date the order actually holds rather than silently jumping to today.
    final first = _expectedDeliveryDate.isBefore(now) ? _expectedDeliveryDate : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedDeliveryDate,
      firstDate: first,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _expectedDeliveryDate = picked);
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _save() async {
    if (_selectedSupplier == null) {
      NotificationService.instance.showError('Please select a supplier');
      return;
    }
    if (_lines.isEmpty) {
      NotificationService.instance.showError(
        'Please add at least one item line',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final supplierId = _selectedSupplier!.supplierId;
      final supplierName = _selectedSupplier!.name;
      final deliveryDate = _expectedDeliveryDate.toIso8601String();
      final notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();
      final lines = [
        for (final line in _lines)
          (
            itemId: line.item.id,
            itemName: line.item.name,
            qty: line.qty,
            price: line.price,
          ),
      ];

      if (isEditing) {
        final updated = await restaurantPurchaseOrderStore.updatePurchaseOrder(
          poId: widget.purchaseOrder!.poId,
          supplierId: supplierId,
          supplierName: supplierName,
          expectedDeliveryDate: deliveryDate,
          notes: notes,
          lines: lines,
        );

        if (!mounted) return;
        if (updated == null) {
          // The order was sent or received from somewhere else while this form
          // was open. Stay put rather than popping as though it saved.
          NotificationService.instance.showError(
            'This purchase order can no longer be edited — it may have been sent or received',
          );
          return;
        }
        Navigator.pop(context, true);
        NotificationService.instance.showSuccess(
          'Purchase order ${updated.poNumber} updated',
        );
        return;
      }

      final po = await restaurantPurchaseOrderStore.createPurchaseOrder(
        supplierId: supplierId,
        supplierName: supplierName,
        expectedDeliveryDate: deliveryDate,
        notes: notes,
        lines: lines,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
      NotificationService.instance.showSuccess(
        'Purchase order ${po.poNumber} created',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSupplierPicker() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Observer(
        builder: (context) => AppDialogShell(
          title: 'Select Supplier',
          accent: AppColors.primary,
          icon: Icons.storefront_rounded,
          body: SizedBox(
            width: double.maxFinite,
            child: restaurantSupplierStore.suppliers.isEmpty
                ? const AppEmptyState(
                    dense: true,
                    icon: Icons.storefront_outlined,
                    title: 'No suppliers yet',
                    message: 'Tap Add New to create your first supplier.',
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: restaurantSupplierStore.suppliers.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (context, index) {
                      final supplier =
                          restaurantSupplierStore.suppliers[index];
                      final isSelected =
                          _selectedSupplier?.supplierId == supplier.supplierId;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.1,
                          ),
                          child: Text(
                            supplier.name.trim().isEmpty
                                ? '?'
                                : supplier.name.trim()[0].toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        title: Text(
                          supplier.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: supplier.phone?.isNotEmpty == true
                            ? Text(
                                supplier.phone!,
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.smallFontSize(
                                    context,
                                  ),
                                  color: AppColors.textSecondary,
                                ),
                              )
                            : null,
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primary,
                                size: 20,
                              )
                            : null,
                        onTap: () {
                          setState(() => _selectedSupplier = supplier);
                          Navigator.pop(dialogContext);
                        },
                      );
                    },
                  ),
          ),
          actions: [
            appDialogCancelButton(dialogContext, label: 'Close'),
            const SizedBox(width: 12),
            appDialogPrimaryButton(
              label: 'Add New',
              onPressed: () {
                Navigator.pop(dialogContext);
                _showAddSupplierSheet();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSupplierSheet() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final gstController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DialogDisposeScope(
        disposables: [
          nameController,
          phoneController,
          addressController,
          gstController,
        ],
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Add New Supplier',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.subheadingFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: nameController,
                    label: 'Name',
                    required: true,
                    icon: Icons.storefront_outlined,
                    textCapitalization: TextCapitalization.words,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: phoneController,
                    label: 'Phone',
                    hint: PhoneRule.hint,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    maxLength: PhoneRule.maxLength,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => PhoneRule.validate(v, required: false),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: addressController,
                    label: 'Address',
                    icon: Icons.location_on_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: gstController,
                    label: TaxIdRule.label,
                    hint: TaxIdRule.hint,
                    icon: Icons.badge_outlined,
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) {
                          NotificationService.instance.showError(
                            'Supplier name is required',
                          );
                          return;
                        }
                        final phone = phoneController.text.trim();
                        final phoneError = PhoneRule.validate(
                          phone,
                          required: false,
                        );
                        if (phoneError != null) {
                          NotificationService.instance.showError(phoneError);
                          return;
                        }

                        final supplier = await restaurantSupplierStore
                            .addSupplier(
                              name: name,
                              phone: phone.isEmpty ? null : phone,
                              address: addressController.text.trim().isEmpty
                                  ? null
                                  : addressController.text.trim(),
                              gstNumber: gstController.text.trim().isEmpty
                                  ? null
                                  : gstController.text.trim().toUpperCase(),
                            );

                        if (!mounted || !sheetContext.mounted) return;
                        setState(() => _selectedSupplier = supplier);
                        Navigator.pop(sheetContext);
                        NotificationService.instance.showSuccess(
                          '"${supplier.name}" added and selected',
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Add Supplier',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Opens the line sheet — appends when [index] is null, replaces that line
  /// in place otherwise.
  void _showLineSheet({int? index}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LineSheet(
        initial: index == null ? null : _lines[index],
        onSubmit: (line) => setState(() {
          if (index == null) {
            _lines.add(line);
          } else {
            _lines[index] = line;
          }
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalQty = _lines.fold<double>(0, (sum, l) => sum + l.qty);
    final estimatedTotal = _lines.fold<double>(
      0,
      (sum, l) => sum + (l.qty * (l.price ?? 0)),
    );

    return MoneyScope(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: buildPrimaryAppBar(
          title: isEditing ? 'Edit Purchase Order' : 'Create Purchase Order',
          actions: [
            TextButton(
              onPressed: (_saving || _loadingExisting) ? null : _save,
              child: Text(
                'Save',
                style: GoogleFonts.poppins(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        // While an existing PO is being read the form would otherwise render
        // "Select Supplier *" and "No lines added" for a frame, which reads as
        // data loss on an order that plainly has both.
        body: _loadingExisting
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.white,
                padding: AppResponsive.padding(context),
                child: AppResponsive.constrainedContent(
                  context: context,
                  maxWidth: AppResponsive.maxFormWidth(context),
                  heightFactor: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: _showSupplierPicker,
                        child: Container(
                          padding: EdgeInsets.all(
                            AppResponsive.mediumSpacing(context),
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.divider),
                            borderRadius: BorderRadius.circular(
                              AppResponsive.smallBorderRadius(context),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.storefront,
                                color: AppColors.textSecondary,
                                size: AppResponsive.iconSize(context),
                              ),
                              SizedBox(
                                width: AppResponsive.mediumSpacing(context),
                              ),
                              Expanded(
                                child: Text(
                                  _selectedSupplier?.name ??
                                      'Select Supplier *',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: AppResponsive.bodyFontSize(
                                      context,
                                    ),
                                    color: _selectedSupplier == null
                                        ? AppColors.textSecondary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_drop_down,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: AppResponsive.mediumSpacing(context)),
                      InkWell(
                        onTap: _pickDeliveryDate,
                        child: Container(
                          padding: EdgeInsets.all(
                            AppResponsive.mediumSpacing(context),
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.divider),
                            borderRadius: BorderRadius.circular(
                              AppResponsive.smallBorderRadius(context),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: AppColors.textSecondary,
                                size: AppResponsive.iconSize(context),
                              ),
                              SizedBox(
                                width: AppResponsive.mediumSpacing(context),
                              ),
                              Expanded(
                                child: Text(
                                  'Expected: ${_formatDate(_expectedDeliveryDate)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: AppResponsive.bodyFontSize(
                                      context,
                                    ),
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.edit,
                                color: AppColors.textSecondary,
                                size: AppResponsive.smallIconSize(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: AppResponsive.mediumSpacing(context)),
                      AppTextField(
                        controller: _notesController,
                        label: 'Notes (Optional)',
                        icon: Icons.notes,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.white,
                margin: EdgeInsets.only(
                  top: AppResponsive.smallSpacing(context),
                ),
                padding: AppResponsive.padding(context),
                child: AppResponsive.constrainedContent(
                  context: context,
                  maxWidth: AppResponsive.maxFormWidth(context),
                  heightFactor: 1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Qty',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.smallFontSize(context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            totalQty.toStringAsFixed(
                              totalQty.truncateToDouble() == totalQty ? 0 : 2,
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.subheadingFontSize(
                                context,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Estimated Total',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.smallFontSize(context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            estimatedTotal > 0
                                ? formatMoney(estimatedTotal)
                                : '--',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.subheadingFontSize(
                                context,
                              ),
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.white,
                margin: EdgeInsets.only(
                  top: AppResponsive.smallSpacing(context),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: AppResponsive.padding(context).left,
                  vertical: AppResponsive.mediumSpacing(context),
                ),
                child: AppResponsive.constrainedContent(
                  context: context,
                  maxWidth: AppResponsive.maxFormWidth(context),
                  heightFactor: 1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order Lines',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.subheadingFontSize(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${_lines.length} items',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _lines.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No lines added',
                      message: 'Tap the + button to add an item line.',
                    ),
                  )
                : SliverPadding(
                    padding: AppResponsive.padding(context),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => AppResponsive.constrainedContent(
                          context: context,
                          maxWidth: AppResponsive.maxFormWidth(context),
                          heightFactor: 1,
                          child: _buildLineCard(index),
                        ),
                        childCount: _lines.length,
                      ),
                    ),
                  ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showLineSheet(),
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildLineCard(int index) {
    final line = _lines[index];
    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.smallBorderRadius(context),
        ),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Padding(
        padding: AppResponsive.cardPadding(context),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: AppResponsive.smallSpacing(context)),
                  Wrap(
                    spacing: AppResponsive.mediumSpacing(context),
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Qty: ${formatQtyWithUnit(line.qty, line.item.unit)}',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            fontWeight: FontWeight.w600,
                            color: AppColors.info,
                          ),
                        ),
                      ),
                      if (line.price != null)
                        Text(
                          '@ ${formatMoney(line.price!)}',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (line.price != null)
                  Text(
                    formatMoney(line.qty * line.price!),
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                const SizedBox(height: 6),
                // Edit re-opens the same sheet pre-filled and replaces the line
                // in place, so changing a quantity no longer means deleting the
                // line and re-entering its price.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RowActionButton(
                      icon: Icons.edit_outlined,
                      color: AppColors.info,
                      tooltip: 'Edit line',
                      onTap: () => _showLineSheet(index: index),
                    ),
                    const SizedBox(width: 6),
                    RowActionButton(
                      icon: Icons.delete_outline,
                      color: AppColors.danger,
                      tooltip: 'Remove line',
                      onTap: () => setState(() => _lines.removeAt(index)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom-sheet to pick a purchasable item plus qty/estimated price for one
/// PO line — same interaction shape as the Extras/Toppings picker.
///
/// Serves add and edit both: pass [initial] to pre-fill it, and [onSubmit]
/// then carries the revised line back for the caller to put in place.
class _LineSheet extends StatefulWidget {
  final ValueChanged<_POLine> onSubmit;

  /// The line being edited, or null when adding a new one.
  final _POLine? initial;

  const _LineSheet({required this.onSubmit, this.initial});

  @override
  State<_LineSheet> createState() => _LineSheetState();
}

class _LineSheetState extends State<_LineSheet> {
  Items? _selectedItem;
  late final TextEditingController _qtyController;
  late final TextEditingController _priceController;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _selectedItem = initial?.item;
    // formatQty, not toString(): a whole quantity must seed the field as "10",
    // never "10.0", or every edit round-trips a decimal the user didn't type.
    _qtyController = TextEditingController(
      text: initial == null ? '1' : formatQty(initial.qty),
    );
    _priceController = TextEditingController(
      text: initial?.price == null ? '' : initial!.price!.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  /// What a supplier can actually deliver: Raw Materials **and** Finished
  /// Goods (a bottled drink is bought, not cooked). Both own physical stock,
  /// and `confirmGRN` has no product-type check of its own — it just calls
  /// `applyStockDelta`, which is correct for either.
  ///
  /// Excluded, deliberately:
  /// - **Recipe-Based** owns no stock at all (`resolvePhysicalStock` forces
  ///   `trackInventory: false, stockQuantity: 0`), so receiving one would
  ///   write a quantity nothing ever reads.
  /// - **Semi-Finished** is replenished by the Production flow, not GRN —
  ///   see `ProductType.semiFinished` and inventory_recipe_system_plan.md §6.3.
  ///   A product decision, not a technical limit; revisit if a shop needs to
  ///   buy prep it would normally make in-house.
  List<Items> get _purchasableItems => itemStore.items
      .where((i) => i.isRawMaterial || i.isFinishedGood)
      .toList();

  void _pickItem() async {
    final selected = await showDialog<Items>(
      context: context,
      builder: (_) => _PurchasableItemPickerDialog(items: _purchasableItems),
    );
    if (selected != null) {
      setState(() {
        _selectedItem = selected;
        if (_priceController.text.trim().isEmpty &&
            selected.lastPurchaseCost != null) {
          _priceController.text = selected.lastPurchaseCost!.toStringAsFixed(2);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                _isEditing ? 'Edit Line' : 'Add Item',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.subheadingFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _purchasableItems.isEmpty ? null : _pickItem,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    border: Border.all(
                      color: _selectedItem != null
                          ? AppColors.primary
                          : AppColors.divider,
                      width: _selectedItem != null ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.grain_outlined,
                        size: 20,
                        color: _selectedItem != null
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedItem?.name ??
                              (_purchasableItems.isEmpty
                                  ? 'No purchasable items found'
                                  : 'Select Item *'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(context),
                            fontWeight: _selectedItem != null
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: _selectedItem != null
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _qtyController,
                label: 'Quantity',
                required: true,
                icon: Icons.numbers_rounded,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _priceController,
                label: 'Estimated Price (per unit)',
                hint: 'Leave empty if unknown',
                icon: Icons.sell_outlined,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_selectedItem == null) {
                      NotificationService.instance.showError(
                        'Please select an item',
                      );
                      return;
                    }
                    final qty =
                        double.tryParse(_qtyController.text.trim()) ?? 0;
                    if (qty <= 0) {
                      NotificationService.instance.showError(
                        'Please enter a valid quantity',
                      );
                      return;
                    }
                    final priceText = _priceController.text.trim();
                    widget.onSubmit(
                      _POLine(
                        item: _selectedItem!,
                        qty: qty,
                        price: priceText.isEmpty
                            ? null
                            : double.tryParse(priceText),
                      ),
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    _isEditing ? 'Update Line' : 'Add Line',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple searchable list dialog over the items a supplier can deliver.
class _PurchasableItemPickerDialog extends StatefulWidget {
  final List<Items> items;

  const _PurchasableItemPickerDialog({required this.items});

  @override
  State<_PurchasableItemPickerDialog> createState() =>
      _PurchasableItemPickerDialogState();
}

class _PurchasableItemPickerDialogState
    extends State<_PurchasableItemPickerDialog> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.items
        : widget.items
              .where((i) => i.name.toLowerCase().contains(_query.toLowerCase()))
              .toList();

    return AppDialogShell(
      title: 'Select Item',
      accent: AppColors.primary,
      icon: Icons.grain_rounded,
      body: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.5,
        child: Column(
          children: [
            AppTextField(
              controller: _searchController,
              hint: 'Search items...',
              icon: Icons.search_rounded,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const AppEmptyState(
                      dense: true,
                      icon: Icons.search_off_rounded,
                      title: 'No items found',
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: AppResponsive.bodyFontSize(context),
                            ),
                          ),
                          // Type is named because two kinds now share this
                          // list — "Tomato Sauce" could be a bought jar or a
                          // prepped batch, and only the type tells them apart.
                          subtitle: Text(
                            '${ProductType.displayName(item.productType)}'
                            ' · Stock: '
                            '${formatQtyWithUnit(item.stockQuantity, item.unit)}',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.smallFontSize(context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [appDialogCancelButton(context, label: 'Close')],
    );
  }
}
