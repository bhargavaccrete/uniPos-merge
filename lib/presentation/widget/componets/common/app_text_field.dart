import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';

/// Unified text field widget for the entire app.
/// Replaces [CommonTextForm] and all inline `_fieldDec()` helpers.
///
/// Usage:
/// ```dart
/// AppTextField(
///   controller: _nameController,
///   label: 'Item Name',
///   hint: 'e.g. Margherita Pizza',
///   icon: Icons.restaurant_menu_rounded,
///   required: true,
/// )
/// ```
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Label shown above (floating) the field.
  final String? label;

  /// Placeholder text inside the field.
  final String? hint;

  /// Leading icon inside the field.
  final IconData? icon;

  /// Custom widget placed at the end of the field (e.g. password toggle).
  final Widget? suffixIcon;

  /// Appends a red " *" to the label when true.
  final bool required;

  final TextInputType keyboardType;
  final int maxLines;
  final int minLines;
  final int? maxLength;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;

  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final void Function()? onTap;

  final List<TextInputFormatter>? inputFormatters;

  /// Optional prefix widget (e.g. currency symbol text).
  final Widget? prefixWidget;

  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.icon,
    this.suffixIcon,
    this.required = false,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.minLines = 1,
    this.maxLength,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.onTap,
    this.inputFormatters,
    this.prefixWidget,
  });

  @override
  Widget build(BuildContext context) {
    final labelText = label != null
        ? (required ? '$label *' : label!)
        : null;

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      maxLength: maxLength,
      obscureText: obscureText,
      enabled: enabled,
      readOnly: readOnly,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      onTap: onTap,
      inputFormatters: inputFormatters,
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.poppins(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        prefixIcon: prefixWidget != null
            ? prefixWidget
            : icon != null
                ? Icon(icon, color: AppColors.primary, size: 20)
                : null,
        prefixIconConstraints: prefixWidget != null
            ? const BoxConstraints(minWidth: 0, minHeight: 0)
            : null,
        suffixIcon: suffixIcon,
        counterText: '',
        filled: true,
        fillColor: enabled ? AppColors.surfaceLight : AppColors.divider.withOpacity(0.4),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.divider.withOpacity(0.5)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        errorStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.red),
      ),
    );
  }
}
