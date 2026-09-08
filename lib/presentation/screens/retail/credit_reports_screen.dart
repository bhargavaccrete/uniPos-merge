import 'package:flutter/material.dart';
import 'package:billberrylite/util/common/short_ref.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

import 'package:intl/intl.dart';
import '../../../core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/credit_payment_model_218.dart';
import 'package:billberrylite/data/repositories/retail/credit_payment_repository.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/credit_report_export.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_export_button.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';

import 'customer_detail_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';

/// Credit Reports Screen - Credit Sales, Collection, Outstanding reports
class CreditReportsScreen extends StatefulWidget {
  const CreditReportsScreen({super.key});

  @override
  State<CreditReportsScreen> createState() => _CreditReportsScreenState();
}

/// Query bounds for the user-facing range: midnight to midnight with an
/// **exclusive** end.
///
/// The picker hands back midnight of the final day, and every retail query is
/// exclusive at the end — so passing it straight through dropped that whole
/// last day. [DateTimeRange] itself stays inclusive because it is what the
/// filter chip displays.
(DateTime, DateTime) _queryBounds(DateTimeRange range) {
  final start = DateTime(range.start.year, range.start.month, range.start.day);
  final end = DateTime(
    range.end.year,
    range.end.month,
    range.end.day,
  ).add(const Duration(days: 1));
  return (start, end);
}

/// The period an export covers, in the words the filter chip uses.
///
/// "All time" rather than a blank: an export handed to an accountant has to say
/// what it covers, and an unfiltered credit report legitimately covers
/// everything the plan lets it see.
String _periodLabel(DateTimeRange? range) {
  if (range == null) return 'All time';
  final f = DateFormat('dd MMM yyyy');
  return '${f.format(range.start)} - ${f.format(range.end)}';
}

class _CreditReportsScreenState extends State<CreditReportsScreen>
    with SingleTickerProviderStateMixin {
  /// Tab index of Outstanding — a CURRENT balance, with no date dimension.
  static const int _outstandingTab = 2;

  late TabController _tabController;
  DateTimeRange? _dateFilter;
  int _tabIndex = 0;

  /// Outstanding is what customers owe RIGHT NOW; a date range means nothing to
  /// it, and it never read one. The control used to stay lit above it anyway,
  /// with a blue banner announcing a period the tab was quietly ignoring.
  ///
  /// The selection itself is KEPT, not cleared — switching back to Credit Sales
  /// restores the range the user picked.
  bool get _filterApplies => _tabIndex != _outstandingTab;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!mounted || _tabController.index == _tabIndex) return;
    setState(() => _tabIndex = _tabController.index);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateFilter,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF4CAF50)),
          ),
          child: child!,
        );
      },
    );

    if (result != null) {
      setState(() => _dateFilter = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Credit Reports',
        actions: [
          if (_filterApplies) ...[
            IconButton(
              // White on the primary fill; the amber marks an active filter,
              // which used to be green-on-white and is now invisible otherwise.
              icon: Icon(
                Icons.filter_alt_outlined,
                color: _dateFilter != null ? AppColors.warning : Colors.white,
              ),
              tooltip: 'Filter by date',
              onPressed: _selectDateRange,
            ),
            if (_dateFilter != null)
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.white),
                tooltip: 'Clear filter',
                onPressed: () => setState(() => _dateFilter = null),
              ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Credit Sales'),
            Tab(text: 'Collections'),
            Tab(text: 'Outstanding'),
          ],
        ),
      ),
      // Every amount here goes through formatMoney; MoneyScope is the single
      // subscription that re-renders them when the store's currency or decimal
      // precision changes.
      body: MoneyScope(
        child: AppResponsive.constrainedContent(
          context: context,
          alignment: Alignment.topCenter,
          maxWidth: AppResponsive.maxContentWidth(context),
          child: Column(
            children: [
              // Date Filter Info — not over Outstanding, which ignores it.
              if (_dateFilter != null && _filterApplies)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: const Color(0xFFE3F2FD),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Color(0xFF1976D2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${DateFormat('dd/MM/yy').format(_dateFilter!.start)} - ${DateFormat('dd/MM/yy').format(_dateFilter!.end)}',
                        style: TextStyle(
                          color: const Color(0xFF1976D2),
                          fontSize: AppResponsive.smallFontSize(context),
                        ),
                      ),
                    ],
                  ),
                ),

              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _CreditSalesTab(dateFilter: _dateFilter),
                    _CollectionsTab(dateFilter: _dateFilter),
                    // No `dateFilter`: it never used one, and passing it in
                    // implied otherwise.
                    const _OutstandingTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Credit Sales Tab
class _CreditSalesTab extends StatefulWidget {
  final DateTimeRange? dateFilter;

  const _CreditSalesTab({this.dateFilter});

  @override
  State<_CreditSalesTab> createState() => _CreditSalesTabState();
}

class _CreditSalesTabState extends State<_CreditSalesTab> {
  List<SaleModel> _creditSales = [];
  double _totalCreditSales = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant _CreditSalesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dateFilter != widget.dateFilter) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Through ReportService, so the plan's report-history cutoff applies the
      // same way it does on every other retail report. Reading SaleRepository
      // directly skipped it: a plan limited to 30 days still listed every
      // credit sale ever made.
      final (start, end) = widget.dateFilter == null
          ? (null, null)
          : _queryBounds(widget.dateFilter!);
      final sales = await ReportService()
          .getCreditSalesReport(startDate: start, endDate: end);

      final total = sales.fold<double>(0, (sum, s) => sum + s.totalAmount);

      setState(() {
        _creditSales = sales;
        _totalCreditSales = total;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Summary
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                'Total Credit Sales',
                formatMoney(_totalCreditSales),
                Icons.credit_card,
                Colors.orange,
              ),
              _buildSummaryItem(
                'Transactions',
                _creditSales.length.toString(),
                Icons.receipt_long,
                const Color(0xFF4CAF50),
              ),
            ],
          ),
        ),
        if (_creditSales.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ReportExportButton(onPressed: _export),
          ),
        const Divider(height: 1),

        // List
        Expanded(
          child: _creditSales.isEmpty
              ? const Center(child: Text('No credit sales found'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _creditSales.length,
                    itemBuilder: (context, index) {
                      final sale = _creditSales[index];
                      return _buildCreditSaleCard(sale);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 28, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: AppResponsive.subheadingFontSize(context),
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: AppResponsive.captionFontSize(context),
            color: Color(0xFF6B6B6B),
          ),
        ),
      ],
    );
  }

  /// Exports the rows the tab is showing — not a re-query, so the file can
  /// never cover a different period than the screen above it. The summary
  /// reads the same two figures the cards do.
  Future<void> _export() async {
    final export = CreditReportExport.creditSales(
      sales: _creditSales,
      totalCreditSales: _totalCreditSales,
      period: _periodLabel(widget.dateFilter),
    );
    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'credit_sales',
      reportTitle: 'Credit Sales',
      headers: export.headers,
      data: export.rows,
      summary: export.summary,
    );
  }

  Widget _buildCreditSaleCard(SaleModel sale) {
    final date = DateTime.tryParse(sale.date);
    final dateStr = date != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(date)
        : sale.date;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFF3E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                sale.displayNumber,
                style: TextStyle(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(sale.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  sale.statusDisplayText,
                  style: TextStyle(
                    fontSize: AppResponsive.captionFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(sale.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            dateStr,
            style: TextStyle(
              fontSize: AppResponsive.captionFontSize(context),
              color: Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                  Text(
                    formatMoney(sale.totalAmount),
                    style: TextStyle(
                      fontSize: AppResponsive.subheadingFontSize(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Due',
                    style: TextStyle(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                  Text(
                    formatMoney(sale.dueAmount),
                    style: TextStyle(
                      fontSize: AppResponsive.subheadingFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: sale.dueAmount > 0 ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'partially_paid':
        return Colors.orange;
      case 'due':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// Collections Tab
class _CollectionsTab extends StatefulWidget {
  final DateTimeRange? dateFilter;

  const _CollectionsTab({this.dateFilter});

  @override
  State<_CollectionsTab> createState() => _CollectionsTabState();
}

class _CollectionsTabState extends State<_CollectionsTab> {
  List<CreditPaymentModel> _payments = [];
  Map<String, double> _collectionByMode = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant _CollectionsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dateFilter != widget.dateFilter) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // One list, one window rule — bounds AND the plan's history cutoff, via
      // ReportService like every other retail report.
      final (start, end) = widget.dateFilter == null
          ? (null, null)
          : _queryBounds(widget.dateFilter!);
      final payments = await ReportService()
          .getCreditCollectionsReport(startDate: start, endDate: end);

      // The summary is bucketed from THAT list, so the cards can never describe
      // a different set of rows than the one below them. `bucketCollections` is
      // the single place deciding what counts as collected: write-offs and
      // return adjustments are listed but not counted.
      final collections = CreditPaymentRepository.bucketCollections(payments);

      setState(() {
        _payments = payments;
        _collectionByMode = collections;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Summary Cards
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildModeCard(
                      'Cash',
                      _collectionByMode['cash'] ?? 0,
                      const Color(0xFF4CAF50),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildModeCard(
                      'UPI',
                      _collectionByMode['upi'] ?? 0,
                      const Color(0xFF9C27B0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildModeCard(
                      'Card',
                      _collectionByMode['card'] ?? 0,
                      const Color(0xFF2196F3),
                    ),
                  ),
                  // Anything collected under a mode that is not one of the
                  // three above. Without it those cards silently failed to add
                  // up to the Total printed below them. Hidden when empty, so
                  // the ordinary bill shows the same three cards as before.
                  if ((_collectionByMode[CreditPaymentRepository.otherMode] ??
                          0) >
                      0) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildModeCard(
                        'Other',
                        _collectionByMode[CreditPaymentRepository.otherMode]!,
                        AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Collections',
                      style: TextStyle(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      formatMoney((_collectionByMode['total'] ?? 0)),
                      style: TextStyle(
                        fontSize: AppResponsive.subheadingFontSize(context),
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_payments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ReportExportButton(onPressed: _export),
          ),
        const Divider(height: 1),

        // List
        Expanded(
          child: _payments.isEmpty
              ? const Center(child: Text('No collections found'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _payments.length,
                    itemBuilder: (context, index) {
                      final payment = _payments[index];
                      return _buildPaymentCard(payment);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  /// Exports the rows on screen, with the summary bucketed from the very map
  /// the cards render — so the file cannot disagree with them.
  Future<void> _export() async {
    final export = CreditReportExport.collections(
      payments: _payments,
      buckets: _collectionByMode,
      period: _periodLabel(widget.dateFilter),
    );
    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'credit_collections',
      reportTitle: 'Credit Collections',
      headers: export.headers,
      data: export.rows,
      summary: export.summary,
    );
  }

  Widget _buildModeCard(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: AppResponsive.captionFontSize(context),
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatMoney(amount),
            style: TextStyle(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(CreditPaymentModel payment) {
    final date = DateTime.tryParse(payment.date);
    final dateStr = date != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(date)
        : payment.date;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: payment.isDebtWriteOff
                  ? Colors.grey.withOpacity(0.1)
                  : const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              payment.isDebtWriteOff ? Icons.delete_outline : Icons.payment,
              color: payment.isDebtWriteOff
                  ? Colors.grey
                  : const Color(0xFF4CAF50),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.isDebtWriteOff
                      ? 'Write-Off'
                      : payment.paymentModeDisplayText,
                  style: TextStyle(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: Color(0xFF9E9E9E),
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatMoney(payment.amount),
            style: TextStyle(
              fontSize: AppResponsive.subheadingFontSize(context),
              fontWeight: FontWeight.w600,
              color: payment.isDebtWriteOff
                  ? Colors.grey
                  : const Color(0xFF4CAF50),
            ),
          ),
        ],
      ),
    );
  }
}

/// Outstanding Tab
class _OutstandingTab extends StatefulWidget {
  const _OutstandingTab();

  @override
  State<_OutstandingTab> createState() => _OutstandingTabState();
}

class _OutstandingTabState extends State<_OutstandingTab> {
  List<Customer> _customersWithDue = [];
  double _totalOutstanding = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Already ordered by the repository: largest debt first, customer id as
      // the tie-break. The screen used to re-sort with the same comparator and
      // no tie-break, which just re-introduced the instability.
      final customers = await customerStore.getCustomersWithCredit();
      final total = customers.fold<double>(
        0,
        (sum, c) => sum + c.creditBalance,
      );

      setState(() {
        _customersWithDue = customers;
        _totalOutstanding = total;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Summary
        Container(
          padding: const EdgeInsets.all(20),
          color: const Color(0xFFFFEBEE),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Outstanding',
                    style: TextStyle(
                      fontSize: AppResponsive.bodyFontSize(context),
                      color: Color(0xFF6B6B6B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatMoney(_totalOutstanding),
                    style: TextStyle(
                      fontSize: AppResponsive.headingFontSize(context),
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_customersWithDue.length}',
                      style: TextStyle(
                        fontSize: AppResponsive.headingFontSize(context),
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                      ),
                    ),
                    Text(
                      'Customers',
                      style: TextStyle(
                        fontSize: AppResponsive.captionFontSize(context),
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (_customersWithDue.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ReportExportButton(onPressed: _export),
          ),

        // List
        Expanded(
          child: _customersWithDue.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 64,
                        color: Color(0xFF4CAF50),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No outstanding balance!',
                        style: TextStyle(
                          fontSize: AppResponsive.subheadingFontSize(context),
                          color: Color(0xFF6B6B6B),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _customersWithDue.length,
                    itemBuilder: (context, index) {
                      final customer = _customersWithDue[index];
                      return _buildCustomerCard(customer);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _export() async {
    final export = CreditReportExport.outstanding(
      customers: _customersWithDue,
      totalOutstanding: _totalOutstanding,
      asAt: DateTime.now(),
    );
    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'credit_outstanding',
      reportTitle: 'Outstanding Credit',
      headers: export.headers,
      data: export.rows,
      summary: export.summary,
    );
  }

  Widget _buildCustomerCard(Customer customer) {
    final percentage = _totalOutstanding > 0
        ? (customer.creditBalance / _totalOutstanding * 100)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CustomerDetailScreen(customer: customer),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.red.withOpacity(0.1),
                    child: Text(
                      (customer.name?.isNotEmpty ?? false)
                          ? customer.name![0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name ?? '',
                          style: TextStyle(
                            fontSize: AppResponsive.bodyFontSize(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          customer.phone ?? '',
                          style: TextStyle(
                            fontSize: AppResponsive.captionFontSize(context),
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatMoney(customer.creditBalance),
                        style: TextStyle(
                          fontSize: AppResponsive.subheadingFontSize(context),
                          fontWeight: FontWeight.w700,
                          color: Colors.red,
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: AppResponsive.captionFontSize(context),
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Progress bar showing percentage of total
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: const Color(0xFFFFEBEE),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
