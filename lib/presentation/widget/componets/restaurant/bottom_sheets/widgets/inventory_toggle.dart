import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../util/color.dart';

/// Widget for toggling inventory management settings
class InventoryToggle extends StatelessWidget {
  final bool trackInventory;
  final bool allowOrderWhenOutOfStock;
  final Function(bool) onTrackInventoryChanged;
  final Function(bool) onAllowOutOfStockChanged;

  const InventoryToggle({
    super.key,
    required this.trackInventory,
    required this.allowOrderWhenOutOfStock,
    required this.onTrackInventoryChanged,
    required this.onAllowOutOfStockChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // ── Track Inventory row ────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Manage Inventory',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                _yesNoToggle(
                  value: trackInventory,
                  onChanged: onTrackInventoryChanged,
                ),
              ],
            ),
          ),

          // ── Out-of-stock row (visible only when inventory ON) ──────
          if (trackInventory) ...[
            Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.remove_shopping_cart_outlined,
                      size: 20, color: Colors.orange.shade600),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Allow order if out of stock',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  _yesNoToggle(
                    value: allowOrderWhenOutOfStock,
                    onChanged: onAllowOutOfStockChanged,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _yesNoToggle({
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _chip('YES', value, () => onChanged(true)),
        const SizedBox(width: 6),
        _chip('NO', !value, () => onChanged(false)),
      ],
    );
  }

  Widget _chip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}