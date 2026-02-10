import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/retail/hive_model/customer_model_208.dart';
import '../../../domain/services/restaurant/notification_service.dart';
import 'customer_detail_screen.dart';
class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    customerStoreRestail.searchCustomers(query);
  }

  void _showAddCustomerDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();
    final notesController = TextEditingController();
    final gstController = TextEditingController();
    final creditLimitController = TextEditingController();
    final openingBalanceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Customer'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Basic Information Section
                const Text(
                  'Basic Information',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B6B6B),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                    isDense: true,
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
                    isDense: true,
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
                    isDense: true,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Business Information Section
                const Text(
                  'Business Information',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B6B6B),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: gstController,
                  decoration: const InputDecoration(
                    labelText: 'GST Number',
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: 'e.g., 22AAAAA0000A1Z5',
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Credit Settings Section
                const Text(
                  'Credit Settings',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B6B6B),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: creditLimitController,
                        decoration: const InputDecoration(
                          labelText: 'Credit Limit',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixText: '\u20B9 ',
                          hintText: '0 = Unlimited',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: openingBalanceController,
                        decoration: const InputDecoration(
                          labelText: 'Opening Balance',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixText: '\u20B9 ',
                          hintText: 'Due amount',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Opening balance is the due amount carried forward from previous records.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9E9E9E),
                    fontStyle: FontStyle.italic,
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Notes Section
                const Text(
                  'Additional Notes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B6B6B),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: 'Any additional information...',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
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
                NotificationService.instance.showError('Name and Phone are required');
                return;
              }

              // Parse credit values
              final creditLimit = double.tryParse(creditLimitController.text.trim()) ?? 0.0;
              final openingBalance = double.tryParse(openingBalanceController.text.trim()) ?? 0.0;

              final newCustomer = CustomerModel.create(
                customerId: const Uuid().v4(),
                name: nameController.text.trim(),
                phone: phoneController.text.trim(),
                email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                gstNumber: gstController.text.trim().isEmpty ? null : gstController.text.trim().toUpperCase(),
                creditLimit: creditLimit,
                openingBalance: openingBalance,
              );

              await customerStoreRestail.addCustomer(newCustomer);

              if (mounted) {
                Navigator.pop(context);
                NotificationService.instance.showSuccess(
                  openingBalance > 0
                      ? 'Customer added with \u20B9${openingBalance.toStringAsFixed(2)} opening balance'
                      : 'Customer added successfully',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Customer'),
          ),
        ],
      ),
    );
  }

  void _openCustomerDetails(CustomerModel customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerDetailScreen(customer: customer),
      ),
    ).then((_) {
      // Refresh customer list when returning from detail screen
      customerStoreRestail.loadCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Customers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: Observer(
              builder: (context) {
                // Show all customers when search is empty
                if (_searchController.text.isEmpty) {
                  if (customerStoreRestail.customerCount == 0) {
                    return _buildEmptyState();
                  }
                  return _buildAllCustomersList();
                }

                // Show no results when searching but no matches
                if (customerStoreRestail.searchResults.isEmpty) {
                  return _buildNoResultsState();
                }

                // Show search results
                return _buildSearchResults();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCustomerDialog,
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by name or phone...',
          hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFB0B0B0)),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF6B6B6B)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFF6B6B6B)),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: (value) {
          _onSearchChanged(value);
          setState(() {});
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'No customers yet',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B6B6B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first customer using the + button',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFB0B0B0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'No customers found',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B6B6B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No results for "${_searchController.text}"',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFB0B0B0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllCustomersList() {
    return Observer(
      builder: (context) {
        final customers = customerStoreRestail.customers;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: customers.length,
          itemBuilder: (context, index) {
            final customer = customers[index];
            return _buildCustomerCard(customer);
          },
        );
      },
    );
  }

  Widget _buildSearchResults() {
    return Observer(
      builder: (context) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: customerStoreRestail.searchResults.length,
          itemBuilder: (context, index) {
            final customer = customerStoreRestail.searchResults[index];
            return _buildCustomerCard(customer);
          },
        );
      },
    );
  }

  Widget _buildCustomerCard(CustomerModel customer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF4CAF50).withOpacity(0.1),
          child: Text(
            customer.name[0].toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF4CAF50),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                customer.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            if (customer.creditBalance > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Due: \u20B9${customer.creditBalance.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '+91 ${customer.phone}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B6B)),
                ),
                if (customer.visitCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B6B6B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${customer.visitCount} visits',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (customer.totalPurchaseAmount > 0) ...[
                  const Icon(Icons.shopping_bag_outlined, size: 14, color: Color(0xFF4CAF50)),
                  const SizedBox(width: 4),
                  Text(
                    '\u20B9${customer.totalPurchaseAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (customer.pointsBalance > 0) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.star_outline, size: 14, color: Color(0xFFFFA726)),
                  const SizedBox(width: 4),
                  Text(
                    '${customer.pointsBalance} pts',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFFFA726),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (customer.totalPurchaseAmount == 0 && customer.pointsBalance == 0)
                  const Text(
                    'No purchases yet',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB0B0B0),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFB0B0B0)),
        onTap: () => _openCustomerDetails(customer),
      ),
    );
  }
}