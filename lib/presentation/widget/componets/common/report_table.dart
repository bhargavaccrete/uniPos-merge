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
class ReportTable extends StatelessWidget {
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
  static DataColumn column(BuildContext context, String label, {bool numeric = false}) {
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
          builder: (context, box) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: box.maxWidth),
              child: DataTable(
                showCheckboxColumn: showCheckboxColumn,
                columnSpacing: AppResponsive.tableColumnSpacing(context),
                headingRowColor: WidgetStateProperty.all(AppColors.surfaceLight),
                headingRowHeight: AppResponsive.tableHeadingHeight(context),
                dataRowMinHeight: AppResponsive.tableRowMinHeight(context),
                dataRowMaxHeight: AppResponsive.tableRowMaxHeight(context),
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
                columns: columns,
                rows: rows,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
