import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/customer_model_125.dart';
import 'add_edit_customer_screen.dart';
import 'customer_detail_screen.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';

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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_rounded,
                color: Colors.red,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Customer?',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${customer.name ?? 'this customer'}? This action cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
                TextField(
                  controller: _searchController,
                  onChanged: _searchCustomers,
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 15 : 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by name or phone...',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: isTablet ? 15 : 14,
                      color: Colors.grey.shade500,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                      size: isTablet ? 24 : 22,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: isTablet ? 22 : 20),
                            onPressed: () {
                              _searchController.clear();
                              _searchCustomers('');
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: isTablet ? 16 : 12,
                    ),
                  ),
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

              return Container(
                margin: EdgeInsets.all(isTablet ? 20 : 16),
                padding: EdgeInsets.all(isTablet ? 20 : 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total',
                        customers.length.toString(),
                        Icons.people_rounded,
                        Colors.blue,
                        isTablet,
                      ),
                    ),
                    SizedBox(width: isTablet ? 16 : 12),
                    Expanded(
                      child: _buildStatCard(
                        'Visits',
                        customers
                            .fold(0, (sum, c) => sum + c.totalVisites)
                            .toString(),
                        Icons.calendar_today_rounded,
                        Colors.green,
                        isTablet,
                      ),
                    ),
                    SizedBox(width: isTablet ? 16 : 12),
                    Expanded(
                      child: _buildStatCard(
                        'Points',
                        customers
                            .fold(0, (sum, c) => sum + c.loyaltyPoints)
                            .toString(),
                        Icons.stars_rounded,
                        Colors.orange,
                        isTablet,
                      ),
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

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isTablet) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isTablet ? 12 : 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: color,
            size: isTablet ? 28 : 24,
          ),
        ),
        SizedBox(height: isTablet ? 10 : 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 22 : 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 13 : 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerCard(RestaurantCustomer customer, bool isTablet) {
    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 12 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToCustomerDetail(customer),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 16 : 14),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: isTablet ? 56 : 50,
                  height: isTablet ? 56 : 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      customer.name?.isNotEmpty == true
                          ? customer.name![0].toUpperCase()
                          : '?',
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 24 : 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),

                // Customer Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name ?? 'Unknown',
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 16 : 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      if (customer.phone != null)
                        Row(
                          children: [
                            Icon(
                              Icons.phone_rounded,
                              size: isTablet ? 15 : 14,
                              color: Colors.grey.shade600,
                            ),
                            SizedBox(width: 4),
                            Text(
                              customer.phone!,
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 14 : 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          _buildInfoChip(
                            Icons.restaurant_rounded,
                            '${customer.totalVisites} visits',
                            Colors.blue,
                            isTablet,
                          ),
                          SizedBox(width: 8),
                          _buildInfoChip(
                            Icons.stars_rounded,
                            '${customer.loyaltyPoints} pts',
                            Colors.orange,
                            isTablet,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _navigateToCustomerDetail(customer),
                      icon: Icon(Icons.visibility_rounded),
                      color: Colors.blue,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
                      ),
                    ),
                    SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: Colors.grey.shade700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _navigateToEditCustomer(customer);
                            break;
                          case 'delete':
                            _deleteCustomer(customer);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                size: 20,
                                color: Colors.orange,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Edit',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
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
                                Icons.delete_rounded,
                                size: 20,
                                color: Colors.red,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Delete',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color, bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 10 : 8,
        vertical: isTablet ? 5 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isTablet ? 15 : 14,
            color: color,
          ),
          SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 12 : 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}