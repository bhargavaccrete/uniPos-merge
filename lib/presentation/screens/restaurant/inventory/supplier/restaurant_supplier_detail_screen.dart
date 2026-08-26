import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_ledger_entry_model.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/domain/store/restaurant/restaurant_supplier_store.dart';
import 'package:billberrylite/presentation/screens/restaurant/inventory/supplier/restaurant_supplier_form_sheet.dart';
import 'package:billberrylite/presentation/screens/restaurant/inventory/supplier/restaurant_supplier_payment_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// One supplier's account: who they are, what is owed, why, and every document
/// raised against them.
///
/// The Ledger tab is the source of truth for history — `currentBalance` is only
/// ever moved by `RestaurantSupplierStore.recordBalanceMovement`, which writes a
/// row here for every movement.
class RestaurantSupplierDetailScreen extends StatefulWidget {
  final String supplierId;

  const RestaurantSupplierDetailScreen({super.key, required this.supplierId});

  @override
  State<RestaurantSupplierDetailScreen> createState() =>
      _RestaurantSupplierDetailScreenState();
}

class _RestaurantSupplierDetailScreenState
    extends State<RestaurantSupplierDetailScreen> {
  RestaurantSupplierModel? _supplier;
  List<RestaurantSupplierLedgerEntryModel> _ledger = const [];
  RestaurantSupplierAccountSummary _summary =
      const RestaurantSupplierAccountSummary();
  RestaurantSupplierReferences _references =
      const RestaurantSupplierReferences();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final supplier =
        restaurantSupplierRepository.getSupplierById(widget.supplierId);
    if (supplier == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final ledger = await restaurantSupplierStore.getLedger(widget.supplierId);
    final references =
        await restaurantSupplierStore.referencesFor(widget.supplierId);

    if (!mounted) return;
    setState(() {
      _supplier = supplier;
      _ledger = ledger;
      _summary = summariseRestaurantLedger(ledger);
      _references = references;
      _loading = false;
    });
  }

  Future<void> _edit() async {
    final updated =
        await showRestaurantSupplierFormSheet(context, existing: _supplier);
    if (updated != null) await _load();
  }

  Future<void> _recordPayment() async {
    final saved = await showRestaurantSupplierPaymentDialog(
      context: context,
      supplier: _supplier!,
    );
    if (saved == true) await _load();
  }

  /// A supplier with any document against them can never be deleted — those
  /// records resolve the supplier name by id, so removing it would orphan them.
  Future<void> _delete() async {
    if (!_references.isEmpty) {
      await showAppErrorDialog(
        context: context,
        title: 'Cannot delete supplier',
        message:
            '${_supplier!.name} is referenced by ${_references.blockingSummary}. '
            'Deleting the supplier would leave those documents pointing at nothing.\n\n'
            'Keep the supplier so their purchase history stays readable.',
      );
      return;
    }

    if (_supplier!.currentBalance != 0) {
      await showAppErrorDialog(
        context: context,
        title: 'Cannot delete supplier',
        message:
            '${_supplier!.name} still has an outstanding balance of '
            '${formatMoney(_supplier!.currentBalance.abs())}. '
            'Settle the balance first, then delete.',
      );
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete supplier?',
      message:
          '${_supplier!.name} has no purchase orders, GRNs, returns or claims. '
          'This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;

    await restaurantSupplierStore.deleteSupplier(widget.supplierId);
    if (!mounted) return;
    NotificationService.instance.showSuccess('Supplier deleted');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: buildPrimaryAppBar(title: 'Supplier'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_supplier == null) {
      return Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: buildPrimaryAppBar(title: 'Supplier'),
        body: const AppEmptyState(
          icon: Icons.person_off_rounded,
          title: 'Supplier not found',
          message: 'This supplier may have been deleted.',
        ),
      );
    }

    return MoneyScope(
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: AppColors.surfaceLight,
          appBar: buildPrimaryAppBar(
            title: _supplier!.name,
            actions: [
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined),
                onPressed: _edit,
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: _delete,
              ),
            ],
            bottom: TabBar(
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Ledger'),
                Tab(text: 'Documents'),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _recordPayment,
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.account_balance_wallet_rounded),
            label: Text(
              'Record Payment',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
          body: TabBarView(
            children: [
              _overviewTab(),
              _ledgerTab(),
              _documentsTab(),
            ],
          ),
        ),
      ),
    );
  }

  EdgeInsets get _pagePadding => EdgeInsets.fromLTRB(
        AppResponsive.getValue(context, mobile: 16.0, tablet: 20.0, desktop: 24.0),
        16,
        AppResponsive.getValue(context, mobile: 16.0, tablet: 20.0, desktop: 24.0),
        96,
      );

  // ──────────────────────────── Overview ────────────────────────────

  Widget _overviewTab() {
    return ListView(
      padding: _pagePadding,
      children: [
        _outstandingCard(),
        const SizedBox(height: 14),
        _contactCard(),
        const SizedBox(height: 14),
        _reconciliationCard(),
        const SizedBox(height: 14),
        _exposureCard(),
      ],
    );
  }

  Widget _outstandingCard() {
    final balance = _supplier!.currentBalance;
    final isAdvance = balance < 0;
    final settled = balance == 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            settled
                ? 'Account settled'
                : (isAdvance ? 'Advance with supplier' : 'Currently owed'),
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatMoney(balance.abs()),
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.getValue(context,
                  mobile: 26.0, tablet: 28.0, desktop: 30.0),
              fontWeight: FontWeight.w700,
              color: settled
                  ? AppColors.textPrimary
                  : (isAdvance ? AppColors.info : AppColors.danger),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isAdvance
                ? 'You have paid more than was billed.'
                : 'Positive balance means money is owed to this supplier.',
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactCard() {
    final s = _supplier!;
    final rows = <({IconData icon, String label, String value})>[
      if ((s.phone ?? '').isNotEmpty)
        (icon: Icons.phone_outlined, label: 'Phone', value: s.phone!),
      if ((s.address ?? '').isNotEmpty)
        (icon: Icons.location_on_outlined, label: 'Address', value: s.address!),
      if ((s.gstNumber ?? '').isNotEmpty)
        (icon: Icons.receipt_long_outlined, label: 'GST', value: s.gstNumber!),
    ];

    return _card(
      title: 'Contact',
      icon: Icons.contact_page_outlined,
      child: rows.isEmpty
          ? Text(
              'No contact details recorded.',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            )
          : Column(
              children: [
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(row.icon,
                            size: 17, color: AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Text(
                          row.label,
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            row.value,
                            textAlign: TextAlign.right,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  /// Opening + purchases − credits − payments ± adjustments must equal the
  /// closing balance. When it doesn't, something moved the balance outside the
  /// choke point, and this card says so rather than hiding it.
  Widget _reconciliationCard() {
    final drift = (_summary.impliedClosing - _summary.closing).abs();
    final reconciles = drift < 0.01;

    return _card(
      title: 'Reconciliation',
      icon: Icons.balance_rounded,
      child: Column(
        children: [
          _summaryRow('Opening balance', _summary.opening),
          _summaryRow('Purchases (GRNs)', _summary.purchases),
          _summaryRow('Return credits', _summary.returnCredits),
          _summaryRow('Claim credits', _summary.claimCredits),
          _summaryRow('Payments', _summary.payments),
          _summaryRow('Adjustments', _summary.adjustments),
          const Divider(height: 20),
          _summaryRow('Closing balance', _summary.closing, bold: true),
          if (!reconciles) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 17, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ledger does not reconcile — off by ${formatMoney(drift)}. '
                      'A balance movement bypassed the journal.',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              color: bold ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            formatMoney(value),
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: value < 0 ? AppColors.success : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _exposureCard() {
    return _card(
      title: 'Documents',
      icon: Icons.folder_open_rounded,
      child: Row(
        children: [
          _exposureTile('POs', _references.purchaseOrders.length,
              Icons.receipt_long_rounded, AppColors.info),
          _exposureTile('GRNs', _references.grns.length,
              Icons.inventory_2_rounded, AppColors.success),
          _exposureTile('Returns', _references.purchaseReturns.length,
              Icons.assignment_return_rounded, AppColors.orange),
          _exposureTile('Claims', _references.claims.length,
              Icons.gavel_rounded, AppColors.accent),
        ],
      ),
    );
  }

  Widget _exposureTile(String label, int count, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────── Ledger ─────────────────────────────

  Widget _ledgerTab() {
    if (_ledger.isEmpty) {
      return const AppEmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'No movements yet',
        message:
            'Confirming a GRN, recording a credit note, settling a claim or paying this supplier will each appear here.',
      );
    }

    // Newest first for reading; the stored balanceAfter already carries the
    // running total, so no re-derivation is needed.
    final rows = _ledger.reversed.toList();

    return ListView.separated(
      padding: _pagePadding,
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _ledgerRow(rows[i]),
    );
  }

  Widget _ledgerRow(RestaurantSupplierLedgerEntryModel entry) {
    final isDebit = entry.isDebit;
    final color = isDebit ? AppColors.danger : AppColors.success;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.typeDisplay,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${isDebit ? '+' : '−'}${formatMoney(entry.amount.abs())}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.description,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                _formatDate(entry.date),
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              if (entry.docNumber != null) ...[
                const Text('  ·  ',
                    style: TextStyle(color: AppColors.textSecondary)),
                Text(
                  entry.docNumber!,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (entry.paymentMode != null) ...[
                const Text('  ·  ',
                    style: TextStyle(color: AppColors.textSecondary)),
                Text(
                  entry.paymentMode!,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                'Bal ${formatMoney(entry.balanceAfter)}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if ((entry.referenceNo ?? '').isNotEmpty ||
              (entry.note ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              [
                if ((entry.referenceNo ?? '').isNotEmpty)
                  'Ref: ${entry.referenceNo}',
                if ((entry.note ?? '').isNotEmpty) entry.note!,
              ].join('  ·  '),
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────── Documents ───────────────────────────

  Widget _documentsTab() {
    if (_references.isEmpty) {
      return const AppEmptyState(
        icon: Icons.folder_open_rounded,
        title: 'No documents yet',
        message:
            'Purchase orders, GRNs, returns and claims raised against this supplier will be listed here.',
      );
    }

    return ListView(
      padding: _pagePadding,
      children: [
        if (_references.purchaseOrders.isNotEmpty)
          _documentSection(
            'Purchase Orders',
            Icons.receipt_long_rounded,
            AppColors.info,
            [
              for (final po in _references.purchaseOrders)
                (
                  number: po.poNumber,
                  subtitle: 'Status: ${po.status}',
                  date: po.createdAt,
                  amount: po.estimatedTotal,
                ),
            ],
          ),
        if (_references.grns.isNotEmpty)
          _documentSection(
            'Goods Received',
            Icons.inventory_2_rounded,
            AppColors.success,
            [
              for (final grn in _references.grns)
                (
                  number: grn.grnNumber,
                  subtitle: 'Against ${grn.poNumber}',
                  date: grn.receivedDate,
                  amount: grn.totalAmount ?? 0,
                ),
            ],
          ),
        if (_references.purchaseReturns.isNotEmpty)
          _documentSection(
            'Purchase Returns',
            Icons.assignment_return_rounded,
            AppColors.orange,
            [
              for (final r in _references.purchaseReturns)
                (
                  number: r.returnNumber,
                  subtitle: 'Status: ${r.status}',
                  date: r.returnDate,
                  amount: r.totalAmount,
                ),
            ],
          ),
        if (_references.claims.isNotEmpty)
          _documentSection(
            'Supplier Claims',
            Icons.gavel_rounded,
            AppColors.accent,
            [
              for (final c in _references.claims)
                (
                  number: c.claimNumber,
                  subtitle: 'Status: ${c.status}',
                  date: c.claimDate,
                  amount: c.totalAmount,
                ),
            ],
          ),
      ],
    );
  }

  Widget _documentSection(
    String title,
    IconData icon,
    Color color,
    List<({String number, String subtitle, String date, double amount})> rows,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _card(
        title: '$title (${rows.length})',
        icon: icon,
        accent: color,
        child: Column(
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.number,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${row.subtitle}  ·  ${_formatDate(row.date)}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatMoney(row.amount),
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────── Shared ─────────────────────────────

  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
    Color accent = AppColors.primary,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
