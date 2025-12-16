import 'package:flutter/material.dart';
import 'package:unipos/domain/services/retail/store_settings_service.dart';
import 'package:unipos/util/color.dart';

class StoreInfoSettingsScreen extends StatefulWidget {
  const StoreInfoSettingsScreen({Key? key}) : super(key: key);

  @override
  State<StoreInfoSettingsScreen> createState() => _StoreInfoSettingsScreenState();
}

class _StoreInfoSettingsScreenState extends State<StoreInfoSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeSettingsService = StoreSettingsService();

  // Controllers
  final _storeNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstNumberController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    _storeNameController.text = await _storeSettingsService.getStoreName() ?? '';
    _ownerNameController.text = await _storeSettingsService.getOwnerName() ?? '';
    _addressController.text = await _storeSettingsService.getStoreAddress() ?? '';
    _cityController.text = await _storeSettingsService.getStoreCity() ?? '';
    _stateController.text = await _storeSettingsService.getStoreState() ?? '';
    _pincodeController.text = await _storeSettingsService.getStorePincode() ?? '';
    _phoneController.text = await _storeSettingsService.getStorePhone() ?? '';
    _emailController.text = await _storeSettingsService.getStoreEmail() ?? '';
    _gstNumberController.text = await _storeSettingsService.getGSTNumber() ?? '';

    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final success = await _storeSettingsService.saveAllSettings(
      storeName: _storeNameController.text,
      ownerName: _ownerNameController.text.isNotEmpty ? _ownerNameController.text : null,
      address: _addressController.text.isNotEmpty ? _addressController.text : null,
      city: _cityController.text.isNotEmpty ? _cityController.text : null,
      state: _stateController.text.isNotEmpty ? _stateController.text : null,
      pincode: _pincodeController.text.isNotEmpty ? _pincodeController.text : null,
      phone: _phoneController.text.isNotEmpty ? _phoneController.text : null,
      email: _emailController.text.isNotEmpty ? _emailController.text : null,
      gstNumber: _gstNumberController.text.isNotEmpty ? _gstNumberController.text : null,
    );

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Store information saved successfully' : 'Failed to save settings'),
          backgroundColor: success ? AppColors.success : AppColors.danger,
        ),
      );

      if (success) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _gstNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Store Information'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkNeutral,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.info.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.info),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This information will appear on all receipts and invoices',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Business Details Section
                    _buildSectionHeader('Business Details'),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _storeNameController,
                      label: 'Store Name',
                      icon: Icons.store,
                      hint: 'e.g., ABC Retail Store',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Store name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _ownerNameController,
                      label: 'Owner Name',
                      icon: Icons.person,
                      hint: 'e.g., John Doe',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _gstNumberController,
                      label: 'GST Number',
                      icon: Icons.account_balance_wallet,
                      hint: 'e.g., 22AAAAA0000A1Z5',
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 24),

                    // Address Section
                    _buildSectionHeader('Address'),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _addressController,
                      label: 'Street Address',
                      icon: Icons.location_on,
                      hint: 'e.g., 123 Main Street',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
                            controller: _cityController,
                            label: 'City',
                            icon: Icons.location_city,
                            hint: 'e.g., Mumbai',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _pincodeController,
                            label: 'Pincode',
                            icon: Icons.pin_drop,
                            hint: '400001',
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _stateController,
                      label: 'State',
                      icon: Icons.map,
                      hint: 'e.g., Maharashtra',
                    ),
                    const SizedBox(height: 24),

                    // Contact Information Section
                    _buildSectionHeader('Contact Information'),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone,
                      hint: '+91 1234567890',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      icon: Icons.email,
                      hint: 'store@example.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Save Information',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.darkNeutral,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.words,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.white,
        counterText: maxLength != null ? '' : null,
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      validator: validator,
    );
  }
}