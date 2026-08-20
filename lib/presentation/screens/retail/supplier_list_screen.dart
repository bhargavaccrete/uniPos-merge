import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/core/config/phone_rule.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_model_205.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/core/plan/plan_guard.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    supplierStore.setSearchQuery('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    supplierStore.setSearchQuery(''); // Leave a clean filter for the next visit
    super.dispose();
  }

  void _onSearchChanged(String query) {
    supplierStore.setSearchQuery(query);
    setState(() {});
  }

  String _formatDate(String isoDate) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return isoDate;
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  /// Avatar initial. Guarded because a name could be blank in older data —
  /// the add form used to accept whitespace-only names.
  String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }

  // ==================== ADD / EDIT ====================

  /// One form for both modes — pass [existing] to edit.
  Future<void> _showSupplierForm({SupplierModel? existing}) async {
    final isEdit = existing != null;

    final nameController = TextEditingController(text: existing?.name ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');
    final addressController = TextEditingController(
      text: existing?.address ?? '',
    );
    final gstController = TextEditingController(
      text: existing?.gstNumber ?? '',
    );
    // Opening balance is the starting point of the ledger — editing it after
    // purchases have moved the current balance would silently rewrite history,
    // so it's add-only.
    final openingBalanceController = TextEditingController();

    await showDialog<void>(
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
            title: isEdit ? 'Edit Supplier' : 'Add Supplier',
            accent: AppColors.primary,
            icon: isEdit ? Icons.edit_outlined : Icons.storefront_rounded,
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
                  // Optional for suppliers — only validated once typed into.
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
                if (!isEdit) ...[
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
              ],
            ),
            actions: [
              appDialogCancelButton(dialogContext),
              const SizedBox(width: 12),
              appDialogPrimaryButton(
                label: isEdit ? 'Save' : 'Add Supplier',
                onPressed: () => _saveSupplier(
                  dialogContext,
                  existing: existing,
                  name: nameController.text,
                  phone: phoneController.text,
                  address: addressController.text,
                  gst: gstController.text,
                  openingBalance: openingBalanceController.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveSupplier(
    BuildContext dialogContext, {
    SupplierModel? existing,
    required String name,
    required String phone,
    required String address,
    required String gst,
    required String openingBalance,
  }) async {
    // Validate the TRIMMED name — checking the raw text let "   " through and
    // saved a blank-named supplier that then crashed the list.
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      NotificationService.instance.showError('Name is required');
      return;
    }

    final trimmedPhone = phone.trim();
    final phoneError = PhoneRule.validate(trimmedPhone, required: false);
    if (phoneError != null) {
      NotificationService.instance.showError(phoneError);
      return;
    }

    final trimmedAddress = address.trim();
    final trimmedGst = gst.trim();

    // Plan gate — block a NEW supplier once the cap is reached (edits exempt).
    // No-op until a retail manifest is present (see PlanEnforce).
    if (existing == null && !supplierStore.canAddSupplier) {
      final max = supplierStore.supplierLimit;
      NotificationService.instance.showError(
        'Supplier limit reached${max != null ? ' (max $max)' : ''}. Upgrade your plan to add more.',
      );
      return;
    }
    if (existing != null &&
        !PlanGuard.allowedOr(
          context,
          RetailEntKeys.suppliersEdit,
          featureName: 'Edit Suppliers',
        )) {
      return;
    }

    try {
      if (existing != null) {
        // Emptying an optional field must actually clear it.
        await supplierStore.updateSupplier(
          existing.copyWith(
            name: trimmedName,
            phone: trimmedPhone.isEmpty ? null : trimmedPhone,
            clearPhone: trimmedPhone.isEmpty,
            address: trimmedAddress.isEmpty ? null : trimmedAddress,
            clearAddress: trimmedAddress.isEmpty,
            gstNumber: trimmedGst.isEmpty ? null : trimmedGst.toUpperCase(),
            clearGstNumber: trimmedGst.isEmpty,
          ),
        );
      } else {
        final opening = double.tryParse(openingBalance.trim()) ?? 0.0;
        await supplierStore.addSupplier(
          SupplierModel.create(
            name: trimmedName,
            phone: trimmedPhone.isEmpty ? null : trimmedPhone,
            address: trimmedAddress.isEmpty ? null : trimmedAddress,
            gstNumber: trimmedGst.isEmpty ? null : trimmedGst.toUpperCase(),
            openingBalance: opening,
            currentBalance: opening,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      NotificationService.instance.showError('Failed to save supplier: $e');
      return;
    }

    if (!dialogContext.mounted) return;
    Navigator.pop(dialogContext);
    NotificationService.instance.showSuccess(
      existing != null
          ? 'Supplier updated successfully'
          : 'Supplier added successfully',
    );
  }

  // ==================== DELETE ====================

  Future<void> _deleteSupplier(SupplierModel supplier) async {
    if (!PlanGuard.allowedOr(
      context,
      RetailEntKeys.suppliersDelete,
      featureName: 'Delete Suppliers',
    )) {
      return;
    }
    // Purchases/POs/GRNs resolve the supplier name by id at render time, so
    // removing a supplier with history would leave those screens blank.
    final references = await supplierStore.countReferences(supplier.supplierId);
    if (!mounted) return;

    if (references > 0) {
      await showAppErrorDialog(
        context: context,
        title: 'Can\'t delete "${supplier.name}"',
        message:
            '$references purchase record${references == 1 ? '' : 's'} still reference this supplier. '
            'Deleting them would leave that history without a supplier name.',
      );
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete "${supplier.name}"?',
      message: 'This action cannot be undone.',
      confirmLabel: 'Delete',
      accent: AppColors.danger,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;

    try {
      await supplierStore.deleteSupplier(supplier.supplierId);
      NotificationService.instance.showSuccess('Supplier deleted');
    } catch (e) {
      NotificationService.instance.showError('Failed to delete supplier: $e');
    }
  }

  // ==================== DETAILS ====================

  void _showSupplierDetails(SupplierModel supplier) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => MoneyScope(
        child: AppDialogShell(
          title: supplier.name,
          subtitle: supplier.phone,
          accent: AppColors.primary,
          icon: Icons.storefront_rounded,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (supplier.address?.isNotEmpty ?? false)
                _buildDetailRow('Address', supplier.address!),
              if (supplier.gstNumber?.isNotEmpty ?? false)
                _buildDetailRow('GST Number', supplier.gstNumber!),
              _buildDetailRow(
                'Opening Balance',
                formatMoney(supplier.openingBalance),
              ),
              _buildDetailRow(
                'Current Balance',
                formatMoney(supplier.currentBalance.abs()) +
                    (supplier.currentBalance < 0 ? ' advance' : ''),
                valueColor: supplier.currentBalance > 0
                    ? AppColors.danger
                    : AppColors.success,
              ),
              const Divider(height: 20, color: AppColors.divider),
              _buildDetailRow('Created', _formatDate(supplier.createdAt)),
              _buildDetailRow('Last Updated', _formatDate(supplier.updatedAt)),
            ],
          ),
          actions: [
            appDialogCancelButton(dialogContext, label: 'Close'),
            const SizedBox(width: 12),
            appDialogPrimaryButton(
              label: 'Update Balance',
              onPressed: () {
                Navigator.pop(dialogContext);
                _showUpdateBalanceDialog(supplier);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
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
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BALANCE ====================

  Future<void> _showUpdateBalanceDialog(SupplierModel supplier) async {
    final amountController = TextEditingController();
    bool isDebit = true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => DialogDisposeScope(
        disposables: [amountController],
        child: MoneyScope(
          child: StatefulBuilder(
            builder: (context, setLocalState) => AppDialogShell(
              title: 'Update Balance',
              subtitle: 'Current: ${formatMoney(supplier.currentBalance)}',
              accent: AppColors.primary,
              icon: Icons.account_balance_wallet_outlined,
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBalanceModeTile(
                    label: 'Purchase (Debit)',
                    caption: 'Increases what you owe',
                    selected: isDebit,
                    onTap: () => setLocalState(() => isDebit = true),
                  ),
                  const SizedBox(height: 8),
                  _buildBalanceModeTile(
                    label: 'Payment (Credit)',
                    caption: 'Reduces what you owe',
                    selected: !isDebit,
                    onTap: () => setLocalState(() => isDebit = false),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: amountController,
                    label: 'Amount',
                    icon: Icons.currency_rupee_rounded,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    autofocus: true,
                  ),
                ],
              ),
              actions: [
                appDialogCancelButton(dialogContext),
                const SizedBox(width: 12),
                appDialogPrimaryButton(
                  label: 'Update',
                  onPressed: () async {
                    final amount = double.tryParse(
                      amountController.text.trim(),
                    );
                    if (amount == null || amount <= 0) {
                      NotificationService.instance.showError(
                        'Please enter a valid amount',
                      );
                      return;
                    }

                    try {
                      await supplierStore.updateSupplierBalance(
                        supplier.supplierId,
                        isDebit ? amount : -amount,
                      );
                    } catch (e) {
                      if (!mounted) return;
                      NotificationService.instance.showError(
                        'Failed to update balance: $e',
                      );
                      return;
                    }

                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    NotificationService.instance.showSuccess(
                      'Balance updated successfully',
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceModeTile({
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

  // ==================== BUILD ====================

  /// Caps content width on large screens. Backgrounds still span edge to edge —
  /// only what you read is constrained, so a laptop doesn't stretch a one-line
  /// supplier row across the whole window.
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
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Suppliers',
        actions: [
          // Populated → add lives here; empty → the centred empty-state button
          // is the only prompt.
          Observer(
            builder: (context) => supplierStore.suppliers.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.add_business_rounded),
                    tooltip: 'Add supplier',
                    onPressed: () => _showSupplierForm(),
                  ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: MoneyScope(
        child: Column(
          children: [
            Container(
              color: AppColors.white,
              padding: AppResponsive.padding(context),
              child: _capped(
                context,
                AppTextField(
                  controller: _searchController,
                  hint: 'Search by name, phone, or GST...',
                  icon: Icons.search_rounded,
                  onChanged: _onSearchChanged,
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            size: AppResponsive.smallIconSize(context),
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                ),
              ),
            ),
            _buildSummaryRow(context),
            Expanded(
              child: Observer(
                builder: (context) {
                  final suppliers = supplierStore.filteredSuppliers;

                  if (suppliers.isEmpty) {
                    return _searchController.text.isEmpty
                        ? AppEmptyState(
                            icon: Icons.storefront_outlined,
                            title: 'No suppliers yet',
                            message:
                                'Add your first supplier to track purchases and balances.',
                            action: appEmptyStateAction(
                              label: 'Add Supplier',
                              onPressed: () => _showSupplierForm(),
                            ),
                          )
                        : AppEmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No suppliers found',
                            message:
                                'No results for "${_searchController.text}".',
                          );
                  }

                  return _capped(
                    context,
                    ListView.builder(
                      padding: AppResponsive.padding(context),
                      itemCount: suppliers.length,
                      itemBuilder: (context, index) =>
                          _buildSupplierCard(context, suppliers[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context) {
    return Observer(
      builder: (context) {
        if (supplierStore.suppliers.isEmpty) return const SizedBox.shrink();

        final net = supplierStore.totalOutstanding;
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.padding(context).left,
            vertical: AppResponsive.smallSpacing(context),
          ),
          child: _capped(
            context,
            Row(
              children: [
                _buildStatChip(
                  context,
                  '${supplierStore.supplierCount} suppliers',
                  Icons.storefront_rounded,
                  AppColors.primary,
                ),
                SizedBox(width: AppResponsive.smallSpacing(context)),
                // Net of advances — a supplier you've overpaid offsets the rest.
                _buildStatChip(
                  context,
                  '${formatMoney(net.abs())} ${net < 0 ? 'advance' : 'payable'}',
                  Icons.account_balance_wallet_rounded,
                  net > 0 ? AppColors.danger : AppColors.success,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatChip(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: AppResponsive.smallSpacing(context),
          horizontal: AppResponsive.smallSpacing(context),
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(
            AppResponsive.smallBorderRadius(context),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: AppResponsive.smallIconSize(context),
              color: color,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierCard(BuildContext context, SupplierModel supplier) {
    final balance = supplier.currentBalance;
    final hasBalance = balance != 0;
    final isAdvance = balance < 0;
    final radius = AppResponsive.borderRadius(context);

    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: balance > 0
              ? AppColors.danger.withValues(alpha: 0.3)
              : AppColors.divider,
        ),
      ),
      child: InkWell(
        onTap: () => _showSupplierDetails(supplier),
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          // Right stays tight — the popup menu carries its own tap padding.
          padding: EdgeInsets.fromLTRB(
            AppResponsive.mediumSpacing(context),
            AppResponsive.smallSpacing(context),
            4,
            AppResponsive.smallSpacing(context),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: AppResponsive.smallAvatarSize(context) / 2,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  _initial(supplier.name),
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(width: AppResponsive.mediumSpacing(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supplier.name.trim().isEmpty
                          ? 'Unnamed supplier'
                          : supplier.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (supplier.phone?.isNotEmpty ?? false)
                          supplier.phone!,
                        if (supplier.gstNumber?.isNotEmpty ?? false)
                          supplier.gstNumber!,
                      ].join('  •  '),
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
              if (hasBalance) ...[
                SizedBox(width: AppResponsive.smallSpacing(context)),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (isAdvance ? AppColors.success : AppColors.danger)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${formatMoney(balance.abs())} ${isAdvance ? 'advance' : 'due'}',
                    maxLines: 1,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: isAdvance ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ),
              ],
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.textSecondary,
                  size: AppResponsive.iconSize(context),
                ),
                color: AppColors.white,
                surfaceTintColor: AppColors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onSelected: (value) {
                  if (value == 'edit') _showSupplierForm(existing: supplier);
                  if (value == 'delete') _deleteSupplier(supplier);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Edit',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(context),
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Delete',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(context),
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
