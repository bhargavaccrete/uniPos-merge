import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../../../../core/di/service_locator.dart';
import '../../../../../data/models/restaurant/db/taxmodel_314.dart';
import '../../../../../domain/services/restaurant/notification_service.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';

/// Result from tax selection. [rate] is a decimal (0.18 for 18%);
/// both null means "No Tax".
class TaxSelectionResult {
  final String? id;
  final double? rate;

  TaxSelectionResult({this.id, this.rate});
}

/// Bottom sheet for selecting a tax — mirrors [CategorySelectorSheet] so the
/// add/edit item forms feel consistent.
class TaxSelectorSheet extends StatefulWidget {
  final String? selectedTaxId;

  const TaxSelectorSheet({super.key, this.selectedTaxId});

  static Future<TaxSelectionResult?> show(
    BuildContext context, {
    String? selectedTaxId,
  }) {
    return showModalBottomSheet<TaxSelectionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TaxSelectorSheet(selectedTaxId: selectedTaxId),
    );
  }

  @override
  State<TaxSelectorSheet> createState() => _TaxSelectorSheetState();
}

class _TaxSelectorSheetState extends State<TaxSelectorSheet> {
  List<Tax> _taxes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTaxes();
  }

  Future<void> _loadTaxes() async {
    await taxStore.loadTaxes();
    if (!mounted) return;
    setState(() {
      _taxes = taxStore.taxes.toList();
      _isLoading = false;
    });
  }

  void _select(String? id, double? percentage) {
    Navigator.pop(
      context,
      TaxSelectionResult(
        id: id,
        rate: percentage != null ? percentage / 100.0 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.75;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.percent_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Select Tax',
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      Text('${_taxes.length} tax rate${_taxes.length == 1 ? '' : 's'} available',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.grey.shade500),
                  splashRadius: 20,
                ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey.shade100),

          // List
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            )
          else
            Flexible(
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _taxes.length + 1, // +1 for the "No Tax" option
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return _buildTaxItem(
                      id: null,
                      name: 'No Tax',
                      percentage: null,
                      isSelected: widget.selectedTaxId == null,
                    );
                  }
                  final tax = _taxes[i - 1];
                  return _buildTaxItem(
                    id: tax.id,
                    name: tax.taxname,
                    percentage: tax.taxperecentage,
                    isSelected: widget.selectedTaxId == tax.id,
                  );
                },
              ),
            ),

          // Add New Tax button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showAddTaxDialog,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: Text('Add New Tax',
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxItem({
    required String? id,
    required String name,
    required double? percentage,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => _select(id, percentage),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.07)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isSelected ? Icons.check_rounded : Icons.percent_rounded,
                size: 18,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.primary : Colors.black87,
                ),
              ),
            ),
            Text(
              '${(percentage ?? 0).toStringAsFixed(2)}%',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey.shade600),
            ),
            // Delete action (not for the "No Tax" row)
            if (id != null) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _deleteTax(id),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 16, color: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTax(String taxId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Tax?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to delete this tax?',
            style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Delete', style: GoogleFonts.poppins(fontSize: 13)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await taxStore.deleteTax(taxId);
      _loadTaxes();
    }
  }

  Future<void> _showAddTaxDialog() async {
    final nameController = TextEditingController();
    final percentageController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add New Tax',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: nameController,
                label: 'Tax Name',
                hint: 'e.g. GST, VAT',
                icon: Icons.receipt_outlined,
              ),
              const SizedBox(height: 15),
              AppTextField(
                controller: percentageController,
                label: 'Tax Percentage (%)',
                hint: 'e.g. 18',
                icon: Icons.percent_rounded,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final name = nameController.text.trim();
              final percentage =
                  double.tryParse(percentageController.text.trim());
              if (name.isEmpty || percentage == null) {
                NotificationService.instance
                    .showError('Please enter valid tax details');
                return;
              }
              final newTax = Tax(
                id: const Uuid().v4(),
                taxname: name,
                taxperecentage: percentage,
              );
              await taxStore.addTax(newTax);
              if (ctx.mounted) Navigator.pop(ctx);
              // Auto-select the newly added tax and close the sheet.
              if (mounted) _select(newTax.id, percentage);
            },
            child: Text('Add Tax',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
