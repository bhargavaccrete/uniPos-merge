import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/data/models/restaurant/db/customer_model_125.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_customer.dart';
import 'package:unipos/util/color.dart';
import 'add_edit_customer_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final RestaurantCustomer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late RestaurantCustomer _customer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
  }

  void _refreshCustomerData() {
    final updatedCustomer = HiveCustomer.getCustomerById(_customer.customerId);
    if (updatedCustomer != null) {
      setState(() {
        _customer = updatedCustomer;
      });
    }
  }

  Future<void> _editCustomer() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditCustomerScreen(customer: _customer),
      ),
    );

    if (result == true) {
      _refreshCustomerData();
    }
  }

  Future<void> _addLoyaltyPoints() async {
    final pointsController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Loyalty Points', style: GoogleFonts.poppins()),
        content: TextField(
          controller: pointsController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Points',
            labelStyle: GoogleFonts.poppins(),
            hintText: 'Enter points to add',
            hintStyle: GoogleFonts.poppins(),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            child: Text(
              'Add',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (result == true && pointsController.text.isNotEmpty) {
      final points = int.tryParse(pointsController.text);
      if (points != null && points > 0) {
        await HiveCustomer.addLoyaltyPoints(_customer.customerId, points);
        _refreshCustomerData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$points loyalty points added',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteCustomer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Customer', style: GoogleFonts.poppins()),
        content: Text(
          'Are you sure you want to delete ${_customer.name ?? 'this customer'}? This action cannot be undone.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await HiveCustomer.deleteCustomer(_customer.customerId);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Customer deleted successfully',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Never';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy hh:mm a').format(date);
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Customer Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editCustomer,
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteCustomer,
            tooltip: 'Delete',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Header
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          child: Text(
                            _customer.name?.isNotEmpty == true
                                ? _customer.name![0].toUpperCase()
                                : '?',
                            style: GoogleFonts.poppins(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _customer.name ?? 'Unknown Customer',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (_customer.phone != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.phone,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _customer.phone!,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Stats Cards
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Visits',
                            _customer.totalVisites.toString(),
                            Icons.restaurant,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Loyalty Points',
                            _customer.loyaltyPoints.toString(),
                            Icons.stars,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Information Sections
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Last Visit Info
                        _buildSectionTitle('Last Visit Information'),
                        const SizedBox(height: 12),
                        _buildInfoCard([
                          _buildInfoRow(
                            Icons.calendar_today,
                            'Last Visit',
                            _formatDate(_customer.lastVisitAt),
                          ),
                          if (_customer.lastorderType != null)
                            _buildInfoRow(
                              Icons.delivery_dining,
                              'Order Type',
                              _customer.lastorderType!,
                            ),
                        ]),

                        const SizedBox(height: 24),

                        // Preferences
                        _buildSectionTitle('Preferences'),
                        const SizedBox(height: 12),
                        _buildInfoCard([
                          if (_customer.foodPrefrence != null)
                            _buildInfoRow(
                              Icons.restaurant_menu,
                              'Food Preference',
                              _customer.foodPrefrence!,
                            )
                          else
                            _buildInfoRow(
                              Icons.restaurant_menu,
                              'Food Preference',
                              'Not specified',
                              isSubdued: true,
                            ),
                          if (_customer.favoriteItems != null)
                            _buildInfoRow(
                              Icons.favorite,
                              'Favorite Items',
                              _customer.favoriteItems!,
                            ),
                        ]),

                        const SizedBox(height: 24),

                        // Notes
                        if (_customer.notes != null) ...[
                          _buildSectionTitle('Notes'),
                          const SizedBox(height: 12),
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.notes,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _customer.notes!,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Account Info
                        _buildSectionTitle('Account Information'),
                        const SizedBox(height: 12),
                        _buildInfoCard([
                          _buildInfoRow(
                            Icons.person_add,
                            'Created',
                            _formatDate(_customer.createdAt),
                          ),
                          if (_customer.updatedAt != null)
                            _buildInfoRow(
                              Icons.update,
                              'Last Updated',
                              _formatDate(_customer.updatedAt),
                            ),
                          _buildInfoRow(
                            Icons.badge,
                            'Customer ID',
                            _customer.customerId.substring(0, 8) + '...',
                            isSubdued: true,
                          ),
                        ]),

                        const SizedBox(height: 32),

                        // Action Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _addLoyaltyPoints,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.add_circle, color: Colors.white),
                            label: Text(
                              'Add Loyalty Points',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.grey[800],
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool isSubdued = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: isSubdued ? Colors.grey[400] : AppColors.primary,
          ),
          const SizedBox(width: 12),
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
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isSubdued ? Colors.grey[500] : Colors.grey[800],
                    fontWeight: isSubdued ? FontWeight.normal : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}