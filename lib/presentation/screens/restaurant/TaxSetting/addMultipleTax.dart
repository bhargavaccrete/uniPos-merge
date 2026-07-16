import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/taxmodel_314.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import '../../../widget/componets/common/app_text_field.dart';
import '../../../widget/componets/common/primary_app_bar.dart';
import 'apply_tax_screen.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

class Addtax extends StatefulWidget {
  @override
  State<Addtax> createState() => _AddtaxState();
}

class _AddtaxState extends State<Addtax> {
  bool _ischecked1 = false;
  bool _isSaving = false;

  final TextEditingController _taxNameController = TextEditingController();
  final TextEditingController _taxNumberController = TextEditingController();

  // Focus chain: tax name → tax %.
  final _taxNameFocus = FocusNode();
  final _taxNumberFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    taxStore.loadTaxes();
  }

  @override
  void dispose() {
    _taxNumberController.dispose();
    _taxNameController.dispose();
    _taxNameFocus.dispose();
    _taxNumberFocus.dispose();
    super.dispose();
  }

  void _clearControllers(){
    _taxNumberController.clear();
    _taxNameController.clear();
  }

  Future<void> _addOrUpdateTax({Tax? existingTax}) async {
    if (_isSaving) return;

    final taxName = _taxNameController.text.trim();
    final taxPercentage = double.tryParse(_taxNumberController.text.trim());

    if (taxName.isEmpty || taxPercentage == null) {
      NotificationService.instance.showError(
        'Enter a valid Tax Name/Number',
      );
      return;
    }

    if (taxPercentage <= 0 || taxPercentage > 100) {
      NotificationService.instance.showError(
        'Tax percentage must be between 0 and 100',
      );
      return;
    }

    final isDuplicate = taxStore.taxes.any(
      (t) =>
          t.taxname.toLowerCase() == taxName.toLowerCase() &&
          t.id != (existingTax?.id ?? ''),
    );
    if (isDuplicate) {
      NotificationService.instance.showError(
        'A tax with this name already exists',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      bool success;
      if (existingTax != null) {
        final updatedTax = Tax(
          id: existingTax.id,
          taxname: taxName,
          taxperecentage: taxPercentage,
        );
        success = await taxStore.updateTax(updatedTax);
      } else {
        final newTax = Tax(
          id: Uuid().v4(),
          taxname: taxName,
          taxperecentage: taxPercentage,
        );
        success = await taxStore.addTax(newTax);

        // Apply tax to all items if checkbox is checked
        if (_ischecked1 && success) {
          await _applyTaxToAllItems(newTax.id, taxPercentage);
        }
      }

      if (success) {
        _clearControllers();
        setState(() {
          _ischecked1 = false;
        });
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }


  Future<void> _delete(String id) async {
    await taxStore.deleteTax(id);
  }

  Future<void> _applyTaxToAllItems(String taxId, double taxPercentage) async {
    final rate = taxPercentage / 100.0;

    for (final item in itemStore.items) {
      // Adds the tax (max 2 per item); skips items already taxed / at the cap.
      if (item.applyTax(taxId, rate)) {
        await itemStore.updateItem(item);
      }
    }

    NotificationService.instance.showSuccess(
      'Tax applied to all items',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);

    return Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: buildPrimaryAppBar(
          title: 'Tax Settings',
          titleFontSize: AppResponsive.headingFontSize(context),
        ),
        body: Column(
          children: [
            // Tax List
            Expanded(
              child: Observer(
                builder: (context) {
                  if (taxStore.isLoading) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  final allTax = taxStore.taxes;

                  if (allTax.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calculate_outlined,
                            size: AppResponsive.getValue(context, mobile: 64.0, tablet: 80.0, desktop: 96.0),
                            color: AppColors.divider,
                          ),
                          SizedBox(height: AppResponsive.getValue(context, mobile: 16.0, tablet: 20.0, desktop: 24.0)),
                          Text(
                            'No taxes configured yet',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.getValue(context, mobile: 16.0, tablet: 18.0, desktop: 20.0),
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add your first tax to get started',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.getValue(context, mobile: 13.0, tablet: 14.0, desktop: 15.0),
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 16.0, tablet: 20.0, desktop: 24.0)),
                    itemCount: allTax.length,
                    itemBuilder: (context, index) {
                      final tax = allTax[index];
                      return Container(
                        margin: EdgeInsets.only(bottom: AppResponsive.getValue(context, mobile: 10.0, tablet: 12.0, desktop: 14.0)),
                        padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 14.0, tablet: 16.0, desktop: 18.0)),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                          border: Border.all(
                            color: AppColors.divider,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: AppResponsive.shadowBlurRadius(context),
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tax.taxname,
                                        style: GoogleFonts.poppins(
                                          fontSize: AppResponsive.getValue(context, mobile: 16.0, tablet: 17.0, desktop: 18.0),
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: AppResponsive.getValue(context, mobile: 8.0, tablet: 10.0, desktop: 12.0),
                                          vertical: AppResponsive.getValue(context, mobile: 4.0, tablet: 5.0, desktop: 6.0),
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Tax Rate: ${DecimalSettings.formatAmount(tax.taxperecentage ?? 0)}%',
                                          style: GoogleFonts.poppins(
                                            fontSize: AppResponsive.getValue(context, mobile: 13.0, tablet: 14.0, desktop: 15.0),
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () => _model(isTablet, existingTax: tax),
                                      icon: Icon(Icons.edit_rounded),
                                      color: AppColors.primary,
                                      style: IconButton.styleFrom(
                                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () => _showDeleteConfirmation(context, tax.id),
                                      icon: Icon(Icons.delete_rounded),
                                      color: Colors.red,
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.red.withValues(alpha: 0.1),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: AppResponsive.getValue(context, mobile: 12.0, tablet: 14.0, desktop: 16.0)),
                            SizedBox(
                              width: double.infinity,
                              height: AppResponsive.getValue(context, mobile: 44.0, tablet: 48.0, desktop: 52.0),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ApplyTaxScreen(taxToApply: tax),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: Icon(Icons.check_circle_outline_rounded, size: AppResponsive.getValue(context, mobile: 18.0, tablet: 20.0, desktop: 22.0)),
                                label: Text(
                                  'Apply Tax on Items',
                                  style: GoogleFonts.poppins(
                                    fontSize: AppResponsive.getValue(context, mobile: 14.0, tablet: 15.0, desktop: 16.0),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),


            // Add Tax Button
            Container(
              color: Colors.white,
              padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 16.0, tablet: 20.0, desktop: 24.0)),
              child: SizedBox(
                width: double.infinity,
                height: AppResponsive.getValue(context, mobile: 50.0, tablet: 54.0, desktop: 58.0),
                child: ElevatedButton.icon(
                  onPressed: () => _model(isTablet),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(Icons.add_circle_rounded, size: AppResponsive.getValue(context, mobile: 22.0, tablet: 24.0, desktop: 26.0)),
                  label: Text(
                    'Add New Tax',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.getValue(context, mobile: 16.0, tablet: 17.0, desktop: 18.0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ));
  }


  void _showDeleteConfirmation(BuildContext context, String taxId) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete Tax?',
      message:
          'Are you sure you want to delete this tax? This action cannot be undone.',
      confirmLabel: 'Delete',
      accent: AppColors.danger,
      icon: Icons.warning_rounded,
    );
    if (confirmed) {
      await _delete(taxId);
    }
  }


  /// Shared field block (name + % + optional "apply to all" checkbox), used by
  /// BOTH the tablet dialog and the mobile bottom sheet so they never drift.
  /// Carries the focus chain: name → % → done submits.
  Widget _taxFields(bool isEdit, StateSetter setModalState, {Tax? existingTax}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _taxNameController,
                focusNode: _taxNameFocus,
                label: 'Tax Name',
                hint: 'e.g. GST, VAT',
                icon: Icons.receipt_outlined,
                required: true,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _taxNumberFocus.requestFocus(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _taxNumberController,
                focusNode: _taxNumberFocus,
                label: 'Tax %',
                hint: 'e.g. 18',
                icon: Icons.percent_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _addOrUpdateTax(existingTax: existingTax),
              ),
            ),
          ],
        ),
        if (!isEdit) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _ischecked1,
                  activeColor: AppColors.primary,
                  onChanged: (bool? value) {
                    setModalState(() => _ischecked1 = value ?? false);
                  },
                ),
                Expanded(
                  child: Text(
                    'Apply to all existing items',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.getValue(context, mobile: 13.0, tablet: 14.0, desktop: 15.0),
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Mobile bottom-sheet body: drag handle + header + shared fields + the
  /// standard app-dialog action buttons (kept a sheet on mobile by design).
  Widget _buildSheetContent(bool isEdit, StateSetter setModalState, {Tax? existingTax}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isEdit ? Icons.edit_rounded : Icons.add_circle_rounded,
                size: 24,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isEdit ? 'Edit Tax' : 'Add New Tax',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
              color: Colors.grey.shade700,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _taxFields(isEdit, setModalState, existingTax: existingTax),
        const SizedBox(height: 24),
        Row(
          children: [
            appDialogCancelButton(context),
            const SizedBox(width: 12),
            appDialogPrimaryButton(
              label: isEdit ? 'Update' : 'Add Tax',
              onPressed: () => _addOrUpdateTax(existingTax: existingTax),
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Future<void> _model(bool isTablet, {Tax? existingTax}) {
    bool isEdit = existingTax != null;

    if (isEdit) {
      _taxNameController.text = existingTax.taxname;
      _taxNumberController.text = existingTax.taxperecentage.toString();
    } else {
      _clearControllers();
    }

    // Tablet: centered dialog
    if (isTablet) {
      return showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setModalState) => AppDialogShell(
            title: isEdit ? 'Edit Tax' : 'Add New Tax',
            accent: AppColors.primary,
            icon: isEdit ? Icons.edit_rounded : Icons.add_circle_rounded,
            body: _taxFields(isEdit, setModalState, existingTax: existingTax),
            actions: [
              appDialogCancelButton(context),
              const SizedBox(width: 12),
              appDialogPrimaryButton(
                label: isEdit ? 'Update' : 'Add Tax',
                onPressed: () => _addOrUpdateTax(existingTax: existingTax),
              ),
            ],
          ),
        ),
      );
    }

    // Mobile: bottom sheet (unchanged)
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: _buildSheetContent(isEdit, setModalState, existingTax: existingTax),
              ),
            );
          },
        );
      },
    );
  }
}

