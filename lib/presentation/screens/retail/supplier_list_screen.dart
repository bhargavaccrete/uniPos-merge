import 'package:flutter/material.dart';
import 'package:billberrylite/core/config/tax_id_rule.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/core/config/phone_rule.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_model_205.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/presentation/screens/retail/supplier_detail_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/row_action_button.dart';
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
                SizedBox(height: AppResponsive.mediumSpacing(context)),
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
                SizedBox(height: AppResponsive.mediumSpacing(context)),
                AppTextField(
                  controller: addressController,
                  label: 'Address',
                  icon: Icons.location_on_outlined,
                  maxLines: 2,
                ),
                SizedBox(height: AppResponsive.mediumSpacing(context)),
                AppTextField(
                  controller: gstController,
                  label: TaxIdRule.label,
                  hint: TaxIdRule.hint,
                  icon: Icons.badge_outlined,
                  textCapitalization: TextCapitalization.characters,
                ),
                if (!isEdit) ...[
                  SizedBox(height: AppResponsive.mediumSpacing(context)),
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
              SizedBox(width: AppResponsive.mediumSpacing(context)),
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
    // Deleting also wipes the supplier's ledger, so any purchase paperwork,
    // payment/credit or outstanding balance blocks it — named, not counted.
    final blockers = await supplierStore.deleteBlockers(supplier.supplierId);
    if (!mounted) return;

    if (blockers.isNotEmpty) {
      await showAppErrorDialog(
        context: context,
        title: 'Can\'t delete "${supplier.name}"',
        message: 'This supplier still has history. Deleting it would lose '
            'that record and its account statement.',
        errors: blockers,
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

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'Suppliers'),
      body: MoneyScope(
        child: Column(
          children: [
            Container(
              color: AppColors.white,
              padding: AppResponsive.padding(context),
              child: AppResponsive.constrainedContent(
                context: context,
                alignment: Alignment.topCenter,
                maxWidth: AppResponsive.maxContentWidth(context),
                child: AppTextField(
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
                        ? const AppEmptyState(
                            icon: Icons.storefront_outlined,
                            title: 'No suppliers yet',
                            message:
                                'Add your first supplier to track purchases and balances.',
                          )
                        : AppEmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No suppliers found',
                            message:
                                'No results for "${_searchController.text}".',
                          );
                  }

                  return AppResponsive.constrainedContent(
                    context: context,
                    alignment: Alignment.topCenter,
                    maxWidth: AppResponsive.maxContentWidth(context),
                    child: ListView.builder(
                      padding: AppResponsive.padding(
                        context,
                      ).copyWith(bottom: 88),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSupplierForm(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
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
          child: AppResponsive.constrainedContent(
            context: context,
            alignment: Alignment.topCenter,
            maxWidth: AppResponsive.maxContentWidth(context),
            child: Row(
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
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SupplierDetailScreen(supplier: supplier),
          ),
        ),
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          // Even padding now: the popup menu that carried its own tap padding
          // has been replaced by buttons that sit flush.
          padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.mediumSpacing(context),
            vertical: AppResponsive.smallSpacing(context),
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
                      // Phone plus a 15-character GST number does not fit one
                      // line on a phone; allow a second rather than hide the GST.
                      maxLines: 2,
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
                // Flexible + ellipsis: the chip is a fixed-size sibling of the
                // Expanded name column, so a long balance ('₹1,25,000.00 due')
                // would otherwise take that width straight out of the name.
                Flexible(
                  child: Container(
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
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: isAdvance ? AppColors.success : AppColors.danger,
                      ),
                    ),
                  ),
                ),
              ],
              SizedBox(width: AppResponsive.smallSpacing(context)),
              RowActionButton(
                icon: Icons.edit_outlined,
                color: AppColors.primary,
                tooltip: 'Edit Supplier',
                onTap: () => _showSupplierForm(existing: supplier),
              ),
              const SizedBox(width: 6),
              RowActionButton(
                icon: Icons.delete_outline_rounded,
                color: AppColors.danger,
                tooltip: 'Delete Supplier',
                onTap: () => _deleteSupplier(supplier),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
