import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// The standard report table: a card that the table stretches to fill,
/// scrolling horizontally only when its columns genuinely overflow.
///
/// `minWidth` comes from the parent constraints, not `AppResponsive.screenWidth`.
/// Report bodies sit inside `constrainedContent` (capped at 1000/1400px), so
/// `screenWidth - 40` on a wide monitor asks for a table wider than its box and
/// grows a scrollbar that should not exist.
class ReportTable extends StatefulWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;

  /// Set false when rows are tappable via `onSelectChanged` but should not
  /// render a selection checkbox.
  final bool showCheckboxColumn;

  const ReportTable({
    super.key,
    required this.columns,
    required this.rows,
    this.showCheckboxColumn = true,
  });

  /// A header cell in the standard style.
  static DataColumn column(
    BuildContext context,
    String label, {
    bool numeric = false,
  }) {
    return DataColumn(
      numeric: numeric,
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: AppResponsive.bodyFontSize(context),
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  @override
  State<ReportTable> createState() => _ReportTableState();
}

class _ReportTableState extends State<ReportTable> {
  /// Whether there are columns still hidden to the right.
  bool _moreToTheRight = false;

  /// A six-column financial table does not fit a phone, so it scrolls — but
  /// nothing said so, and the first column simply looked missing. This tracks
  /// the remaining extent so the fade below can be shown only when it means
  /// something.
  ///
  /// Metrics arrive during layout, so the flag is flipped after the frame
  /// rather than inside the notification.
  bool _handleScroll(Notification n) {
    if (n is! ScrollNotification && n is! ScrollMetricsNotification) {
      return false;
    }
    final metrics = n is ScrollNotification
        ? n.metrics
        : (n as ScrollMetricsNotification).metrics;
    if (metrics.axis != Axis.horizontal) return false;

    final more = metrics.maxScrollExtent - metrics.pixels > 1.0;
    if (more != _moreToTheRight) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _moreToTheRight = more);
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final radius = AppResponsive.borderRadius(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.divider, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: LayoutBuilder(
          builder: (context, box) => Stack(
            children: [
              NotificationListener<Notification>(
                onNotification: _handleScroll,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: box.maxWidth),
                    child: DataTable(
                      showCheckboxColumn: widget.showCheckboxColumn,
                      columnSpacing: AppResponsive.tableColumnSpacing(context),
                      headingRowColor: WidgetStateProperty.all(
                        AppColors.surfaceLight,
                      ),
                      headingRowHeight: AppResponsive.tableHeadingHeight(
                        context,
                      ),
                      dataRowMinHeight: AppResponsive.tableRowMinHeight(
                        context,
                      ),
                      dataRowMaxHeight: AppResponsive.tableRowMaxHeight(
                        context,
                      ),
                      // Everything else about this table scaled with the breakpoint
                      // except the cell text, which fell back to Flutter's fixed
                      // default — so on a tablet the header row and row heights grew
                      // while the values inside them stayed phone-sized.
                      //
                      // Only a default: a cell that passes its own `style` still
                      // wins, so screens that colour a value (negative revenue, a
                      // status) or bold it are untouched.
                      dataTextStyle: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(context),
                        color: AppColors.textPrimary,
                      ),
                      columns: widget.columns,
                      rows: widget.rows,
                    ),
                  ),
                ),
              ),
              // Sits above the right edge only while columns remain hidden.
              // IgnorePointer so it never eats the swipe it is advertising.
              if (_moreToTheRight)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            AppColors.white.withValues(alpha: 0),
                            AppColors.white,
                          ],
                        ),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 2),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: AppResponsive.smallIconSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
