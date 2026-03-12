import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unipos/util/color.dart';
import '../../../../util/restaurant/restaurant_auth_helper.dart';
import '../../../widget/componets/common/app_text_field.dart';

class Changepassword extends StatefulWidget {
  @override
  State<Changepassword> createState() => _ChangepasswordState();
}

class _ChangepasswordState extends State<Changepassword> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscureCurrentPass = true;
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;
  bool _isLoading = false;
  String? _errorMessage;

  static const String _passwordKey = 'restaurant_admin_password';
  static const String _defaultPassword = '123456';

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage =
          'New password and confirm password do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedPassword = prefs.getString(_passwordKey) ??
          RestaurantAuthHelper.hashPassword(_defaultPassword);
      final currentPassword = _currentPasswordController.text;
      final newPassword = _newPasswordController.text;

      if (!RestaurantAuthHelper.verifyPassword(
          currentPassword, storedPassword)) {
        setState(() {
          _errorMessage = 'Current password is incorrect';
          _isLoading = false;
        });
        return;
      }

      if (currentPassword == newPassword) {
        setState(() {
          _errorMessage =
              'New password must be different from the current password';
          _isLoading = false;
        });
        return;
      }

      await prefs.setString(
          _passwordKey, RestaurantAuthHelper.hashPassword(newPassword));

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      setState(() => _isLoading = false);
      _showSuccessDialog();
    } catch (_) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.green, size: 40),
            ),
            const SizedBox(height: 16),
            Text('Password Changed!',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Your password has been updated successfully.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Done',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.white,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(
          'Change Password',
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 22 : 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 12, vertical: 8),
            child: Container(
              padding: EdgeInsets.all(isTablet ? 10 : 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.person_rounded,
                  size: isTablet ? 22 : 20, color: AppColors.primary),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isTablet ? 24 : 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Header card ──────────────────────────────────────────
                Container(
                  padding: EdgeInsets.all(isTablet ? 18 : 16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.shield_outlined,
                          color: Colors.blue.shade700,
                          size: isTablet ? 26 : 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Secure your account',
                              style: GoogleFonts.poppins(
                                  fontSize: isTablet ? 14 : 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade800)),
                          const SizedBox(height: 2),
                          Text(
                            'Use a 4–6 digit PIN to protect admin access.',
                            style: GoogleFonts.poppins(
                                fontSize: isTablet ? 13 : 12,
                                color: Colors.blue.shade600),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 24),

                // ── Error banner ─────────────────────────────────────────
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Colors.red, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_errorMessage!,
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.red.shade700)),
                      ),
                      InkWell(
                        onTap: () =>
                            setState(() => _errorMessage = null),
                        child: const Icon(Icons.close_rounded,
                            size: 16, color: Colors.red),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Fields card ──────────────────────────────────────────
                Container(
                  padding: EdgeInsets.all(isTablet ? 20 : 16),
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
                  child: Column(children: [
                    AppTextField(
                      controller: _currentPasswordController,
                      label: 'Current Password',
                      hint: 'Enter current PIN',
                      icon: Icons.lock_outline_rounded,
                      required: true,
                      obscureText: _obscureCurrentPass,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureCurrentPass
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => setState(
                            () => _obscureCurrentPass =
                                !_obscureCurrentPass),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'PIN is required';
                        if (!RegExp(r'^\d{4,6}$').hasMatch(v.trim()))
                          return 'PIN must be 4–6 digits';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),
                    Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 16),

                    AppTextField(
                      controller: _newPasswordController,
                      label: 'New Password',
                      hint: 'Enter new PIN',
                      icon: Icons.lock_reset_rounded,
                      required: true,
                      obscureText: _obscureNewPass,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPass
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => setState(
                            () => _obscureNewPass = !_obscureNewPass),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'PIN is required';
                        if (!RegExp(r'^\d{4,6}$').hasMatch(v.trim()))
                          return 'PIN must be 4–6 digits';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),
                    Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 16),

                    AppTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirm New Password',
                      hint: 'Re-enter new PIN',
                      icon: Icons.lock_rounded,
                      required: true,
                      obscureText: _obscureConfirmPass,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPass
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => setState(() =>
                            _obscureConfirmPass = !_obscureConfirmPass),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'PIN is required';
                        if (!RegExp(r'^\d{4,6}$').hasMatch(v.trim()))
                          return 'PIN must be 4–6 digits';
                        return null;
                      },
                    ),
                  ]),
                ),

                const SizedBox(height: 24),

                // ── Submit button ────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: isTablet ? 54 : 50,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isLoading ? null : _handleChangePassword,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Icon(Icons.check_circle_outline_rounded,
                            color: Colors.white),
                    label: Text(
                      _isLoading ? 'Updating…' : 'Change Password',
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Requirements card ────────────────────────────────────
                Container(
                  padding: EdgeInsets.all(isTablet ? 16 : 14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.security_rounded,
                              color: AppColors.primary, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Text('PIN Requirements',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                      ]),
                      const SizedBox(height: 12),
                      _req('4–6 digits, numbers only'),
                      _req('Must differ from current password'),
                      _req('New PIN and confirm PIN must match'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _req(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        Icon(Icons.check_circle_outline_rounded,
            size: 15, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textSecondary)),
        ),
      ]),
    );
  }
}
