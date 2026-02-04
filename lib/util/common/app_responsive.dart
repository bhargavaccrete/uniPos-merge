import 'package:flutter/material.dart';

/// Comprehensive responsive utility for consistent UI across all screen sizes
/// Aligned with existing Responsive widget breakpoints
/// Use this for all new screens going forward
class AppResponsive {
  // ==================== BREAKPOINTS ====================
  // Aligned with lib/util/responsive.dart breakpoints

  /// Mobile breakpoint (< 850px)
  static const double mobileBreakpoint = 850;

  /// Tablet breakpoint (850px - 1100px)
  static const double tabletBreakpoint = 1100;

  /// Desktop breakpoint (>= 1100px)
  static const double desktopBreakpoint = 1100;

  // ==================== SCREEN TYPE CHECKS ====================

  /// Check if current screen is mobile (< 850px)
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  /// Check if current screen is tablet (850px - 1100px)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  /// Check if current screen is desktop (>= 1100px)
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;

  /// Get screen type enum
  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return ScreenType.mobile;
    if (width < tabletBreakpoint) return ScreenType.tablet;
    return ScreenType.desktop;
  }

  // ==================== RESPONSIVE VALUES ====================

  /// Get responsive value based on screen size
  /// Usage: AppResponsive.getValue(context, mobile: 12, tablet: 14, desktop: 16)
  static T getValue<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }

  // ==================== FONT SIZES ====================

  /// Responsive font size for headings
  static double headingFontSize(BuildContext context) =>
      getValue(context, mobile: 20.0, tablet: 22.0, desktop: 24.0);

  /// Responsive font size for subheadings
  static double subheadingFontSize(BuildContext context) =>
      getValue(context, mobile: 16.0, tablet: 18.0, desktop: 20.0);

  /// Responsive font size for body text
  static double bodyFontSize(BuildContext context) =>
      getValue(context, mobile: 14.0, tablet: 15.0, desktop: 16.0);

  /// Responsive font size for small text
  static double smallFontSize(BuildContext context) =>
      getValue(context, mobile: 12.0, tablet: 13.0, desktop: 14.0);

  /// Responsive font size for captions
  static double captionFontSize(BuildContext context) =>
      getValue(context, mobile: 11.0, tablet: 12.0, desktop: 13.0);

  /// Responsive font size for buttons
  static double buttonFontSize(BuildContext context) =>
      getValue(context, mobile: 15.0, tablet: 16.0, desktop: 17.0);

  // ==================== ICON SIZES ====================

  /// Responsive icon size for small icons
  static double smallIconSize(BuildContext context) =>
      getValue(context, mobile: 16.0, tablet: 18.0, desktop: 20.0);

  /// Responsive icon size for regular icons
  static double iconSize(BuildContext context) =>
      getValue(context, mobile: 20.0, tablet: 22.0, desktop: 24.0);

  /// Responsive icon size for large icons
  static double largeIconSize(BuildContext context) =>
      getValue(context, mobile: 28.0, tablet: 32.0, desktop: 36.0);

  // ==================== SPACING ====================

  /// Responsive small spacing
  static double smallSpacing(BuildContext context) =>
      getValue(context, mobile: 8.0, tablet: 10.0, desktop: 12.0);

  /// Responsive medium spacing
  static double mediumSpacing(BuildContext context) =>
      getValue(context, mobile: 12.0, tablet: 14.0, desktop: 16.0);

  /// Responsive large spacing
  static double largeSpacing(BuildContext context) =>
      getValue(context, mobile: 16.0, tablet: 20.0, desktop: 24.0);

  /// Responsive extra large spacing
  static double extraLargeSpacing(BuildContext context) =>
      getValue(context, mobile: 24.0, tablet: 28.0, desktop: 32.0);

  // ==================== PADDING ====================

  /// Responsive padding (all sides)
  static EdgeInsets padding(BuildContext context) =>
      EdgeInsets.all(getValue(context, mobile: 16.0, tablet: 20.0, desktop: 24.0));

  /// Responsive horizontal padding
  static EdgeInsets horizontalPadding(BuildContext context) =>
      EdgeInsets.symmetric(
        horizontal: getValue(context, mobile: 16.0, tablet: 20.0, desktop: 24.0),
      );

  /// Responsive vertical padding
  static EdgeInsets verticalPadding(BuildContext context) =>
      EdgeInsets.symmetric(
        vertical: getValue(context, mobile: 16.0, tablet: 20.0, desktop: 24.0),
      );

  /// Responsive card padding
  static EdgeInsets cardPadding(BuildContext context) =>
      EdgeInsets.all(getValue(context, mobile: 16.0, tablet: 20.0, desktop: 24.0));

  /// Responsive screen padding
  static EdgeInsets screenPadding(BuildContext context) =>
      EdgeInsets.all(getValue(context, mobile: 16.0, tablet: 20.0, desktop: 24.0));

  // ==================== BORDER RADIUS ====================

  /// Responsive small border radius
  static double smallBorderRadius(BuildContext context) =>
      getValue(context, mobile: 8.0, tablet: 10.0, desktop: 12.0);

  /// Responsive medium border radius
  static double borderRadius(BuildContext context) =>
      getValue(context, mobile: 12.0, tablet: 14.0, desktop: 16.0);

  /// Responsive large border radius
  static double largeBorderRadius(BuildContext context) =>
      getValue(context, mobile: 16.0, tablet: 18.0, desktop: 20.0);

  // ==================== CONTAINER DIMENSIONS ====================

  /// Responsive button height
  static double buttonHeight(BuildContext context) =>
      getValue(context, mobile: 48.0, tablet: 52.0, desktop: 56.0);

  /// Responsive input field height
  static double inputHeight(BuildContext context) =>
      getValue(context, mobile: 48.0, tablet: 52.0, desktop: 56.0);

  /// Responsive app bar height
  static double appBarHeight(BuildContext context) =>
      getValue(context, mobile: 56.0, tablet: 64.0, desktop: 72.0);

  /// Responsive card elevation
  static double cardElevation(BuildContext context) =>
      getValue(context, mobile: 2.0, tablet: 3.0, desktop: 4.0);

  // ==================== MAX CONTENT WIDTH ====================

  /// Get max content width for centering content on large screens
  static double maxContentWidth(BuildContext context) =>
      getValue(context, mobile: double.infinity, tablet: 1000.0, desktop: 1400.0);

  /// Get max form width for forms and dialogs
  static double maxFormWidth(BuildContext context) =>
      getValue(context, mobile: double.infinity, tablet: 600.0, desktop: 800.0);

  /// Get max card width for cards in lists
  static double maxCardWidth(BuildContext context) =>
      getValue(context, mobile: double.infinity, tablet: 800.0, desktop: 1000.0);

  // ==================== DATA TABLE ====================

  /// Responsive data table column spacing
  static double tableColumnSpacing(BuildContext context) =>
      getValue(context, mobile: 16.0, tablet: 24.0, desktop: 40.0);

  /// Responsive data table heading row height
  static double tableHeadingHeight(BuildContext context) =>
      getValue(context, mobile: 48.0, tablet: 56.0, desktop: 64.0);

  /// Responsive data table row min height
  static double tableRowMinHeight(BuildContext context) =>
      getValue(context, mobile: 48.0, tablet: 52.0, desktop: 60.0);

  /// Responsive data table row max height
  static double tableRowMaxHeight(BuildContext context) =>
      getValue(context, mobile: 56.0, tablet: 64.0, desktop: 72.0);

  // ==================== GRID ====================

  /// Get number of grid columns based on screen size
  static int gridColumns(BuildContext context, {int mobile = 2, int tablet = 3, int desktop = 4}) =>
      getValue(context, mobile: mobile, tablet: tablet, desktop: desktop);

  /// Responsive grid spacing
  static double gridSpacing(BuildContext context) =>
      getValue(context, mobile: 12.0, tablet: 16.0, desktop: 20.0);

  /// Responsive grid child aspect ratio
  static double gridAspectRatio(BuildContext context) =>
      getValue(context, mobile: 1.1, tablet: 1.2, desktop: 1.3);

  // ==================== DIMENSION HELPERS ====================

  /// Get responsive width percentage
  static double width(BuildContext context, double percentage) =>
      MediaQuery.of(context).size.width * percentage;

  /// Get responsive height percentage
  static double height(BuildContext context, double percentage) =>
      MediaQuery.of(context).size.height * percentage;

  /// Get screen width
  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  /// Get screen height
  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  // ==================== DIALOG & MODAL ====================

  /// Responsive dialog width
  static double dialogWidth(BuildContext context) =>
      getValue(context, mobile: double.infinity, tablet: 500.0, desktop: 600.0);

  /// Responsive bottom sheet max height
  static double bottomSheetMaxHeight(BuildContext context) =>
      getValue(context, mobile: 0.9, tablet: 0.8, desktop: 0.7) * screenHeight(context);

  // ==================== LIST & TILE ====================

  /// Responsive list tile height
  static double listTileHeight(BuildContext context) =>
      getValue(context, mobile: 56.0, tablet: 64.0, desktop: 72.0);

  /// Responsive list tile padding
  static EdgeInsets listTilePadding(BuildContext context) =>
      EdgeInsets.symmetric(
        horizontal: getValue(context, mobile: 16.0, tablet: 20.0, desktop: 24.0),
        vertical: getValue(context, mobile: 8.0, tablet: 10.0, desktop: 12.0),
      );

  // ==================== DIVIDER ====================

  /// Responsive divider thickness
  static double dividerThickness(BuildContext context) =>
      getValue(context, mobile: 1.0, tablet: 1.5, desktop: 2.0);

  /// Responsive divider indent
  static double dividerIndent(BuildContext context) =>
      getValue(context, mobile: 16.0, tablet: 20.0, desktop: 24.0);

  // ==================== SHADOW & ELEVATION ====================

  /// Responsive box shadow blur radius
  static double shadowBlurRadius(BuildContext context) =>
      getValue(context, mobile: 8.0, tablet: 10.0, desktop: 12.0);

  /// Responsive box shadow spread radius
  static double shadowSpreadRadius(BuildContext context) =>
      getValue(context, mobile: 0.0, tablet: 1.0, desktop: 2.0);

  // ==================== IMAGE & AVATAR ====================

  /// Responsive avatar size
  static double avatarSize(BuildContext context) =>
      getValue(context, mobile: 40.0, tablet: 48.0, desktop: 56.0);

  /// Responsive small avatar size
  static double smallAvatarSize(BuildContext context) =>
      getValue(context, mobile: 32.0, tablet: 36.0, desktop: 40.0);

  /// Responsive large avatar size
  static double largeAvatarSize(BuildContext context) =>
      getValue(context, mobile: 64.0, tablet: 72.0, desktop: 80.0);

  /// Responsive image border radius
  static double imageBorderRadius(BuildContext context) =>
      getValue(context, mobile: 8.0, tablet: 10.0, desktop: 12.0);

  // ==================== ANIMATION ====================

  /// Responsive animation duration (milliseconds)
  static int animationDuration(BuildContext context) =>
      getValue(context, mobile: 200, tablet: 250, desktop: 300);

  /// Fast animation duration
  static int fastAnimationDuration(BuildContext context) =>
      getValue(context, mobile: 150, tablet: 175, desktop: 200);

  /// Slow animation duration
  static int slowAnimationDuration(BuildContext context) =>
      getValue(context, mobile: 300, tablet: 350, desktop: 400);

  // ==================== UTILITIES ====================

  /// Constrain content to max width with centering
  static Widget constrainedContent({
    required BuildContext context,
    required Widget child,
    double? maxWidth,
  }) {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? maxContentWidth(context),
        ),
        child: child,
      ),
    );
  }

  /// Responsive SizedBox for spacing
  static Widget verticalSpace(BuildContext context, {SpacingSize size = SpacingSize.medium}) {
    final spacing = switch (size) {
      SpacingSize.small => smallSpacing(context),
      SpacingSize.medium => mediumSpacing(context),
      SpacingSize.large => largeSpacing(context),
      SpacingSize.extraLarge => extraLargeSpacing(context),
    };
    return SizedBox(height: spacing);
  }

  /// Responsive horizontal SizedBox for spacing
  static Widget horizontalSpace(BuildContext context, {SpacingSize size = SpacingSize.medium}) {
    final spacing = switch (size) {
      SpacingSize.small => smallSpacing(context),
      SpacingSize.medium => mediumSpacing(context),
      SpacingSize.large => largeSpacing(context),
      SpacingSize.extraLarge => extraLargeSpacing(context),
    };
    return SizedBox(width: spacing);
  }

  /// Responsive box constraints for containers
  static BoxConstraints boxConstraints(BuildContext context, {
    double? minWidth,
    double? maxWidth,
    double? minHeight,
    double? maxHeight,
  }) {
    return BoxConstraints(
      minWidth: minWidth ?? 0.0,
      maxWidth: maxWidth ?? double.infinity,
      minHeight: minHeight ?? 0.0,
      maxHeight: maxHeight ?? double.infinity,
    );
  }
}

/// Screen type enum
enum ScreenType {
  mobile,
  tablet,
  desktop,
}

/// Spacing size enum for consistent spacing
enum SpacingSize {
  small,
  medium,
  large,
  extraLarge,
}