import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_page_scaffold.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_notice.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Every sale where money was given away, with the three mechanisms that do it
/// kept apart.
///
/// A shop gives money away three different ways and only one of them is a
/// "discount" as the data models it. A price override lowers the charged price
/// before the discount engine ever sees the line, and a loyalty redemption is
/// applied after the discount is final — so neither appears in
/// `SaleModel.discountAmount`, and neither was visible in any existing report.
/// Those two are precisely the levers a cashier can pull without the day's
/// discount total moving, which is why they are columns here rather than a
/// footnote.
///
/// The headline is the sum of all three. The "Where it went" card underneath
/// breaks it back down, because a single number cannot tell a manager which
/// lever is being pulled.
class DiscountReportScreen extends StatelessWidget {
  const DiscountReportScreen({super.key});

  String _date(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd MMM yyyy, hh:mm a').format(d);
  }

  double _sum(List<Map<String, dynamic>> rows, String key) =>
      rows.fold<double>(0, (s, r) => s + ((r[key] as num?) ?? 0).toDouble());

  /// The reason a bill was discounted. Bill-level reasons are free text and
  /// line-level ones are codes, so they are shown in priority order rather than
  /// merged — the two vocabularies do not line up.
  String _reason(Map<String, dynamic> row) {
    final bill = (row['discountReason'] as String? ?? '').trim();
    if (bill.isNotEmpty) return bill;
    final line = (row['lineDiscountReasons'] as String? ?? '').trim();
    if (line.isNotEmpty) return line;
    final override = (row['overrideReasons'] as String? ?? '').trim();
    if (override.isNotEmpty) return override;
    return '—';
  }

  /// Money cell that turns red when negative — a return leg nets its original
  /// rather than being dropped, so negative rows are expected here.
  Widget _money(BuildContext context, double value) {
    return Text(
      formatMoney(value),
      style: GoogleFonts.poppins(
        fontSize: AppResponsive.bodyFontSize(context),
        color: value < 0 ? AppColors.danger : null,
      ),
    );
  }

  Widget _statLine(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
    bool indent = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: AppResponsive.smallSpacing(context),
        left: indent ? AppResponsive.mediumSpacing(context) : 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: bold ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = ReportService();

    return ReportPageScaffold(
      title: 'Discounts Given',
      subtitle: 'Discounts, price overrides and points redeemed',
      featureNoun: 'discounts',
      exportFileName: 'discounts_given',
      rowUnit: 'sales',
      emptyIcon: Icons.local_offer_outlined,
      emptyTitle: 'No discounts given',
      emptyMessage:
          'No sale in this period was discounted, overridden or paid with points.',
      loader: (start, end) =>
          service.getDiscountReport(startDate: start, endDate: end),
      summaryCards: (rows) {
        final given = _sum(rows, 'totalGivenAway');
        final list = _sum(rows, 'listValue');
        final pct = list == 0 ? 0.0 : given / list * 100;

        return [
          ReportSummaryCard(
            title: 'Total Given Away',
            value: formatMoney(given),
            subtitle:
                'across ${rows.length} sale${rows.length == 1 ? '' : 's'}',
            icon: Icons.card_giftcard_rounded,
            color: AppColors.warning,
          ),
          ReportSummaryCard(
            title: 'List Value',
            value: formatMoney(list),
            subtitle: 'before any giveaway',
            icon: Icons.sell_rounded,
            color: AppColors.info,
          ),
          ReportSummaryCard(
            title: 'Giveaway Rate',
            value: '${pct.toStringAsFixed(1)}%',
            subtitle: 'of list value',
            icon: Icons.percent_rounded,
            color: pct <= 5
                ? AppColors.success
                : pct <= 15
                ? AppColors.warning
                : AppColors.danger,
          ),
        ];
      },
      detail: (context, rows) {
        final bill = _sum(rows, 'billDiscount');
        final line = _sum(rows, 'lineDiscount');
        final override = _sum(rows, 'overrideDelta');
        final loyalty = _sum(rows, 'loyaltyValue');
        final points = rows.fold<int>(
          0,
          (s, r) => s + ((r['loyaltyPointsUsed'] as int?) ?? 0),
        );
        final hasReturns = rows.any((r) => r['isReturn'] as bool);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ReportCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Where it went',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.subheadingFontSize(context),
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: AppResponsive.mediumSpacing(context)),
                  _statLine(context, 'Bill Discount', formatMoney(bill)),
                  _statLine(
                    context,
                    'Item (Line) Discounts',
                    formatMoney(line),
                  ),
                  _statLine(
                    context,
                    'Subtotal — Discounts',
                    formatMoney(bill + line),
                    indent: true,
                  ),
                  _statLine(context, 'Price Overrides', formatMoney(override)),
                  _statLine(
                    context,
                    'Loyalty Redemption',
                    '${formatMoney(loyalty)}  ($points pts)',
                  ),
                  const Divider(height: 20),
                  _statLine(
                    context,
                    'Total Given Away',
                    formatMoney(bill + line + override + loyalty),
                    bold: true,
                  ),
                ],
              ),
            ),
            if (loyalty > 0 && hasReturns) ...[
              SizedBox(height: AppResponsive.mediumSpacing(context)),
              const ReportNotice(
                message:
                    'Redeemed points are not returned to the customer when a '
                    'sale is refunded, so a refunded sale still shows its '
                    'redemption here.',
                icon: Icons.loyalty_rounded,
              ),
            ],
          ],
        );
      },
      columns: (context) => [
        ReportTable.column(context, 'Date'),
        ReportTable.column(context, 'Customer'),
        ReportTable.column(context, 'Reason'),
        ReportTable.column(context, 'List Value', numeric: true),
        ReportTable.column(context, 'Discount', numeric: true),
        ReportTable.column(context, 'Override', numeric: true),
        ReportTable.column(context, 'Points', numeric: true),
        ReportTable.column(context, 'Total Given', numeric: true),
        ReportTable.column(context, '%', numeric: true),
      ],
      rowBuilder: (context, row) => DataRow(
        cells: [
          DataCell(Text(_date(row['date'] as String))),
          DataCell(Text(row['customerName'] as String)),
          DataCell(Text(_reason(row))),
          DataCell(_money(context, row['listValue'] as double)),
          DataCell(_money(context, row['discountTotal'] as double)),
          DataCell(_money(context, row['overrideDelta'] as double)),
          DataCell(Text('${row['loyaltyPointsUsed']}')),
          DataCell(_money(context, row['totalGivenAway'] as double)),
          DataCell(Text('${(row['giveawayPct'] as num).toStringAsFixed(1)}%')),
        ],
      ),
      exportData: (rows) => ReportExportData(
        headers: const [
          'Date',
          'Invoice',
          'Customer',
          'Payment',
          'Type',
          'List Value',
          'Bill Discount',
          'Item Discount',
          'Discount Total',
          'Price Override',
          'Points Used',
          'Points Value',
          'Total Given Away',
          'Net Total',
          'Giveaway %',
          'Bill Discount Reason',
          'Line Discount Reasons',
          'Override Reasons',
          'Staff',
        ],
        rows: rows
            .map(
              (r) => [
                _date(r['date'] as String),
                r['saleId'],
                r['customerName'],
                r['paymentType'],
                (r['isReturn'] as bool) ? 'Return' : 'Sale',
                ReportExportService.formatCurrency(r['listValue'] as double),
                ReportExportService.formatCurrency(r['billDiscount'] as double),
                ReportExportService.formatCurrency(r['lineDiscount'] as double),
                ReportExportService.formatCurrency(
                  r['discountTotal'] as double,
                ),
                ReportExportService.formatCurrency(
                  r['overrideDelta'] as double,
                ),
                r['loyaltyPointsUsed'],
                ReportExportService.formatCurrency(r['loyaltyValue'] as double),
                ReportExportService.formatCurrency(
                  r['totalGivenAway'] as double,
                ),
                ReportExportService.formatCurrency(r['netTotal'] as double),
                '${(r['giveawayPct'] as num).toStringAsFixed(1)}%',
                r['discountReason'] ?? '',
                r['lineDiscountReasons'] ?? '',
                r['overrideReasons'] ?? '',
                r['staffName'],
              ],
            )
            .toList(),
        summary: {
          'Sales': rows.length,
          'List Value': ReportExportService.formatCurrency(
            _sum(rows, 'listValue'),
          ),
          'Bill Discount': ReportExportService.formatCurrency(
            _sum(rows, 'billDiscount'),
          ),
          'Item Discount': ReportExportService.formatCurrency(
            _sum(rows, 'lineDiscount'),
          ),
          'Price Overrides': ReportExportService.formatCurrency(
            _sum(rows, 'overrideDelta'),
          ),
          'Loyalty Redemption': ReportExportService.formatCurrency(
            _sum(rows, 'loyaltyValue'),
          ),
          'Total Given Away': ReportExportService.formatCurrency(
            _sum(rows, 'totalGivenAway'),
          ),
        },
      ),
    );
  }
}
