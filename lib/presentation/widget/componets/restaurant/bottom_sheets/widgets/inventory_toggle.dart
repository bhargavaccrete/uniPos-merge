import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../componets/filterButton.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Manage Inventory Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Manage Inventory",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              Row(
                children: [
                  Filterbutton(
                    title: 'YES',
                    selectedFilter: trackInventory ? 'YES' : 'NO',
                    onpressed: () => onTrackInventoryChanged(true),
                  ),
                  const SizedBox(width: 8),
                  Filterbutton(
                    title: 'NO',
                    selectedFilter: trackInventory ? 'YES' : 'NO',
                    onpressed: () => onTrackInventoryChanged(false),
                  ),
                ],
              ),
            ],
          ),

          // Out of Stock Option (shown only when inventory is YES)
          if (trackInventory) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Allow order if out of stock",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Row(
                  children: [
                    Transform.scale(
                      scale: 0.8,
                      child: Filterbutton(
                        title: 'YES',
                        selectedFilter: allowOrderWhenOutOfStock ? 'YES' : 'NO',
                        onpressed: () => onAllowOutOfStockChanged(true),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Transform.scale(
                      scale: 0.8,
                      child: Filterbutton(
                        title: 'NO',
                        selectedFilter: allowOrderWhenOutOfStock ? 'YES' : 'NO',
                        onpressed: () => onAllowOutOfStockChanged(false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
