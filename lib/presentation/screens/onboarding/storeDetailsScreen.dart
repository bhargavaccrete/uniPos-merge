import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/stores/setup_wizard_store.dart';
import '../../../presentation/widget/componets/common/app_text_field.dart';
import '../../../util/color.dart';
import '../../../util/common/app_responsive.dart';

/// Store Details Step
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

  String _val(String? v, String fallback) =>
      (v != null && v.isNotEmpty) ? v : fallback;

  void _initializeControllers() {
    _storeNameController = TextEditingController(text: _val(widget.store.storeName, 'Green Apple'));
    _ownerNameController = TextEditingController(text: _val(widget.store.ownerName, 'Bhargav'));
    _phoneController = TextEditingController(text: _val(widget.store.phone, '7845963574'));
    _emailController = TextEditingController(text: _val(widget.store.email, 'info@apple.com'));
    _addressController = TextEditingController(text: _val(widget.store.address, 'Infocity, Gandhinnagar'));
    _gstController = TextEditingController(text: _val(widget.store.gstin, 'GVFU415151YVBF'));
    _panController = TextEditingController(text: _val(widget.store.pan, 'FU415151YVBF'));
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
    final isWide = AppResponsive.isTablet(context) || AppResponsive.isDesktop(context);
    final hPad = AppResponsive.getValue<double>(context, mobile: 20, tablet: 32, desktop: 40);
    final vPad = AppResponsive.getValue<double>(context, mobile: 16, tablet: 20, desktop: 24);

    return Column(
      children: [
        // ── Scrollable form content ──────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, 0),
            child: Form(
              key: _formKey,
              child: isWide
                  ? _buildTabletLayout(context)
                  : _buildMobileLayout(context),
            ),
          ),
        ),

        // ── Buttons pinned at bottom ─────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(hPad, 12, hPad, vPad),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: AppColors.divider.withValues(alpha: 0.6)),
            ),
          ),
          child: _buildNavButtons(context),
        ),
      ],
    );
  }

  // ── Mobile: single column ────────────────────────────────────────────────────

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, isTablet: false),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        _buildBasicSection(context, isTablet: false),
        SizedBox(height: AppResponsive.mediumSpacing(context)),
        _buildContactSection(context, isTablet: false),
        SizedBox(height: AppResponsive.mediumSpacing(context)),
        _buildLegalSection(context),
        SizedBox(height: AppResponsive.largeSpacing(context)),
      ],
    );
  }

  // ── Tablet: centered max-width, two-column logo+fields ──────────────────────

  Widget _buildTabletLayout(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: AppResponsive.getValue<double>(context, mobile: 600, tablet: 700, desktop: 820),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, isTablet: true),
            SizedBox(height: AppResponsive.largeSpacing(context)),
            _buildBasicSection(context, isTablet: true),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            _buildContactSection(context, isTablet: true),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            _buildLegalSection(context),
            SizedBox(height: AppResponsive.largeSpacing(context)),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, {required bool isTablet}) {
    if (isTablet) {
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.store_rounded, color: Colors.white, size: 30),
          ),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Store Information',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.getValue<double>(context, mobile: 22, tablet: 26, desktop: 30),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Tell us about your store so we can personalize your experience',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Store Information',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.getValue<double>(context, mobile: 20, tablet: 24, desktop: 28),
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: AppResponsive.smallSpacing(context) - 2),
        Text(
          'Basic details about your store',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ── Section card wrapper ──────────────────────────────────────────────────────

  Widget _sectionCard(BuildContext context, {required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.mediumSpacing(context),
              vertical: AppResponsive.smallSpacing(context),
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppResponsive.borderRadius(context)),
                topRight: Radius.circular(AppResponsive.borderRadius(context)),
              ),
              border: Border(bottom: BorderSide(color: AppColors.divider.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                Icon(icon, size: AppResponsive.smallIconSize(context), color: AppColors.primary),
                SizedBox(width: AppResponsive.smallSpacing(context)),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          // Section content
          Padding(
            padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
            child: child,
          ),
        ],
      ),
    );
  }

  // ── Basic info section (name + owner + logo) ──────────────────────────────────

  Widget _buildBasicSection(BuildContext context, {required bool isTablet}) {
    return _sectionCard(
      context,
      title: 'Basic Information',
      icon: Icons.business_rounded,
      child: Column(
        children: [
          if (isTablet)
            // Tablet: logo left, name+owner right
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo upload
                SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Store Logo',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.smallFontSize(context),
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: AppResponsive.smallSpacing(context)),
                      _buildLogoUpload(context, height: 140),
                    ],
                  ),
                ),
                SizedBox(width: AppResponsive.mediumSpacing(context)),
                // Name + owner stacked
                Expanded(
                  child: Column(
                    children: [
                      AppTextField(
                        controller: _storeNameController,
                        label: 'Store Name',
                        hint: 'e.g. Green Apple Cafe',
                        icon: Icons.store_rounded,
                        required: true,
                        onChanged: (v) => widget.store.setStoreName(v),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Store name is required' : null,
                      ),
                      SizedBox(height: AppResponsive.mediumSpacing(context)),
                      AppTextField(
                        controller: _ownerNameController,
                        label: 'Owner Name',
                        hint: 'e.g. Bhargav Patel',
                        icon: Icons.person_rounded,
                        required: true,
                        onChanged: (v) => widget.store.setOwnerName(v),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Owner name is required' : null,
                      ),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            // Mobile: stacked
            AppTextField(
              controller: _storeNameController,
              label: 'Store Name',
              hint: 'e.g. Green Apple Cafe',
              icon: Icons.store_rounded,
              required: true,
              onChanged: (v) => widget.store.setStoreName(v),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Store name is required' : null,
            ),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            AppTextField(
              controller: _ownerNameController,
              label: 'Owner Name',
              hint: 'e.g. Bhargav Patel',
              icon: Icons.person_rounded,
              required: true,
              onChanged: (v) => widget.store.setOwnerName(v),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Owner name is required' : null,
            ),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            Text(
              'Store Logo',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: AppResponsive.smallSpacing(context)),
            _buildLogoUpload(context, height: 160),
          ],
        ],
      ),
    );
  }

  // ── Logo upload widget ────────────────────────────────────────────────────────

  Widget _buildLogoUpload(BuildContext context, {double height = 160}) {
    return Observer(
      builder: (_) {
        final hasImage = widget.store.logoByte != null;
        return InkWell(
          borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
          onTap: () => widget.store.pickLogo(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
              color: hasImage ? Colors.black : AppColors.surfaceLight,
              border: Border.all(color: AppColors.divider),
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
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.add_photo_alternate_rounded,
                              color: AppColors.primary, size: height > 140 ? 32 : 24),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload Logo',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        if (height > 140)
                          Text(
                            'Tap to browse',
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: AppColors.textSecondary),
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
                        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Contact section (phone + email + address) ─────────────────────────────────

  Widget _buildContactSection(BuildContext context, {required bool isTablet}) {
    return _sectionCard(
      context,
      title: 'Contact Details',
      icon: Icons.contact_phone_rounded,
      child: Column(
        children: [
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
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Phone is required' : null,
                ),
              ),
              SizedBox(width: AppResponsive.mediumSpacing(context)),
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
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          AppTextField(
            controller: _addressController,
            label: 'Store Address',
            hint: 'Street, City, State',
            icon: Icons.location_on_rounded,
            maxLines: isTablet ? 2 : 3,
            onChanged: (v) => widget.store.setAddress(v),
          ),
        ],
      ),
    );
  }

  // ── Legal section (GST + PAN) ──────────────────────────────────────────────────

  Widget _buildLegalSection(BuildContext context) {
    return _sectionCard(
      context,
      title: 'Tax & Legal (Optional)',
      icon: Icons.receipt_long_rounded,
      child: Row(
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
          SizedBox(width: AppResponsive.mediumSpacing(context)),
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
    );
  }

  // ── Nav buttons ───────────────────────────────────────────────────────────────

  Widget _buildNavButtons(BuildContext context) {
    return Observer(
      builder: (_) => Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                _syncToStore();
                widget.onPrevious();
              },
              icon: Icon(Icons.arrow_back, size: AppResponsive.smallIconSize(context)),
              label: Text(
                'Back',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.divider),
                padding: EdgeInsets.symmetric(
                  vertical: AppResponsive.getValue<double>(context, mobile: 14, tablet: 16, desktop: 16),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                ),
              ),
            ),
          ),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _syncToStore();
                  widget.store.saveBusinessDetails();
                  widget.onNext();
                }
              },
              icon: widget.store.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(Icons.arrow_forward, size: AppResponsive.smallIconSize(context), color: AppColors.white),
              label: Text(
                'Continue',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(
                  vertical: AppResponsive.getValue<double>(context, mobile: 14, tablet: 16, desktop: 16),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}