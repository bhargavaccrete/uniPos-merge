import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../util/color.dart';
import '../add_item_form_state.dart';

// ── Result returned from the sheet ─────────────────────────────────────────

class SellingMethodResult {
  final SellingMethod method;
  final String unit; // only meaningful when method == byWeight
  SellingMethodResult({required this.method, required this.unit});
}

// ── Bottom-sheet picker ─────────────────────────────────────────────────────

class SellingMethodSheet extends StatefulWidget {
  final SellingMethod currentMethod;
  final String currentUnit;

  const SellingMethodSheet({
    super.key,
    required this.currentMethod,
    required this.currentUnit,
  });

  static Future<SellingMethodResult?> show(
    BuildContext context, {
    required SellingMethod currentMethod,
    required String currentUnit,
  }) async {
    return showModalBottomSheet<SellingMethodResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SellingMethodSheet(
        currentMethod: currentMethod,
        currentUnit: currentUnit,
      ),
    );
  }

  @override
  State<SellingMethodSheet> createState() => _SellingMethodSheetState();
}

class _SellingMethodSheetState extends State<SellingMethodSheet> {
  late SellingMethod _method;
  late String _unit;

  static const _units = ['kg', 'gm', 'lbs', 'litre', 'ml', 'pcs'];

  @override
  void initState() {
    super.initState();
    _method = widget.currentMethod;
    _unit = widget.currentUnit;
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ──────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.sell_outlined,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Selling Method',
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    Text('How is this item measured?',
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

          // ── Method cards ─────────────────────────────────────────────
          _methodCard(
            method: SellingMethod.byUnit,
            label: 'By Unit',
            subtitle: 'Sold as individual pieces (e.g. burger, pizza)',
            icon: Icons.countertops_outlined,
          ),
          const SizedBox(height: 10),
          _methodCard(
            method: SellingMethod.byWeight,
            label: 'By Weight',
            subtitle: 'Sold by measurable quantity (e.g. kg, litre)',
            icon: Icons.scale_outlined,
          ),

          // ── Unit selector (only for Weight) ──────────────────────────
          if (_method == SellingMethod.byWeight) ...[
            const SizedBox(height: 14),
            Text('Select Unit',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _units.map((u) {
                final isSel = _unit == u;
                return GestureDetector(
                  onTap: () => setState(() => _unit = u),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSel
                          ? AppColors.primary
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            isSel ? AppColors.primary : AppColors.divider,
                      ),
                    ),
                    child: Text(u,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSel
                              ? Colors.white
                              : AppColors.textSecondary,
                        )),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 20),

          // ── Confirm button ───────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(
                context,
                SellingMethodResult(method: _method, unit: _unit),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text('Confirm',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodCard(
      {required SellingMethod method,
      required String label,
      required String subtitle,
      required IconData icon}) {
    final isSelected = _method == method;
    return InkWell(
      onTap: () => setState(() => _method = method),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.07)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary
                    .withValues(alpha: isSelected ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: AppColors.primary, size: 22),
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
                        color: isSelected
                            ? AppColors.primary
                            : Colors.black87,
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
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    size: 14, color: Colors.white),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Colors.grey.shade300, width: 1.5),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Inline display button (shows in the form) ──────────────────────────────

class SellingMethodButton extends StatelessWidget {
  final SellingMethod method;
  final String unit;
  final VoidCallback onTap;

  const SellingMethodButton({
    super.key,
    required this.method,
    required this.unit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isByWeight = method == SellingMethod.byWeight;
    final label = isByWeight ? 'By Weight · $unit' : 'By Unit';
    final icon = isByWeight ? Icons.scale_outlined : Icons.countertops_outlined;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Selling Method',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textSecondary)),
                  Text(label,
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary)),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 22, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}