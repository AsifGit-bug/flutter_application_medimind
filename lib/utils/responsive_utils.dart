import 'package:flutter/material.dart';

/// Utility class for responsive design breakpoints
class ResponsiveUtils {
  /// Check if the device is a tablet (shortest side >= 600dp)
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.shortestSide >= 600;
  }

  /// Check if the device is a large tablet (shortest side >= 900dp)
  static bool isLargeTablet(BuildContext context) {
    return MediaQuery.of(context).size.shortestSide >= 900;
  }

  /// Check if we're in landscape mode
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Get the number of grid columns based on screen width
  static int getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 4;
    if (width >= 900) return 3;
    if (width >= 600) return 2;
    return 1;
  }

  /// Get content padding based on screen size
  static EdgeInsets getContentPadding(BuildContext context) {
    if (isLargeTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 48, vertical: 24);
    }
    if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 20);
    }
    return const EdgeInsets.all(16);
  }

  /// Get constrained width for content on large screens
  static double? getMaxContentWidth(BuildContext context) {
    if (isLargeTablet(context)) return 1200;
    if (isTablet(context)) return 900;
    return null; // Full width for phones
  }
}
