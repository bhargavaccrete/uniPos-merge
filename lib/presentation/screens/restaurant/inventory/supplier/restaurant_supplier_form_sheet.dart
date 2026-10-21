import 'package:flutter/material.dart';
import 'package:billberrylite/core/config/tax_id_rule.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_model.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/currency_helper.dart';

/// Add or edit a restaurant supplier.
///
/// Returns the saved supplier, or null if cancelled. [existing] switches it to
/// edit mode, where **opening balance is read-only** — it is a posted ledger
/// row, and quietly rewriting it would break the account's reconciliation. The
/// payment dialog's "Adjustment" mode is the sanctioned way to correct it.
Future<RestaurantSupplierModel?> showRestaurantSupplierFormSheet(
  BuildContext context, {
  RestaurantSupplierModel? existing,
}) {
  return showModalBottomSheet<RestaurantSupplierModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // A modal sheet spans the whole window, so on a laptop this form would
    // stretch edge to edge. `constraints` caps the sheet itself and keeps it
    // centred; the scrim behind it still covers the full screen.
    constraints: BoxConstraints(maxWidth: AppResponsive.maxFormWidth(context)),
    builder: (_) => _RestaurantSupplierFormSheet(existing: existing),
  );
}

class _RestaurantSupplierFormSheet extends StatefulWidget {
  final RestaurantSupplierModel? existing;

  const _RestaurantSupplierFormSheet({this.existing});

  @override
  State<_RestaurantSupplierFormSheet> createState() =>
      _RestaurantSupplierFormSheetState();
}

class _RestaurantSupplierFormSheetState
    extends State<_RestaurantSupplierFormSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstController = TextEditingController();
  final _openingController = TextEditingController();

  bool _saving = false;
  String? _nameError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    if (s != null) {
      _nameController.text = s.name;
      _phoneController.text = s.phone ?? '';
      _addressController.text = s.address ?? '';
      _gstController.text = s.gstNumber ?? '';
      _openingController.text = s.openingBalance == 0
          ? ''
          : s.openingBalance.toStringAsFixed(2);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Supplier name is required');
      return;
    }
    setState(() {
      _nameError = null;
      _saving = true;
    });

    final navigator = Navigator.of(context);
    try {
      final phone = _phoneController.text.trim();
      final address = _addressController.text.trim();
      final gst = _gstController.text.trim();

      if (_isEdit) {
        await restaurantSupplierStore.updateSupplier(
          widget.existing!,
          name: name,
          phone: phone.isEmpty ? null : phone,
          address: address.isEmpty ? null : address,
          gstNumber: gst.isEmpty ? null : gst,
        );
        final updated = restaurantSupplierRepository.getSupplierById(
          widget.existing!.supplierId,
        );
        NotificationService.instance.showSuccess('Supplier updated');
        navigator.pop(updated);
      } else {
        final supplier = await restaurantSupplierStore.addSupplier(
          name: name,
          phone: phone.isEmpty ? null : phone,
          address: address.isEmpty ? null : address,
          gstNumber: gst.isEmpty ? null : gst,
          openingBalance: double.tryParse(_openingController.text.trim()) ?? 0,
        );
        NotificationService.instance.showSuccess('Supplier added');
        navigator.pop(supplier);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        NotificationService.instance.showError('Could not save supplier');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DialogDisposeScope(
      disposables: [
        _nameController,
        _phoneController,
        _addressController,
        _gstController,
        _openingController,
      ],
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(
            AppResponsive.getValue(
              context,
              mobile: 20.0,
              tablet: 24.0,
              desktop: 28.0,
            ),
            12,
            AppResponsive.getValue(
              context,
              mobile: 20.0,
              tablet: 24.0,
              desktop: 28.0,
            ),
            24,
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
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _isEdit ? 'Edit Supplier' : 'Add Supplier',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 18),
                AppTextField(
                  controller: _nameController,
                  label: 'Supplier name',
                  hint: 'e.g. Fresh Farms',
                  icon: Icons.storefront_rounded,
                  required: true,
                  autofocus: !_isEdit,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) {
                    if (_nameError != null) setState(() => _nameError = null);
                  },
                ),
                if (_nameError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _nameError!,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      color: AppColors.danger,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                AppTextField(
                  controller: _phoneController,
                  label: 'Phone',
                  hint: 'Optional',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')),
                  ],
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _addressController,
                  label: 'Address',
                  hint: 'Optional',
                  icon: Icons.location_on_outlined,
                  maxLines: 2,
                  minLines: 1,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _gstController,
                  label: TaxIdRule.label,
                  hint: 'Optional',
                  icon: Icons.receipt_long_outlined,
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 14),
                if (_isEdit)
                  _openingBalanceReadOnly()
                else
                  AppTextField(
                    controller: _openingController,
                    label: 'Opening balance (${CurrencyHelper.currentSymbol})',
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
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.divider),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isEdit ? 'Save Changes' : 'Add Supplier',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// In edit mode the opening balance is shown but locked — see the sheet's
  /// doc comment for why.
  Widget _openingBalanceReadOnly() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Opening balance',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${CurrencyHelper.currentSymbol}'
                  '${widget.existing!.openingBalance.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Already posted to the ledger. Use an adjustment to correct it.',
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
    );
  }
}
