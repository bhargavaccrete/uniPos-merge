import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'customer_form_dialog.dart';
import 'customer_detail_screen.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String sortBy = 'name'; // name, visits, points

  @override
  void initState() {
    super.initState();
    customerStore.setSearchQuery(''); // Ensure clean state on entry
    customerStore.loadCustomers();
  }

  List<Customer> _getSortedCustomers(List<Customer> customers) {
    final sorted = customers.toList();
    switch (sortBy) {
      case 'name':
        sorted.sort((a, b) {
          final nameA = a.name?.toLowerCase() ?? '';
          final nameB = b.name?.toLowerCase() ?? '';
          return nameA.compareTo(nameB);
        });
        break;
      case 'visits':
        sorted.sort((a, b) => b.totalVisites.compareTo(a.totalVisites));
        break;
      case 'points':
        sorted.sort((a, b) => b.loyaltyPoints.compareTo(a.loyaltyPoints));
        break;
    }
    return sorted;
  }

  void _searchCustomers(String query) {
    customerStore.setSearchQuery(query);
  }

  void _navigateToAddCustomer() async {
    final result = await showCustomerFormDialog(context);

    if (result == 'added') {
      if (mounted) {
        NotificationService.instance.showSuccess('Customer added successfully');
      }
    }
  }

  void _navigateToEditCustomer(Customer customer) async {
    final result = await showCustomerFormDialog(context, customer: customer);

    if (result == 'updated') {
      if (mounted) {
        NotificationService.instance.showSuccess(
          'Customer updated successfully',
        );
      }
    }
  }

  void _navigateToCustomerDetail(Customer customer) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerDetailScreen(customer: customer),
      ),
    );

    if (result == 'deleted') {
      if (mounted) {
        NotificationService.instance.showSuccess(
          'Customer deleted successfully',
        );
      }
    }
  }

  void _deleteCustomer(Customer customer) async {
    final confirm = await showAppConfirmDialog(
      context: context,
      title: 'Delete "${customer.name ?? 'Customer'}"?',
      message: 'This action cannot be undone.',
      confirmLabel: 'Delete',
      accent: AppColors.danger,
      icon: Icons.delete_outline,
    );

    if (confirm) {
      final success = await customerStore.deleteCustomer(customer.customerId);
      if (mounted && success) {
        NotificationService.instance.showSuccess(
          'Customer deleted successfully',
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    customerStore.setSearchQuery(''); // Clear filter so next visit shows all
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Customers',
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.sort_rounded),
            tooltip: 'Sort by',
            color: AppColors.white,
            surfaceTintColor: AppColors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              setState(() {
                sortBy = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(
                      Icons.sort_by_alpha,
                      size: 20,
                      color: sortBy == 'name'
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Name',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        color: sortBy == 'name'
                            ? AppColors.primary
                            : Colors.black87,
                        fontWeight: sortBy == 'name'
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'visits',
                child: Row(
                  children: [
                    Icon(
                      Icons.people_rounded,
                      size: 20,
                      color: sortBy == 'visits'
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Visits',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        color: sortBy == 'visits'
                            ? AppColors.primary
                            : Colors.black87,
                        fontWeight: sortBy == 'visits'
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'points',
                child: Row(
                  children: [
                    Icon(
                      Icons.stars_rounded,
                      size: 20,
                      color: sortBy == 'points'
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Points',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        color: sortBy == 'points'
                            ? AppColors.primary
                            : Colors.black87,
                        fontWeight: sortBy == 'points'
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(width: 8),
        ],
      ),
      body: AppResponsive.constrainedContent(
        context: context,
        maxWidth: AppResponsive.maxContentWidth(context),
        alignment: Alignment.topCenter,
        child: Column(
          children: [
            // Search Bar & Add Button Section
            Container(
              color: AppColors.white,
              padding: AppResponsive.padding(context),
              child: Column(
                children: [
                  AppTextField(
                    controller: _searchController,
                    hint: 'Search by name or phone...',
                    icon: Icons.search_rounded,
                    onChanged: (v) {
                      _searchCustomers(v);
                      setState(() {});
                    },
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              _searchCustomers('');
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  SizedBox(height: AppResponsive.mediumSpacing(context)),
                  SizedBox(
                    width: double.infinity,
                    height: AppResponsive.buttonHeight(context),
                    child: ElevatedButton.icon(
                      onPressed: _navigateToAddCustomer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        Icons.person_add_rounded,
                        size: AppResponsive.iconSize(context),
                      ),
                      label: Text(
                        'Add New Customer',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.buttonFontSize(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Stats Row
            Observer(
              builder: (context) {
                final customers = customerStore.customers;
                if (customers.isEmpty) return const SizedBox.shrink();

                final totalVisits = customers.fold(
                  0,
                  (sum, c) => sum + c.totalVisites,
                );
                final totalPoints = customers.fold(
                  0,
                  (sum, c) => sum + c.loyaltyPoints,
                );

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppResponsive.largeSpacing(context),
                    vertical: AppResponsive.smallSpacing(context),
                  ),
                  child: Row(
                    children: [
                      _buildStatChip(
                        '${customers.length} customers',
                        Icons.people_rounded,
                        Colors.blue,
                      ),
                      SizedBox(width: 8),
                      _buildStatChip(
                        '$totalVisits visits',
                        Icons.calendar_today_rounded,
                        Colors.green,
                      ),
                      SizedBox(width: 8),
                      _buildStatChip(
                        '$totalPoints pts',
                        Icons.stars_rounded,
                        Colors.orange,
                      ),
                    ],
                  ),
                );
              },
            ),

            // Customer List
            Expanded(
              child: Observer(
                builder: (context) {
                  if (customerStore.isLoading) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  final filteredCustomers = _getSortedCustomers(
                    customerStore.filteredCustomers,
                  );

                  if (filteredCustomers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            size: AppResponsive.getValue(
                              context,
                              mobile: 64.0,
                              tablet: 80.0,
                              desktop: 96.0,
                            ),
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(height: AppResponsive.largeSpacing(context)),
                          Text(
                            _searchController.text.isEmpty
                                ? 'No customers yet'
                                : 'No customers found',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.subheadingFontSize(
                                context,
                              ),
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (_searchController.text.isEmpty) ...[
                            SizedBox(height: 8),
                            Text(
                              'Add your first customer to get started',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.smallFontSize(context),
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredCustomers.length,
                    padding: AppResponsive.padding(context),
                    itemBuilder: (context, index) {
                      final customer = filteredCustomers[index];
                      return _buildCustomerCard(customer);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard(Customer customer) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: () => _navigateToCustomerDetail(customer),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: AppResponsive.getValue(
                  context,
                  mobile: 18.0,
                  tablet: 20.0,
                  desktop: 22.0,
                ),
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  customer.name?.isNotEmpty == true
                      ? customer.name![0].toUpperCase()
                      : '?',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name ?? 'Unknown',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      [
                        if (customer.phone != null) customer.phone!,
                        '${customer.totalVisites} visits',
                        '${customer.loyaltyPoints} pts',
                      ].join('  •  '),
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                color: AppColors.white,
                surfaceTintColor: AppColors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onSelected: (value) {
                  if (value == 'edit') _navigateToEditCustomer(customer);
                  if (value == 'delete') _deleteCustomer(customer);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Edit',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(context),
                            color: AppColors.textPrimary,
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
                          Icons.delete_outline,
                          size: 18,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Delete',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(context),
                            color: AppColors.danger,
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
}
