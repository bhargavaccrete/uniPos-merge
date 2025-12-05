import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/widget/componets/restaurant/bottom_sheets/add_item_sheet.dart';
import 'package:unipos/util/restaurant/responsive_helper.dart';
import 'Button.dart';

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
    return CommonButton(
      bordercircular: 25,
      width: width ?? ResponsiveHelper.responsiveWidth(context, 0.5),
      height: height ?? ResponsiveHelper.responsiveHeight(context, 0.06),
      onTap: () {
        AddItemSheet.show(
          context,
          onCategorySelected: onCategorySelected,
          onItemAdded: () {
            // Item was added successfully
          },
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.add),
          ),
          const SizedBox(width: 5),
          Text(
            'Add items',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: ResponsiveHelper.responsiveTextSize(context, 16),
            ),
          )
        ],
      ),
    );
  }
}
