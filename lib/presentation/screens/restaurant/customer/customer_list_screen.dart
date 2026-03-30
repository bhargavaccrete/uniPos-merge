import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/customer_model_125.dart';
import 'add_edit_customer_screen.dart';
import 'customer_detail_screen.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';

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
    restaurantCustomerStore.setSearchQuery(''); // Ensure clean state on entry
    restaurantCustomerStore.loadCustomers();
  }

  List<RestaurantCustomer> _getSortedCustomers(List<RestaurantCustomer> customers) {
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
    restaurantCustomerStore.setSearchQuery(query);
  }

  void _navigateToAddCustomer() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddEditCustomerScreen(),
      ),
    );

    if (result == 'added') {
      await restaurantCustomerStore.loadCustomers();
      if (mounted) {
        NotificationService.instance.showSuccess('Customer added successfully');
      }
    }
  }

  void _navigateToEditCustomer(RestaurantCustomer customer) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditCustomerScreen(customer: customer),
      ),
    );

    if (result == 'updated') {
      await restaurantCustomerStore.loadCustomers();
      if (mounted) {
        NotificationService.instance.showSuccess('Customer updated successfully');
      }
    }
  }

  void _navigateToCustomerDetail(RestaurantCustomer customer) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerDetailScreen(customer: customer),
      ),
    );

    if (result == 'deleted') {
      await restaurantCustomerStore.loadCustomers();
      if (mounted) {
        NotificationService.instance.showSuccess('Customer deleted successfully');
      }
    } else if (result != null) {
      await restaurantCustomerStore.loadCustomers();
    }
  }

  void _deleteCustomer(RestaurantCustomer customer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Delete "${customer.name ?? 'Customer'}"?', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
        content: Text('This action cannot be undone.', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.w500))),
        ],
      ),
    );

    if (confirm == true) {
      final success = await restaurantCustomerStore.deleteCustomer(customer.customerId);
      if (mounted && success) {
        NotificationService.instance.showSuccess('Customer deleted successfully');
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    restaurantCustomerStore.setSearchQuery(''); // Clear filter so next visit shows all
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black87),
        title: Text(
          'Customers',
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 22 : 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.sort_rounded, color: Colors.black87),
            tooltip: 'Sort by',
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
                      color: sortBy == 'name' ? AppColors.primary : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Name',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: sortBy == 'name' ? AppColors.primary : Colors.black87,
                        fontWeight: sortBy == 'name' ? FontWeight.w600 : FontWeight.normal,
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
                      color: sortBy == 'visits' ? AppColors.primary : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Visits',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: sortBy == 'visits' ? AppColors.primary : Colors.black87,
                        fontWeight: sortBy == 'visits' ? FontWeight.w600 : FontWeight.normal,
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
                      color: sortBy == 'points' ? AppColors.primary : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Points',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: sortBy == 'points' ? AppColors.primary : Colors.black87,
                        fontWeight: sortBy == 'points' ? FontWeight.w600 : FontWeight.normal,
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
      body: Column(
        children: [
          // Search Bar & Add Button Section
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(isTablet ? 20 : 16),
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
                SizedBox(height: isTablet ? 16 : 12),
                SizedBox(
                  width: double.infinity,
                  height: isTablet ? 50 : 46,
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
                    icon: Icon(Icons.person_add_rounded, size: isTablet ? 22 : 20),
                    label: Text(
                      'Add New Customer',
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 16 : 15,
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
              final customers = restaurantCustomerStore.customers;
              if (customers.isEmpty) return const SizedBox.shrink();

              final totalVisits = customers.fold(0, (sum, c) => sum + c.totalVisites);
              final totalPoints = customers.fold(0, (sum, c) => sum + c.loyaltyPoints);

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 16, vertical: 8),
                child: Row(
                  children: [
                    _buildStatChip('${customers.length} customers', Icons.people_rounded, Colors.blue),
                    SizedBox(width: 8),
                    _buildStatChip('$totalVisits visits', Icons.calendar_today_rounded, Colors.green),
                    SizedBox(width: 8),
                    _buildStatChip('$totalPoints pts', Icons.stars_rounded, Colors.orange),
                  ],
                ),
              );
            },
          ),

          // Customer List
          Expanded(
            child: Observer(
              builder: (context) {
                if (restaurantCustomerStore.isLoading) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  );
                }

                final filteredCustomers = _getSortedCustomers(
                  restaurantCustomerStore.filteredCustomers,
                );

                if (filteredCustomers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: isTablet ? 80 : 64,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: isTablet ? 20 : 16),
                        Text(
                          _searchController.text.isEmpty
                              ? 'No customers yet'
                              : 'No customers found',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (_searchController.text.isEmpty) ...[
                          SizedBox(height: 8),
                          Text(
                            'Add your first customer to get started',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 14 : 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredCustomers.length,
                  padding: EdgeInsets.all(isTablet ? 20 : 16),
                  itemBuilder: (context, index) {
                    final customer = filteredCustomers[index];
                    return _buildCustomerCard(customer, isTablet);
                  },
                );
              },
            ),
          ),
        ],
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
            Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard(RestaurantCustomer customer, bool isTablet) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => _navigateToCustomerDetail(customer),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: isTablet ? 20 : 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  customer.name?.isNotEmpty == true ? customer.name![0].toUpperCase() : '?',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.primary),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer.name ?? 'Unknown', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
                    Text(
                      [
                        if (customer.phone != null) customer.phone!,
                        '${customer.totalVisites} visits',
                        '${customer.loyaltyPoints} pts',
                      ].join('  •  '),
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade500, size: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onSelected: (value) {
                  if (value == 'edit') _navigateToEditCustomer(customer);
                  if (value == 'delete') _deleteCustomer(customer);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text('Edit', style: GoogleFonts.poppins(fontSize: 13))),
                  PopupMenuItem(value: 'delete', child: Text('Delete', style: GoogleFonts.poppins(fontSize: 13, color: Colors.red))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}