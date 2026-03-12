import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/stores/setup_wizard_store.dart';
import '../../../presentation/widget/componets/common/app_text_field.dart';
import '../../../util/color.dart';

/// Store Details Step
/// UI Only - uses Observer to listen to store changes
/// Calls store methods for actions
class StoreDetailsStep extends StatefulWidget {
  final SetupWizardStore store;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const StoreDetailsStep({
    Key? key,
    required this.store,
    required this.onNext,
    required this.onPrevious,
  }) : super(key: key);

  @override
  State<StoreDetailsStep> createState() => _StoreDetailsStepState();
}

class _StoreDetailsStepState extends State<StoreDetailsStep> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _storeNameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _gstController;
  late TextEditingController _panController;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  String getValue(String? storeValue, String defaultValue) {
    return (storeValue != null && storeValue.isNotEmpty) ? storeValue : defaultValue;
  }

  void _initializeControllers() {
    _storeNameController = TextEditingController(text: getValue(widget.store.storeName, 'Green Apple'));
    _ownerNameController = TextEditingController(text: getValue(widget.store.ownerName, 'Bhargav'));
    _phoneController = TextEditingController(text: getValue(widget.store.phone, '7845963574'));
    _emailController = TextEditingController(text: getValue(widget.store.email, 'info@apple.com'));
    _addressController = TextEditingController(text: getValue(widget.store.address, 'Infocity, Gandhinnagar'));
    _gstController = TextEditingController(text: getValue(widget.store.gstin, 'GVFU415151YVBF'));
    _panController = TextEditingController(text: getValue(widget.store.pan, 'FU415151YVBF'));
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    _panController.dispose();
    super.dispose();
  }

  void _syncToStore() {
    widget.store.setStoreName(_storeNameController.text);
    widget.store.setOwnerName(_ownerNameController.text);
    widget.store.setPhone(_phoneController.text);
    widget.store.setEmail(_emailController.text);
    widget.store.setAddress(_addressController.text);
    widget.store.setGstin(_gstController.text);
    widget.store.setPan(_panController.text);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Store Information',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Basic details about your store',
              style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),

            // Store Name
            AppTextField(
              controller: _storeNameController,
              label: 'Store Name',
              hint: 'e.g. Green Apple Cafe',
              icon: Icons.store_rounded,
              required: true,
              onChanged: (v) => widget.store.setStoreName(v),
              validator: (v) => (v == null || v.isEmpty) ? 'Store name is required' : null,
            ),
            const SizedBox(height: 18),

            // Owner Name
            AppTextField(
              controller: _ownerNameController,
              label: 'Owner Name',
              hint: 'e.g. Bhargav Patel',
              icon: Icons.person_rounded,
              required: true,
              onChanged: (v) => widget.store.setOwnerName(v),
              validator: (v) => (v == null || v.isEmpty) ? 'Owner name is required' : null,
            ),
            const SizedBox(height: 18),

            // Logo Upload
            Text(
              'Store Logo',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: AppColors.surfaceLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.divider),
              ),
              child: Observer(
                builder: (_) {
                  bool hasImage = widget.store.logoByte != null;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => widget.store.pickLogo(),
                    child: Container(
                      width: double.infinity,
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: hasImage ? Colors.black : AppColors.surfaceLight,
                        image: hasImage
                            ? DecorationImage(
                                image: MemoryImage(widget.store.logoByte!),
                                fit: BoxFit.contain,
                              )
                            : null,
                      ),
                      child: Stack(
                        children: [
                          if (!hasImage)
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.add_photo_alternate_rounded,
                                        color: AppColors.primary, size: 36),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Upload Logo',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to browse your files',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          if (hasImage)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: InkWell(
                                onTap: () => widget.store.deleteLogo(),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.delete_rounded,
                                      color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),

            // Phone & Email Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    hint: '9876543210',
                    icon: Icons.phone_rounded,
                    required: true,
                    keyboardType: TextInputType.phone,
                    onChanged: (v) => widget.store.setPhone(v),
                    validator: (v) => (v == null || v.isEmpty) ? 'Phone is required' : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AppTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'info@store.com',
                    icon: Icons.email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (v) => widget.store.setEmail(v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Address
            AppTextField(
              controller: _addressController,
              label: 'Store Address',
              hint: 'Street, City, State',
              icon: Icons.location_on_rounded,
              maxLines: 3,
              onChanged: (v) => widget.store.setAddress(v),
            ),
            const SizedBox(height: 18),

            // GST & PAN Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _gstController,
                    label: 'GST Number',
                    hint: 'Optional',
                    icon: Icons.receipt_long_rounded,
                    onChanged: (v) => widget.store.setGstin(v),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AppTextField(
                    controller: _panController,
                    label: 'PAN Number',
                    hint: 'Optional',
                    icon: Icons.credit_card_rounded,
                    onChanged: (v) => widget.store.setPan(v),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Navigation Buttons
            Observer(
              builder: (_) => Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _syncToStore();
                        widget.onPrevious();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Back',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _syncToStore();
                          widget.store.saveBusinessDetails();
                          widget.onNext();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: widget.store.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Continue',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
