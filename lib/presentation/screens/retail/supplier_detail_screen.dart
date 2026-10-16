import 'package:flutter/material.dart';
import 'package:billberrylite/core/config/tax_id_rule.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_model_213.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_model_211.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_ledger_entry_model_179.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_claim_model_176.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_model_205.dart';
import 'package:billberrylite/data/repositories/retail/grn_repository.dart';
import 'package:billberrylite/data/repositories/retail/purchase_order_repository.dart';
import 'package:billberrylite/presentation/screens/retail/purchase_order_list_screen.dart';
import 'package:billberrylite/presentation/screens/retail/supplier_payment_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/retail/purchase_order_detail_sheet.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// One supplier's account: what is owed, how it got there, and what was bought.
///
/// Mirrors `customer_detail_screen.dart` — primary AppBar with a TabBar in
/// `bottom:`, a header card above, `MoneyScope` around the TabBarView.
///
/// The Overview tab is a **reconciliation**, not a stat sheet: its lines add up
/// to the Outstanding figure in the header. That is only possible because every
/// balance movement now writes a ledger row through
/// `SupplierStore.recordBalanceMovement`.
class SupplierDetailScreen extends StatefulWidget {
  final SupplierModel supplier;

  const SupplierDetailScreen({super.key, required this.supplier});

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late SupplierModel _supplier;

  List<SupplierLedgerEntryModel> _ledger = [];

  /// Running balance per entry id, in ledger reading order.
  Map<String, double> _running = const {};
  SupplierAccountSummary _summary = const SupplierAccountSummary();
  List<_PurchaseGroup> _purchases = [];
  bool _isLoading = true;

  /// Inclusive date filter on the Ledger tab.
  DateTimeRange? _dateFilter;

  @override
  void initState() {
    super.initState();
    _supplier = widget.supplier;
    _tabController = TabController(length: 3, vsync: this);
    // This screen holds its own supplier, but the PO detail sheet it opens
    // resolves the WhatsApp number out of supplierStore — which nothing on
    // this route was hydrating.
    supplierStore.loadSuppliers();
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final ledger = await supplierStore.getLedger(_supplier.supplierId);
    final orders = await PurchaseOrderRepository().getPurchaseOrdersBySupplier(
      _supplier.supplierId,
    );
    final receipts = await GRNRepository().getGRNsBySupplier(
      _supplier.supplierId,
    );

    if (!mounted) return;
    setState(() {
      // Re-read from the store: a payment recorded on this screen changes the
      // balance, and the widget's copy would still hold the old one.
      _supplier = supplierStore.suppliers.firstWhere(
        (s) => s.supplierId == _supplier.supplierId,
        orElse: () => _supplier,
      );
      _ledger = ledger.reversed.toList(); // newest first for display
      // Recomputed in reading order — the stored balanceAfter is entry-time
      // and reads out of sequence once anything is back-dated.
      _running = ledgerRunningBalances(ledger);
      _summary = summariseLedger(ledger);
      _purchases = _groupPurchases(orders, receipts);
      _isLoading = false;
    });
  }

  /// Receipts nested under the order they arrived against.
  ///
  /// A PO and its GRN are two different documents, but for a single-delivery
  /// order they look like duplicates side by side. Nesting shows the real
  /// relationship and makes partial deliveries obvious — two receipts simply
  /// sit under one order.
  ///
  /// Draft POs are included because a draft is still work in progress for this
  /// supplier. Unconfirmed GRNs are not: they moved neither stock nor money.
  List<_PurchaseGroup> _groupPurchases(
    List<PurchaseOrderModel> orders,
    List<GRNModel> receipts,
  ) {
    final confirmed = receipts
        .where((g) => g.statusEnum == GRNStatus.confirmed)
        .toList();

    final groups = orders.map((po) {
      final own = confirmed.where((g) => g.poId == po.poId).toList()
        ..sort((a, b) => a.receivedDate.compareTo(b.receivedDate));
      return _PurchaseGroup(order: po, receipts: own);
    }).toList();

    // Every GRN carries a poId, so an orphan means its PO was removed — which
    // the delete guard prevents. Surface any that slip through rather than
    // silently dropping money from the list.
    final claimed = groups
        .expand((g) => g.receipts)
        .map((g) => g.grnId)
        .toSet();
    final orphans = confirmed.where((g) => !claimed.contains(g.grnId));
    for (final orphan in orphans) {
      groups.add(_PurchaseGroup(order: null, receipts: [orphan]));
    }

    groups.sort((a, b) => b.sortDate.compareTo(a.sortDate));
    return groups;
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    final date = DateTime.tryParse(iso);
    return date == null ? iso : DateFormat('dd MMM yyyy').format(date);
  }

  // ==================== ACTIONS ====================

  Future<void> _recordPayment({required bool isAdjustment}) async {
    final saved = await showSupplierPaymentDialog(
      context: context,
      supplier: _supplier,
      isAdjustment: isAdjustment,
    );
    if (saved == true) await _load();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateFilter,
    );
    if (picked != null) setState(() => _dateFilter = picked);
  }

  List<SupplierLedgerEntryModel> get _filteredLedger {
    final filter = _dateFilter;
    if (filter == null) return _ledger;
    return _ledger.where((e) {
      final date = DateTime.tryParse(e.date);
      if (date == null) return false;
      // End-of-day on the closing date, so entries made that afternoon aren't
      // silently dropped.
      return date.isAfter(filter.start.subtract(const Duration(days: 1))) &&
          date.isBefore(filter.end.add(const Duration(days: 1)));
    }).toList();
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: _supplier.name.trim().isEmpty
            ? 'Unnamed supplier'
            : _supplier.name,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withValues(alpha: 0.7),
          indicatorColor: AppColors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Ledger'),
            Tab(text: 'Purchases'),
          ],
        ),
      ),
      body: MoneyScope(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildLedgerTab(),
                  _buildPurchasesTab(),
                ],
              ),
      ),
    );
  }

  EdgeInsets get _pagePad => EdgeInsets.fromLTRB(
    AppResponsive.padding(context).left,
    AppResponsive.mediumSpacing(context),
    AppResponsive.padding(context).left,
    AppResponsive.extraLargeSpacing(context),
  );

  // ==================== OVERVIEW ====================

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: _pagePad,
        child: AppResponsive.constrainedContent(
          context: context,
          alignment: Alignment.topCenter,
          maxWidth: AppResponsive.maxCardWidth(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildContactCard(),
              SizedBox(height: AppResponsive.largeSpacing(context)),
              _buildOutstandingCard(),
              SizedBox(height: AppResponsive.largeSpacing(context)),
              _buildReconciliationCard(),
              SizedBox(height: AppResponsive.largeSpacing(context)),
              _buildExposureCards(),
              SizedBox(height: AppResponsive.largeSpacing(context)),
              _buildRecentActivityCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard() {
    final details = <String>[
      if (_supplier.phone?.isNotEmpty ?? false) _supplier.phone!,
      if (_supplier.gstNumber?.isNotEmpty ?? false)
        '${TaxIdRule.printLabel}: ${_supplier.gstNumber}',
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: AppResponsive.avatarSize(context) / 2,
            backgroundColor: AppColors.white.withValues(alpha: 0.18),
            child: Text(
              _supplier.name.trim().isEmpty
                  ? '?'
                  : _supplier.name.trim()[0].toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.headingFontSize(context),
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
          ),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _supplier.name.trim().isEmpty
                      ? 'Unnamed supplier'
                      : _supplier.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    details.join('  •  '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: AppColors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
                if (_supplier.address?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 2),
                  Text(
                    _supplier.address!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: AppColors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutstandingCard() {
    final balance = _supplier.currentBalance;
    final isAdvance = balance < 0;
    final accent = balance > 0 ? AppColors.danger : AppColors.success;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAdvance ? 'Advance with supplier' : 'Outstanding payable',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatMoney(balance.abs()),
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.getValue(
                context,
                mobile: 30.0,
                tablet: 34.0,
                desktop: 38.0,
              ),
              fontWeight: FontWeight.w700,
              color: balance == 0 ? AppColors.textPrimary : accent,
            ),
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _recordPayment(isAdjustment: false),
                  icon: Icon(
                    Icons.payments_outlined,
                    size: AppResponsive.smallIconSize(context),
                  ),
                  label: Text(
                    'Record Payment',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      vertical: AppResponsive.getValue(
                        context,
                        mobile: 12.0,
                        tablet: 14.0,
                        desktop: 16.0,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppResponsive.smallBorderRadius(context),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppResponsive.smallSpacing(context)),
              // Corrections are kept off the primary button so a typo fix is
              // never recorded as a payment.
              IconButton(
                onPressed: () => _recordPayment(isAdjustment: true),
                tooltip: 'Post an adjustment',
                icon: Icon(
                  Icons.tune_rounded,
                  color: AppColors.textSecondary,
                  size: AppResponsive.iconSize(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The lines here must add up to the Outstanding figure above — that is the
  /// whole point of the tab, and why four unrelated stats would be weaker.
  Widget _buildReconciliationCard() {
    final s = _summary;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Account summary'),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          if (s.opening != 0) _amountLine('Opening balance', s.opening),
          _amountLine('Purchases billed', s.purchases),
          if (s.returnCredits != 0)
            _amountLine('Returns credited', s.returnCredits),
          if (s.claimCredits != 0)
            _amountLine('Claims settled', s.claimCredits),
          if (s.payments != 0) _amountLine('Payments', s.payments),
          if (s.adjustments != 0) _amountLine('Adjustments', s.adjustments),
          const Divider(height: 20, color: AppColors.divider),
          _amountLine(
            s.isAdvance ? 'Advance' : 'Outstanding',
            s.closing,
            bold: true,
          ),
        ],
      ),
    );
  }

  /// Forward-looking exposure. Outstanding is what already happened; these two
  /// are what is still in flight.
  Widget _buildExposureCards() {
    final openReturns = damagedGoodsStore.purchaseReturns
        .where((r) => r.supplierId == _supplier.supplierId && r.isOpen)
        .fold<double>(0, (sum, r) => sum + r.totalAmount);
    final openClaims = damagedGoodsStore.supplierClaims
        .where(
          (c) =>
              c.supplierId == _supplier.supplierId &&
              c.statusEnum != SupplierClaimStatus.rejected &&
              !c.isCreditApplied,
        )
        .fold<double>(0, (sum, c) => sum + c.totalAmount);

    final onOrder = purchaseOrderStore.purchaseOrders
        .where((po) => po.supplierId == _supplier.supplierId && po.canReceive)
        .toList();
    final onOrderValue = onOrder.fold<double>(0, (sum, po) {
      final progress = purchaseOrderStore.progressFor(po);
      final remaining = po.estimatedTotal - progress.billedAmount;
      return sum + (remaining > 0 ? remaining : 0);
    });

    return Row(
      children: [
        Expanded(
          child: _statCard(
            'Pending recovery',
            formatMoney(openReturns + openClaims),
            'returns & claims not yet credited',
            Icons.assignment_return_outlined,
            AppColors.warning,
          ),
        ),
        SizedBox(width: AppResponsive.smallSpacing(context)),
        Expanded(
          child: _statCard(
            'On order',
            formatMoney(onOrderValue),
            '${onOrder.length} order${onOrder.length == 1 ? '' : 's'} awaiting delivery',
            Icons.local_shipping_outlined,
            AppColors.info,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivityCard() {
    final recent = _ledger.take(5).toList();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _cardTitle('Recent activity')),
              if (_ledger.length > 5)
                TextButton(
                  onPressed: () => _tabController.animateTo(1),
                  child: Text(
                    'View All',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          if (recent.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: AppResponsive.mediumSpacing(context),
              ),
              child: Text(
                'No activity yet.',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            for (final entry in recent) _ledgerRow(entry, compact: true),
        ],
      ),
    );
  }

  // ==================== LEDGER ====================

  Widget _buildLedgerTab() {
    final entries = _filteredLedger;

    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: entries.isEmpty
              ? const AppEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No entries',
                  message:
                      'Receipts, credits and payments will appear here as they happen.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: _pagePad,
                    itemCount: entries.length,
                    itemBuilder: (context, index) =>
                        AppResponsive.constrainedContent(
                          context: context,
                          alignment: Alignment.topCenter,
                          maxWidth: AppResponsive.maxCardWidth(context),
                          child: _card(child: _ledgerRow(entries[index])),
                        ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: AppColors.white,
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.padding(context).left,
        vertical: AppResponsive.smallSpacing(context),
      ),
      child: AppResponsive.constrainedContent(
        context: context,
        alignment: Alignment.topCenter,
        maxWidth: AppResponsive.maxCardWidth(context),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _dateFilter == null
                    ? 'All entries'
                    : '${_formatDate(_dateFilter!.start.toIso8601String())} — ${_formatDate(_dateFilter!.end.toIso8601String())}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (_dateFilter != null)
              IconButton(
                icon: Icon(
                  Icons.clear_rounded,
                  size: AppResponsive.smallIconSize(context),
                  color: AppColors.textSecondary,
                ),
                tooltip: 'Clear filter',
                onPressed: () => setState(() => _dateFilter = null),
              ),
            IconButton(
              icon: Icon(
                Icons.date_range_rounded,
                size: AppResponsive.iconSize(context),
                color: AppColors.primary,
              ),
              tooltip: 'Filter by date',
              onPressed: _selectDateRange,
            ),
          ],
        ),
      ),
    );
  }

  /// Coloured by SIGN, not by type — what matters at a glance is whether a row
  /// grew or shrank what is owed.
  Widget _ledgerRow(SupplierLedgerEntryModel entry, {bool compact = false}) {
    final isDebit = entry.isDebit;
    final color = isDebit ? AppColors.danger : AppColors.success;

    final subtitle = <String>[
      _formatDate(entry.date),
      if (entry.docNumber != null) entry.docNumber!,
      if (entry.paymentMode != null) entry.paymentMode!.toUpperCase(),
      if (entry.referenceNo != null) 'Ref ${entry.referenceNo}',
    ].join('  •  ');

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? AppResponsive.smallSpacing(context) / 2 : 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: AppResponsive.smallSpacing(context)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isDebit ? '+' : '−'}${formatMoney(entry.amount.abs())}',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatMoney((_running[entry.entryId] ?? entry.balanceAfter).abs()),
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== PURCHASES ====================

  Widget _buildPurchasesTab() {
    if (_purchases.isEmpty) {
      return const AppEmptyState(
        icon: Icons.assignment_outlined,
        title: 'Nothing purchased yet',
        message: 'Purchase orders and goods receipts will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        padding: _pagePad,
        itemCount: _purchases.length + 1,
        itemBuilder: (context, index) {
          if (index == _purchases.length) {
            return AppResponsive.constrainedContent(
              context: context,
              alignment: Alignment.topCenter,
              maxWidth: AppResponsive.maxCardWidth(context),
              child: Padding(
                padding: EdgeInsets.only(
                  top: AppResponsive.mediumSpacing(context),
                ),
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      // Pre-filtered: arriving on every supplier's orders would
                      // throw away the context this screen is about.
                      builder: (_) =>
                          PurchaseOrderListScreen(initialSupplier: _supplier),
                    ),
                  ),
                  icon: Icon(
                    Icons.open_in_new_rounded,
                    size: AppResponsive.smallIconSize(context),
                  ),
                  label: Text(
                    'Open in Purchase Orders',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }
          return AppResponsive.constrainedContent(
            context: context,
            alignment: Alignment.topCenter,
            maxWidth: AppResponsive.maxCardWidth(context),
            child: _purchaseGroupCard(_purchases[index]),
          );
        },
      ),
    );
  }

  /// One order with its receipts nested inside it.
  ///
  /// Tapping opens the same detail sheet the Purchase Orders screen uses —
  /// shared rather than reimplemented, so Edit / Mark Sent / Receive behave
  /// identically wherever an order is opened from.
  Widget _purchaseGroupCard(_PurchaseGroup group) {
    final po = group.order;

    return _card(
      onTap: po == null
          ? null
          : () => showPurchaseOrderDetailSheet(
              context: context,
              po: po,
              // The sheet can receive goods or mark an order sent, both of
              // which move the balance this screen is built around.
              onChanged: _load,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (po != null)
            _docHeader(
              badge: 'PO',
              accent: AppColors.info,
              number: po.poNumber,
              meta:
                  '${_formatDate(po.createdAt)}  •  ${po.totalItems} ordered  •  ${_PurchaseGroup.poStatusLabel(po.statusEnum)}',
              amount: po.estimatedTotal,
              amountLabel: 'ordered',
            )
          else
            // Only reachable if a PO was removed out from under its receipt.
            _docHeader(
              badge: 'GRN',
              accent: AppColors.warning,
              number: 'Receipt without an order',
              meta: 'The purchase order is missing',
              amount: group.billedTotal,
              amountLabel: 'billed',
            ),

          if (group.receipts.isEmpty && po != null)
            Padding(
              padding: EdgeInsets.only(
                top: AppResponsive.smallSpacing(context),
              ),
              child: Text(
                po.statusEnum == POStatus.cancelled
                    ? 'Cancelled before any delivery.'
                    : 'Nothing received yet.',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            for (final grn in group.receipts) _receiptLine(grn),
        ],
      ),
    );
  }

  Widget _docHeader({
    required String badge,
    required Color accent,
    required String number,
    required String meta,
    required double amount,
    required String amountLabel,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.smallSpacing(context),
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badge,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ),
        SizedBox(width: AppResponsive.smallSpacing(context)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                number,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: AppResponsive.smallSpacing(context)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatMoney(amount),
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              amountLabel,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// A receipt under its order. Indented and rule-led so it reads as belonging
  /// to the row above rather than as a sibling document.
  Widget _receiptLine(GRNModel grn) {
    return Padding(
      padding: EdgeInsets.only(
        top: AppResponsive.smallSpacing(context),
        left: AppResponsive.smallSpacing(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 2,
            height: 30,
            margin: EdgeInsets.only(right: AppResponsive.smallSpacing(context)),
            color: AppColors.divider,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  grn.grnNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${_formatDate(grn.receivedDate)}  •  ${grn.totalReceivedQty} received',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: AppResponsive.smallSpacing(context)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(grn.totalAmount ?? 0),
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
              Text(
                'billed',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== SHARED BITS ====================

  Widget _card({required Widget child, VoidCallback? onTap}) {
    final radius = AppResponsive.borderRadius(context);
    final decorated = Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.divider),
      ),
      // Clip so the InkWell ripple follows the rounded corners instead of
      // painting a square over them.
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
            child: child,
          ),
        ),
      ),
    );
    return decorated;
  }

  Widget _cardTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: AppResponsive.bodyFontSize(context),
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _amountLine(String label, double amount, {bool bold = false}) {
    final showSign = !bold && amount != 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                color: bold ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            showSign
                ? '${amount > 0 ? '+' : '−'}${formatMoney(amount.abs())}'
                : formatMoney(amount.abs()),
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: bold
                  ? (amount > 0 ? AppColors.danger : AppColors.success)
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    String title,
    String value,
    String caption,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppResponsive.iconSize(context), color: color),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.subheadingFontSize(context),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            maxLines: 2,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// One purchase order with the receipts that arrived against it.
///
/// [order] is null only for a receipt whose order has gone missing — the
/// supplier delete guard makes that unreachable, but the list surfaces it
/// rather than dropping billed money on the floor.
class _PurchaseGroup {
  final PurchaseOrderModel? order;
  final List<GRNModel> receipts;

  const _PurchaseGroup({required this.order, required this.receipts});

  /// Sort by the order date so a group stays put as deliveries trickle in.
  String get sortDate =>
      order?.createdAt ?? (receipts.isEmpty ? '' : receipts.first.receivedDate);

  double get billedTotal =>
      receipts.fold<double>(0, (sum, g) => sum + (g.totalAmount ?? 0));

  static String poStatusLabel(POStatus status) {
    switch (status) {
      case POStatus.draft:
        return 'Draft';
      case POStatus.sent:
        return 'Sent';
      case POStatus.partiallyCompleted:
        return 'Partially received';
      case POStatus.fullyCompleted:
        return 'Completed';
      case POStatus.cancelled:
        return 'Cancelled';
      case POStatus.closed:
        return 'Closed short';
    }
  }
}
