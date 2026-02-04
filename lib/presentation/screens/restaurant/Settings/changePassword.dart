import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../constants/restaurant/color.dart';
import '../../../../util/restaurant/responsive_helper.dart';
import '../../../widget/componets/restaurant/componets/Button.dart';
import '../../../widget/componets/restaurant/componets/Textform.dart';
import 'package:unipos/util/color.dart';
class Changepassword extends StatefulWidget {
  @override
  State<Changepassword> createState() => _ChangepasswordState();
}

class _ChangepasswordState extends State<Changepassword> {
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscureCurrentPass = true;
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // SharedPreferences keys (must match login screen)
  static const String _usernameKey = 'restaurant_admin_username';
  static const String _passwordKey = 'restaurant_admin_password';
  static const String _defaultPassword = '123456';

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Validate and change password
  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Additional validation
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'New password and confirm password do not match';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedPassword = prefs.getString(_passwordKey) ?? _defaultPassword;
      final currentPassword = _currentPasswordController.text;
      final newPassword = _newPasswordController.text;

      // Verify current password
      if (currentPassword != storedPassword) {
        setState(() {
          _errorMessage = 'Current password is incorrect';
          _isLoading = false;
        });
        return;
      }

      // Prevent setting same password
      if (currentPassword == newPassword) {
        setState(() {
          _errorMessage = 'New password must be different from current password';
          _isLoading = false;
        });
        return;
      }

      // Save new password
      await prefs.setString(_passwordKey, newPassword);

      // Clear form
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      setState(() {
        _successMessage = 'Password changed successfully!';
        _isLoading = false;
      });

      // Show success dialog
      _showSuccessDialog();
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  /// Show success dialog
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Text(
              'Success',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        content: Text(
          'Your password has been changed successfully.',
          style: GoogleFonts.poppins(fontSize: 15),
        ),
        actions: [
          CommonButton(
            width: 100,
            height: 45,
            bgcolor: AppColors.primary,
            bordercircular: 8,
            onTap: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to settings
            },
            child: Center(
              child: Text(
                'OK',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final width = size.width;
    final height = size.height;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black87),
        title: Text(
          'Change Password',
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 22 : 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: 8,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 10 : 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person,
                    size: isTablet ? 22 : 20,
                    color: AppColors.primary,
                  ),
                ),
                if (isTablet) ...[
                  SizedBox(width: 10),
                  Text(
                    'Admin',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ],
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
                // Info Card
                Container(
                  width: width,
                  padding: EdgeInsets.all(isTablet ? 18 : 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                          size: isTablet ? 26 : 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Change your admin password to keep your account secure.',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 14 : 13,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: height * 0.03),

                // Error Message
                if (_errorMessage != null) ...[
                  Container(
                    width: width,
                    padding: EdgeInsets.all(isTablet ? 14 : 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.error_outline,
                            color: Colors.red.shade700,
                            size: isTablet ? 22 : 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.poppins(
                              color: Colors.red.shade700,
                              fontSize: isTablet ? 15 : 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: height * 0.02),
                ],

                // Success Message
                if (_successMessage != null) ...[
                  Container(
                    width: width,
                    padding: EdgeInsets.all(isTablet ? 14 : 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.check_circle_outline,
                            color: Colors.green.shade700,
                            size: isTablet ? 22 : 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: GoogleFonts.poppins(
                              color: Colors.green.shade700,
                              fontSize: isTablet ? 15 : 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: height * 0.02),
                ],

                // Current Password
                Text(
                  "Current Password",
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 16 : 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: height * 0.01),
                CommonTextForm(
                  controller: _currentPasswordController,
                  obsecureText: _obscureCurrentPass,
                  hintText: 'Enter current password',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter current password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                  gesture: GestureDetector(
                    onTap: () {
                      setState(() {
                        _obscureCurrentPass = !_obscureCurrentPass;
                      });
                    },
                    child: Icon(
                      _obscureCurrentPass ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.primary,
                    ),
                  ),
                ),

                SizedBox(height: height * 0.02),

                // New Password
                Text(
                  "New Password",
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 16 : 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: height * 0.01),
                CommonTextForm(
                  controller: _newPasswordController,
                  obsecureText: _obscureNewPass,
                  hintText: 'Enter new password',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter new password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                  gesture: GestureDetector(
                    onTap: () {
                      setState(() {
                        _obscureNewPass = !_obscureNewPass;
                      });
                    },
                    child: Icon(
                      _obscureNewPass ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.primary,
                    ),
                  ),
                ),

                SizedBox(height: height * 0.02),

                // Confirm Password
                Text(
                  "Confirm New Password",
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 16 : 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: height * 0.01),
                CommonTextForm(
                  controller: _confirmPasswordController,
                  obsecureText: _obscureConfirmPass,
                  hintText: 'Confirm new password',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm new password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                  gesture: GestureDetector(
                    onTap: () {
                      setState(() {
                        _obscureConfirmPass = !_obscureConfirmPass;
                      });
                    },
                    child: Icon(
                      _obscureConfirmPass ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.primary,
                    ),
                  ),
                ),

                SizedBox(height: height * 0.04),

                // Submit Button
                CommonButton(
                  width: width,
                  height: height * 0.065,
                  onTap: _isLoading ? () {} : _handleChangePassword,
                  bordercircular: 8,
                  bgcolor: _isLoading ? Colors.grey : AppColors.primary,
                  bordercolor: _isLoading ? Colors.grey : AppColors.primary,
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Center(
                          child: Text(
                            "Change Password",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),

                SizedBox(height: height * 0.02),

                // Password Requirements
                Container(
                  padding: EdgeInsets.all(isTablet ? 16 : 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.security_rounded,
                              color: AppColors.primary,
                              size: isTablet ? 20 : 18,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Password Requirements:',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 15 : 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildRequirement('Minimum 6 characters'),
                      _buildRequirement('Different from current password'),
                      _buildRequirement('New password and confirm password must match'),
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

  Widget _buildRequirement(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}