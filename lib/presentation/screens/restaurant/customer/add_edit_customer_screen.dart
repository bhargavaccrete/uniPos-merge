import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';
import 'package:uuid/uuid.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/customer_model_125.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';

class AddEditCustomerScreen extends StatefulWidget {
  final RestaurantCustomer? customer;

  const AddEditCustomerScreen({super.key, this.customer});

  @override
  State<AddEditCustomerScreen> createState() => _AddEditCustomerScreenState();
}

class _AddEditCustomerScreenState extends State<AddEditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _foodPreferenceController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;
  bool get _isEditMode => widget.customer != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _nameController.text = widget.customer!.name ?? '';
      _phoneController.text = widget.customer!.phone ?? '';
      _foodPreferenceController.text = widget.customer!.foodPrefrence ?? '';
      _notesController.text = widget.customer!.notes ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _foodPreferenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isEditMode) {
        // Update existing customer
        final updatedCustomer = widget.customer!.copyWith(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          foodPrefrence: _foodPreferenceController.text.trim().isEmpty
              ? null
              : _foodPreferenceController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          updatedAt: DateTime.now().toIso8601String(),
        );

        final success = await restaurantCustomerStore.updateCustomer(updatedCustomer);

        if (mounted) {
          Navigator.pop(context, success ? 'updated' : false);
        }
      } else {
        // Check if phone already exists
        final existingCustomer = await restaurantCustomerStore.getCustomerByPhone(
          _phoneController.text.trim(),
        );

        if (existingCustomer != null) {
          if (mounted) {
            NotificationService.instance.showError('A customer with this phone number already exists');
          }
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // Create new customer
        final newCustomer = RestaurantCustomer.create(
          customerId: const Uuid().v4(),
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          foodPrefrence: _foodPreferenceController.text.trim().isEmpty
              ? null
              : _foodPreferenceController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

        final success = await restaurantCustomerStore.addCustomer(newCustomer);

        if (mounted) {
          Navigator.pop(context, success ? 'added' : false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        NotificationService.instance.showError('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
          _isEditMode ? 'Edit Customer' : 'Add Customer',
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 22 : 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          if (_isLoading)
            Padding(
              padding: EdgeInsets.all(isTablet ? 18 : 16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(isTablet ? 20 : 16),
          children: [
            // Header Card
            Container(
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
                  Container(
                    width: isTablet ? 60 : 56,
                    height: isTablet ? 60 : 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isEditMode ? Icons.edit_rounded : Icons.person_add_rounded,
                      size: isTablet ? 32 : 28,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditMode ? 'Update Information' : 'New Customer',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 18 : 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _isEditMode
                              ? 'Edit customer details'
                              : 'Add a new customer to your database',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 14 : 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: isTablet ? 28 : 24),

            // Basic Information Section
            Text(
              'Basic Information',
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 17 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: isTablet ? 14 : 12),

            // Name Field
            TextFormField(
              controller: _nameController,
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 15 : 14,
              ),
              decoration: InputDecoration(
                labelText: 'Customer Name *',
                labelStyle: GoogleFonts.poppins(
                  fontSize: isTablet ? 14 : 13,
                  color: Colors.grey.shade600,
                ),
                hintText: 'Enter customer name',
                hintStyle: GoogleFonts.poppins(
                  fontSize: isTablet ? 14 : 13,
                ),
                prefixIcon: Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primary,
                  size: isTablet ? 22 : 20,
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
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isTablet ? 16 : 14,
                ),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter customer name';
                }
                return null;
              },
            ),

            SizedBox(height: isTablet ? 18 : 16),

            // Phone Field
            TextFormField(
              controller: _phoneController,
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 15 : 14,
              ),
              decoration: InputDecoration(
                labelText: 'Phone Number *',
                labelStyle: GoogleFonts.poppins(
                  fontSize: isTablet ? 14 : 13,
                  color: Colors.grey.shade600,
                ),
                hintText: 'Enter phone number',
                hintStyle: GoogleFonts.poppins(
                  fontSize: isTablet ? 14 : 13,
                ),
                prefixIcon: Icon(
                  Icons.phone_rounded,
                  color: AppColors.primary,
                  size: isTablet ? 22 : 20,
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
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isTablet ? 16 : 14,
                ),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter phone number';
                }
                if (value.trim().length < 10) {
                  return 'Please enter a valid phone number';
                }
                return null;
              },
            ),

            SizedBox(height: isTablet ? 28 : 24),

            // Preferences Section
            Text(
              'Preferences',
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 17 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: isTablet ? 14 : 12),

            // Food Preference Field
            TextFormField(
              controller: _foodPreferenceController,
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 15 : 14,
              ),
              decoration: InputDecoration(
                labelText: 'Food Preference',
                labelStyle: GoogleFonts.poppins(
                  fontSize: isTablet ? 14 : 13,
                  color: Colors.grey.shade600,
                ),
                hintText: 'E.g., Vegetarian, Non-Veg, Vegan',
                hintStyle: GoogleFonts.poppins(
                  fontSize: isTablet ? 14 : 13,
                ),
                prefixIcon: Icon(
                  Icons.restaurant_menu_rounded,
                  color: AppColors.primary,
                  size: isTablet ? 22 : 20,
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
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isTablet ? 16 : 14,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),

            SizedBox(height: isTablet ? 18 : 16),

            // Notes Field
            TextFormField(
              controller: _notesController,
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 15 : 14,
              ),
              decoration: InputDecoration(
                labelText: 'Notes',
                labelStyle: GoogleFonts.poppins(
                  fontSize: isTablet ? 14 : 13,
                  color: Colors.grey.shade600,
                ),
                hintText: 'Any special notes about this customer',
                hintStyle: GoogleFonts.poppins(
                  fontSize: isTablet ? 14 : 13,
                ),
                prefixIcon: Icon(
                  Icons.notes_rounded,
                  color: AppColors.primary,
                  size: isTablet ? 22 : 20,
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
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isTablet ? 16 : 14,
                ),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),

            SizedBox(height: isTablet ? 28 : 24),

            // Info Card
            if (_isEditMode)
              Container(
                padding: EdgeInsets.all(isTablet ? 16 : 14),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.info_outline_rounded,
                        color: Colors.blue,
                        size: isTablet ? 24 : 22,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customer Stats',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 15 : 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Total Visits: ${widget.customer!.totalVisites} | Loyalty Points: ${widget.customer!.loyaltyPoints}',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 13 : 12,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: isTablet ? 36 : 32),

            // Save Button
            SizedBox(
              height: isTablet ? 54 : 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveCustomer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _isEditMode ? 'Update Customer' : 'Add Customer',
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
    );
  }
}