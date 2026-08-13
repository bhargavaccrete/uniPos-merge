import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/restaurant/staticswitch.dart';
import 'package:billberrylite/presentation/widget/componets/restaurant/componets/visual_keyboard.dart';

/// Unified text field widget for the entire app.
/// Replaces [CommonTextForm] and all inline `_fieldDec()` helpers.
///
/// When [AppSettings.visualKeyboard] is enabled, tapping the field
/// opens a [VisualKeyboard] bottom sheet instead of the system keyboard.
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
class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Starting text for controller-less (keyed) fields. Mutually exclusive with
  /// [controller]. The visual keyboard needs a controller, so fields using this
  /// always fall back to the system keyboard.
  final String? initialValue;

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
  final bool autofocus;

  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final void Function()? onTap;

  /// Keyboard action button (e.g. TextInputAction.next to chain focus).
  final TextInputAction? textInputAction;

  final List<TextInputFormatter>? inputFormatters;

  /// Optional prefix widget (e.g. currency symbol text).
  final Widget? prefixWidget;

  final bool enableSuggestions;
  final bool autocorrect;

  /// Auto-capitalisation for the soft keyboard (e.g. [TextCapitalization.words]
  /// on name fields).
  final TextCapitalization textCapitalization;

  /// When to auto-validate. Defaults to [AutovalidateMode.onUserInteraction] so
  /// a shown "… is required" error clears as soon as the user fills the field
  /// (and re-appears if they clear it) — instead of lingering until the next
  /// full-form validation. Pass [AutovalidateMode.disabled] to opt out.
  final AutovalidateMode autovalidateMode;

  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.initialValue,
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
    this.autofocus = false,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.onTap,
    this.textInputAction,
    this.inputFormatters,
    this.prefixWidget,
    this.enableSuggestions = true,
    this.autocorrect = true,
    this.textCapitalization = TextCapitalization.none,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  /// Whether VK mode is active for this field.
  bool get _useVK =>
      AppSettings.visualKeyboard &&
      widget.controller != null &&
      !widget.readOnly &&
      widget.enabled;

  /// Forward controller changes to [onChanged] when VK is active,
  /// because readOnly=true prevents TextFormField's own onChanged.
  void _onControllerChanged() {
    widget.onChanged?.call(widget.controller!.text);
  }

  @override
  void initState() {
    super.initState();
    if (_useVK && widget.onChanged != null) {
      widget.controller!.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    // Safe to call even if listener was never added.
    widget.controller?.removeListener(_onControllerChanged);
    super.dispose();
  }

  /// Maps Flutter's [TextInputType] to the visual keyboard's [KeyboardType].
  KeyboardType _mapKeyboardType() {
    if (widget.keyboardType == TextInputType.number ||
        widget.keyboardType == TextInputType.phone) {
      return KeyboardType.numeric;
    }
    return KeyboardType.text;
  }

  @override
  Widget build(BuildContext context) {
    final useVK = _useVK;

    final labelText = widget.label != null
        ? (widget.required ? '${widget.label} *' : widget.label!)
        : null;

    return TextFormField(
      controller: widget.controller,
      initialValue: widget.controller == null ? widget.initialValue : null,
      focusNode: widget.focusNode,
      keyboardType: widget.keyboardType,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      obscureText: widget.obscureText,
      enabled: widget.enabled,
      readOnly: widget.readOnly || useVK,
      autofocus: widget.autofocus,
      enableSuggestions: widget.enableSuggestions,
      autocorrect: widget.autocorrect,
      textCapitalization: widget.textCapitalization,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      onChanged: useVK ? null : widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      textInputAction: widget.textInputAction,
      onTap: useVK
          ? () {
              widget.onTap?.call();
              VisualKeyboardHelper.show(
                context: context,
                controller: widget.controller!,
                keyboardType: _mapKeyboardType(),
              );
            }
          : widget.onTap,
      inputFormatters: widget.inputFormatters,
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: widget.enabled ? AppColors.textPrimary : AppColors.textSecondary,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.poppins(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
        hintText: widget.hint,
        hintStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        prefixIcon: widget.prefixWidget != null
            ? widget.prefixWidget
            : widget.icon != null
                ? Icon(widget.icon, color: AppColors.primary, size: 20)
                : null,
        prefixIconConstraints: widget.prefixWidget != null
            ? const BoxConstraints(minWidth: 0, minHeight: 0)
            : null,
        suffixIcon: widget.suffixIcon,
        counterText: '',
        filled: true,
        fillColor: widget.enabled ? AppColors.surfaceLight : AppColors.divider.withOpacity(0.4),
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