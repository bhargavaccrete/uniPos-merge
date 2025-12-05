import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/di/service_locator.dart';
import 'package:unipos/data/models/retail/hive_model//customer_model_208.dart';
import 'package:unipos/data/models/retail/hive_model//sale_model_203.dart';
import 'package:unipos/presentation/screens/retail/sale_detail_screen.dart';
import 'package:unipos/presentation/screens/retail/receive_payment_screen.dart';
import 'package:unipos/presentation/screens/retail/customer_ledger_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final CustomerModel customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SaleModel> _customerSales = [];
  bool _isLoading = true;
  late CustomerModel _customer;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _tabController = TabController(length: 2, vsync: this);
    _loadCustomerSales();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerSales() async {
    setState(() => _isLoading = true);
    try {
      final sales = await saleStore.getSalesByCustomerId(_customer.customerId);
      setState(() {
        _customerSales = sales;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshCustomer() async {
    final updated = await customerStore.getCustomerById(_customer.customerId);
    if (updated != null) {
      setState(() => _customer = updated);
    }
    await _loadCustomerSales();
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatShortDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  void _showEditCustomerDialog() {
    final nameController = TextEditingController(text: _customer.name);
    final phoneController = TextEditingController(text: _customer.phone);
    final emailController = TextEditingController(text: _customer.email ?? '');
    final addressController =
        TextEditingController(text: _customer.address ?? '');
    final notesController = TextEditingController(text: _customer.notes ?? '');
    final gstController = TextEditingController(text: _customer.gstNumber ?? '');
    final creditLimitController =
        TextEditingController(text: _customer.creditLimit.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Customer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone *',
                  border: OutlineInputBorder(),
                  prefixText: '+91 ',
                ),
                keyboardType: TextInputType.phone,
                maxLength: 10,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: gstController,
                decoration: const InputDecoration(
                  labelText: 'GST Number',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: creditLimitController,
                decoration: const InputDecoration(
                  labelText: 'Credit Limit',
                  border: OutlineInputBorder(),
                  prefixText: '\u20B9 ',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || phoneController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Name and Phone are required'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final updatedCustomer = _customer.copyWith(
                name: nameController.text.trim(),
                phone: phoneController.text.trim(),
                email: emailController.text.trim().isEmpty
                    ? null
                    : emailController.text.trim(),
                address: addressController.text.trim().isEmpty
                    ? null
                    : addressController.text.trim(),
                notes: notesController.text.trim().isEmpty
                    ? null
                    : notesController.text.trim(),
                gstNumber: gstController.text.trim().isEmpty
                    ? null
                    : gstController.text.trim(),
                creditLimit:
                    double.tryParse(creditLimitController.text.trim()) ?? 0.0,
                updatedAt: DateTime.now().toIso8601String(),
              );

              await customerStore.updateCustomer(updatedCustomer);
              setState(() => _customer = updatedCustomer);

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Customer updated successfully'),
                    backgroundColor: Color(0xFF4CAF50),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showRedeemPointsDialog() {
    final pointsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Redeem Points'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available Points: ${_customer.pointsBalance}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFFA726),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pointsController,
              decoration: const InputDecoration(
                labelText: 'Points to Redeem',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final points = int.tryParse(pointsController.text) ?? 0;
              if (points <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid points'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (points > _customer.pointsBalance) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Insufficient points'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              await customerStore.redeemCustomerPoints(
                  _customer.customerId, points);
              await _refreshCustomer();

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$points points redeemed successfully'),
                    backgroundColor: const Color(0xFF4CAF50),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFA726),
              foregroundColor: Colors.white,
            ),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(_customer.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditCustomerDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4CAF50),
          unselectedLabelColor: const Color(0xFF6B6B6B),
          indicatorColor: const Color(0xFF4CAF50),
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Bills'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailsTab(),
          _buildBillsTab(),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return RefreshIndicator(
      onRefresh: _refreshCustomer,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Header Card
            _buildHeaderCard(),
            const SizedBox(height: 16),

            // Contact Info
            _buildSectionCard(
              title: 'Contact Information',
              icon: Icons.contact_phone,
              children: [
                _buildInfoRow('Phone', '+91 ${_customer.phone}'),
                if (_customer.email != null && _customer.email!.isNotEmpty)
                  _buildInfoRow('Email', _customer.email!),
                if (_customer.address != null && _customer.address!.isNotEmpty)
                  _buildInfoRow('Address', _customer.address!),
                if (_customer.gstNumber != null &&
                    _customer.gstNumber!.isNotEmpty)
                  _buildInfoRow('GST Number', _customer.gstNumber!),
              ],
            ),
            const SizedBox(height: 16),

            // Purchase Summary
            _buildSectionCard(
              title: 'Purchase Summary',
              icon: Icons.shopping_cart,
              children: [
                _buildInfoRow('Total Purchase',
                    '\u20B9${_customer.totalPurchaseAmount.toStringAsFixed(2)}'),
                _buildInfoRow('Visit Count', _customer.visitCount.toString()),
                _buildInfoRow(
                  'Last Visited',
                  _customer.lastVisited != null
                      ? _formatShortDate(_customer.lastVisited!)
                      : 'Never',
                ),
                _buildInfoRow('Total Bills', _customerSales.length.toString()),
              ],
            ),
            const SizedBox(height: 16),

            // Loyalty Points
            _buildSectionCard(
              title: 'Loyalty Points',
              icon: Icons.star,
              iconColor: const Color(0xFFFFA726),
              trailing: _customer.pointsBalance > 0
                  ? TextButton(
                      onPressed: _showRedeemPointsDialog,
                      child: const Text('Redeem'),
                    )
                  : null,
              children: [
                _buildInfoRow(
                    'Points Balance', _customer.pointsBalance.toString(),
                    valueColor: const Color(0xFFFFA726)),
                _buildInfoRow(
                    'Total Earned', _customer.totalPointEarned.toString()),
                _buildInfoRow(
                    'Total Redeemed', _customer.totalPointRedeemed.toString()),
              ],
            ),
            const SizedBox(height: 16),

            // Credit Info
            _buildCreditCard(),
            const SizedBox(height: 16),

            // Notes
            if (_customer.notes != null && _customer.notes!.isNotEmpty)
              _buildSectionCard(
                title: 'Notes',
                icon: Icons.note,
                children: [
                  Text(
                    _customer.notes!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B6B6B),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 16),

            // Metadata
            _buildSectionCard(
              title: 'Account Info',
              icon: Icons.info_outline,
              children: [
                _buildInfoRow(
                    'Customer Since', _formatShortDate(_customer.createdAt)),
                if (_customer.updatedAt != null)
                  _buildInfoRow(
                      'Last Updated', _formatShortDate(_customer.updatedAt!)),
                _buildInfoRow('Customer ID', _customer.customerId,
                    valueStyle: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB0B0B0),
                      fontFamily: 'monospace',
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              _customer.name[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _customer.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '+91 ${_customer.phone}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildHeaderBadge(
                      Icons.shopping_bag,
                      '\u20B9${_customer.totalPurchaseAmount.toStringAsFixed(0)}',
                    ),
                    const SizedBox(width: 12),
                    _buildHeaderBadge(
                      Icons.star,
                      '${_customer.pointsBalance} pts',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    Color? iconColor,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon,
                    size: 20, color: iconColor ?? const Color(0xFF4CAF50)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                if (trailing != null) ...[
                  const Spacer(),
                  trailing,
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {Color? valueColor, TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B6B6B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle ??
                  TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? const Color(0xFF1A1A1A),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCard() {
    final hasCredit = _customer.creditBalance > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasCredit ? Colors.red.withOpacity(0.3) : const Color(0xFFE8E8E8),
          width: hasCredit ? 1 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.credit_card,
                  size: 20,
                  color: hasCredit ? Colors.red : const Color(0xFF4CAF50),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Credit Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Outstanding Balance - prominent display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: hasCredit
                        ? const Color(0xFFFFEBEE)
                        : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Outstanding Balance',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B6B6B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\u20B9${_customer.creditBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: hasCredit ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      if (hasCredit)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'DUE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Credit Limit Info
                _buildInfoRow(
                  'Credit Limit',
                  _customer.creditLimit > 0
                      ? '\u20B9${_customer.creditLimit.toStringAsFixed(2)}'
                      : 'Unlimited',
                ),

                // Available Credit
                if (_customer.creditLimit > 0)
                  _buildInfoRow(
                    'Available Credit',
                    '\u20B9${(_customer.creditLimit - _customer.creditBalance).clamp(0, double.infinity).toStringAsFixed(2)}',
                    valueColor: const Color(0xFF4CAF50),
                  ),

                const SizedBox(height: 8),

                // Action Buttons
                Row(
                  children: [
                    // Receive Payment Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: hasCredit
                            ? () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ReceivePaymentScreen(
                                      customer: _customer,
                                    ),
                                  ),
                                );
                                await _refreshCustomer();
                              }
                            : null,
                        icon: const Icon(Icons.payment, size: 18),
                        label: const Text('Receive Payment'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // View Ledger Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CustomerLedgerScreen(
                                customer: _customer,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.receipt_long, size: 18),
                        label: const Text('View Ledger'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1976D2),
                          side: const BorderSide(color: Color(0xFF1976D2)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
      );
    }

    if (_customerSales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'No bills yet',
              style: TextStyle(fontSize: 16, color: Color(0xFF6B6B6B)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Customer purchases will appear here',
              style: TextStyle(fontSize: 14, color: Color(0xFFB0B0B0)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCustomerSales,
      child: Column(
        children: [
          // Summary Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  'Total Bills',
                  _customerSales.length.toString(),
                  Icons.receipt,
                ),
                _buildSummaryItem(
                  'Total Amount',
                  '\u20B9${_customerSales.fold<double>(0, (sum, s) => sum + s.totalAmount).toStringAsFixed(2)}',
                  Icons.payments,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Bills List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _customerSales.length,
              itemBuilder: (context, index) {
                final sale = _customerSales[index];
                return _buildBillCard(sale);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: const Color(0xFF4CAF50)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B6B6B),
          ),
        ),
      ],
    );
  }

  Widget _buildBillCard(SaleModel sale) {
    final isReturn = sale.isReturn ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isReturn ? Colors.red.withOpacity(0.3) : const Color(0xFFE8E8E8),
          width: 0.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SaleDetailScreen(saleId: sale.saleId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isReturn ? Icons.assignment_return : Icons.receipt,
                        size: 18,
                        color: isReturn ? Colors.red : const Color(0xFF4CAF50),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isReturn ? 'Return' : 'Sale',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isReturn ? Colors.red : const Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPaymentColor(sale.paymentType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      sale.paymentType.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _getPaymentColor(sale.paymentType),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bill #${sale.saleId.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(sale.date),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B6B6B),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isReturn ? '-' : ''}\u20B9${sale.totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isReturn ? Colors.red : const Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        '${sale.totalItems} items',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B6B6B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tap to view details',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[400],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Color(0xFFB0B0B0),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPaymentColor(String paymentType) {
    switch (paymentType.toLowerCase()) {
      case 'cash':
        return const Color(0xFF4CAF50);
      case 'card':
        return const Color(0xFF2196F3);
      case 'upi':
        return const Color(0xFF9C27B0);
      case 'split':
        return const Color(0xFFFF9800);
      case 'credit':
        return Colors.red;
      default:
        return const Color(0xFF6B6B6B);
    }
  }
}