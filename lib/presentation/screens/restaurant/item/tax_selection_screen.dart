import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/data/models/restaurant/db/taxmodel_314.dart';
import 'package:billberrylite/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:uuid/uuid.dart';
import 'package:billberrylite/core/di/service_locator.dart';

import '../../../../util/common/app_responsive.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import '../../../widget/componets/common/app_text_field.dart';
import '../../../widget/componets/common/primary_app_bar.dart';
class TaxSelectionScreen extends StatefulWidget {
  final String? selectedTaxId;
  final double? currentTaxRate;

  const TaxSelectionScreen({
    super.key,
    this.selectedTaxId,
    this.currentTaxRate,
  });

  @override
  State<TaxSelectionScreen> createState() => _TaxSelectionScreenState();
}

class _TaxSelectionScreenState extends State<TaxSelectionScreen> {
  List<Tax> availableTaxes = [];
  String? selectedTaxId;
  double? selectedTaxRate;

  @override
  void initState() {
    super.initState();
    _loadTaxes();
    selectedTaxId = widget.selectedTaxId;
    selectedTaxRate = widget.currentTaxRate;
  }

  void _loadTaxes() async {
    await taxStore.loadTaxes();
    setState(() {
      availableTaxes = taxStore.taxes.toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Select Tax',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline),
            onPressed: () => _showAddTaxDialog(),
            tooltip: 'Add New Tax',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: availableTaxes.isEmpty
                ? _buildEmptyState()
                : _buildTaxList(),
          ),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_outlined,
              size: 80,
              color: AppColors.divider,
            ),
            const SizedBox(height: 20),
            Text(
              'No Taxes Available',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Add a tax to get started',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 30),
            CommonButton(
              onTap: () => _showAddTaxDialog(),
              height: 50,
              width: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    'Add Tax',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
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

  Widget _buildTaxList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: availableTaxes.length + 1, // +1 for "No Tax" option
      itemBuilder: (context, index) {
        // First item is "No Tax" option
        if (index == 0) {
          return _buildTaxCard(
            null,
            'No Tax',
            0.0,
            selectedTaxId == null,
          );
        }

        final tax = availableTaxes[index - 1];
        return _buildTaxCard(
          tax.id,
          tax.taxname,
          tax.taxperecentage,
          selectedTaxId == tax.id,
        );
      },
    );
  }

  Widget _buildTaxCard(String? taxId, String name, double? percentage, bool isSelected) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: isSelected ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.divider,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: () {
          setState(() {
            selectedTaxId = taxId;
            selectedTaxRate = percentage != null ? percentage / 100.0 : null;
          });
        },
        leading: Icon(
          isSelected ? Icons.check_circle : Icons.circle_outlined,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
        ),
        title: Text(
          name,
          style: GoogleFonts.poppins(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          '${(percentage ?? 0.0).toStringAsFixed(2)}%',
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        trailing: taxId != null
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteTax(taxId),
              )
            : null,
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.divider,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: CommonButton(
              onTap: () => Navigator.pop(context),
              bgcolor: AppColors.white,
              bordercolor: AppColors.primary,
              bordercircular: 10,
              height:AppResponsive.height(context, 0.06),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: CommonButton(
              onTap: () {
                Navigator.pop(context, {
                  'taxId': selectedTaxId,
                  'taxRate': selectedTaxRate,
                });
              },
              bordercircular: 10,
              height:AppResponsive.height(context, 0.06),
              child: Text(
                'Apply Tax',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTaxDialog() async {
    final nameController = TextEditingController();
    final percentageController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AppDialogShell(
        title: 'Add New Tax',
        accent: AppColors.primary,
        icon: Icons.receipt_long_rounded,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              controller: nameController,
              label: 'Tax Name',
              hint: 'e.g. GST, VAT, Sales Tax',
              icon: Icons.receipt_outlined,
            ),
            const SizedBox(height: 15),
            AppTextField(
              controller: percentageController,
              label: 'Tax Percentage (%)',
              hint: 'e.g. 18',
              icon: Icons.percent_rounded,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          appDialogCancelButton(context),
          const SizedBox(width: 12),
          appDialogPrimaryButton(
            label: 'Add Tax',
            onPressed: () async {
              final name = nameController.text.trim();
              final percentage = double.tryParse(percentageController.text.trim());

              if (name.isEmpty || percentage == null) {
                NotificationService.instance.showError('Please enter valid tax details');
                return;
              }

              final newTax = Tax(
                id: const Uuid().v4(),
                taxname: name,
                taxperecentage: percentage,
              );

              // Save the tax
              await taxStore.addTax(newTax);

              // Unfocus keyboard
              FocusScope.of(context).unfocus();

              // Close the dialog
              Navigator.of(context).pop();

              // Dispose controllers after dialog is closed
              await Future.delayed(const Duration(milliseconds: 100));
              nameController.dispose();
              percentageController.dispose();

              // Auto-select the newly added tax
              if (mounted) {
                setState(() {
                  selectedTaxId = newTax.id;
                  selectedTaxRate = newTax.taxperecentage != null
                      ? newTax.taxperecentage! / 100.0
                      : null;
                });
                _loadTaxes();
              }

              // Show success message
              if (mounted) {
                NotificationService.instance.showSuccess('$name added and selected successfully');
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTax(String taxId) async {
    final confirm = await showAppConfirmDialog(
      context: context,
      title: 'Delete Tax?',
      message: 'Are you sure you want to delete this tax?',
      confirmLabel: 'Yes, Delete',
      cancelLabel: 'No',
      accent: Colors.red,
      icon: Icons.delete_rounded,
    );

    if (confirm == true) {
      await taxStore.deleteTax(taxId);
      if (selectedTaxId == taxId) {
        setState(() {
          selectedTaxId = null;
          selectedTaxRate = null;
        });
      }
      _loadTaxes();
    }
  }
}
