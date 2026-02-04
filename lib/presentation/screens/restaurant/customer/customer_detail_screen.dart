import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/customer_model_125.dart';
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

  Future<void> _refreshCustomerData() async {
    final updatedCustomer = await restaurantCustomerStore.getCustomerById(_customer.customerId);
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

    if (result == 'updated') {
      await _refreshCustomerData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Customer updated successfully',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _addLoyaltyPoints() async {
    final pointsController = TextEditingController();
    final result = await showDialog<bool>(
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
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.stars_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Add Loyalty Points',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: pointsController,
          keyboardType: TextInputType.number,
          style: GoogleFonts.poppins(fontSize: 15),
          decoration: InputDecoration(
            labelText: 'Points',
            labelStyle: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            hintText: 'Enter points to add',
            hintStyle: GoogleFonts.poppins(fontSize: 14),
            prefixIcon: Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.primary,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
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
            onPressed: () {
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Add',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true && pointsController.text.isNotEmpty) {
      final points = int.tryParse(pointsController.text);
      if (points != null && points > 0) {
        final success = await restaurantCustomerStore.addLoyaltyPoints(_customer.customerId, points);
        if (success) {
          await _refreshCustomerData();
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
  }

  Future<void> _deleteCustomer() async {
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
          'Are you sure you want to delete ${_customer.name ?? 'this customer'}? This action cannot be undone.',
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
      final success = await restaurantCustomerStore.deleteCustomer(_customer.customerId);
      if (mounted && success) {
        Navigator.pop(context, 'deleted');
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
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black87),
        title: Text(
          'Customer Details',
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 22 : 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.edit_rounded,
              color: Colors.orange,
              size: isTablet ? 24 : 22,
            ),
            onPressed: _editCustomer,
            tooltip: 'Edit',
            style: IconButton.styleFrom(
              backgroundColor: Colors.orange.withValues(alpha: 0.1),
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.delete_rounded,
              color: Colors.red,
              size: isTablet ? 24 : 22,
            ),
            onPressed: _deleteCustomer,
            tooltip: 'Delete',
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha: 0.1),
            ),
          ),
          SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Header
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: EdgeInsets.all(isTablet ? 28 : 24),
                    child: Column(
                      children: [
                        Container(
                          width: isTablet ? 100 : 90,
                          height: isTablet ? 100 : 90,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _customer.name?.isNotEmpty == true
                                  ? _customer.name![0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 42 : 38,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: isTablet ? 18 : 16),
                        Text(
                          _customer.name ?? 'Unknown Customer',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 24 : 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        if (_customer.phone != null) ...[
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.phone_rounded,
                                color: Colors.grey.shade600,
                                size: isTablet ? 18 : 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                _customer.phone!,
                                style: GoogleFonts.poppins(
                                  fontSize: isTablet ? 16 : 15,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Stats Cards
                  Container(
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
                            'Total Visits',
                            _customer.totalVisites.toString(),
                            Icons.restaurant_rounded,
                            Colors.blue,
                            isTablet,
                          ),
                        ),
                        SizedBox(width: isTablet ? 16 : 12),
                        Expanded(
                          child: _buildStatCard(
                            'Loyalty Points',
                            _customer.loyaltyPoints.toString(),
                            Icons.stars_rounded,
                            Colors.orange,
                            isTablet,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Information Sections
                  Padding(
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Last Visit Info
                        _buildSectionTitle('Last Visit Information', isTablet),
                        SizedBox(height: isTablet ? 14 : 12),
                        _buildInfoCard(
                          [
                            _buildInfoRow(
                              Icons.calendar_today_rounded,
                              'Last Visit',
                              _formatDate(_customer.lastVisitAt),
                              isTablet,
                            ),
                            if (_customer.lastorderType != null)
                              _buildInfoRow(
                                Icons.delivery_dining_rounded,
                                'Order Type',
                                _customer.lastorderType!,
                                isTablet,
                              ),
                          ],
                          isTablet,
                        ),

                        SizedBox(height: isTablet ? 28 : 24),

                        // Preferences
                        _buildSectionTitle('Preferences', isTablet),
                        SizedBox(height: isTablet ? 14 : 12),
                        _buildInfoCard(
                          [
                            if (_customer.foodPrefrence != null)
                              _buildInfoRow(
                                Icons.restaurant_menu_rounded,
                                'Food Preference',
                                _customer.foodPrefrence!,
                                isTablet,
                              )
                            else
                              _buildInfoRow(
                                Icons.restaurant_menu_rounded,
                                'Food Preference',
                                'Not specified',
                                isTablet,
                                isSubdued: true,
                              ),
                            if (_customer.favoriteItems != null)
                              _buildInfoRow(
                                Icons.favorite_rounded,
                                'Favorite Items',
                                _customer.favoriteItems!,
                                isTablet,
                              ),
                          ],
                          isTablet,
                        ),

                        SizedBox(height: isTablet ? 28 : 24),

                        // Notes
                        if (_customer.notes != null) ...[
                          _buildSectionTitle('Notes', isTablet),
                          SizedBox(height: isTablet ? 14 : 12),
                          Container(
                            padding: EdgeInsets.all(isTablet ? 16 : 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade200,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.notes_rounded,
                                  color: AppColors.primary,
                                  size: isTablet ? 22 : 20,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _customer.notes!,
                                    style: GoogleFonts.poppins(
                                      fontSize: isTablet ? 14 : 13,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: isTablet ? 28 : 24),
                        ],

                        // Account Info
                        _buildSectionTitle('Account Information', isTablet),
                        SizedBox(height: isTablet ? 14 : 12),
                        _buildInfoCard(
                          [
                            _buildInfoRow(
                              Icons.person_add_rounded,
                              'Created',
                              _formatDate(_customer.createdAt),
                              isTablet,
                            ),
                            if (_customer.updatedAt != null)
                              _buildInfoRow(
                                Icons.update_rounded,
                                'Last Updated',
                                _formatDate(_customer.updatedAt),
                                isTablet,
                              ),
                            _buildInfoRow(
                              Icons.badge_rounded,
                              'Customer ID',
                              '${_customer.customerId.substring(0, 8)}...',
                              isTablet,
                              isSubdued: true,
                            ),
                          ],
                          isTablet,
                        ),

                        SizedBox(height: isTablet ? 36 : 32),

                        // Action Button
                        SizedBox(
                          width: double.infinity,
                          height: isTablet ? 54 : 50,
                          child: ElevatedButton.icon(
                            onPressed: _addLoyaltyPoints,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            icon: Icon(
                              Icons.add_circle_rounded,
                              size: isTablet ? 24 : 22,
                            ),
                            label: Text(
                              'Add Loyalty Points',
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 17 : 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: isTablet ? 20 : 16),
                      ],
                    ),
                  ),
                ],
              ),
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
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool isTablet) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: isTablet ? 18 : 17,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    bool isTablet, {
    bool isSubdued = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isTablet ? 10 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: isTablet ? 22 : 20,
            color: isSubdued ? Colors.grey.shade400 : AppColors.primary,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 13 : 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 15 : 14,
                    color: isSubdued ? Colors.grey.shade500 : Colors.grey.shade800,
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