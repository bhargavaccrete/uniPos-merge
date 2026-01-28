import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/widget/componets/restaurant/bottom_sheets/add_item_sheet.dart';

// Re-export the SellingMethod enum for backward compatibility

/// Button that opens the Add Item bottom sheet
class BottomsheetMenu extends StatelessWidget {
  final Function(String)? onCategorySelected;
  final double? height;
  final double? width;
  final Function(Map<String, String>)? onAdditem;

  const BottomsheetMenu({
    super.key,
    this.onAdditem,
    this.onCategorySelected,
    this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () {
            AddItemSheet.show(
              context,
              onCategorySelected: onCategorySelected,
              onItemAdded: () {
                // Item was added successfully
              },
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF1976D2), // AppColors.primary
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.add, color: Color(0xFF1976D2), size: 20),
              ),
              SizedBox(width: 10),
              Text(
                'Add Item',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
