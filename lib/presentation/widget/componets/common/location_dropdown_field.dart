import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// A dropdown field styled to match [AppTextField], used for Country / State /
/// City on the registration screen. Tapping it opens a searchable dialog.
///
/// - [options] are the selectable values (already filtered for the parent
///   selection, e.g. states of the chosen country).
/// - [allowCustom] = true (City) lets the user keep a value they typed even if
///   it isn't in the list — coverage for towns the dataset is missing.
/// - [ready] = false means a prerequisite isn't met yet (e.g. City before a
///   State is chosen). The field stays fully tappable and normal-looking; a tap
///   just fires [onBlocked] (the parent shows a "select … first" message)
///   instead of opening the picker.
/// - Validation flows through the surrounding [Form]: the [FormField] reads the
///   external [value] (owned by the parent's controller), so `_formKey.validate`
///   catches an empty selection just like the old text fields did.
class LocationDropdownField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final List<String> options;
  final bool allowCustom;
  final bool ready;
  final VoidCallback? onBlocked;
  final ValueChanged<String> onSelected;
  final String? Function(String?)? validator;

  const LocationDropdownField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onSelected,
    this.allowCustom = false,
    this.ready = true,
    this.onBlocked,
    this.validator,
  });

  bool get _isEmpty => value == null || value!.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      // The FormField holds no value of its own — it validates the parent's
      // external [value], so cascading resets never desync an internal copy.
      validator: (_) => validator?.call(value),
      builder: (field) {
        // Only flag an error while the value is ACTUALLY still empty. A stale
        // FormField error (set by a previous "Continue" with no selection) must
        // clear the instant a value is picked — otherwise the red border and
        // "… is required" text linger after the user selects one.
        final showError = field.hasError && _isEmpty;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plain fixed-height Container (NOT InputDecorator) — fully
            // deterministic, so every instance is byte-for-byte the same size.
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                if (!ready) {
                  onBlocked?.call();
                  return;
                }
                final picked = await _openPicker(context);
                if (picked != null && picked.isNotEmpty) {
                  onSelected(picked);
                  field.didChange(picked); // clears any prior error
                }
              },
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: showError ? Colors.red : AppColors.divider,
                    width: showError ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isEmpty ? '$label *' : value!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: _isEmpty
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            // Validation error rendered BELOW the box, so an error on one field
            // never makes its box taller than the other.
            if (showError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 12),
                child: Text(
                  field.errorText!,
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.red),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<String?> _openPicker(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => _LocationPickerDialog(
        title: label,
        icon: icon,
        options: options,
        allowCustom: allowCustom,
        selected: value,
      ),
    );
  }
}

/// Searchable centered dialog with an accent header (matches [AppDialogShell]).
/// Filters options as you type; when [allowCustom] is on and the query matches
/// nothing, offers a row to use the typed value.
class _LocationPickerDialog extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<String> options;
  final bool allowCustom;
  final String? selected;

  const _LocationPickerDialog({
    required this.title,
    required this.icon,
    required this.options,
    required this.allowCustom,
    required this.selected,
  });

  @override
  State<_LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<_LocationPickerDialog> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filtered {
    if (_query.isEmpty) return widget.options;
    final q = _query.toLowerCase();
    return widget.options.where((o) => o.toLowerCase().contains(q)).toList();
  }

  bool get _showCustomRow =>
      widget.allowCustom &&
      _query.trim().isNotEmpty &&
      !widget.options.any(
        (o) => o.toLowerCase() == _query.trim().toLowerCase(),
      );

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          // Same width as every other dialog in the app (∞ / 500 / 600) — a
          // fixed 440 left this picker narrower than its neighbours on desktop.
          maxWidth: AppResponsive.dialogWidth(context),
          // Shorter dialog: ~55% of the visible area (screen minus keyboard),
          // capped at 440 so it never dominates the screen.
          maxHeight:
              ((MediaQuery.of(context).size.height -
                          MediaQuery.of(context).viewInsets.bottom) *
                      0.55)
                  .clamp(280.0, 440.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Accent header: icon badge + title + close
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
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
                      widget.icon,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Select ${widget.title}',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.getValue(
                          context,
                          mobile: 17.0,
                          tablet: 18.0,
                          desktop: 20.0,
                        ),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Search box
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                ),
                decoration: InputDecoration(
                  hintText: 'Search ${widget.title.toLowerCase()}',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColors.textSecondary,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
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
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            Flexible(
              child: (filtered.isEmpty && !_showCustomRow)
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Text(
                        'No matches',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 8),
                      children: [
                        if (_showCustomRow)
                          ListTile(
                            leading: Icon(
                              Icons.add_circle_outline_rounded,
                              color: AppColors.primary,
                            ),
                            title: Text(
                              'Use "${_query.trim()}"',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.bodyFontSize(context),
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary,
                              ),
                            ),
                            onTap: () => Navigator.pop(context, _query.trim()),
                          ),
                        ...filtered.map((o) {
                          final isSel = o == widget.selected;
                          return ListTile(
                            selected: isSel,
                            selectedTileColor: AppColors.primary.withValues(
                              alpha: 0.08,
                            ),
                            title: Text(
                              o,
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.bodyFontSize(context),
                                fontWeight: isSel
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSel
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            trailing: isSel
                                ? Icon(
                                    Icons.check_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  )
                                : null,
                            onTap: () => Navigator.pop(context, o),
                          );
                        }),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
