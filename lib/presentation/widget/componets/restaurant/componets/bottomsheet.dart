import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/presentation/widget/componets/restaurant/bottom_sheets/add_item_sheet.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';

/// Floating action button that opens the Add Item bottom sheet
///
/// This is a reusable component that provides a consistent
/// "Add Item" button at the bottom of screens.
class BottomsheetMenu extends StatefulWidget {
  /// Callback when a category is selected in the item form
  final Function(String)? onCategorySelected;

  /// Callback when an item is successfully added
  final VoidCallback? onItemAdded;

  /// Custom button text (defaults to "Add Item")
  final String? buttonText;

  /// Custom button icon (defaults to Icons.add)
  final IconData? buttonIcon;

  const BottomsheetMenu({
    super.key,
    this.onCategorySelected,
    this.onItemAdded,
    this.buttonText,
    this.buttonIcon,
  });

  @override
  State<BottomsheetMenu> createState() => _BottomsheetMenuState();
}

class _BottomsheetMenuState extends State<BottomsheetMenu> {
  bool _isLoading = false;

  Future<void> _openAddItemSheet() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      await AddItemSheet.show(
        context,
        onCategorySelected: widget.onCategorySelected,
        onItemAdded: widget.onItemAdded,
      );
    } catch (e) {
      // Show error feedback if sheet fails to open
      if (mounted) {
        NotificationService.instance.showError('Failed to open form. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _openAddItemSheet,
            icon: _isLoading
                ? SizedBox(
                    height: isTablet ? 20 : 18,
                    width: isTablet ? 20 : 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(widget.buttonIcon ?? Icons.add, size: isTablet ? 22 : 20),
            label: Text(
              _isLoading ? 'Adding…' : (widget.buttonText ?? 'Add Item'),
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
              elevation: 0,
              padding: EdgeInsets.symmetric(vertical: isTablet ? 18 : 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
