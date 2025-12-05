import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/di/service_locator.dart';
import 'package:unipos/data/models/retail/hive_model/credit_payment_model_218.dart';
import 'package:unipos/data/models/retail/hive_model/customer_model_208.dart';
import 'package:unipos/data/models/retail/hive_model/sale_model_203.dart';

import 'customer_detail_screen.dart';


/// Credit Reports Screen - Credit Sales, Collection, Outstanding reports
class CreditReportsScreen extends StatefulWidget {
  const CreditReportsScreen({super.key});

  @override
  State<CreditReportsScreen> createState() => _CreditReportsScreenState();
}

class _CreditReportsScreenState extends State<CreditReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange? _dateFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
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
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Credit Reports'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_alt_outlined,
              color: _dateFilter != null ? const Color(0xFF4CAF50) : null,
            ),
            onPressed: _selectDateRange,
          ),
          if (_dateFilter != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _dateFilter = null),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4CAF50),
          unselectedLabelColor: const Color(0xFF6B6B6B),
          indicatorColor: const Color(0xFF4CAF50),
          tabs: const [
            Tab(text: 'Credit Sales'),
            Tab(text: 'Collections'),
            Tab(text: 'Outstanding'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Date Filter Info
          if (_dateFilter != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFE3F2FD),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Color(0xFF1976D2)),
                  const SizedBox(width: 8),
                  Text(
                    '${DateFormat('dd/MM/yy').format(_dateFilter!.start)} - ${DateFormat('dd/MM/yy').format(_dateFilter!.end)}',
                    style: const TextStyle(color: Color(0xFF1976D2), fontSize: 13),
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
                _OutstandingTab(dateFilter: _dateFilter),
              ],
            ),
          ),
        ],
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
      List<SaleModel> sales;
      if (widget.dateFilter != null) {
        sales = await saleStore.getCreditSalesByDateRange(
          widget.dateFilter!.start,
          widget.dateFilter!.end,
        );
      } else {
        sales = await saleStore.getCreditSales();
      }

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
                '₹${_totalCreditSales.toStringAsFixed(2)}',
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

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 28, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
        ),
      ],
    );
  }

  Widget _buildCreditSaleCard(SaleModel sale) {
    final date = DateTime.tryParse(sale.date);
    final dateStr = date != null ? DateFormat('dd MMM yyyy, hh:mm a').format(date) : sale.date;

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
                'INV-${sale.saleId.substring(0, 8).toUpperCase()}',
                style: const TextStyle(
                  fontSize: 14,
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
                    fontSize: 11,
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
            style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                  ),
                  Text(
                    '₹${sale.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Due',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                  ),
                  Text(
                    '₹${sale.dueAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
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
      List<CreditPaymentModel> payments;
      Map<String, double> collections;

      if (widget.dateFilter != null) {
        payments = await creditPaymentRepository.getPaymentsByDateRange(
          widget.dateFilter!.start,
          widget.dateFilter!.end,
        );
        collections = await creditPaymentRepository.getCollectionByModeInRange(
          widget.dateFilter!.start,
          widget.dateFilter!.end,
        );
      } else {
        payments = await creditPaymentRepository.getAllPayments();
        collections = {'cash': 0, 'card': 0, 'upi': 0, 'total': 0};
        for (var p in payments) {
          if (!(p.isWriteOff ?? false)) {
            final mode = p.paymentMode.toLowerCase();
            collections[mode] = (collections[mode] ?? 0) + p.amount;
            collections['total'] = (collections['total'] ?? 0) + p.amount;
          }
        }
      }

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
                  Expanded(child: _buildModeCard('Cash', _collectionByMode['cash'] ?? 0, const Color(0xFF4CAF50))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildModeCard('UPI', _collectionByMode['upi'] ?? 0, const Color(0xFF9C27B0))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildModeCard('Card', _collectionByMode['card'] ?? 0, const Color(0xFF2196F3))),
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
                    const Text(
                      'Total Collections',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '₹${(_collectionByMode['total'] ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
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
            style: TextStyle(fontSize: 12, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 14,
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
    final dateStr = date != null ? DateFormat('dd MMM yyyy, hh:mm a').format(date) : payment.date;

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
              color: payment.isDebtWriteOff ? Colors.grey : const Color(0xFF4CAF50),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.isDebtWriteOff ? 'Write-Off' : payment.paymentModeDisplayText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                ),
              ],
            ),
          ),
          Text(
            '₹${payment.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: payment.isDebtWriteOff ? Colors.grey : const Color(0xFF4CAF50),
            ),
          ),
        ],
      ),
    );
  }
}

/// Outstanding Tab
class _OutstandingTab extends StatefulWidget {
  final DateTimeRange? dateFilter;

  const _OutstandingTab({this.dateFilter});

  @override
  State<_OutstandingTab> createState() => _OutstandingTabState();
}

class _OutstandingTabState extends State<_OutstandingTab> {
  List<CustomerModel> _customersWithDue = [];
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
      final customers = await customerStore.getCustomersWithCredit();
      final total = customers.fold<double>(0, (sum, c) => sum + c.creditBalance);

      // Sort by credit balance descending
      customers.sort((a, b) => b.creditBalance.compareTo(a.creditBalance));

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
                  const Text(
                    'Total Outstanding',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${_totalOutstanding.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 28,
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
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                      ),
                    ),
                    const Text(
                      'Customers',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: _customersWithDue.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 64, color: Color(0xFF4CAF50)),
                      SizedBox(height: 16),
                      Text(
                        'No outstanding balance!',
                        style: TextStyle(fontSize: 16, color: Color(0xFF6B6B6B)),
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

  Widget _buildCustomerCard(CustomerModel customer) {
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
                      customer.name[0].toUpperCase(),
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
                          customer.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          customer.phone,
                          style: const TextStyle(
                            fontSize: 12,
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
                        '₹${customer.creditBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.red,
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 11,
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