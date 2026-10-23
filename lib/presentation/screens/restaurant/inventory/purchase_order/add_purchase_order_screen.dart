import 'package:flutter/material.dart';
import 'package:billberrylite/core/config/tax_id_rule.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/core/config/phone_rule.dart';
import 'package:billberrylite/core/constants/item_units.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_model.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/domain/services/restaurant/purchasable_item_rule.dart';
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

bool _hasRecipe(Items item) =>
    recipeRepository.getRecipeForItem(item.id)?.hasIngredients ?? false;

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

/// One order line, edited in place on its card.
class _POLine {
  final Items item;
  final TextEditingController qty;
  final TextEditingController price;

  // formatQty, not toString(): a whole quantity seeds as "10", never "10.0".
  _POLine(this.item, {double? qty, double? price})
      : qty = TextEditingController(text: qty == null ? '' : formatQty(qty)),
        price = TextEditingController(
          text: price == null ? '' : price.toStringAsFixed(2),
        );

  double get qtyValue => double.tryParse(qty.text.trim()) ?? 0;

  double? get priceValue {
    final t = price.text.trim();
    return t.isEmpty ? null : double.tryParse(t);
  }

  void dispose() {
    qty.dispose();
    price.dispose();
  }
}

/// The unit an item's quantity and price are in. No unit = pieces.
String _unitOf(Items item) => normalizeItemUnit(item.unit) ?? 'piece';

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
      lines.add(_POLine(item, qty: row.orderedQty, price: row.estimatedPrice));
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
    for (final line in _lines) {
      line.dispose();
    }
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
    final noQty = _lines.where((l) => l.qtyValue <= 0).toList();
    if (noQty.isNotEmpty) {
      NotificationService.instance.showError(
        'Enter a quantity for ${noQty.map((l) => l.item.name).join(', ')}',
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
            qty: line.qtyValue,
            price: line.priceValue,
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

  /// What a supplier can deliver — see [PurchasableItemRule]. `confirmGRN`
  /// has no product-type check of its own; this picker is the gate.
  List<Items> get _purchasableItems => itemStore.items
      .where((i) =>
          PurchasableItemRule.isPurchasable(i, hasRecipe: _hasRecipe(i)))
      .toList();

  /// Pick every item at once; each becomes a line whose quantity and price
  /// are then typed on its card. Price starts at the last purchase cost.
  Future<void> _addItems() async {
    final picked = await showDialog<List<Items>>(
      context: context,
      builder: (_) => _PurchasableItemPickerDialog(
        items: _purchasableItems,
        alreadyAdded: {for (final l in _lines) l.item.id},
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() {
      for (final item in picked) {
        _lines.add(_POLine(item, price: item.lastPurchaseCost));
      }
    });
  }

  void _removeLine(int index) {
    final line = _lines[index];
    setState(() => _lines.removeAt(index));
    // Its fields are still mounted this frame — dispose once they're gone.
    WidgetsBinding.instance.addPostFrameCallback((_) => line.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final totalQty = _lines.fold<double>(0, (sum, l) => sum + l.qtyValue);
    final estimatedTotal = _lines.fold<double>(
      0,
      (sum, l) => sum + (l.qtyValue * (l.priceValue ?? 0)),
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
                      title: 'No items yet',
                      message:
                          'Tap + to choose all the items to order, then enter '
                          'each quantity and price.',
                    ),
                  )
                : SliverPadding(
                    // Bottom inset clears the Add Items button.
                    padding: AppResponsive.padding(context).copyWith(
                      bottom: AppResponsive.padding(context).bottom + 80,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => AppResponsive.constrainedContent(
                          context: context,
                          maxWidth: AppResponsive.maxFormWidth(context),
                          heightFactor: 1,
                          // Keyed by item: removing a line must not hand its
                          // neighbour's fields to the wrong card.
                          child: KeyedSubtree(
                            key: ValueKey(_lines[index].item.id),
                            child: _buildLineCard(index),
                          ),
                        ),
                        childCount: _lines.length,
                      ),
                    ),
                  ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addItems,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          icon: const Icon(Icons.add),
          label: Text(
            'Add Items',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildLineCard(int index) {
    final line = _lines[index];
    final unit = _unitOf(line.item);
    final qty = line.qtyValue;
    final price = line.priceValue;
    final missingQty = qty <= 0;
    final numberFormat = [
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
    ];

    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.smallBorderRadius(context),
        ),
        border: Border.all(
          color: missingQty
              ? AppColors.warning.withValues(alpha: 0.6)
              : AppColors.divider,
          width: missingQty ? 1 : 0.5,
        ),
      ),
      child: Padding(
        padding: AppResponsive.cardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    line.item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!missingQty && price != null)
                  Text(
                    formatMoney(qty * price),
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                const SizedBox(width: 6),
                RowActionButton(
                  icon: Icons.delete_outline,
                  color: AppColors.danger,
                  tooltip: 'Remove line',
                  onTap: () => _removeLine(index),
                ),
              ],
            ),
            SizedBox(height: AppResponsive.smallSpacing(context)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    controller: line.qty,
                    label: 'Qty ($unit)',
                    hint: 'Enter qty',
                    required: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: numberFormat,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(width: AppResponsive.smallSpacing(context)),
                Expanded(
                  child: AppTextField(
                    controller: line.price,
                    label: 'Price / $unit',
                    hint: 'Optional',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: numberFormat,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Searchable multi-select over the items a supplier can deliver. Items
/// already on the order are shown as added and can't be picked again.
/// Pops the newly ticked items.
class _PurchasableItemPickerDialog extends StatefulWidget {
  final List<Items> items;
  final Set<String> alreadyAdded;

  const _PurchasableItemPickerDialog({
    required this.items,
    required this.alreadyAdded,
  });

  @override
  State<_PurchasableItemPickerDialog> createState() =>
      _PurchasableItemPickerDialogState();
}

class _PurchasableItemPickerDialogState
    extends State<_PurchasableItemPickerDialog> {
  final _searchController = TextEditingController();
  String _query = '';
  final Set<String> _ticked = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggle(Items item) => setState(() {
        if (!_ticked.remove(item.id)) _ticked.add(item.id);
      });

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.items
        : widget.items
              .where((i) => i.name.toLowerCase().contains(_query.toLowerCase()))
              .toList();

    return AppDialogShell(
      title: 'Select Items',
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
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? AppEmptyState(
                      dense: true,
                      icon: Icons.search_off_rounded,
                      title: widget.items.isEmpty
                          ? 'No purchasable items found'
                          : 'No items found',
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final added = widget.alreadyAdded.contains(item.id);
                        final typeLabel = PurchasableItemRule.isLegacyBoughtIn(
                                item,
                                hasRecipe: _hasRecipe(item))
                            ? PurchasableItemRule.legacyLabel
                            : ProductType.displayName(item.productType);
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AppColors.primary,
                          value: added || _ticked.contains(item.id),
                          onChanged: added ? null : (_) => _toggle(item),
                          title: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: AppResponsive.bodyFontSize(context),
                            ),
                          ),
                          // Type is named because several kinds share this
                          // list — "Tomato Sauce" could be a bought jar or a
                          // prepped batch, and only the type tells them apart.
                          subtitle: Text(
                            added
                                ? 'Added'
                                : '$typeLabel · Stock: '
                                    '${formatQtyWithUnit(item.stockQuantity, _unitOf(item))}',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.smallFontSize(context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        appDialogCancelButton(context),
        appDialogPrimaryButton(
          label: _ticked.isEmpty ? 'Add' : 'Add ${_ticked.length}',
          onPressed: () => Navigator.pop(context, [
            for (final i in widget.items)
              if (_ticked.contains(i.id)) i,
          ]),
        ),
      ],
    );
  }
}
