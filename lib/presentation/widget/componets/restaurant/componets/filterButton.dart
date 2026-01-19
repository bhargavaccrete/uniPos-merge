
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';

import '../../../../../constants/restaurant/color.dart';

class Filterbutton extends StatelessWidget {
  final String title;
  final String selectedFilter;
  final void Function() onpressed;
  final double? borderc;
  final double? width;
  final double? height;


  const Filterbutton(
      {super.key,
      required this.title,
      required this.selectedFilter,
      required this.onpressed,
      this.borderc, this.width, this.height,
       });
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      child: ElevatedButton(
          onPressed: onpressed,
          style: ElevatedButton.styleFrom(
              backgroundColor:
                  selectedFilter == title ? AppColors.primary : Colors.white,
              foregroundColor:
                  selectedFilter == title ? Colors.white : AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderc ?? 8),
                  side: BorderSide(color: AppColors.primary))),
          child: Text(title,style:GoogleFonts.poppins(),textScaler: TextScaler.linear(1),)),
    );
  }
}