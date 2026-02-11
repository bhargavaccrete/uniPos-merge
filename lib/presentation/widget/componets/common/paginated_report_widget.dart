import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../../../util/color.dart';

/// Reusable widget for paginated reports with date filtering
/// Provides consistent pagination UI across all report screens
class PaginatedReportWidget extends StatelessWidget {
  final List<PastOrderModel> orders;
  final int currentPage;
  final int totalPages;
  final int totalCount;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final VoidCallback onNextPage;
  final VoidCallback onPreviousPage;
  final Function(int) onGoToPage;
  final bool isLoading;

  // Date filter callbacks (optional)
  final VoidCallback? onTodayFilter;
  final VoidCallback? onWeekFilter;
  final VoidCallback? onMonthFilter;
  final VoidCallback? onCustomFilter;

  // Content builder - receives filtered/paginated orders
  final Widget Function(List<PastOrderModel> orders) contentBuilder;

  // Optional header widget (summary cards, etc.)
  final Widget? summaryHeader;

  const PaginatedReportWidget({
    required this.orders,
    required this.currentPage,
    required this.totalPages,
    required this.totalCount,
    required this.hasNextPage,
    required this.hasPreviousPage,
    required this.onNextPage,
    required this.onPreviousPage,
    required this.onGoToPage,
    required this.contentBuilder,
    this.isLoading = false,
    this.onTodayFilter,
    this.onWeekFilter,
    this.onMonthFilter,
    this.onCustomFilter,
    this.summaryHeader,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Quick date filters (if provided)
        if (onTodayFilter != null) _buildDateFilters(),

        // Summary cards/header (if provided)
        if (summaryHeader != null) summaryHeader!,

        // Pagination controls (top)
        if (totalCount > 0) _buildPaginationControls(context),

        // Content area
        Expanded(
          child: isLoading
              ? _buildLoadingState()
              : orders.isEmpty
                  ? _buildEmptyState()
                  : contentBuilder(orders),
        ),

        // Pagination controls (bottom)
        if (totalCount > 0) _buildPaginationControls(context),
      ],
    );
  }

  /// Date filter chips
  Widget _buildDateFilters() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (onTodayFilter != null)
              _filterChip('Today', Icons.today, onTodayFilter!),
            if (onWeekFilter != null) ...[
              const SizedBox(width: 8),
              _filterChip('This Week', Icons.view_week, onWeekFilter!),
            ],
            if (onMonthFilter != null) ...[
              const SizedBox(width: 8),
              _filterChip('This Month', Icons.calendar_month, onMonthFilter!),
            ],
            if (onCustomFilter != null) ...[
              const SizedBox(width: 8),
              _filterChip('Custom', Icons.date_range, onCustomFilter!),
            ],
          ],
        ),
      ),
    );
  }

  /// Individual filter chip
  Widget _filterChip(String label, IconData icon, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Pagination controls
  Widget _buildPaginationControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous button
          Flexible(
            child: ElevatedButton.icon(
              onPressed: hasPreviousPage ? onPreviousPage : null,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Previous'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[600],
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Page info with dropdown
          Flexible(
            flex: 2,
            child: _buildPageSelector(context),
          ),

          const SizedBox(width: 8),

          // Next button
          Flexible(
            child: ElevatedButton.icon(
              onPressed: hasNextPage ? onNextPage : null,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Next'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[600],
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Page selector with info
  Widget _buildPageSelector(BuildContext context) {
    // Show dropdown only if more than 5 pages
    if (totalPages > 5) {
      return Row(
        children: [
          Text(
            'Page',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<int>(
              value: currentPage,
              underline: const SizedBox.shrink(),
              isDense: true,
              items: List.generate(
                totalPages,
                (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text('${index + 1}'),
                ),
              ),
              onChanged: (page) {
                if (page != null) onGoToPage(page);
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'of $totalPages ($totalCount total)',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    // Simple page indicator for <= 5 pages
    return Text(
      'Page $currentPage of $totalPages ($totalCount orders)',
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  /// Loading state
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading orders...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Empty state
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No orders found',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or date range',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
