import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_model.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/restaurant/restaurant_purchase_report_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_body.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_export_button.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_notice.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_period.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_period_filter_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_row.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// What is owed to each supplier, how overdue it is, and the movements behind
/// it.
///
/// **Two modes in one screen**, because they answer two halves of one
/// question:
///
/// - **Overview** (no supplier picked) — every supplier carrying a balance,
///   aged into 0-30 / 31-60 / 61-90 / 90+. **No period filter**: a balance is
///   as-of-now, it does not belong to a month.
/// - **Statement** (a supplier picked) — that supplier's ledger with a running
///   balance, filtered by period, opening with a brought-forward line so the
///   running total starts from the truth.
///
/// Composed from the kit rather than `ReportPageScaffold` because the two
/// modes are two datasets and only one of them has a date dimension.
class RestaurantSupplierStatementReportScreen extends StatefulWidget {
  const RestaurantSupplierStatementReportScreen({super.key});

  @override
  State<RestaurantSupplierStatementReportScreen> createState() =>
      _RestaurantSupplierStatementReportScreenState();
}

class _RestaurantSupplierStatementReportScreenState
    extends State<RestaurantSupplierStatementReportScreen> {
  final _service = RestaurantPurchaseReportService();

  String? _supplierId;
  ReportPeriod _period = ReportPeriod.thisMonth;

  List<Map<String, dynamic>>? _rows;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // RestaurantSupplierStore never self-loads, so the picker would be empty
    // on a cold start.
    restaurantSupplierStore.loadSuppliers();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final id = _supplierId;
    final rows = id == null
        ? await _service.getSupplierOutstandingAgeing()
        : await _service.getSupplierStatement(
            supplierId: id,
            startDate: reportPeriodStartBound(_period, DateTime.now()),
            endDate: reportPeriodEndBound(_period, DateTime.now()),
          );
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  String _date(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd MMM yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return MoneyScope(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: reportAppBar(
          title: 'Supplier Statement',
          subtitle: _supplierId == null
              ? 'What you owe, and how overdue it is'
              : 'Account movements and running balance',
        ),
        body: Column(
          children: [
            AppResponsive.verticalSpace(context, size: SpacingSize.small),
            _supplierPicker(),
            // The period only means something for a statement — ageing is
            // as-of-now by definition.
            if (_supplierId != null) ...[
              AppResponsive.verticalSpace(context, size: SpacingSize.small),
              ReportPeriodFilterBar(
                selected: _period,
                featureNoun: 'movements',
                // No custom range: the brought-forward anchor is computed from
                // a period start, and an open-ended custom range has none.
                periods: const [
                  ReportPeriod.today,
                  ReportPeriod.thisWeek,
                  ReportPeriod.thisMonth,
                  ReportPeriod.thisYear,
                ],
                onSelected: (p) {
                  setState(() => _period = p);
                  _load();
                },
              ),
            ],
            AppResponsive.verticalSpace(context, size: SpacingSize.small),
            Expanded(
              child: _loading
                  ? const ReportLoading()
                  : (_rows ?? const []).isEmpty
                      ? _empty()
                      : (_supplierId == null
                          ? _overview(_rows!)
                          : _statement(_rows!)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() => ReportBody(
        child: ReportEmptyState(
          icon: _supplierId == null
              ? Icons.verified_outlined
              : Icons.receipt_long_outlined,
          title: _supplierId == null ? 'Nothing outstanding' : 'No movements',
          message: _supplierId == null
              ? 'No supplier is carrying a balance.'
              : 'This supplier had no account activity in the period.',
        ),
      );

  Widget _supplierPicker() {
    final suppliers = restaurantSupplierStore.suppliers.toList();
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.getValue(
          context,
          mobile: 16.0,
          tablet: 20.0,
          desktop: 24.0,
        ),
      ),
      child: DropdownButtonFormField<String?>(
        initialValue: _supplierId,
        isExpanded: true,
        // Declaring only `border` left every OTHER state — enabled, focused —
        // on Material's defaults, so this field rendered in the framework's
        // grey/indigo instead of the app palette that AppTextField uses
        // everywhere else. Each state is named explicitly for that reason.
        decoration: InputDecoration(
          labelText: 'Supplier',
          labelStyle: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            color: AppColors.textSecondary,
          ),
          floatingLabelStyle: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            color: AppColors.primary,
          ),
          filled: true,
          fillColor: AppColors.surfaceLight,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(AppResponsive.borderRadius(context)),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(AppResponsive.borderRadius(context)),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(AppResponsive.borderRadius(context)),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
        dropdownColor: AppColors.white,
        iconEnabledColor: AppColors.textSecondary,
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Text(
              'All suppliers (ageing overview)',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
              ),
            ),
          ),
          ...suppliers.map(
            (RestaurantSupplierModel s) => DropdownMenuItem<String?>(
              value: s.supplierId,
              child: Text(
                s.name,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                ),
              ),
            ),
          ),
        ],
        onChanged: (v) {
          setState(() => _supplierId = v);
          _load();
        },
      ),
    );
  }

  // ── Overview ──────────────────────────────────────────────────────────────

  Widget _overview(List<Map<String, dynamic>> rows) {
    double sum(String key) =>
        rows.fold(0.0, (s, r) => s + (r[key] as num).toDouble());
    final outstanding = sum('closing');
    final over90 = sum('b90plus');

    return ReportBody(
      child: Column(
        children: [
          ReportSummaryRow(
            cards: [
              ReportSummaryCard(
                title: 'Suppliers Owing',
                value: '${rows.length}',
                subtitle: 'carrying a balance',
                icon: Icons.people_alt_rounded,
                color: AppColors.primary,
              ),
              ReportSummaryCard(
                title: 'Total Outstanding',
                value: formatMoney(outstanding),
                subtitle: 'owed to suppliers',
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.warning,
              ),
              ReportSummaryCard(
                title: 'Over 90 Days',
                value: formatMoney(over90),
                subtitle: 'long overdue',
                icon: Icons.priority_high_rounded,
                color: over90 > 0 ? AppColors.danger : AppColors.textSecondary,
              ),
            ],
          ),
          AppResponsive.verticalSpace(context),
          const ReportNotice(
            message: 'Ageing is calculated as of today and is independent of '
                'any period. Credits and payments are applied to the oldest '
                'invoice first.',
          ),
          AppResponsive.verticalSpace(context),
          ReportExportButton(onPressed: () => _exportOverview(rows)),
          AppResponsive.verticalSpace(context),
          ReportCard(
            child: ReportTable(
              columns: [
                ReportTable.column(context, 'Supplier'),
                ReportTable.column(context, '0-30', numeric: true),
                ReportTable.column(context, '31-60', numeric: true),
                ReportTable.column(context, '61-90', numeric: true),
                ReportTable.column(context, '90+', numeric: true),
                ReportTable.column(context, 'Outstanding', numeric: true),
              ],
              rows: rows.map(_overviewRow).toList(),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _overviewRow(Map<String, dynamic> r) {
    double v(String k) => (r[k] as num).toDouble();
    final over90 = v('b90plus');
    final advance = v('unappliedCredit');

    return DataRow(
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(r['supplierName'] as String)),
              // A negative balance is money the supplier owes us.
              if (advance > 0) ...[
                const SizedBox(width: 6),
                Text(
                  'advance',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.info,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        DataCell(Text(formatMoney(v('b0_30')))),
        DataCell(Text(formatMoney(v('b31_60')))),
        DataCell(Text(formatMoney(v('b61_90')))),
        DataCell(
          Text(
            formatMoney(over90),
            style: GoogleFonts.poppins(
              color: over90 > 0 ? AppColors.danger : null,
              fontWeight: over90 > 0 ? FontWeight.w600 : null,
            ),
          ),
        ),
        DataCell(Text(formatMoney(v('closing')))),
      ],
    );
  }

  void _exportOverview(List<Map<String, dynamic>> rows) {
    ReportExportService.showExportDialog(
      context: context,
      fileName: 'restaurant_supplier_ageing',
      reportTitle: 'Supplier Outstanding & Ageing',
      headers: const [
        'Supplier',
        '0-30',
        '31-60',
        '61-90',
        '90+',
        'Outstanding',
        'Oldest Open',
        'Days',
      ],
      data: rows
          .map(
            (r) => [
              r['supplierName'],
              ReportExportService.formatCurrency((r['b0_30'] as num).toDouble()),
              ReportExportService.formatCurrency(
                  (r['b31_60'] as num).toDouble()),
              ReportExportService.formatCurrency(
                  (r['b61_90'] as num).toDouble()),
              ReportExportService.formatCurrency(
                  (r['b90plus'] as num).toDouble()),
              ReportExportService.formatCurrency(
                  (r['closing'] as num).toDouble()),
              _date(r['oldestOpen'] as String?),
              r['oldestDays'],
            ],
          )
          .toList(),
      summary: {
        'Suppliers Owing': rows.length,
        'Total Outstanding': ReportExportService.formatCurrency(
          rows.fold(0.0, (s, r) => s + (r['closing'] as num).toDouble()),
        ),
        'Over 90 Days': ReportExportService.formatCurrency(
          rows.fold(0.0, (s, r) => s + (r['b90plus'] as num).toDouble()),
        ),
      },
    );
  }

  // ── Statement ─────────────────────────────────────────────────────────────

  Widget _statement(List<Map<String, dynamic>> rows) {
    final opening = rows.first['isBroughtForward'] == true
        ? (rows.first['balanceAfter'] as num).toDouble()
        : 0.0;
    final closing = (rows.last['balanceAfter'] as num).toDouble();
    var debits = 0.0;
    var credits = 0.0;
    for (final r in rows) {
      final a = (r['amount'] as num).toDouble();
      if (a > 0) {
        debits += a;
      } else {
        credits += -a;
      }
    }

    return ReportBody(
      child: Column(
        children: [
          ReportSummaryRow(
            cards: [
              ReportSummaryCard(
                title: 'Opening',
                value: formatMoney(opening),
                subtitle: 'brought forward',
                icon: Icons.flag_outlined,
                color: AppColors.textSecondary,
              ),
              ReportSummaryCard(
                title: 'Purchases',
                value: formatMoney(debits),
                subtitle: 'added this period',
                icon: Icons.add_circle_outline_rounded,
                color: AppColors.warning,
              ),
              ReportSummaryCard(
                title: 'Credits & Payments',
                value: formatMoney(credits),
                subtitle: 'reduced the balance',
                icon: Icons.remove_circle_outline_rounded,
                color: AppColors.success,
              ),
              ReportSummaryCard(
                title: 'Closing',
                value: formatMoney(closing),
                subtitle: 'owed at period end',
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.primary,
              ),
            ],
          ),
          AppResponsive.verticalSpace(context),
          ReportExportButton(onPressed: () => _exportStatement(rows)),
          AppResponsive.verticalSpace(context),
          ReportCard(
            child: ReportTable(
              columns: [
                ReportTable.column(context, 'Date'),
                ReportTable.column(context, 'Type'),
                ReportTable.column(context, 'Document'),
                ReportTable.column(context, 'Amount', numeric: true),
                ReportTable.column(context, 'Balance', numeric: true),
              ],
              rows: rows.map(_statementRow).toList(),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _statementRow(Map<String, dynamic> r) {
    final amount = (r['amount'] as num).toDouble();
    final bf = r['isBroughtForward'] == true;

    return DataRow(
      cells: [
        DataCell(Text(_date(r['date'] as String?))),
        DataCell(
          Text(
            r['typeDisplay'] as String,
            style: GoogleFonts.poppins(
              fontStyle: bf ? FontStyle.italic : null,
              color: bf ? AppColors.textSecondary : null,
            ),
          ),
        ),
        DataCell(
          Text((r['docNumber'] as String?) ?? (r['description'] as String)),
        ),
        DataCell(
          Text(
            // The brought-forward row is an anchor, not a movement.
            bf ? '—' : formatMoney(amount),
            style: GoogleFonts.poppins(
              color: bf
                  ? AppColors.textSecondary
                  : (amount > 0 ? AppColors.warning : AppColors.success),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        DataCell(
          Text(
            formatMoney((r['balanceAfter'] as num).toDouble()),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  void _exportStatement(List<Map<String, dynamic>> rows) {
    final name = restaurantSupplierStore.suppliers
        .where((s) => s.supplierId == _supplierId)
        .map((s) => s.name)
        .firstOrNull;

    ReportExportService.showExportDialog(
      context: context,
      fileName: 'restaurant_supplier_statement',
      reportTitle: 'Supplier Statement${name == null ? '' : ' — $name'}',
      headers: const [
        'Date',
        'Type',
        'Document',
        'Description',
        'Amount',
        'Balance',
      ],
      data: rows
          .map(
            (r) => [
              _date(r['date'] as String?),
              r['typeDisplay'],
              r['docNumber'] ?? '',
              r['description'] ?? '',
              r['isBroughtForward'] == true
                  ? ''
                  : ReportExportService.formatCurrency(
                      (r['amount'] as num).toDouble()),
              ReportExportService.formatCurrency(
                  (r['balanceAfter'] as num).toDouble()),
            ],
          )
          .toList(),
      summary: {
        'Supplier': name ?? '',
        'Movements': rows.where((r) => r['isBroughtForward'] != true).length,
        'Closing Balance': ReportExportService.formatCurrency(
          (rows.last['balanceAfter'] as num).toDouble(),
        ),
      },
    );
  }
}
