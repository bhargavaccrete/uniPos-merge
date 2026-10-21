import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:uuid/uuid.dart';

import '../../../../../core/di/service_locator.dart';
import '../../../../../data/models/common/taxmodel_314.dart';
import '../../../../../domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';

/// Result from tax selection. Multiple taxes can be applied; [rate] is the
/// SUMMED decimal rate (0.17 for 5% + 12%). Empty [ids] / rate 0 means "No Tax".
class TaxSelectionResult {
  final List<String> ids;
  final double rate;

  TaxSelectionResult({this.ids = const [], this.rate = 0});
}

/// Bottom sheet for selecting one OR MORE taxes — mirrors [CategorySelectorSheet]
/// so the add/edit item forms feel consistent.
class TaxSelectorSheet extends StatefulWidget {
  final List<String> selectedTaxIds;

  const TaxSelectorSheet({super.key, this.selectedTaxIds = const []});

  static Future<TaxSelectionResult?> show(
    BuildContext context, {
    List<String> selectedTaxIds = const [],
  }) {
    return showModalBottomSheet<TaxSelectionResult>(
      context: context,
      // Nearest navigator: inside the setup wizard's pane the sheet rises from
      // the bottom of the CONTENT, leaving the sidebar visible. No-op elsewhere.
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TaxSelectorSheet(selectedTaxIds: selectedTaxIds),
    );
  }

  @override
  State<TaxSelectorSheet> createState() => _TaxSelectorSheetState();
}

class _TaxSelectorSheetState extends State<TaxSelectorSheet> {
  List<Tax> _taxes = [];
  bool _isLoading = true;
  late Set<String> _selected; // currently-ticked tax IDs

  @override
  void initState() {
    super.initState();
    _selected = {...widget.selectedTaxIds};
    _loadTaxes();
  }

  Future<void> _loadTaxes() async {
    await taxStore.loadTaxes();
    if (!mounted) return;
    setState(() {
      _taxes = taxStore.taxes.toList();
      // Drop any selected IDs that no longer exist.
      final valid = _taxes.map((t) => t.id).toSet();
      _selected = _selected.where(valid.contains).toSet();
      _isLoading = false;
    });
  }

  /// Toggle a tax. id == null is the "No Tax" row → clears everything.
  void _toggle(String? id) {
    setState(() {
      if (id == null) {
        _selected.clear();
      } else if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  /// Apply: pop the selected IDs plus their summed decimal rate.
  void _apply() {
    double sum = 0;
    for (final t in _taxes) {
      if (_selected.contains(t.id)) sum += (t.taxperecentage ?? 0) / 100.0;
    }
    Navigator.pop(
      context,
      TaxSelectionResult(ids: _selected.toList(), rate: sum),
    );
  }

  /// Total selected percentage (e.g. 17 for 5% + 12%), for the Apply label.
  double _selectedPercent() {
    double sum = 0;
    for (final t in _taxes) {
      if (_selected.contains(t.id)) sum += (t.taxperecentage ?? 0);
    }
    return sum;
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
                  child: Icon(
                    Icons.percent_rounded,
                    color: AppColors.primary,
                    size: AppResponsive.iconSize(context),
                  ),
                ),
                SizedBox(width: AppResponsive.mediumSpacing(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Tax',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.subheadingFontSize(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _selected.isEmpty
                            ? 'Tap to apply one or more taxes'
                            : '${_selected.length} selected · ${_selectedPercent().toStringAsFixed(_selectedPercent() % 1 == 0 ? 0 : 2)}% total',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.smallFontSize(context),
                          color: Colors.grey.shade500,
                        ),
                      ),
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
                // A non-shrink-wrapping ListView reports its maximum height, so
                // the sheet filled the 75% cap even with three rows in it. With
                // shrinkWrap the list measures its content and the loose
                // Flexible lets the Column shrink to match; the maxHeight
                // constraint still clamps (and re-enables scrolling) once the
                // list grows past it.
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: _taxes.length + 1, // +1 for the "No Tax" option
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return _buildTaxItem(
                      id: null,
                      name: 'No Tax',
                      percentage: null,
                      isSelected: _selected.isEmpty,
                    );
                  }
                  final tax = _taxes[i - 1];
                  return _buildTaxItem(
                    id: tax.id,
                    name: tax.taxname,
                    percentage: tax.taxperecentage,
                    isSelected: _selected.contains(tax.id),
                  );
                },
              ),
            ),

          // Add New Tax + Apply
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showAddTaxDialog,
                    icon: Icon(
                      Icons.add_circle_outline,
                      size: AppResponsive.smallIconSize(context),
                    ),
                    label: Text(
                      'Add Tax',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: EdgeInsets.symmetric(
                        vertical: AppResponsive.mediumSpacing(context),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppResponsive.borderRadius(context),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppResponsive.mediumSpacing(context)),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: AppResponsive.mediumSpacing(context),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppResponsive.borderRadius(context),
                        ),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _selected.isEmpty
                          ? 'Apply'
                          : 'Apply ${_selectedPercent().toStringAsFixed(_selectedPercent() % 1 == 0 ? 0 : 2)}%',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
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
      onTap: () => _toggle(id),
      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.07)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(
            AppResponsive.borderRadius(context),
          ),
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
                size: AppResponsive.smallIconSize(context),
                color: isSelected ? Colors.white : AppColors.primary,
              ),
            ),
            SizedBox(width: AppResponsive.mediumSpacing(context)),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.primary : Colors.black87,
                ),
              ),
            ),
            Text(
              '${(percentage ?? 0).toStringAsFixed(2)}%',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: Colors.grey.shade600,
              ),
            ),
            // Delete action (not for the "No Tax" row)
            if (id != null) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _deleteTax(id),
                borderRadius: BorderRadius.circular(
                  AppResponsive.smallBorderRadius(context),
                ),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppResponsive.smallBorderRadius(context),
                    ),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: AppResponsive.smallIconSize(context),
                    color: Colors.red,
                  ),
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
      useRootNavigator: false, // see showTaxSelector
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            AppResponsive.largeBorderRadius(context),
          ),
        ),
        title: Text(
          'Delete Tax?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete this tax?',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppResponsive.smallBorderRadius(context),
                ),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
              ),
            ),
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
      useRootNavigator: false, // see showTaxSelector
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            AppResponsive.largeBorderRadius(context),
          ),
        ),
        title: Text(
          'Add New Tax',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final name = nameController.text.trim();
              final percentage = double.tryParse(
                percentageController.text.trim(),
              );
              if (name.isEmpty || percentage == null) {
                NotificationService.instance.showError(
                  'Please enter valid tax details',
                );
                return;
              }
              final newTax = Tax(
                id: const Uuid().v4(),
                taxname: name,
                taxperecentage: percentage,
              );
              await taxStore.addTax(newTax);
              if (ctx.mounted) Navigator.pop(ctx);
              // Auto-tick the newly added tax; keep the sheet open for more.
              if (mounted) {
                setState(() => _selected.add(newTax.id));
                _loadTaxes();
              }
            },
            child: Text(
              'Add Tax',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
