import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';

import '../../../../domain/services/restaurant/notification_service.dart';
import '../../../../domain/services/restaurant/stock_adjust_service.dart';
import '../../../widget/componets/common/app_text_field.dart';
import '../../../widget/componets/common/app_dialog.dart';
import '../../../widget/componets/common/dialog_dispose_scope.dart';
import '../../../widget/componets/common/primary_app_bar.dart';
import '../../../../core/constants/item_units.dart';
import '../../../../data/models/restaurant/db/itemmodel_302.dart';

/// Flat, actionable list of every item/variant that is low or out of stock.
/// Opened from the inventory alert bell.
class LowStockScreen extends StatefulWidget {
  const LowStockScreen({super.key});

  @override
  State<LowStockScreen> createState() => _LowStockScreenState();
}

class _LowStockScreenState extends State<LowStockScreen> {
  static const List<String> _addReasons = [
    'Restock / Purchase',
    'Customer return',
    'Stock correction',
    'Transfer in',
    'Other',
  ];

  String _qty(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  String _unitOf(Items item) =>
      normalizeItemUnit(item.unit) ?? item.unit ?? 'pcs';

  /// Whether [item]'s quantity can be fractional, based on its actual Stock
  /// Unit — only 'piece' (or no unit at all) is a whole-count unit.
  /// `isSoldByWeight` doesn't apply to Raw Material/Semi-Finished and is
  /// never set for them, so it can't decide this.
  bool _allowsDecimals(Items item) {
    final normalized = normalizeItemUnit(item.unit);
    return normalized != null && normalized != 'piece';
  }

  Future<void> _restock(StockAlertEntry e) async {
    final unit = _unitOf(e.item);
    final qtyController = TextEditingController();
    String reason = _addReasons.first;
    final noteController = TextEditingController();
    final qtyFocus = FocusNode();
    final noteFocus = FocusNode();

    final result = await showDialog<({String qty, String note})>(
      context: context,
      builder: (ctx) => DialogDisposeScope(
        disposables: [qtyController, noteController, qtyFocus, noteFocus],
        child: StatefulBuilder(
        builder: (ctx, setLocal) => AppDialogShell(
          title: 'Add Stock',
          subtitle: e.variantName != null
              ? '${e.item.name} (${e.variantName})'
              : e.item.name,
          accent: AppColors.primary,
          icon: Icons.add_box_rounded,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: qtyController,
                focusNode: qtyFocus,
                autofocus: true,
                label: 'Quantity to add ($unit)',
                hint: 'e.g. 10',
                icon: Icons.add_box_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => noteFocus.requestFocus(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: reason,
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _addReasons
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r, style: GoogleFonts.poppins(fontSize: 14)),
                        ))
                    .toList(),
                onChanged: (v) => setLocal(() => reason = v ?? _addReasons.first),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: noteController,
                focusNode: noteFocus,
                hint: 'Note (optional)',
                icon: Icons.notes_outlined,
                maxLines: 2,
                minLines: 1,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => Navigator.pop(
                  ctx,
                  (qty: qtyController.text.trim(), note: noteController.text.trim()),
                ),
              ),
            ],
          ),
          actions: [
            appDialogCancelButton(ctx),
            const SizedBox(width: 12),
            appDialogPrimaryButton(
              label: 'Add',
              onPressed: () => Navigator.pop(
                ctx,
                (qty: qtyController.text.trim(), note: noteController.text.trim()),
              ),
            ),
          ],
        ),
      ),
      ),
    );

    if (result == null) return;

    final qty = double.tryParse(result.qty);
    if (qty == null || qty <= 0) {
      NotificationService.instance.showError('Enter a valid quantity');
      return;
    }
    if (!_allowsDecimals(e.item) && qty % 1 != 0) {
      NotificationService.instance.showError('Unit-based items must be whole numbers');
      return;
    }

    await StockAdjustService.addStock(
      item: e.item,
      variant: e.variant,
      qty: qty,
      reason: reason,
      note: result.note.isEmpty ? null : result.note,
    );

    if (mounted) {
      NotificationService.instance.showSuccess('Added ${_qty(qty)} $unit');
      setState(() {}); // refresh the list (item may drop off if no longer low)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Low Stock',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Observer(
        builder: (context) {
          final entries = StockAdjustService.lowStockEntries();
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: AppColors.success),
                  const SizedBox(height: 16),
                  Text('All good — nothing low',
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary)),
                ],
              ),
            );
          }
          // Out of stock first, then low.
          entries.sort((a, b) {
            if (a.isOut != b.isOut) return a.isOut ? -1 : 1;
            return a.stock.compareTo(b.stock);
          });
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _buildRow(entries[i]),
          );
        },
      ),
    );
  }

  Widget _buildRow(StockAlertEntry e) {
    final unit = _unitOf(e.item);
    final Color color = e.isOut ? AppColors.danger : AppColors.orange;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        e.item.name,
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ),
                    if (e.variantName != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(e.variantName!,
                            style: GoogleFonts.poppins(
                                fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(e.isOut ? 'Out' : 'Low',
                          style: GoogleFonts.poppins(
                              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                    ),
                    const SizedBox(width: 8),
                    Text('${_qty(e.stock)} $unit left',
                        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: () => _restock(e),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('Add', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
