import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'customer_form_dialog.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late Customer _customer;
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
    final updatedCustomer = await customerStore.getCustomerById(
      _customer.customerId,
    );
    if (updatedCustomer != null) {
      setState(() {
        _customer = updatedCustomer;
      });
    }
  }

  Future<void> _editCustomer() async {
    final result = await showCustomerFormDialog(context, customer: _customer);

    if (result == 'updated') {
      await _refreshCustomerData();
      if (mounted) {
        NotificationService.instance.showSuccess(
          'Customer updated successfully',
        );
      }
    }
  }

  Future<void> _addLoyaltyPoints() async {
    if (_isLoading) return;
    _pointsController.clear();
    final hInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) -
                      AppResponsive.dialogWidth(context)) /
                  2)
              .clamp(40.0, double.infinity)
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.stars_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Add Loyalty Points',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.subheadingFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
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
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Add Points',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
      NotificationService.instance.showError(
        'Please enter the number of points',
      );
      return;
    }
    final points = int.tryParse(rawText);
    if (points == null || points <= 0) {
      NotificationService.instance.showError(
        'Points must be a number greater than 0',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      final success = await customerStore.addLoyaltyPoints(
        _customer.customerId,
        points,
      );
      if (success) {
        await _refreshCustomerData();
        if (mounted) {
          NotificationService.instance.showSuccess(
            '$points loyalty points added',
          );
        }
      }
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
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
      setState(() {
        _isLoading = true;
      });
      try {
        final success = await customerStore.deleteCustomer(
          _customer.customerId,
        );
        if (mounted && success) {
          Navigator.pop(context, 'deleted');
        } else if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      } catch (_) {
        if (mounted)
          setState(() {
            _isLoading = false;
          });
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
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Customer Details',
        actions: [
          IconButton(
            icon: Icon(
              Icons.edit_rounded,
              color: Colors.orange,
              size: AppResponsive.iconSize(context),
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
              size: AppResponsive.iconSize(context),
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
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Header
                  Container(
                    width: double.infinity,
                    color: AppColors.white,
                    padding: EdgeInsets.all(
                      AppResponsive.extraLargeSpacing(context),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: AppResponsive.getValue(
                            context,
                            mobile: 90.0,
                            tablet: 100.0,
                            desktop: 110.0,
                          ),
                          height: AppResponsive.getValue(
                            context,
                            mobile: 90.0,
                            tablet: 100.0,
                            desktop: 110.0,
                          ),
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
                                fontSize: AppResponsive.getValue(
                                  context,
                                  mobile: 38.0,
                                  tablet: 42.0,
                                  desktop: 46.0,
                                ),
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: AppResponsive.largeSpacing(context)),
                        Text(
                          _customer.name ?? 'Unknown Customer',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.getValue(
                              context,
                              mobile: 22.0,
                              tablet: 24.0,
                              desktop: 26.0,
                            ),
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
                                size: AppResponsive.largeSpacing(context),
                              ),
                              SizedBox(width: 8),
                              Text(
                                _customer.phone!,
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.bodyFontSize(context),
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
                    margin: AppResponsive.padding(context),
                    padding: AppResponsive.padding(context),
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
                          ),
                        ),
                        SizedBox(width: AppResponsive.mediumSpacing(context)),
                        Expanded(
                          child: _buildStatCard(
                            'Loyalty Points',
                            _customer.loyaltyPoints.toString(),
                            Icons.stars_rounded,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Information Sections
                  Padding(
                    padding: AppResponsive.padding(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Last Visit Info
                        _buildSectionTitle('Last Visit Information'),
                        SizedBox(height: AppResponsive.mediumSpacing(context)),
                        _buildInfoCard([
                          _buildInfoRow(
                            Icons.calendar_today_rounded,
                            'Last Visit',
                            _formatDate(_customer.lastVisitAt),
                          ),
                          if (_customer.lastorderType != null)
                            _buildInfoRow(
                              Icons.delivery_dining_rounded,
                              'Order Type',
                              _customer.lastorderType!,
                            ),
                        ]),

                        SizedBox(
                          height: AppResponsive.extraLargeSpacing(context),
                        ),

                        // Preferences
                        _buildSectionTitle('Preferences'),
                        SizedBox(height: AppResponsive.mediumSpacing(context)),
                        _buildInfoCard([
                          if (_customer.foodPrefrence != null)
                            _buildInfoRow(
                              Icons.restaurant_menu_rounded,
                              'Food Preference',
                              _customer.foodPrefrence!,
                            )
                          else
                            _buildInfoRow(
                              Icons.restaurant_menu_rounded,
                              'Food Preference',
                              'Not specified',
                              isSubdued: true,
                            ),
                          if (_customer.favoriteItems != null)
                            _buildInfoRow(
                              Icons.favorite_rounded,
                              'Favorite Items',
                              _customer.favoriteItems!,
                            ),
                        ]),

                        SizedBox(
                          height: AppResponsive.extraLargeSpacing(context),
                        ),

                        // Notes
                        if (_customer.notes != null) ...[
                          _buildSectionTitle('Notes'),
                          SizedBox(
                            height: AppResponsive.mediumSpacing(context),
                          ),
                          Container(
                            padding: EdgeInsets.all(
                              AppResponsive.mediumSpacing(context),
                            ),
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
                                  size: AppResponsive.iconSize(context),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _customer.notes!,
                                    style: GoogleFonts.poppins(
                                      fontSize: AppResponsive.smallFontSize(
                                        context,
                                      ),
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: AppResponsive.extraLargeSpacing(context),
                          ),
                        ],

                        // Account Info
                        _buildSectionTitle('Account Information'),
                        SizedBox(height: AppResponsive.mediumSpacing(context)),
                        _buildInfoCard([
                          _buildInfoRow(
                            Icons.person_add_rounded,
                            'Created',
                            _formatDate(_customer.createdAt),
                          ),
                          if (_customer.updatedAt != null)
                            _buildInfoRow(
                              Icons.update_rounded,
                              'Last Updated',
                              _formatDate(_customer.updatedAt),
                            ),
                          _buildInfoRow(
                            Icons.badge_rounded,
                            'Customer ID',
                            '${_customer.customerId.substring(0, 8)}...',
                            isSubdued: true,
                          ),
                        ]),

                        SizedBox(height: AppResponsive.largeIconSize(context)),

                        // Action Button
                        SizedBox(
                          width: double.infinity,
                          height: AppResponsive.getValue(
                            context,
                            mobile: 50.0,
                            tablet: 54.0,
                            desktop: 58.0,
                          ),
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
                              size: AppResponsive.iconSize(context),
                            ),
                            label: Text(
                              'Add Loyalty Points',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.subheadingFontSize(
                                  context,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: AppResponsive.largeSpacing(context)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: color,
            size: AppResponsive.extraLargeSpacing(context),
          ),
        ),
        SizedBox(height: AppResponsive.smallSpacing(context)),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.headingFontSize(context),
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: AppResponsive.subheadingFontSize(context),
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool isSubdued = false,
  }) {
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
                    fontSize: AppResponsive.smallFontSize(context),
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    color: isSubdued
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
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
