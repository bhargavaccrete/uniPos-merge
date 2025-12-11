import 'dart:math';
import 'package:flutter/widgets.dart';


// Category | Inches Range | Pixels (at 160 PPI)
// Phone | 4.0" – 7.0" | 640 – 1120 px
// Tablet | 7.0" – 11.0" | 1120 – 1760 px
// Laptop/Desktop | 11.0" – 17.3" | 1760 – 2768 px
String getDeviceCategory(BuildContext context, {double ppi = 160}) {
  final size = MediaQuery.of(context).size;
  final width = size.width;
  final height = size.height;
  print("this is the heigth and the widht of the screen - ---- > ${width}--- H${height}");
  // Convert logical pixels to actual pixels
  final pixelRatio = MediaQuery.of(context).devicePixelRatio;
  final widthPx = width * pixelRatio;
  final heightPx = height * pixelRatio;

  // Calculate diagonal pixels
  final diagonalPx = sqrt(pow(widthPx, 2) + pow(heightPx, 2));

  // Convert to inches
  final diagonalInches = diagonalPx / ppi;

  if (diagonalInches >= 4.0 && diagonalInches <= 7.0) {
    return "Phone";
  } else if (diagonalInches > 7.0 && diagonalInches <= 11.0) {
    return "Tablet";
  } else if (diagonalInches > 11.0) {
    return "Desktop";
  } else {
    return "Unknown";
  }
}
// String getDeviceCategory(BuildContext context) {
//   final size = MediaQuery.of(context).size;
//   final width = size.width;  // Logical width (in dp)
//   final height = size.height; // Logical height (in dp)
//
//   // Get device pixel ratio
//   final pixelRatio = MediaQuery.of(context).devicePixelRatio;
//
//   // Convert to physical pixels
//   final widthPx = width * pixelRatio;
//   final heightPx = height * pixelRatio;
//
//   // Calculate diagonal in pixels
//   final diagonalPx = sqrt(pow(widthPx, 2) + pow(heightPx, 2));
//
//   final ppi = 460;
//   // Convert diagonal to inches (assuming ppi of 300 is average for smartphones)
//   final diagonalInches = diagonalPx / ppi;
//
//   // Print debug information
//   print("Width: $widthPx px, Height: $heightPx px, Diagonal: $diagonalInches inches");
//
//   // Categorize based on diagonal size
//   if (diagonalInches < 7) {
//     print("Phone");
//     return "Phone";  // Phones typically have diagonal sizes less than 6 inches
//   } else if (diagonalInches >= 7 && diagonalInches <= 13.0) {
//     print("Tablet");
//     return "Tablet";  // Tablets have diagonal sizes between 6 and 10 inches
//   } else {
//     print("Desktop");
//     return "Desktop";  // Anything larger is considered a desktop
//   }
// }

double iconSize(BuildContext context) {
  return MediaQuery.of(context).size.width * 0.06;
}
