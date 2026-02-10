import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/presentation/widget/componets/restaurant/bottom_sheets/add_item_sheet.dart';
import 'package:unipos/util/color.dart';

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
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

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
          height: isTablet ? 56 : 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _openAddItemSheet,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(isTablet ? 5 : 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          widget.buttonIcon ?? Icons.add,
                          color: AppColors.primary,
                          size: isTablet ? 22 : 20,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        widget.buttonText ?? 'Add Item',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: isTablet ? 17 : 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
