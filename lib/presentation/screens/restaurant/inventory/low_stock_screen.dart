import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';

import '../../../../domain/services/restaurant/notification_service.dart';
import '../../../../domain/services/restaurant/stock_adjust_service.dart';
import '../../../widget/componets/common/app_text_field.dart';
import '../../../widget/componets/common/primary_app_bar.dart';

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

  Future<void> _restock(StockAlertEntry e) async {
    final unit = e.item.unit ?? (e.item.isSoldByWeight ? 'kg' : 'pcs');
    final qtyController = TextEditingController();
    String reason = _addReasons.first;
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Add Stock — ${e.variantName != null ? '${e.item.name} (${e.variantName})' : e.item.name}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: qtyController,
                label: 'Quantity to add ($unit)',
                hint: 'e.g. 10',
                icon: Icons.add_box_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                hint: 'Note (optional)',
                icon: Icons.notes_outlined,
                maxLines: 2,
                minLines: 1,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.poppins(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Add', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final qty = double.tryParse(qtyController.text.trim());
    if (qty == null || qty <= 0) {
      NotificationService.instance.showError('Enter a valid quantity');
      return;
    }
    if (!e.item.isSoldByWeight && qty % 1 != 0) {
      NotificationService.instance.showError('Unit-based items must be whole numbers');
      return;
    }

    await StockAdjustService.addStock(
      item: e.item,
      variant: e.variant,
      qty: qty,
      reason: reason,
      note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
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
    final unit = e.item.unit ?? (e.item.isSoldByWeight ? 'kg' : 'pcs');
    final MaterialColor color = e.isOut ? Colors.red : Colors.orange;
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
                              fontSize: 10, fontWeight: FontWeight.w700, color: color.shade700)),
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
