import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';

/// Bottom sheet for selecting Veg/Non-Veg category
class VegSelectorSheet extends StatelessWidget {
  final String currentSelection;
  final Function(String) onSelected;

  const VegSelectorSheet({
    super.key,
    required this.currentSelection,
    required this.onSelected,
  });

  static Future<String?> show(BuildContext context,
      {required String currentSelection}) async {
    String? result;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => VegSelectorSheet(
        currentSelection: currentSelection,
        onSelected: (value) {
          result = value;
          Navigator.pop(context);
        },
      ),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Header ────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.eco_outlined,
                    color: Colors.green, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Food Type',
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    Text('Select the dietary classification',
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
          const SizedBox(height: 20),

          // ── Options ───────────────────────────────────────────────────
          _buildOption(
            context: context,
            label: 'Veg',
            subtitle: 'Plant-based ingredients only',
            icon: Icons.eco_rounded,
            color: Colors.green,
          ),
          const SizedBox(height: 10),
          _buildOption(
            context: context,
            label: 'Non-Veg',
            subtitle: 'Contains meat or animal products',
            icon: Icons.restaurant_rounded,
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = currentSelection == label;
    return InkWell(
      onTap: () => onSelected(label),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.07)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isSelected ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? color : Colors.black87,
                      )),
                  Text(subtitle,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    size: 14, color: Colors.white),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, width: 1.5),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Veg/Non-Veg selector button widget (displays current selection)
class VegSelectorButton extends StatelessWidget {
  final String selectedCategory;
  final VoidCallback onTap;

  const VegSelectorButton({
    super.key,
    required this.selectedCategory,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isVeg = selectedCategory == 'Veg';
    final dotColor = isVeg ? Colors.green : Colors.red;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC), // AppColors.surfaceLight
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)), // AppColors.divider
        ),
        child: Row(
          children: [
            Icon(Icons.eco_outlined, size: 20, color: dotColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedCategory,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF111827), // textPrimary
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: dotColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: dotColor, size: 8),
                  const SizedBox(width: 4),
                  Text(
                    selectedCategory,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: dotColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 22, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }
}
