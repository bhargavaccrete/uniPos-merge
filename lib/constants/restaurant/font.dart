import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

TextStyle customFontStyle({
   fontSize =16,
  FontWeight fontWeight = FontWeight.w100,         // Semi-bold
  Color color = Colors.black,                      // Black text
  double letterSpacing = 0.0,
  FontStyle fontStyle = FontStyle.normal,
  TextDecoration decoration = TextDecoration.none,
}) {
  return GoogleFonts.poppins(
    fontSize:  16,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    fontStyle: fontStyle,
    decoration: decoration,
  );
}



TextStyle customFont18({
  FontWeight fontWeight = FontWeight.w500,         // Semi-bold
  Color color = Colors.black,                      // Black text
  double letterSpacing = 0.0,
  FontStyle fontStyle = FontStyle.normal,
  TextDecoration decoration = TextDecoration.none,
}) {
  return GoogleFonts.poppins(
    fontSize:  18,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    fontStyle: fontStyle,
    decoration: decoration,
  );
}

TextStyle customFont20({
  FontWeight fontWeight = FontWeight.w500,         // Semi-bold
  Color color = Colors.black,                      // Black text
  double letterSpacing = 0.0,
  FontStyle fontStyle = FontStyle.normal,
  TextDecoration decoration = TextDecoration.none,
}) {
  return GoogleFonts.poppins(
    fontSize:  20,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    fontStyle: fontStyle,
    decoration: decoration,
  );
}
