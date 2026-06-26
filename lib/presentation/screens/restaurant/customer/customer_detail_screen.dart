import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/customer_model_125.dart';
import 'add_edit_customer_screen.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';

class CustomerDetailScreen extends StatefulWidget {
  final RestaurantCustomer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late RestaurantCustomer _customer;
  bool _isLoading = false;
  final _pointsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
  }

  @override
  void dispose() {
    _pointsController.dispose();
    super.dispose();
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
        NotificationService.instance.showSuccess('Customer updated successfully');
      }
    }
  }

  Future<void> _addLoyaltyPoints() async {
    if (_isLoading) return;
    _pointsController.clear();
    final hInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2).clamp(40.0, 200.0)
        : 24.0;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.white,
        clipBehavior: Clip.antiAlias,
        insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — accent badge + title
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.stars_rounded,
                        color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Add Loyalty Points',
                        style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                  ),
                ],
              ),
            ),
            // Body — points input
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: AppTextField(
                controller: _pointsController,
                label: 'Points',
                hint: 'Enter points to add',
                icon: Icons.add_circle_outline_rounded,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            // Actions — balanced full-width buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(color: AppColors.divider),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Cancel',
                            style:
                                GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Add Points',
                            textAlign: TextAlign.center,
                            style:
                                GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final rawText = _pointsController.text.trim();

    if (result != true) return;
    if (rawText.isEmpty) {
      NotificationService.instance.showError('Please enter the number of points');
      return;
    }
    final points = int.tryParse(rawText);
    if (points == null || points <= 0) {
      NotificationService.instance.showError('Points must be a number greater than 0');
      return;
    }

    setState(() { _isLoading = true; });
    try {
      final success = await restaurantCustomerStore.addLoyaltyPoints(_customer.customerId, points);
      if (success) {
        await _refreshCustomerData();
        if (mounted) {
          NotificationService.instance.showSuccess('$points loyalty points added');
        }
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _deleteCustomer() async {
    if (_isLoading) return;
    final confirm = await showAppConfirmDialog(
      context: context,
      title: 'Delete "${_customer.name ?? 'Customer'}"?',
      message: 'This action cannot be undone.',
      confirmLabel: 'Delete',
      accent: AppColors.danger,
      icon: Icons.delete_outline,
    );

    if (confirm) {
      setState(() { _isLoading = true; });
      try {
        final success = await restaurantCustomerStore.deleteCustomer(_customer.customerId);
        if (mounted && success) {
          Navigator.pop(context, 'deleted');
        } else if (mounted) {
          setState(() { _isLoading = false; });
        }
      } catch (_) {
        if (mounted) setState(() { _isLoading = false; });
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
    final isTablet = !AppResponsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Customer Details',
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
                    color: AppColors.white,
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
                                fontWeight: FontWeight.w600,
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
                                color: AppColors.textSecondary,
                                size: isTablet ? 18 : 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                _customer.phone!,
                                style: GoogleFonts.poppins(
                                  fontSize: isTablet ? 16 : 15,
                                  color: AppColors.textSecondary,
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
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
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
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.divider),
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
                                      color: AppColors.textPrimary,
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
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 13 : 12,
            color: AppColors.textSecondary,
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
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
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
            color: isSubdued ? AppColors.textSecondary : AppColors.primary,
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
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 15 : 14,
                    color: isSubdued ? AppColors.textSecondary : AppColors.textPrimary,
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