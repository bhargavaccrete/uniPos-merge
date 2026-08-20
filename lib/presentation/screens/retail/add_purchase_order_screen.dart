import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:billberrylite/core/config/phone_rule.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../../core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_model_211.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_item_model_212.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_model_205.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/core/plan/plan_guard.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';

class AddPurchaseOrderScreen extends StatefulWidget {
  final PurchaseOrderModel? purchaseOrder;

  const AddPurchaseOrderScreen({super.key, this.purchaseOrder});

  @override
  State<AddPurchaseOrderScreen> createState() => _AddPurchaseOrderScreenState();
}

class _AddPurchaseOrderScreenState extends State<AddPurchaseOrderScreen> {
  SupplierModel? _selectedSupplier;
  DateTime _expectedDeliveryDate = DateTime.now().add(const Duration(days: 7));
  final TextEditingController _notesController = TextEditingController();
  final List<POItemData> _orderItems = [];
  // Empty until the number is reserved — generation now writes a counter to
  // Hive, so it can't run synchronously in initState.
  String _poNumber = '';

  bool get isEditing => widget.purchaseOrder != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadPOData();
    } else {
      _reservePONumber();
    }
  }

  Future<void> _reservePONumber() async {
    final number = await purchaseOrderStore.generatePONumber();
    if (mounted) setState(() => _poNumber = number);
  }

  Future<void> _loadPOData() async {
    if (widget.purchaseOrder == null) return;

    final po = widget.purchaseOrder!;
    _poNumber = po.poNumber;
    _expectedDeliveryDate = DateTime.parse(po.expectedDeliveryDate);
    _notesController.text = po.notes ?? '';

    // Find supplier
    _selectedSupplier = supplierStore.suppliers
        .where((s) => s.supplierId == po.supplierId)
        .firstOrNull;

    // Load items
    await purchaseOrderStore.loadPOItems(po.poId);
    final items = purchaseOrderStore.currentPOItems;

    final loadedItems = <POItemData>[];
    for (var item in items) {
      final variant = await productStore.getVariantById(item.variantId);
      if (variant != null) {
        loadedItems.add(
          POItemData(
            variant: variant,
            orderedQty: item.orderedQty,
            estimatedPrice: item.estimatedPrice,
            poItemId: item.poItemId,
          ),
        );
      }
    }

    setState(() {
      _orderItems.clear();
      _orderItems.addAll(loadedItems);
    });
  }

  Future<void> _selectDeliveryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedDeliveryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _expectedDeliveryDate = picked;
      });
    }
  }

  Future<void> _savePO() async {
    if (!PlanGuard.allowedOr(
      context,
      RetailEntKeys.purchaseCreate,
      featureName: 'Purchase Orders',
    )) {
      return;
    }
    if (_selectedSupplier == null) {
      NotificationService.instance.showError('Please select a supplier');
      return;
    }

    if (_orderItems.isEmpty) {
      NotificationService.instance.showError('Please add at least one item');
      return;
    }

    final po = isEditing
        ? widget.purchaseOrder!.copyWith(
            supplierId: _selectedSupplier!.supplierId,
            supplierName: _selectedSupplier!.name,
            expectedDeliveryDate: _expectedDeliveryDate.toIso8601String(),
            notes: _notesController.text.isEmpty ? null : _notesController.text,
          )
        : PurchaseOrderModel.create(
            poNumber: _poNumber,
            supplierId: _selectedSupplier!.supplierId,
            supplierName: _selectedSupplier!.name,
            expectedDeliveryDate: _expectedDeliveryDate.toIso8601String(),
            notes: _notesController.text.isEmpty ? null : _notesController.text,
          );

    final items = _orderItems
        .map(
          (item) => PurchaseOrderItemModel.create(
            poId: po.poId,
            variantId: item.variant.varianteId,
            productId: item.variant.productId,
            productName: productStore
                .getProductById(item.variant.productId)
                ?.productName,
            variantInfo: _getVariantDescription(item.variant),
            orderedQty: item.orderedQty,
            estimatedPrice: item.estimatedPrice,
          ),
        )
        .toList();

    if (isEditing) {
      await purchaseOrderStore.updatePurchaseOrder(po, items);
    } else {
      await purchaseOrderStore.addPurchaseOrder(po, items);
    }

    if (mounted) {
      Navigator.pop(context, true);
      NotificationService.instance.showSuccess(
        isEditing ? 'Purchase Order updated' : 'Purchase Order created',
      );
    }
  }

  void _showSupplierSelection() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialogShell(
        title: 'Select Supplier',
        accent: AppColors.primary,
        icon: Icons.storefront_rounded,
        body: SizedBox(
          width: double.maxFinite,
          child: Observer(
            builder: (context) {
              final suppliers = supplierStore.suppliers;

              if (suppliers.isEmpty) {
                // No CTA here on purpose — the footer's 'Add New' is the one
                // way to create a supplier from this dialog.
                return const AppEmptyState(
                  dense: true,
                  icon: Icons.storefront_outlined,
                  title: 'No suppliers yet',
                  message: 'Tap Add New to create your first supplier.',
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                itemCount: suppliers.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppColors.divider),
                itemBuilder: (context, index) {
                  final supplier = suppliers[index];
                  final isSelected =
                      _selectedSupplier?.supplierId == supplier.supplierId;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
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
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: supplier.phone?.isNotEmpty == true
                        ? Text(
                            supplier.phone!,
                            maxLines: 1,
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.captionFontSize(context),
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
              _showAddSupplierDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showAddSupplierDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final gstController = TextEditingController();
    final openingBalanceController = TextEditingController(text: '0');

    showDialog<void>(
      context: context,
      builder: (dialogContext) => DialogDisposeScope(
        disposables: [
          nameController,
          phoneController,
          addressController,
          gstController,
          openingBalanceController,
        ],
        child: MoneyScope(
          child: AppDialogShell(
            title: 'Add Supplier',
            subtitle: 'Selected automatically once saved',
            accent: AppColors.primary,
            icon: Icons.storefront_rounded,
            body: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  label: 'GST Number',
                  hint: 'e.g. 22AAAAA0000A1Z5',
                  icon: Icons.badge_outlined,
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: openingBalanceController,
                  label: 'Opening Balance',
                  hint: 'Amount already owed to this supplier',
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
              ],
            ),
            actions: [
              appDialogCancelButton(dialogContext),
              const SizedBox(width: 12),
              appDialogPrimaryButton(
                label: 'Add Supplier',
                onPressed: () async {
                  // Validate the TRIMMED name — the same whitespace-only trap
                  // the supplier list screen had.
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    NotificationService.instance.showError(
                      'Supplier name is required',
                    );
                    return;
                  }

                  final phone = phoneController.text.trim();
                  final phoneError = PhoneRule.validate(phone, required: false);
                  if (phoneError != null) {
                    NotificationService.instance.showError(phoneError);
                    return;
                  }

                  final address = addressController.text.trim();
                  final gst = gstController.text.trim();
                  final openingBalance =
                      double.tryParse(openingBalanceController.text.trim()) ??
                      0;

                  final newSupplier = SupplierModel.create(
                    name: name,
                    phone: phone.isEmpty ? null : phone,
                    address: address.isEmpty ? null : address,
                    gstNumber: gst.isEmpty ? null : gst.toUpperCase(),
                    openingBalance: openingBalance,
                    currentBalance: openingBalance,
                  );

                  try {
                    await supplierStore.addSupplier(newSupplier);
                  } catch (e) {
                    if (!mounted) return;
                    NotificationService.instance.showError(
                      'Failed to add supplier: $e',
                    );
                    return;
                  }

                  if (!mounted || !dialogContext.mounted) return;

                  setState(() => _selectedSupplier = newSupplier);
                  Navigator.pop(dialogContext);
                  NotificationService.instance.showSuccess(
                    '"${newSupplier.name}" added and selected',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddPOItemDialog(
        onAdd: (item) {
          setState(() {
            _orderItems.add(item);
          });
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _orderItems.removeAt(index);
    });
  }

  void _editItemQty(int index) {
    final item = _orderItems[index];
    final controller = TextEditingController(text: item.orderedQty.toString());

    showDialog<void>(
      context: context,
      builder: (dialogContext) => DialogDisposeScope(
        disposables: [controller],
        child: AppDialogShell(
          title: 'Edit Quantity',
          subtitle:
              productStore
                  .getProductById(item.variant.productId)
                  ?.productName ??
              _getVariantDescription(item.variant),
          accent: AppColors.primary,
          icon: Icons.numbers_rounded,
          body: AppTextField(
            controller: controller,
            label: 'Quantity',
            required: true,
            icon: Icons.inventory_2_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
          ),
          actions: [
            appDialogCancelButton(dialogContext),
            const SizedBox(width: 12),
            appDialogPrimaryButton(
              label: 'Save',
              onPressed: () {
                final newQty = int.tryParse(controller.text.trim()) ?? 0;
                // Silently ignoring 0 used to close the dialog with nothing
                // changed, which reads as the save having failed.
                if (newQty <= 0) {
                  NotificationService.instance.showError(
                    'Quantity must be at least 1',
                  );
                  return;
                }
                setState(() {
                  _orderItems[index] = item.copyWith(orderedQty: newQty);
                });
                Navigator.pop(dialogContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getVariantDescription(VarianteModel variant) {
    return variant.variantDescription;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Caps content width on large screens. Backgrounds still span edge to edge —
  /// only what you read is constrained, so this form doesn't stretch a single
  /// column of fields across a whole laptop.
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

  @override
  Widget build(BuildContext context) {
    final totalItems = _orderItems.fold<int>(
      0,
      (sum, item) => sum + item.orderedQty,
    );
    final estimatedTotal = _orderItems.fold<double>(
      0.0,
      (sum, item) => sum + (item.orderedQty * (item.estimatedPrice ?? 0)),
    );

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        // Title + reserved PO number, so the number is visible while filling
        // the form rather than only after saving.
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEditing ? 'Edit Purchase Order' : 'Create Purchase Order',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.subheadingFontSize(context),
                fontWeight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),
            if (_poNumber.isNotEmpty)
              Text(
                _poNumber,
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
        actions: [
          TextButton(
            onPressed: _savePO,
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
          // PO Header Info
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: AppResponsive.padding(context),
              child: _capped(
                context,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // PO Number
                    Row(
                      children: [
                        Icon(
                          Icons.tag,
                          color: AppColors.textSecondary,
                          size: AppResponsive.iconSize(context),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _poNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppResponsive.subheadingFontSize(
                                context,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppResponsive.mediumSpacing(context)),

                    // Supplier Selection
                    InkWell(
                      onTap:
                          isEditing &&
                              widget.purchaseOrder!.statusEnum != POStatus.draft
                          ? null
                          : _showSupplierSelection,
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
                                _selectedSupplier?.name ?? 'Select Supplier *',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: AppResponsive.bodyFontSize(context),
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

                    // Expected Delivery Date
                    InkWell(
                      onTap: _selectDeliveryDate,
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: AppResponsive.bodyFontSize(context),
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

                    // Notes (single line)
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

          // Summary
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              margin: EdgeInsets.only(top: AppResponsive.smallSpacing(context)),
              padding: AppResponsive.padding(context),
              child: _capped(
                context,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Items',
                          style: TextStyle(
                            fontSize: AppResponsive.smallFontSize(context),
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          totalItems.toString(),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: AppResponsive.subheadingFontSize(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Estimated Total',
                            style: TextStyle(
                              fontSize: AppResponsive.smallFontSize(context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              estimatedTotal > 0
                                  ? formatMoney(estimatedTotal)
                                  : '--',
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: AppResponsive.subheadingFontSize(
                                  context,
                                ),
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Items List Header
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              margin: EdgeInsets.only(top: AppResponsive.smallSpacing(context)),
              padding: EdgeInsets.symmetric(
                horizontal: AppResponsive.padding(context).left,
                vertical: AppResponsive.mediumSpacing(context),
              ),
              child: _capped(
                context,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order Items',
                      style: TextStyle(
                        fontSize: AppResponsive.subheadingFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${_orderItems.length} products',
                      style: TextStyle(
                        fontSize: AppResponsive.bodyFontSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Items List
          _orderItems.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: AppResponsive.padding(context),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: AppResponsive.getValue(
                              context,
                              mobile: 64.0,
                              tablet: 76.0,
                              desktop: 88.0,
                            ),
                            color: Colors.grey[300],
                          ),
                          SizedBox(height: AppResponsive.largeSpacing(context)),
                          Text(
                            'No items added',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: AppResponsive.subheadingFontSize(
                                context,
                              ),
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: AppResponsive.smallSpacing(context)),
                          Text(
                            'Tap + button to add items',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: AppResponsive.bodyFontSize(context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: AppResponsive.padding(context),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = _orderItems[index];
                      return _capped(context, _buildItemCard(item, index));
                    }, childCount: _orderItems.length),
                  ),
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildItemCard(POItemData item, int index) {
    final product = productStore.getProductById(item.variant.productId);

    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: Colors.white,
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
                    product?.productName ?? 'Unknown Product',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getVariantDescription(item.variant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppResponsive.smallFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: AppResponsive.smallSpacing(context)),
                  // Wrap so the unit price drops below the qty chip instead of
                  // overflowing a narrow card.
                  Wrap(
                    spacing: AppResponsive.mediumSpacing(context),
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      InkWell(
                        onTap: () => _editItemQty(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Qty: ${item.orderedQty}',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: AppResponsive.smallFontSize(context),
                              fontWeight: FontWeight.w600,
                              color: AppColors.info,
                            ),
                          ),
                        ),
                      ),
                      if (item.estimatedPrice != null)
                        Text(
                          '@ ${formatMoney(item.estimatedPrice!)}',
                          maxLines: 1,
                          style: TextStyle(
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
                if (item.estimatedPrice != null)
                  Text(
                    formatMoney(item.orderedQty * item.estimatedPrice!),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: AppResponsive.iconSize(context),
                  ),
                  onPressed: () => _removeItem(index),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Data class for PO items during editing
class POItemData {
  final VarianteModel variant;
  final int orderedQty;
  final double? estimatedPrice;
  final String? poItemId;

  POItemData({
    required this.variant,
    required this.orderedQty,
    this.estimatedPrice,
    this.poItemId,
  });

  POItemData copyWith({
    VarianteModel? variant,
    int? orderedQty,
    double? estimatedPrice,
    String? poItemId,
  }) {
    return POItemData(
      variant: variant ?? this.variant,
      orderedQty: orderedQty ?? this.orderedQty,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      poItemId: poItemId ?? this.poItemId,
    );
  }
}

// Dialog for adding items to PO
class _AddPOItemDialog extends StatefulWidget {
  final Function(POItemData) onAdd;

  const _AddPOItemDialog({required this.onAdd});

  @override
  State<_AddPOItemDialog> createState() => _AddPOItemDialogState();
}

class _AddPOItemDialogState extends State<_AddPOItemDialog> {
  VarianteModel? _selectedVariant;
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );
  final TextEditingController _priceController = TextEditingController();

  void _showVariantSelection() async {
    // Show product search dialog
    final selectedVariants = await showDialog<List<VarianteModel>>(
      context: context,
      builder: (context) => const _ProductSearchDialog(),
    );

    if (selectedVariants != null && selectedVariants.isNotEmpty && mounted) {
      // Show quantity confirmation dialog
      final quantityData =
          await showDialog<Map<VarianteModel, _QuantityPriceData>>(
            context: context,
            builder: (context) => _QuantityConfirmationDialog(
              variants: selectedVariants,
              onConfirm: (data) {
                Navigator.pop(context, data);
              },
            ),
          );

      if (quantityData != null && quantityData.isNotEmpty) {
        // Add all selected products to the order
        for (var entry in quantityData.entries) {
          widget.onAdd(
            POItemData(
              variant: entry.key,
              orderedQty: entry.value.quantity,
              estimatedPrice: entry.value.price,
            ),
          );
        }

        // Check if widget is still mounted before popping
        if (mounted) {
          Navigator.pop(context);
        }
      }
    }
  }

  String _getVariantDescription(VarianteModel variant) {
    List<String> parts = [];
    // if (variant.size != null) parts.add(variant.size!);
    // if (variant.color != null) parts.add(variant.color!);
    // if (variant.weight != null) parts.add(variant.weight!);
    // Add custom attributes
    if (variant.customAttributes != null &&
        variant.customAttributes!.isNotEmpty) {
      for (var entry in variant.customAttributes!.entries) {
        parts.add('${entry.key}: ${entry.value}');
      }
    }
    if (variant.sku != null) parts.add('SKU: ${variant.sku}');
    return parts.isEmpty ? 'Default Variant' : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final hasVariant = _selectedVariant != null;

    return MoneyScope(
      child: AppDialogShell(
        title: 'Add Item to Order',
        accent: AppColors.primary,
        icon: Icons.add_shopping_cart_rounded,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product picker styled like an AppTextField so it doesn't read as
            // a different kind of control from the fields under it.
            InkWell(
              onTap: _showVariantSelection,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  border: Border.all(
                    color: hasVariant ? AppColors.primary : AppColors.divider,
                    width: hasVariant ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 20,
                      color: hasVariant
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            hasVariant
                                ? productStore
                                          .getProductById(
                                            _selectedVariant!.productId,
                                          )
                                          ?.productName ??
                                      'Unknown product'
                                : 'Select Product *',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.bodyFontSize(context),
                              fontWeight: hasVariant
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                              color: hasVariant
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          if (hasVariant)
                            Text(
                              _getVariantDescription(_selectedVariant!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.captionFontSize(
                                  context,
                                ),
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
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
              controller: _quantityController,
              label: 'Quantity',
              required: true,
              icon: Icons.numbers_rounded,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _priceController,
              label: 'Estimated Price',
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
            if (_lineTotal > 0) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMedium,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Line total',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        formatMoney(_lineTotal),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          appDialogCancelButton(context),
          const SizedBox(width: 12),
          appDialogPrimaryButton(
            label: 'Add',
            onPressed: () {
              if (_selectedVariant == null) {
                NotificationService.instance.showError(
                  'Please select a product',
                );
                return;
              }

              final quantity =
                  int.tryParse(_quantityController.text.trim()) ?? 0;
              if (quantity <= 0) {
                NotificationService.instance.showError(
                  'Please enter a valid quantity',
                );
                return;
              }

              widget.onAdd(
                POItemData(
                  variant: _selectedVariant!,
                  orderedQty: quantity,
                  estimatedPrice: _priceController.text.trim().isEmpty
                      ? null
                      : double.tryParse(_priceController.text.trim()),
                ),
              );

              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  /// Live qty × price preview, so the cost of the line is visible before it's
  /// added rather than only in the order list afterwards.
  double get _lineTotal {
    final qty = int.tryParse(_quantityController.text.trim()) ?? 0;
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    return qty * price;
  }
}

// Helper class to hold quantity and price data
class _QuantityPriceData {
  final int quantity;
  final double? price;

  _QuantityPriceData({required this.quantity, this.price});
}

/// Product search with multi-select. Returns the chosen variants via
/// `Navigator.pop`, so it needs no callback.
class _ProductSearchDialog extends StatefulWidget {
  const _ProductSearchDialog();

  @override
  State<_ProductSearchDialog> createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<_ProductSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<VarianteModel> _allVariants = [];
  List<VarianteModel> _filteredVariants = [];
  final Set<String> _selectedVariantIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVariants();
    _searchController.addListener(_filterVariants);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVariants() async {
    final variants = await productStore.getAllVariants();
    setState(() {
      _allVariants = variants;
      _filteredVariants = variants;
      _isLoading = false;
    });
  }

  void _filterVariants() {
    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() {
        _filteredVariants = _allVariants;
      });
      return;
    }

    setState(() {
      _filteredVariants = _allVariants.where((variant) {
        final product = productStore.getProductById(variant.productId);
        final productName = product?.productName.toLowerCase() ?? '';
        final variantDesc = _getVariantDescription(variant).toLowerCase();
        final sku = variant.sku?.toLowerCase() ?? '';
        final barcode = variant.barcode?.toLowerCase() ?? '';

        return productName.contains(query) ||
            variantDesc.contains(query) ||
            sku.contains(query) ||
            barcode.contains(query);
      }).toList();
    });
  }

  String _getVariantDescription(VarianteModel variant) {
    List<String> parts = [];
    // if (variant.size != null) parts.add(variant.size!);
    // if (variant.color != null) parts.add(variant.color!);
    // if (variant.weight != null) parts.add(variant.weight!);
    if (variant.customAttributes != null &&
        variant.customAttributes!.isNotEmpty) {
      for (var entry in variant.customAttributes!.entries) {
        parts.add('${entry.key}: ${entry.value}');
      }
    }
    if (variant.sku != null) parts.add('SKU: ${variant.sku}');
    return parts.isEmpty ? 'Default Variant' : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return MoneyScope(
      child: AppDialogShell(
        title: 'Select Product',
        subtitle: 'Tap to select — pick several at once',
        accent: AppColors.primary,
        icon: Icons.inventory_2_rounded,
        body: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              AppTextField(
                controller: _searchController,
                hint: 'Search products, SKU, barcode...',
                icon: Icons.search_rounded,
                autofocus: true,
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
              const SizedBox(height: 16),

              // Selection controls and results count
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedVariantIds.isEmpty
                          ? (_searchController.text.isNotEmpty
                                ? '${_filteredVariants.length} result${_filteredVariants.length != 1 ? 's' : ''} found'
                                : '${_filteredVariants.length} product${_filteredVariants.length != 1 ? 's' : ''}')
                          : '${_selectedVariantIds.length} selected',
                      style: TextStyle(
                        fontSize: AppResponsive.smallFontSize(context),
                        color: _selectedVariantIds.isEmpty
                            ? AppColors.textSecondary
                            : AppColors.primary,
                        fontWeight: _selectedVariantIds.isEmpty
                            ? FontWeight.normal
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_filteredVariants.isNotEmpty) ...[
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedVariantIds.length ==
                              _filteredVariants.length) {
                            _selectedVariantIds.clear();
                          } else {
                            _selectedVariantIds.clear();
                            _selectedVariantIds.addAll(
                              _filteredVariants.map((v) => v.varianteId),
                            );
                          }
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _selectedVariantIds.length == _filteredVariants.length
                            ? 'Clear All'
                            : 'Select All',
                        style: TextStyle(
                          fontSize: AppResponsive.smallFontSize(context),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // Product List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredVariants.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchController.text.isEmpty
                                  ? Icons.inventory_2_outlined
                                  : Icons.search_off,
                              size: AppResponsive.getValue(
                                context,
                                mobile: 64.0,
                                tablet: 76.0,
                                desktop: 88.0,
                              ),
                              color: Colors.grey[300],
                            ),
                            SizedBox(
                              height: AppResponsive.largeSpacing(context),
                            ),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No products found.\nPlease add products first.'
                                  : 'No products match your search',
                              style: TextStyle(
                                fontSize: AppResponsive.bodyFontSize(context),
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filteredVariants.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final variant = _filteredVariants[index];
                          final product = productStore.getProductById(
                            variant.productId,
                          );
                          final isSelected = _selectedVariantIds.contains(
                            variant.varianteId,
                          );

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 4,
                            ),
                            leading: Checkbox(
                              value: isSelected,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedVariantIds.add(variant.varianteId);
                                  } else {
                                    _selectedVariantIds.remove(
                                      variant.varianteId,
                                    );
                                  }
                                });
                              },
                              activeColor: AppColors.primary,
                            ),
                            title: Text(
                              product?.productName ?? 'Unknown',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppResponsive.bodyFontSize(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getVariantDescription(variant),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: AppResponsive.smallFontSize(
                                      context,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: variant.stockQty > 0
                                            ? AppColors.success.withValues(
                                                alpha: 0.1,
                                              )
                                            : Colors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Stock: ${variant.stockQty}',
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize:
                                              AppResponsive.captionFontSize(
                                                context,
                                              ),
                                          fontWeight: FontWeight.w600,
                                          color: variant.stockQty > 0
                                              ? AppColors.success
                                              : Colors.red,
                                        ),
                                      ),
                                    ),
                                    if (variant.costPrice != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        formatMoney(variant.costPrice!),
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: AppResponsive.smallFontSize(
                                            context,
                                          ),
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedVariantIds.remove(
                                    variant.varianteId,
                                  );
                                } else {
                                  _selectedVariantIds.add(variant.varianteId);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          appDialogCancelButton(context),
          if (_selectedVariantIds.isNotEmpty) ...[
            const SizedBox(width: 12),
            appDialogPrimaryButton(
              label: 'Add Selected (${_selectedVariantIds.length})',
              onPressed: () {
                final selectedVariants = _allVariants
                    .where((v) => _selectedVariantIds.contains(v.varianteId))
                    .toList();

                // Pop this dialog and pass the selected variants
                Navigator.pop(context, selectedVariants);
              },
            ),
          ],
        ],
      ),
    );
  }
}

// Dialog to set quantities for multiple selected products
class _QuantityConfirmationDialog extends StatefulWidget {
  final List<VarianteModel> variants;
  final Function(Map<VarianteModel, _QuantityPriceData>) onConfirm;

  const _QuantityConfirmationDialog({
    required this.variants,
    required this.onConfirm,
  });

  @override
  State<_QuantityConfirmationDialog> createState() =>
      _QuantityConfirmationDialogState();
}

class _QuantityConfirmationDialogState
    extends State<_QuantityConfirmationDialog> {
  late Map<String, TextEditingController> _quantityControllers;
  late Map<String, TextEditingController> _priceControllers;

  @override
  void initState() {
    super.initState();
    _quantityControllers = {};
    _priceControllers = {};

    for (var variant in widget.variants) {
      _quantityControllers[variant.varianteId] = TextEditingController(
        text: '1',
      );
      _priceControllers[variant.varianteId] = TextEditingController(
        text: variant.costPrice?.toString() ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
    for (var controller in _priceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _getVariantDescription(VarianteModel variant) {
    List<String> parts = [];
    // if (variant.size != null) parts.add(variant.size!);
    // if (variant.color != null) parts.add(variant.color!);
    // if (variant.weight != null) parts.add(variant.weight!);
    if (variant.customAttributes != null &&
        variant.customAttributes!.isNotEmpty) {
      for (var entry in variant.customAttributes!.entries) {
        parts.add('${entry.key}: ${entry.value}');
      }
    }
    if (variant.sku != null) parts.add('SKU: ${variant.sku}');
    return parts.isEmpty ? 'Default Variant' : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return MoneyScope(
      child: AppDialogShell(
        title: 'Set Quantities',
        subtitle:
            '${widget.variants.length} product${widget.variants.length == 1 ? '' : 's'} selected',
        accent: AppColors.primary,
        icon: Icons.numbers_rounded,
        body: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.6,
          child: ListView.separated(
            itemCount: widget.variants.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final variant = widget.variants[index];
              final product = productStore.getProductById(variant.productId);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product name and variant
                    Text(
                      product?.productName ?? 'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getVariantDescription(variant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppResponsive.smallFontSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: AppResponsive.smallSpacing(context)),

                    // Quantity and Price inputs
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quantity input
                        Expanded(
                          flex: 2,
                          child: AppTextField(
                            controller:
                                _quantityControllers[variant.varianteId],
                            label: 'Qty',
                            keyboardType: TextInputType.number,
                            // keyboardType alone doesn't block letters from a
                            // paste or a hardware keyboard.
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ),
                        SizedBox(width: AppResponsive.mediumSpacing(context)),

                        // Price input
                        Expanded(
                          flex: 3,
                          child: AppTextField(
                            controller: _priceControllers[variant.varianteId],
                            label: 'Price (Optional)',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}'),
                              ),
                            ],
                            prefixWidget: Padding(
                              padding: const EdgeInsets.only(
                                left: 12,
                                right: 4,
                              ),
                              child: Text(CurrencyHelper.currentSymbol),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          appDialogCancelButton(context),
          const SizedBox(width: 12),
          appDialogPrimaryButton(
            label: 'Add to Order',
            onPressed: () {
              // Build map of variants with their quantities and prices
              final result = <VarianteModel, _QuantityPriceData>{};

              for (var variant in widget.variants) {
                final qty =
                    int.tryParse(
                      _quantityControllers[variant.varianteId]!.text,
                    ) ??
                    0;
                if (qty > 0) {
                  final priceText = _priceControllers[variant.varianteId]!.text
                      .trim();
                  result[variant] = _QuantityPriceData(
                    quantity: qty,
                    price: priceText.isEmpty
                        ? null
                        : double.tryParse(priceText),
                  );
                }
              }

              if (result.isEmpty) {
                // Was showSuccess — a validation failure reported as success.
                NotificationService.instance.showError(
                  'Enter a quantity for at least one product',
                );
                return;
              }

              // Pop with the result data
              Navigator.pop(context, result);
            },
          ),
        ],
      ),
    );
  }
}
