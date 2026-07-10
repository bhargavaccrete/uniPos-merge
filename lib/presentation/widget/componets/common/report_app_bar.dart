import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';

/// The standard report header: title + optional subtitle, one size everywhere.
/// Pass [actions] only for a genuinely screen-specific control.
AppBar reportAppBar({
  required String title,
  String? subtitle,
  List<Widget>? actions,
}) {
  return buildPrimaryAppBar(
    actions: actions,
    titleWidget: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
      ],
    ),
  );
}
