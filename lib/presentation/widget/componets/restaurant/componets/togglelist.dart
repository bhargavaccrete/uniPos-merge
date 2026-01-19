import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';

import '../../../../../constants/restaurant/color.dart';

class SwitchList extends StatelessWidget {
  final String title;
  final void Function(bool) onChanged;
  final bool isvalue;
  final double? fontsize;
  final Widget? child; // ✅ New: An optional child widget

  const SwitchList({
    super.key,
    required this.title,
    required this.onChanged,
    required this.isvalue,
    this.fontsize,
    this.child, // ✅ New: Add to constructor
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      color: Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.primary),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        // ✅ Layout is now a Column to hold the switch row and the optional child
        child: Column(
          mainAxisSize: MainAxisSize.min, // Keeps the card height tight
          children: [
            // Row for the Title and Switch
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: fontsize ?? 16,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Switch(
                  activeColor: AppColors.primary,
                  value: isvalue,
                  onChanged: onChanged,
                ),
              ],
            ),
            // ✅ Conditionally display the child if it's provided
            if (child != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: child!,
              ),
          ],
        ),
      ),
    );
  }
}