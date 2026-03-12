import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/stores/setup_wizard_store.dart';
import '../../../util/common/app_responsive.dart';
import 'package:unipos/core/config/app_config.dart';
import 'package:unipos/data/models/retail/hive_model/staff_model_222.dart';
import 'package:unipos/data/models/restaurant/db/staffModel_310.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../core/di/service_locator.dart';
import '../../../util/restaurant/restaurant_auth_helper.dart';
import '../../../util/color.dart';
import '../../../presentation/widget/componets/common/app_text_field.dart';

/// Staff Setup Step — Business Mode Aware
class StaffSetupStep extends StatefulWidget {
  final SetupWizardStore store;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const StaffSetupStep({
    Key? key,
    required this.store,
    required this.onNext,
    required this.onPrevious,
  }) : super(key: key);

  @override
  State<StaffSetupStep> createState() => _StaffSetupStepState();
}

class _StaffSetupStepState extends State<StaffSetupStep> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();
  final _uuid = const Uuid();

  // Focus chain
  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _pinFocus = FocusNode();

  String _selectedRole = 'Cashier';
  final List<String> _retailRoles = ['Manager', 'Cashier', 'Sales', 'Inventory'];
  final List<String> _restaurantRoles = ['Manager', 'Waiter', 'Cashier', 'Chef'];

  static const _roleIcons = {
    'Manager':   Icons.manage_accounts_rounded,
    'Cashier':   Icons.point_of_sale_rounded,
    'Sales':     Icons.storefront_rounded,
    'Inventory': Icons.inventory_2_rounded,
    'Waiter':    Icons.restaurant_rounded,
    'Chef':      Icons.soup_kitchen_rounded,
  };

  static const _roleColors = {
    'Manager':   Color(0xFF7C3AED),
    'Cashier':   Color(0xFF059669),
    'Sales':     Color(0xFFD97706),
    'Inventory': Color(0xFF0284C7),
    'Waiter':    Color(0xFFDB2777),
    'Chef':      Color(0xFFDC2626),
  };

  // Retail-specific permissions
  bool _canGiveDiscounts = false;
  bool _canAccessReports = false;
  bool _canManageInventory = false;

  // UI state
  bool _isPinVisible = false;
  bool _isSaving = false; // double-tap guard for Add button
  bool _isSavingAll = false; // guard for Save & Continue

  // Inline error for first name
  String? _firstNameError;

  List<dynamic> _staffMembers = [];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _usernameController.dispose();
    _pinController.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _usernameFocus.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  // ── Permissions reset when role changes ──────────────────────────────────

  void _applyRoleDefaults(String role) {
    setState(() {
      _selectedRole = role;
      if (role == 'Manager') {
        _canGiveDiscounts = true;
        _canAccessReports = true;
        _canManageInventory = true;
      } else {
        // Reset to non-manager defaults
        _canGiveDiscounts = false;
        _canAccessReports = false;
        _canManageInventory = false;
      }
    });
  }

  // ── Add staff member ─────────────────────────────────────────────────────

  void _addStaff() {
    if (_isSaving) return;

    final firstName = _firstNameController.text.trim();
    final pin = _pinController.text.trim();
    final phone = _phoneController.text.trim();

    // Validate required fields
    if (firstName.isEmpty) {
      setState(() => _firstNameError = 'First name is required');
      _firstNameFocus.requestFocus();
      return;
    }
    if (pin.isEmpty) {
      NotificationService.instance.showError('PIN is required');
      _pinFocus.requestFocus();
      return;
    }
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      NotificationService.instance.showError('PIN must be 4–6 digits');
      _pinFocus.requestFocus();
      return;
    }
    if (phone.isNotEmpty && phone.length != 10) {
      NotificationService.instance.showError('Mobile number must be exactly 10 digits');
      _phoneFocus.requestFocus();
      return;
    }

    // Auto-generate username from first name if blank
    final username = _usernameController.text.trim().isEmpty
        ? firstName.toLowerCase()
        : _usernameController.text.trim();

    // Duplicate username check
    final usernameExists = _staffMembers.any((s) {
      if (s is RetailStaffModel) return s.username.toLowerCase() == username.toLowerCase();
      if (s is StaffModel) return s.userName.toLowerCase() == username.toLowerCase();
      return false;
    });
    if (usernameExists) {
      NotificationService.instance
          .showError('Username "$username" is already taken. Choose a different one.');
      _usernameFocus.requestFocus();
      return;
    }

    // Duplicate PIN check (compare plaintext PINs before hashing)
    final pinExists = _staffMembers.any((s) {
      if (s is RetailStaffModel) return s.pin == pin;
      if (s is StaffModel) {
        // The stored pinNo is already hashed; verify against the new pin
        return RestaurantAuthHelper.verifyPassword(pin, s.pinNo);
      }
      return false;
    });
    if (pinExists) {
      NotificationService.instance
          .showError('This PIN is already used by another staff member.');
      _pinFocus.requestFocus();
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (AppConfig.isRetail) {
        _staffMembers.add(RetailStaffModel(
          id: _uuid.v4(),
          firstName: firstName,
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          phone: phone.isEmpty ? null : phone,
          username: username,
          pin: pin,
          role: _selectedRole,
          canProcessSales: true,
          canProcessReturns: _selectedRole == 'Manager',
          canGiveDiscounts: _canGiveDiscounts,
          maxDiscountPercent: _canGiveDiscounts ? 20.0 : 0.0,
          canAccessReports: _canAccessReports,
          canManageInventory: _canManageInventory,
          canManageStaff: _selectedRole == 'Manager',
          canVoidTransactions: _selectedRole == 'Manager',
          canOpenCashDrawer: true,
          createdAt: DateTime.now(),
        ));
      } else {
        _staffMembers.add(StaffModel(
          id: _uuid.v4(),
          userName: username,
          firstName: firstName,
          lastName: _lastNameController.text.trim(),
          isCashier: _selectedRole,
          mobileNo: phone,
          emailId: _emailController.text.trim(),
          pinNo: RestaurantAuthHelper.hashPassword(pin),
          createdAt: DateTime.now(),
        ));
      }

      // Clear form
      _firstNameController.clear();
      _lastNameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _usernameController.clear();
      _pinController.clear();
      _firstNameError = null;
      _applyRoleDefaults('Cashier');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _deleteStaff(int index) {
    setState(() => _staffMembers.removeAt(index));
  }

  // ── Save all to Hive ─────────────────────────────────────────────────────

  Future<bool> _saveStaffToDatabase() async {
    try {
      if (AppConfig.isRetail) {
        final box = Hive.box<RetailStaffModel>('retail_staff');
        for (final staff in _staffMembers) {
          if (staff is RetailStaffModel) {
            await box.put(staff.id, staff);
            debugPrint('Saved retail staff: ${staff.fullName}');
          }
        }
      } else {
        for (final staff in _staffMembers) {
          if (staff is StaffModel) {
            await staffStore.addStaff(staff);
            debugPrint('Saved restaurant staff: ${staff.firstName} ${staff.lastName}');
          }
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error saving staff: $e');
      if (mounted) {
        NotificationService.instance.showError('Failed to save staff: $e');
      }
      return false;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _staffDisplayName(dynamic staff) {
    if (staff is RetailStaffModel) return '${staff.firstName} ${staff.lastName}'.trim();
    if (staff is StaffModel) return '${staff.firstName} ${staff.lastName}'.trim();
    return 'Unknown';
  }

  String _staffRole(dynamic staff) {
    if (staff is RetailStaffModel) return staff.role;
    if (staff is StaffModel) return staff.isCashier;
    return '';
  }

  String _staffUsername(dynamic staff) {
    if (staff is RetailStaffModel) return '@${staff.username}';
    if (staff is StaffModel) return '@${staff.userName}';
    return '';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isRetail = AppConfig.isRetail;
    final roles = isRetail ? _retailRoles : _restaurantRoles;

    final hPad = AppResponsive.getValue<double>(
        context, mobile: 20, tablet: 32, desktop: 40);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.badge_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Staff Setup',
                        style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text(
                      'Add staff who will use the ${isRetail ? "POS" : "restaurant"} system',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Add Staff Form ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_add_rounded,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text('Add Staff Member',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 20),

                // First + Last name
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppTextField(
                            controller: _firstNameController,
                            focusNode: _firstNameFocus,
                            label: 'First Name',
                            hint: 'e.g. John',
                            icon: Icons.person_outline,
                            required: true,
                            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_lastNameFocus),
                            onChanged: (_) {
                              if (_firstNameError != null) setState(() => _firstNameError = null);
                            },
                          ),
                          if (_firstNameError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 4),
                              child: Text(_firstNameError!,
                                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.danger)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _lastNameController,
                        focusNode: _lastNameFocus,
                        label: 'Last Name',
                        hint: 'e.g. Doe',
                        icon: Icons.person_outline,
                        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_emailFocus),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Email + Phone
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _emailController,
                        focusNode: _emailFocus,
                        label: 'Email',
                        hint: 'Optional',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_phoneFocus),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _phoneController,
                        focusNode: _phoneFocus,
                        label: 'Phone',
                        hint: 'Optional, 10 digits',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_usernameFocus),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Username + PIN
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _usernameController,
                        focusNode: _usernameFocus,
                        label: 'Username',
                        hint: 'Auto from first name',
                        icon: Icons.alternate_email_rounded,
                        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_pinFocus),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _pinController,
                        focusNode: _pinFocus,
                        label: 'PIN',
                        hint: '4–6 digits',
                        icon: Icons.lock_outline_rounded,
                        required: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        obscureText: !_isPinVisible,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPinVisible ? Icons.visibility_off : Icons.visibility,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () => setState(() => _isPinVisible = !_isPinVisible),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Role selector — inline chips
                _buildRoleSelector(roles),
                const SizedBox(height: 12),

                // Retail permissions
                if (isRetail) ...[
                  Text('POS Permissions',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  _buildPermissionTile(
                    label: 'Can Give Discounts',
                    value: _canGiveDiscounts,
                    onChanged: (v) => setState(() => _canGiveDiscounts = v!),
                  ),
                  _buildPermissionTile(
                    label: 'Can Access Reports',
                    value: _canAccessReports,
                    onChanged: (v) => setState(() => _canAccessReports = v!),
                  ),
                  _buildPermissionTile(
                    label: 'Can Manage Inventory',
                    value: _canManageInventory,
                    onChanged: (v) => setState(() => _canManageInventory = v!),
                  ),
                  const SizedBox(height: 4),
                ],

                // Add button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _addStaff,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add, color: AppColors.white, size: 18),
                    label: Text(
                      _isSaving ? 'Adding…' : 'Add Staff Member',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Added staff list ──
          if (_staffMembers.isNotEmpty) ...[
            Text('Added Staff (${_staffMembers.length})',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            ...List.generate(_staffMembers.length, (i) => _buildStaffCard(i)),
          ],

          const SizedBox(height: 32),

          // ── Navigation ──
          Observer(builder: (_) {
            return Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onPrevious,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: Text('Back',
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: (widget.store.isLoading || _isSavingAll)
                        ? null
                        : () async {
                            setState(() => _isSavingAll = true);
                            try {
                              if (_staffMembers.isNotEmpty) {
                                final ok = await _saveStaffToDatabase();
                                if (!ok) return; // error shown, don't advance
                              }
                              widget.onNext();
                            } finally {
                              if (mounted) setState(() => _isSavingAll = false);
                            }
                          },
                    icon: (widget.store.isLoading || _isSavingAll)
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.arrow_forward, size: 16, color: AppColors.white),
                    label: Text(
                      _isSavingAll
                          ? 'Saving…'
                          : _staffMembers.isEmpty
                              ? 'Skip (Add Later)'
                              : 'Save & Continue',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── Staff card ────────────────────────────────────────────────────────────

  Widget _buildStaffCard(int index) {
    final staff = _staffMembers[index];
    final name = _staffDisplayName(staff);
    final role = _staffRole(staff);
    final username = _staffUsername(staff);

    // Role colour
    Color roleColor;
    if (role == 'Manager') {
      roleColor = AppColors.primary;
    } else if (role == 'Cashier') {
      roleColor = AppColors.success;
    } else {
      roleColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Role chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(role,
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: roleColor)),
                      ),
                      const SizedBox(width: 8),
                      // Username
                      Text(username,
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Masked PIN
                  Text('PIN: ●●●●',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: AppColors.danger.withValues(alpha: 0.8), size: 20),
              onPressed: () => _deleteStaff(index),
              tooltip: 'Remove',
              splashRadius: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ── Role selector ─────────────────────────────────────────────────────────

  Widget _buildRoleSelector(List<String> roles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Role',
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: roles.map((role) {
            final isSelected = _selectedRole == role;
            final color = _roleColors[role] ?? AppColors.primary;
            final icon = _roleIcons[role] ?? Icons.person_rounded;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: role != roles.last ? 8 : 0),
                child: GestureDetector(
                  onTap: () => _applyRoleDefaults(role),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.1)
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? color : AppColors.divider,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon,
                            size: 22,
                            color: isSelected ? color : AppColors.textSecondary),
                        const SizedBox(height: 4),
                        Text(role,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected ? color : AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPermissionTile({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
