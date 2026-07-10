import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// "Showing 1–50 of 320 orders" plus prev/next controls.
/// Renders nothing when everything fits on one page.
class ReportPagination extends StatelessWidget {
  /// Zero-based.
  final int currentPage;
  final int rowsPerPage;
  final int totalCount;
  final ValueChanged<int> onPageChanged;

  /// Plural noun for the rows, e.g. 'orders', 'items', 'customers'.
  final String unit;

  const ReportPagination({
    super.key,
    required this.currentPage,
    required this.rowsPerPage,
    required this.totalCount,
    required this.onPageChanged,
    this.unit = 'orders',
  });

  /// The slice of [items] belonging to [page]. Use instead of re-deriving
  /// skip/take per screen — the footer and the table must agree.
  static List<T> pageSlice<T>(List<T> items, int page, int rowsPerPage) {
    if (items.length <= rowsPerPage) return items;
    return items.skip(page * rowsPerPage).take(rowsPerPage).toList();
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (totalCount / rowsPerPage).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    final start = currentPage * rowsPerPage + 1;
    final end = ((currentPage + 1) * rowsPerPage).clamp(1, totalCount);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              'Showing $start–$end of $totalCount $unit',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
                icon: const Icon(Icons.chevron_left),
                iconSize: 24,
                color: AppColors.primary,
                disabledColor: AppColors.divider,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${currentPage + 1} / $totalPages',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              IconButton(
                onPressed:
                    currentPage < totalPages - 1 ? () => onPageChanged(currentPage + 1) : null,
                icon: const Icon(Icons.chevron_right),
                iconSize: 24,
                color: AppColors.primary,
                disabledColor: AppColors.divider,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
