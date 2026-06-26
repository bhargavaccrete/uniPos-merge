import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:billberrylite/util/color.dart';

import '../../../../data/models/restaurant/db/stock_movement_model.dart';
import '../../../../data/repositories/restaurant/stock_movement_repository.dart';
import '../../../widget/componets/common/primary_app_bar.dart';

/// Per-item stock movement history (manual add/remove log).
class StockHistoryScreen extends StatefulWidget {
  final String itemId;
  final String itemName;
  final String unit;

  const StockHistoryScreen({
    super.key,
    required this.itemId,
    required this.itemName,
    required this.unit,
  });

  @override
  State<StockHistoryScreen> createState() => _StockHistoryScreenState();
}

class _StockHistoryScreenState extends State<StockHistoryScreen> {
  final _repo = StockMovementRepository();
  late List<StockMovementModel> _movements;

  @override
  void initState() {
    super.initState();
    _movements = _repo.movementsForItem(widget.itemId);
  }

  String _qty(double v) {
    // Whole numbers for piece-based units, 2dp otherwise.
    return v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Stock History',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Item name header
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Text(
              widget.itemName,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: _movements.isEmpty ? _buildEmpty() : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: AppColors.divider),
          const SizedBox(height: 16),
          Text(
            'No stock movements yet',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add or remove stock to start the log',
            style: GoogleFonts.poppins(
                fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _movements.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildRow(_movements[i]),
    );
  }

  /// Extracts the variant name from a movement's stored item name.
  /// Movements are saved as "Item Name (Variant)" for variant stock, so we
  /// anchor on the known base name to peel off the variant safely.
  String? _variantOf(StockMovementModel m) {
    final base = widget.itemName;
    if (m.itemName.length > base.length &&
        m.itemName.startsWith('$base (') &&
        m.itemName.endsWith(')')) {
      return m.itemName.substring(base.length + 2, m.itemName.length - 1);
    }
    return null;
  }

  Widget _buildRow(StockMovementModel m) {
    final isIn = m.isIn;
    final color = isIn ? AppColors.success : Colors.red;
    final variant = _variantOf(m);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isIn ? Icons.add_rounded : Icons.remove_rounded,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (variant != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      variant,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      m.reason,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${isIn ? '+' : '−'}${_qty(m.quantity)} ${widget.unit}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Balance: ${_qty(m.balanceAfter)} ${widget.unit}',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                if (m.note != null && m.note!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    m.note!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('dd MMM yyyy · hh:mm a').format(m.timestamp)}  •  ${m.staffName}',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
