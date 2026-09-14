import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:uuid/uuid.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

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
    customerStore.loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Customer> _getFilteredCustomers() {
    if (_searchQuery.isEmpty) {
      return customerStore.customers.toList();
    }

    return customerStore.customers.where((customer) {
      final name = customer.name?.toLowerCase() ?? '';
      final phone = customer.phone?.toLowerCase() ?? '';
      final email = customer.email?.toLowerCase() ?? '';
      return name.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          email.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Manage Customers',
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
            padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
            child: AppTextField(
              controller: _searchController,
              hint: 'Search by name, phone, or email',
              icon: Icons.search,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              suffixIcon: _searchQuery.isNotEmpty
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
              onFieldSubmitted: (value) {
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
                if (customerStore.customerCount == 0) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 64 is a decorative empty-state glyph, well above the
                        // largeIconSize ceiling (36) — no ladder applies.
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: AppColors.divider,
                        ),
                        SizedBox(height: AppResponsive.largeSpacing(context)),
                        Text(
                          'No customers yet',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.subheadingFontSize(context),
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: AppResponsive.smallSpacing(context)),
                        Text(
                          'Tap + to add your first customer',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(context),
                            color: AppColors.textSecondary,
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
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: AppColors.divider,
                        ),
                        SizedBox(height: AppResponsive.largeSpacing(context)),
                        Text(
                          'No customers found',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.subheadingFontSize(context),
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppResponsive.smallSpacing(context),
                  ),
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
    );
  }

  Widget _buildCustomerCard(BuildContext context, Customer customer) {
    final cardRadius = AppResponsive.borderRadius(context);

    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showCustomerDetailsDialog(context, customer),
        borderRadius: BorderRadius.circular(cardRadius),
        child: Padding(
          padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
          child: Row(
            children: [
              // Avatar: both the circle and its initial sit above the top of
              // their ladders, so they scale together as a raw pair to keep
              // the glyph-to-circle ratio fixed.
              CircleAvatar(
                radius: AppResponsive.getValue(
                  context,
                  mobile: 30.0,
                  tablet: 33.0,
                  desktop: 36.0,
                ),
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: Text(
                  customer.name?.isNotEmpty == true
                      ? customer.name![0].toUpperCase()
                      : '?',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.getValue(
                      context,
                      mobile: 24.0,
                      tablet: 26.0,
                      desktop: 28.0,
                    ),
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(width: AppResponsive.mediumSpacing(context)),

              // Customer Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name ?? 'Unknown',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.subheadingFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (customer.phone?.isNotEmpty == true) ...[
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            customer.phone!,
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.bodyFontSize(context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (customer.email?.isNotEmpty == true) ...[
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.email,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              customer.email!,
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.bodyFontSize(context),
                                color: AppColors.textSecondary,
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
                        Icon(
                          Icons.edit,
                          size: AppResponsive.iconSize(context),
                          color: AppColors.primary,
                        ),
                        SizedBox(width: AppResponsive.smallSpacing(context)),
                        Text(
                          'Edit',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete,
                          size: AppResponsive.iconSize(context),
                          color: Colors.red,
                        ),
                        SizedBox(width: AppResponsive.smallSpacing(context)),
                        Text(
                          'Delete',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(context),
                          ),
                        ),
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
      builder: (ctx) => DialogDisposeScope(
        disposables: [
          nameController,
          phoneController,
          emailController,
          addressController,
          notesController,
        ],
        child: AppDialogShell(
          title: 'Add New Customer',
          accent: AppColors.primary,
          icon: Icons.person_add_rounded,
          body: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: nameController,
                  hint: 'Customer Name',
                  icon: Icons.person,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 15),
                AppTextField(
                  controller: phoneController,
                  hint: 'Phone Number',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                AppTextField(
                  controller: emailController,
                  hint: 'Email (Optional)',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  // FIX 6: Validate email format when provided.
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty) {
                      if (!RegExp(
                        r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$',
                      ).hasMatch(v.trim())) {
                        return 'Enter a valid email';
                      }
                    }
                    return null;
                  },
                ),
                SizedBox(height: 15),
                AppTextField(
                  controller: addressController,
                  hint: 'Address (Optional)',
                  icon: Icons.location_on,
                  maxLines: 2,
                ),
                SizedBox(height: 15),
                AppTextField(
                  controller: notesController,
                  hint: 'Notes (Optional)',
                  icon: Icons.note,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            appDialogCancelButton(ctx),
            const SizedBox(width: 12),
            appDialogPrimaryButton(
              label: 'Add',
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  // FIX 8: Duplicate phone check before adding.
                  final phone = phoneController.text.trim();
                  if (phone.isNotEmpty) {
                    final exists = customerStore.customers.any(
                      (c) => (c.phone ?? '') == phone,
                    );
                    if (exists) {
                      NotificationService.instance.showError(
                        'A customer with this phone number already exists.',
                      );
                      return;
                    }
                  }
                  await _addCustomer(
                    nameController.text.trim(),
                    phoneController.text.trim(),
                    emailController.text.trim(),
                    addressController.text.trim(),
                    notesController.text.trim(),
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCustomerDialog(BuildContext context, Customer customer) {
    final nameController = TextEditingController(text: customer.name);
    final phoneController = TextEditingController(text: customer.phone);
    final emailController = TextEditingController(text: customer.email);
    final addressController = TextEditingController(text: customer.address);
    final notesController = TextEditingController(text: customer.notes);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => DialogDisposeScope(
        disposables: [
          nameController,
          phoneController,
          emailController,
          addressController,
          notesController,
        ],
        child: AppDialogShell(
          title: 'Edit Customer',
          accent: AppColors.primary,
          icon: Icons.edit_rounded,
          body: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: nameController,
                  hint: 'Customer Name',
                  icon: Icons.person,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 15),
                AppTextField(
                  controller: phoneController,
                  hint: 'Phone Number',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                AppTextField(
                  controller: emailController,
                  hint: 'Email (Optional)',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty) {
                      if (!RegExp(
                        r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$',
                      ).hasMatch(v.trim())) {
                        return 'Enter a valid email';
                      }
                    }
                    return null;
                  },
                ),
                SizedBox(height: 15),
                AppTextField(
                  controller: addressController,
                  hint: 'Address (Optional)',
                  icon: Icons.location_on,
                  maxLines: 2,
                ),
                SizedBox(height: 15),
                AppTextField(
                  controller: notesController,
                  hint: 'Notes (Optional)',
                  icon: Icons.note,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            appDialogCancelButton(ctx),
            const SizedBox(width: 12),
            appDialogPrimaryButton(
              label: 'Update',
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  await _updateCustomer(
                    customer,
                    nameController.text.trim(),
                    phoneController.text.trim(),
                    emailController.text.trim(),
                    addressController.text.trim(),
                    notesController.text.trim(),
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerDetailsDialog(BuildContext context, Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AppDialogShell(
        title: customer.name ?? 'Unknown',
        accent: AppColors.primary,
        icon: Icons.person,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (customer.phone?.isNotEmpty == true)
              _buildDetailRow(context, Icons.phone, 'Phone', customer.phone!),
            if (customer.email?.isNotEmpty == true)
              _buildDetailRow(context, Icons.email, 'Email', customer.email!),
            if (customer.address?.isNotEmpty == true)
              _buildDetailRow(
                context,
                Icons.location_on,
                'Address',
                customer.address!,
              ),
            if (customer.notes?.isNotEmpty == true)
              _buildDetailRow(context, Icons.note, 'Notes', customer.notes!),
            if (customer.totalVisites != null && customer.totalVisites! > 0)
              _buildDetailRow(
                context,
                Icons.shopping_bag,
                'Visits',
                '${customer.totalVisites}',
              ),
            if (customer.totalPurchaseAmount != null &&
                customer.totalPurchaseAmount! > 0)
              _buildDetailRow(
                context,
                Icons.attach_money,
                'Total Purchases',
                '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(customer.totalPurchaseAmount!)}',
              ),
          ],
        ),
        actions: [
          appDialogPrimaryButton(
            label: 'Close',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: AppResponsive.smallSpacing(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: AppResponsive.iconSize(context),
            color: AppColors.primary,
          ),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // 2px label-to-value gap: below the 8px spacing floor, and it
                // groups text rather than laying anything out.
                SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteCustomer(
    BuildContext context,
    Customer customer,
  ) async {
    final ok = await showAppConfirmDialog(
      context: context,
      title: 'Delete Customer',
      message: 'Are you sure you want to delete ${customer.name}?',
      confirmLabel: 'Delete',
      accent: Colors.red,
      icon: Icons.delete_rounded,
    );
    if (ok) {
      await _deleteCustomer(customer);
    }
  }

  Future<void> _addCustomer(
    String name,
    String phone,
    String email,
    String address,
    String notes,
  ) async {
    final customer = Customer.create(
      customerId: const Uuid().v4(),
      name: name,
      phone: phone,
      email: email.isNotEmpty ? email : null,
      address: address.isNotEmpty ? address : null,
      notes: notes.isNotEmpty ? notes : null,
    );

    await customerStore.addCustomer(customer);

    NotificationService.instance.showSuccess('Customer added successfully');
  }

  Future<void> _updateCustomer(
    Customer customer,
    String name,
    String phone,
    String email,
    String address,
    String notes,
  ) async {
    // Emptying an optional field must actually clear it — the clear* flags
    // exist because `x ?? this.x` alone would silently keep the old value.
    final updatedCustomer = customer.copyWith(
      name: name,
      phone: phone,
      email: email.isNotEmpty ? email : null,
      clearEmail: email.isEmpty,
      address: address.isNotEmpty ? address : null,
      clearAddress: address.isEmpty,
      notes: notes.isNotEmpty ? notes : null,
      clearNotes: notes.isEmpty,
      updatedAt: DateTime.now().toIso8601String(),
    );

    await customerStore.updateCustomer(updatedCustomer);

    NotificationService.instance.showSuccess('Customer updated successfully');
  }

  Future<void> _deleteCustomer(Customer customer) async {
    await customerStore.deleteCustomer(customer.customerId);

    NotificationService.instance.showSuccess('Customer deleted successfully');
  }
}
