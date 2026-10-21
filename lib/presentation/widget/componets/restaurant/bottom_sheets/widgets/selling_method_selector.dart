import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/core/constants/item_units.dart';
import '../../../../../../util/color.dart';
import '../add_item_form_state.dart';

// ── Result returned from the sheet ─────────────────────────────────────────

class SellingMethodResult {
  final SellingMethod method;
  final String unit; // only meaningful when method == byWeight
  SellingMethodResult({required this.method, required this.unit});
}

// ── Bottom-sheet picker ─────────────────────────────────────────────────────

/// One picker for every Product Type. There used to be a `unitOnly` variant
/// that hid the method cards for Raw Material / Semi-Finished and showed a
/// bare "Stock Unit" chip list instead — so the same decision looked like two
/// different controls depending on the type selected above it. Now every type
/// answers the same question the same way, with **By Unit meaning the item is
/// measured in `piece`** and By Weight revealing the unit chips.
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
      // Nearest navigator, so the sheet stays inside the setup wizard's pane
      // rather than covering the sidebar. No-op outside a nested navigator.
      useRootNavigator: false,
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

  static const _units = kItemUnits;

  @override
  void initState() {
    super.initState();
    _method = widget.currentMethod;
    // Clamp to a supported value so legacy units don't crash the dropdown.
    _unit = normalizeItemUnit(widget.currentUnit) ?? _units.first;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
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
                child: Icon(
                  Icons.sell_outlined,
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
                      'Selling Method',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.subheadingFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'How is this item measured?',
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
          SizedBox(height: AppResponsive.largeSpacing(context)),

          // ── Method cards — shown for every Product Type ──────────────
          _methodCard(
            method: SellingMethod.byUnit,
            label: 'By Unit',
            subtitle: 'Counted in whole pieces (e.g. burger, can, packet)',
            icon: Icons.countertops_outlined,
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          _methodCard(
            method: SellingMethod.byWeight,
            label: 'By Weight',
            subtitle: 'Measured quantity (e.g. kg, litre)',
            icon: Icons.scale_outlined,
          ),

          // ── Unit selector — only By Weight needs one; By Unit always
          // means 'piece' ──────────────────────────────────────────────
          if (_method == SellingMethod.byWeight) ...[
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            _unitChips(),
          ],

          SizedBox(height: AppResponsive.largeSpacing(context)),

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
                'Confirm',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The unit-chip row, shown once By Weight is picked.
  Widget _unitChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Unit',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        SizedBox(height: AppResponsive.smallSpacing(context)),
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
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSel ? AppColors.primary : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSel ? AppColors.primary : AppColors.divider,
                  ),
                ),
                child: Text(
                  u,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: isSel ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _methodCard({
    required SellingMethod method,
    required String label,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _method == method;
    return InkWell(
      onTap: () => setState(() => _method = method),
      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(
                  alpha: isSelected ? 0.15 : 0.08,
                ),
                borderRadius: BorderRadius.circular(
                  AppResponsive.borderRadius(context),
                ),
              ),
              child: Icon(
                icon,
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
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.primary : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: Colors.white,
                ),
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
    const title = 'Selling Method';
    final label = isByWeight ? 'By Weight · $unit' : 'By Unit · piece';
    final icon = isByWeight ? Icons.scale_outlined : Icons.countertops_outlined;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(
            AppResponsive.borderRadius(context),
          ),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: AppResponsive.iconSize(context),
              color: AppColors.primary,
            ),
            SizedBox(width: AppResponsive.smallSpacing(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: AppResponsive.iconSize(context),
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
