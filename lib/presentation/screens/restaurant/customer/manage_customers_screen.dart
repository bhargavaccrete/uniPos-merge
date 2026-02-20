import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/retail/hive_model/customer_model_208.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Textform.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';

class ManageCustomersScreen extends StatefulWidget {
  const ManageCustomersScreen({super.key});

  @override
  State<ManageCustomersScreen> createState() => _ManageCustomersScreenState();
}

class _ManageCustomersScreenState extends State<ManageCustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    customerStoreRestail.loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CustomerModel> _getFilteredCustomers() {
    if (_searchQuery.isEmpty) {
      return customerStoreRestail.customers.toList();
    }

    return customerStoreRestail.customers.where((customer) {
      final name = customer.name.toLowerCase();
      final phone = customer.phone.toLowerCase();
      final email = customer.email?.toLowerCase() ?? '';
      return name.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          email.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          'Manage Customers',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add),
            onPressed: () => _showAddCustomerDialog(context),
            tooltip: 'Add Customer',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.all(width * 0.02),
            child: CommonTextForm(
              controller: _searchController,
              hintText: 'Search by name, phone, or email',
              obsecureText: false,
              BorderColor: AppColors.primary,
              icon: Icon(Icons.search, color: AppColors.primary),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              gesture: _searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                      child: Icon(Icons.clear, color: Colors.grey),
                    )
                  : null,
              onfieldsumbitted: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Customer List
          Expanded(
            child: Observer(
              builder: (context) {
                if (customerStoreRestail.customerCount == 0) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
                        SizedBox(height: height * 0.02),
                        Text(
                          'No customers yet',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: height * 0.01),
                        Text(
                          'Tap + to add your first customer',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final customers = _getFilteredCustomers();

                if (customers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
                        SizedBox(height: height * 0.02),
                        Text(
                          'No customers found',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: width * 0.02),
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    return _buildCustomerCard(context, customer);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCustomerDialog(context),
        backgroundColor: AppColors.primary,
        child: Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  Widget _buildCustomerCard(BuildContext context, CustomerModel customer) {
    final width = MediaQuery.of(context).size.width;

    final height = MediaQuery.of(context).size.height;

    return Card(
      margin: EdgeInsets.only(bottom: height * 0.015),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showCustomerDetailsDialog(context, customer),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(width * 0.03),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primary.withOpacity(0.2),
                child: Text(
                  customer.name?.isNotEmpty == true
                      ? customer.name![0].toUpperCase()
                      : '?',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(width: width * 0.03),

              // Customer Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name ?? 'Unknown',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (customer.phone?.isNotEmpty == true) ...[
                      SizedBox(height: 4),
                      Row(
                        children: [

                          Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text(
                            customer.phone!,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (customer.email?.isNotEmpty == true) ...[
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.email, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              customer.email!,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Actions
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditCustomerDialog(context, customer);
                  } else if (value == 'delete') {
                    _confirmDeleteCustomer(context, customer);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add New Customer',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CommonTextForm(
                  controller: nameController,
                  hintText: 'Customer Name',
                  obsecureText: false,
                  BorderColor: AppColors.primary,
                  icon: Icon(Icons.person, color: AppColors.primary),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 15),
                CommonTextForm(
                  controller: phoneController,
                  hintText: 'Phone Number',
                  obsecureText: false,
                  keyboardType: TextInputType.phone,
                  BorderColor: AppColors.primary,
                  icon: Icon(Icons.phone, color: AppColors.primary),
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      if (!RegExp(r'^\d{10}$').hasMatch(value.trim())) {
                        return 'Enter a valid 10-digit phone number';
                      }
                    }
                    return null;
                  },
                ),
                SizedBox(height: 15),
                CommonTextForm(
                  controller: emailController,
                  hintText: 'Email (Optional)',
                  obsecureText: false,
                  keyboardType: TextInputType.emailAddress,
                  BorderColor: AppColors.primary,
                  icon: Icon(Icons.email, color: AppColors.primary),
                ),
                SizedBox(height: 15),
                CommonTextForm(
                  controller: addressController,
                  hintText: 'Address (Optional)',
                  obsecureText: false,
                  maxline: 2,
                  BorderColor: AppColors.primary,
                  icon: Icon(Icons.location_on, color: AppColors.primary),
                ),
                SizedBox(height: 15),
                CommonTextForm(
                  controller: notesController,
                  hintText: 'Notes (Optional)',
                  obsecureText: false,
                  maxline: 2,
                  BorderColor: AppColors.primary,
                  icon: Icon(Icons.note, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          CommonButton(
            onTap: () async {
              if (formKey.currentState!.validate()) {
                await _addCustomer(
                  nameController.text.trim(),
                  phoneController.text.trim(),
                  emailController.text.trim(),
                  addressController.text.trim(),
                  notesController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
            child: Text('Add', style: GoogleFonts.poppins(color: Colors.white)),
            height: 40,
            width: 80,
            bgcolor: AppColors.primary,
          ),
        ],
      ),
    ).then((_) {
      nameController.dispose();
      phoneController.dispose();
      emailController.dispose();
      addressController.dispose();
      notesController.dispose();
    });
  }

  void _showEditCustomerDialog(BuildContext context, CustomerModel customer) {
    final nameController = TextEditingController(text: customer.name);
    final phoneController = TextEditingController(text: customer.phone);
    final emailController = TextEditingController(text: customer.email);
    final addressController = TextEditingController(text: customer.address);
    final notesController = TextEditingController(text: customer.notes);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit Customer',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CommonTextForm(
                  controller: nameController,
                  hintText: 'Customer Name',
                  obsecureText: false,
                  BorderColor: AppColors.primary,
                  icon: Icon(Icons.person, color: AppColors.primary),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 15),
                CommonTextForm(
                  controller: phoneController,
                  hintText: 'Phone Number',
                  obsecureText: false,
                  keyboardType: TextInputType.phone,
                  BorderColor: AppColors.primary,
                  icon: Icon(Icons.phone, color: AppColors.primary),
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      if (!RegExp(r'^\d{10}$').hasMatch(value.trim())) {
                        return 'Enter a valid 10-digit phone number';
                      }
                    }
                    return null;
                  },
                ),
                SizedBox(height: 15),
                CommonTextForm(
                  controller: emailController,
                  hintText: 'Email (Optional)',
                  obsecureText: false,
                  keyboardType: TextInputType.emailAddress,
                  BorderColor: AppColors.primary,
                  icon: Icon(Icons.email, color: AppColors.primary),
                ),
                SizedBox(height: 15),
                CommonTextForm(
                  controller: addressController,
                  hintText: 'Address (Optional)',
                  obsecureText: false,
                  maxline: 2,
                  BorderColor: AppColors.primary,
                  icon: Icon(Icons.location_on, color: AppColors.primary),
                ),
                SizedBox(height: 15),
                CommonTextForm(
                  controller: notesController,
                  hintText: 'Notes (Optional)',
                  obsecureText: false,
                  maxline: 2,
                  BorderColor: AppColors.primary,
                  icon: Icon(Icons.note, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          CommonButton(
            onTap: () async {
              if (formKey.currentState!.validate()) {
                await _updateCustomer(
                  customer,
                  nameController.text.trim(),
                  phoneController.text.trim(),
                  emailController.text.trim(),
                  addressController.text.trim(),
                  notesController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
            child: Text('Update', style: GoogleFonts.poppins(color: Colors.white)),
            height: 40,
            width: 80,
            bgcolor: AppColors.primary,
          ),
        ],
      ),
    ).then((_) {
      nameController.dispose();
      phoneController.dispose();
      emailController.dispose();
      addressController.dispose();
      notesController.dispose();
    });
  }

  void _showCustomerDetailsDialog(BuildContext context, CustomerModel customer) {
    final width = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: AppColors.primary.withOpacity(0.2),
              child: Text(
                customer.name?.isNotEmpty == true
                    ? customer.name![0].toUpperCase()
                    : '?',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                customer.name ?? 'Unknown',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (customer.phone?.isNotEmpty == true)
                _buildDetailRow(Icons.phone, 'Phone', customer.phone!),
              if (customer.email?.isNotEmpty == true)
                _buildDetailRow(Icons.email, 'Email', customer.email!),
              if (customer.address?.isNotEmpty == true)
                _buildDetailRow(Icons.location_on, 'Address', customer.address!),
              if (customer.notes?.isNotEmpty == true)
                _buildDetailRow(Icons.note, 'Notes', customer.notes!),
              if (customer.visitCount != null && customer.visitCount! > 0)
                _buildDetailRow(Icons.shopping_bag, 'Visits', '${customer.visitCount}'),
              if (customer.totalPurchaseAmount != null && customer.totalPurchaseAmount! > 0)
                _buildDetailRow(Icons.attach_money, 'Total Purchases', '₹${customer.totalPurchaseAmount!.toStringAsFixed(2)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(color: AppColors.primary),
            ),
          ),
          CommonButton(
            onTap: () {
              Navigator.pop(context);
              _showEditCustomerDialog(context, customer);
            },
            child: Text('Edit', style: GoogleFonts.poppins(color: Colors.white)),
            height: 40,
            width: 80,
            bgcolor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCustomer(BuildContext context, CustomerModel customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Customer',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete ${customer.name}?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              await _deleteCustomer(customer);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addCustomer(String name, String phone, String email, String address, String notes) async {
    final customer = CustomerModel.create(
      customerId: const Uuid().v4(),
      name: name,
      phone: phone,
      email: email.isNotEmpty ? email : null,
      address: address.isNotEmpty ? address : null,
      notes: notes.isNotEmpty ? notes : null,
    );

    await customerStoreRestail.addCustomer(customer);

    NotificationService.instance.showSuccess('Customer added successfully');
  }

  Future<void> _updateCustomer(CustomerModel customer, String name, String phone, String email, String address, String notes) async {
    final updatedCustomer = customer.copyWith(
      name: name,
      phone: phone,
      email: email.isNotEmpty ? email : null,
      address: address.isNotEmpty ? address : null,
      notes: notes.isNotEmpty ? notes : null,
      updatedAt: DateTime.now().toIso8601String(),
    );

    await customerStoreRestail.updateCustomer(updatedCustomer);

    NotificationService.instance.showSuccess('Customer updated successfully');
  }

  Future<void> _deleteCustomer(CustomerModel customer) async {
    await customerStoreRestail.deleteCustomer(customer.customerId);

    NotificationService.instance.showSuccess('Customer deleted successfully');
  }
}
