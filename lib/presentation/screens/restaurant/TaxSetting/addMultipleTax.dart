import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/taxmodel_314.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import '../../../widget/componets/common/app_text_field.dart';
import '../../../widget/componets/common/primary_app_bar.dart';
import 'apply_tax_screen.dart';
import 'package:unipos/util/common/app_responsive.dart';

class Addtax extends StatefulWidget {
  @override
  State<Addtax> createState() => _AddtaxState();
}

class _AddtaxState extends State<Addtax> {
  bool _ischecked1 = false;
  bool _isSaving = false;

  final TextEditingController _taxNameController = TextEditingController();
  final TextEditingController _taxNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    taxStore.loadTaxes();
  }

  @override
  void dispose() {
    _taxNumberController.dispose();
    _taxNameController.dispose();
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


  Future<void> _delete(String id)async{
    final success = await taxStore.deleteTax(id);
    if(success && mounted) {
      Navigator.pop(context);
    }
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
          title: 'Manage Taxes',
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
                                      onPressed: () => _showDeleteConfirmation(context, isTablet, tax.id),
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


  void _showDeleteConfirmation(BuildContext context, bool isTablet, String taxId) {
    final hInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2).clamp(40.0, 200.0)
        : 24.0;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_rounded,
                color: Colors.red,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Tax?',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this tax? This action cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => _delete(taxId),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildFormContent(bool isTablet, bool isEdit, StateSetter setModalState, {Tax? existingTax}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isEdit ? Icons.edit_rounded : Icons.add_circle_rounded,
                size: AppResponsive.getValue(context, mobile: 24.0, tablet: 28.0, desktop: 32.0),
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                isEdit ? 'Edit Tax' : 'Add New Tax',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.getValue(context, mobile: 18.0, tablet: 20.0, desktop: 22.0),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded),
              color: Colors.grey.shade700,
            ),
          ],
        ),
        Divider(height: 32, color: AppColors.divider),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _taxNameController,
                label: 'Tax Name',
                hint: 'e.g. GST, VAT',
                icon: Icons.receipt_outlined,
                required: true,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _taxNumberController,
                label: 'Tax %',
                hint: 'e.g. 18',
                icon: Icons.percent_rounded,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        if (!isEdit)
          Container(
            padding: EdgeInsets.all(12),
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
        SizedBox(height: AppResponsive.getValue(context, mobile: 24.0, tablet: 28.0, desktop: 32.0)),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: AppResponsive.getValue(context, mobile: 20.0, tablet: 24.0, desktop: 28.0),
                  vertical: AppResponsive.getValue(context, mobile: 12.0, tablet: 14.0, desktop: 16.0),
                ),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.getValue(context, mobile: 14.0, tablet: 15.0, desktop: 16.0),
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => _addOrUpdateTax(existingTax: existingTax),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: AppResponsive.getValue(context, mobile: 24.0, tablet: 28.0, desktop: 32.0),
                  vertical: AppResponsive.getValue(context, mobile: 12.0, tablet: 14.0, desktop: 16.0),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                isEdit ? 'Update' : 'Add Tax',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.getValue(context, mobile: 14.0, tablet: 15.0, desktop: 16.0),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
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
          builder: (context, setModalState) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: EdgeInsets.symmetric(horizontal: 80, vertical: 60),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: _buildFormContent(isTablet, isEdit, setModalState, existingTax: existingTax),
            ),
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
                child: _buildFormContent(false, isEdit, setModalState, existingTax: existingTax),
              ),
            );
          },
        );
      },
    );
  }
}

