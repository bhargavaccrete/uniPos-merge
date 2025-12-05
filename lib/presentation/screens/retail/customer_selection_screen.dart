import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import 'package:uuid/uuid.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/retail/hive_model/customer_model_208.dart';

class CustomerSelectionScreen extends StatefulWidget {
  const CustomerSelectionScreen({super.key});

  @override
  State<CustomerSelectionScreen> createState() => _CustomerSelectionScreenState();
}

class _CustomerSelectionScreenState extends State<CustomerSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Clear any previous selection and search
    customerStore.clearSelection();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    customerStore.searchCustomers(query);
  }

  void _selectCustomer(CustomerModel customer) {
    customerStore.selectCustomer(customer);
    Navigator.pop(context, customer);
  }

  void _showAddCustomerDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController(text: _searchController.text);
    final emailController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Customer'),
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

              final newCustomer = CustomerModel.create(
                customerId: const Uuid().v4(),
                name: nameController.text.trim(),
                phone: phoneController.text.trim(),
                email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
              );

              await customerStore.addCustomer(newCustomer);

              if (mounted) {
                Navigator.pop(context);
                _selectCustomer(newCustomer);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Select Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () {
              // Skip customer selection
              Navigator.pop(context, null);
            },
            child: const Text(
              'Skip',
              style: TextStyle(color: Color(0xFF6B6B6B)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: Observer(
              builder: (context) {
                if (_searchController.text.isEmpty) {
                  return _buildEmptyState();
                }

                if (customerStore.searchResults.isEmpty) {
                  return _buildNoResultsState();
                }

                return _buildSearchResults();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Search by name or phone',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B6B6B),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Type name or mobile number...',
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
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'Search for a customer',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B6B6B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Type a name or mobile number to find customers',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFB0B0B0),
            ),
            textAlign: TextAlign.center,
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
            Icons.person_add_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'No customer found',
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
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddCustomerDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add New Customer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Observer(
      builder: (context) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: customerStore.searchResults.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildAddNewCustomerTile();
            }

            final customer = customerStore.searchResults[index - 1];
            return _buildCustomerTile(customer);
          },
        );
      },
    );
  }

  Widget _buildAddNewCustomerTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4CAF50), width: 1),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        title: const Text(
          'Add New Customer',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4CAF50),
          ),
        ),
        subtitle: Text(
          'Create customer with "${_searchController.text}"',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B6B)),
        ),
        onTap: _showAddCustomerDialog,
      ),
    );
  }

  Widget _buildCustomerTile(CustomerModel customer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: ListTile(
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
        title: Text(
          customer.name,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              customer.phone,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B6B)),
            ),
            if (customer.totalPurchaseAmount > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Total Purchase: ₹${customer.totalPurchaseAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF4CAF50),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFB0B0B0)),
        onTap: () => _selectCustomer(customer),
      ),
    );
  }
}