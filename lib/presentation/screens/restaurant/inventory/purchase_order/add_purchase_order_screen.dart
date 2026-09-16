import 'package:flutter/material.dart';
import 'package:billberrylite/core/config/tax_id_rule.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/core/config/phone_rule.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_model.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Create a restaurant raw-material Purchase Order — supplier, expected
/// delivery date, and a dynamic list of Raw Material lines (qty + estimated
/// price). See docs/inventory_recipe_system_plan.md §6.2.
class AddPurchaseOrderScreen extends StatefulWidget {
  const AddPurchaseOrderScreen({super.key});

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

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDeliveryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedDeliveryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
        'Please add at least one raw material line',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final po = await restaurantPurchaseOrderStore.createPurchaseOrder(
        supplierId: _selectedSupplier!.supplierId,
        supplierName: _selectedSupplier!.name,
        expectedDeliveryDate: _expectedDeliveryDate.toIso8601String(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        lines: [
          for (final line in _lines)
            (
              itemId: line.item.id,
              itemName: line.item.name,
              qty: line.qty,
              price: line.price,
            ),
        ],
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
            child: restaurantPurchaseOrderStore.suppliers.isEmpty
                ? const AppEmptyState(
                    dense: true,
                    icon: Icons.storefront_outlined,
                    title: 'No suppliers yet',
                    message: 'Tap Add New to create your first supplier.',
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: restaurantPurchaseOrderStore.suppliers.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (context, index) {
                      final supplier =
                          restaurantPurchaseOrderStore.suppliers[index];
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

                        final supplier = await restaurantPurchaseOrderStore
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

  void _showAddLineSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _AddLineSheet(onAdd: (line) => setState(() => _lines.add(line))),
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
          title: 'Create Purchase Order',
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
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
        body: CustomScrollView(
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
                        'Raw Material Lines',
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
                      message: 'Tap the + button to add a raw material line.',
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
          onPressed: _showAddLineSheet,
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
                          'Qty: ${line.qty} ${line.item.unit ?? ''}',
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
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: AppColors.danger,
                    size: AppResponsive.iconSize(context),
                  ),
                  onPressed: () => setState(() => _lines.removeAt(index)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom-sheet to pick a Raw Material item plus qty/estimated price for one
/// PO line — same interaction shape as the Extras/Toppings picker.
class _AddLineSheet extends StatefulWidget {
  final ValueChanged<_POLine> onAdd;

  const _AddLineSheet({required this.onAdd});

  @override
  State<_AddLineSheet> createState() => _AddLineSheetState();
}

class _AddLineSheetState extends State<_AddLineSheet> {
  Items? _selectedItem;
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController();

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  List<Items> get _rawMaterials =>
      itemStore.items.where((i) => i.isRawMaterial).toList();

  void _pickItem() async {
    final selected = await showDialog<Items>(
      context: context,
      builder: (_) => _RawMaterialPickerDialog(items: _rawMaterials),
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
                'Add Raw Material',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.subheadingFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _rawMaterials.isEmpty ? null : _pickItem,
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
                              (_rawMaterials.isEmpty
                                  ? 'No Raw Material items found'
                                  : 'Select Raw Material *'),
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
                        'Please select a raw material',
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
                    widget.onAdd(
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
                    'Add Line',
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

/// Simple searchable list dialog limited to Raw Material items.
class _RawMaterialPickerDialog extends StatefulWidget {
  final List<Items> items;

  const _RawMaterialPickerDialog({required this.items});

  @override
  State<_RawMaterialPickerDialog> createState() =>
      _RawMaterialPickerDialogState();
}

class _RawMaterialPickerDialogState extends State<_RawMaterialPickerDialog> {
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
      title: 'Select Raw Material',
      accent: AppColors.primary,
      icon: Icons.grain_rounded,
      body: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.5,
        child: Column(
          children: [
            AppTextField(
              controller: _searchController,
              hint: 'Search raw materials...',
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
                      title: 'No raw materials found',
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
                          subtitle: Text(
                            'Stock: ${item.stockQuantity} ${item.unit ?? ''}',
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
