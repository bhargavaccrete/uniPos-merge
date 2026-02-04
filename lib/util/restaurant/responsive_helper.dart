/*
import 'package:flutter/material.dart';


class ResponsiveHelper {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
          MediaQuery.of(context).size.width < 1024;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  static double responsiveTextSize(BuildContext context, double baseSize) {
    if (isMobile(context)) return baseSize;
    if (isTablet(context)) return baseSize * 1.1;
    return baseSize * 1.2; // Desktop
  }

  static double responsiveWidth(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.width * percentage;
  }

  static double responsiveHeight(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.height * percentage;
  }

  static double maxContentWidth(BuildContext context) {
    if (isDesktop(context)) return MediaQuery.of(context).size.width * 0.6;
    if (isTablet(context)) return MediaQuery.of(context).size.width * 0.85;
    return MediaQuery.of(context).size.width;
  }

  static EdgeInsets responsivePadding(BuildContext context) {
    if (isDesktop(context)) return EdgeInsets.all(30);
    if (isTablet(context)) return EdgeInsets.all(20);
    return EdgeInsets.all(15);
  }

  static EdgeInsets responsiveSymmetricPadding(BuildContext context,
      {double horizontalPercent = 0.05, double verticalPercent = 0.02}) {
    return EdgeInsets.symmetric(
      horizontal: responsiveWidth(context, horizontalPercent),
      vertical: responsiveHeight(context, verticalPercent),
    );
  }

}*/
