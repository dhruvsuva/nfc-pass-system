import 'package:flutter/material.dart';
import 'responsive_utils.dart';

/// Comprehensive spacing utility for consistent spacing throughout the app
class AppSpacing {
  // Base spacing units - REDUCED for cleaner UI
  static const double _baseUnit = 6.0; // Reduced from 8.0
  
  // Standard spacing values - NORMALIZED
  static const double xs = _baseUnit * 0.5;  // 3px (was 4px)
  static const double sm = _baseUnit;        // 6px (was 8px)
  static const double md = _baseUnit * 2;    // 12px (was 16px)
  static const double lg = _baseUnit * 2.5;  // 15px (was 24px)
  static const double xl = _baseUnit * 3;    // 18px (was 32px)
  static const double xxl = _baseUnit * 4;   // 24px (was 48px)
  static const double xxxl = _baseUnit * 5;  // 30px (was 64px)

  // Responsive spacing methods - OPTIMIZED
  static double getResponsiveSpacing(BuildContext context, {
    double mobile = md,
    double tablet = md,
    double desktop = lg,
    double largeDesktop = lg,
  }) {
    return ResponsiveBreakpoints.getResponsiveValue(
      context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
      largeDesktop: largeDesktop,
    );
  }

  // Common spacing patterns - REDUCED
  static double getCardPadding(BuildContext context) {
    return getResponsiveSpacing(
      context,
      mobile: md,      // 12px (was 16px)
      tablet: md,      // 12px (was 24px)
      desktop: lg,     // 15px (was 24px)
      largeDesktop: lg, // 15px (was 32px)
    );
  }
  
  static double getPagePadding(BuildContext context) {
    return getResponsiveSpacing(
      context,
      mobile: md,      // 12px (was 16px)
      tablet: lg,      // 15px (was 24px)
      desktop: lg,     // 15px (was 32px)
      largeDesktop: xl, // 18px (was 48px)
    );
  }

  static double getSectionSpacing(BuildContext context) {
    return getResponsiveSpacing(
      context,
      mobile: lg,      // 15px (was 24px)
      tablet: lg,      // 15px (was 32px)
      desktop: xl,     // 18px (was 32px)
      largeDesktop: xl, // 18px (was 48px)
    );
  }
  
  static double getElementSpacing(BuildContext context) {
    return getResponsiveSpacing(
      context,
      mobile: sm,      // 6px (was 8px)
      tablet: sm,      // 6px (was 12px)
      desktop: md,     // 12px (was 12px)
      largeDesktop: md, // 12px (was 12px)
    );
  }
  
  // Widget spacing helpers
  static Widget verticalSpace(double height) => SizedBox(height: height);
  static Widget horizontalSpace(double width) => SizedBox(width: width);
  
  // Responsive spacing widgets
  static Widget responsiveVerticalSpace(BuildContext context, {
    double mobile = md,
    double tablet = md,
    double desktop = lg,
    double largeDesktop = lg,
  }) {
    return SizedBox(
      height: getResponsiveSpacing(
        context,
        mobile: mobile,
        tablet: tablet,
        desktop: desktop,
        largeDesktop: largeDesktop,
      ),
    );
  }
  
  static Widget responsiveHorizontalSpace(BuildContext context, {
    double mobile = md,
    double tablet = md,
    double desktop = lg,
    double largeDesktop = lg,
  }) {
    return SizedBox(
      width: getResponsiveSpacing(
        context,
        mobile: mobile,
        tablet: tablet,
        desktop: desktop,
        largeDesktop: largeDesktop,
      ),
    );
  }
  
  // Common spacing widgets
  static Widget get smallVerticalSpace => verticalSpace(sm);
  static Widget get mediumVerticalSpace => verticalSpace(md);
  static Widget get largeVerticalSpace => verticalSpace(lg);
  static Widget get extraLargeVerticalSpace => verticalSpace(xl);
  
  static Widget get smallHorizontalSpace => horizontalSpace(sm);
  static Widget get mediumHorizontalSpace => horizontalSpace(md);
  static Widget get largeHorizontalSpace => horizontalSpace(lg);
  static Widget get extraLargeHorizontalSpace => horizontalSpace(xl);
  
  // Padding helpers
  static EdgeInsets all(double value) => EdgeInsets.all(value);
  static EdgeInsets symmetric({double vertical = 0, double horizontal = 0}) =>
      EdgeInsets.symmetric(vertical: vertical, horizontal: horizontal);
  static EdgeInsets only({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) =>
      EdgeInsets.only(left: left, top: top, right: right, bottom: bottom);
  
  // Responsive padding
  static EdgeInsets getResponsivePadding(BuildContext context, {
    double mobile = md,
    double tablet = md,
    double desktop = lg,
    double largeDesktop = lg,
  }) {
    final spacing = getResponsiveSpacing(
      context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
      largeDesktop: largeDesktop,
    );
    return EdgeInsets.all(spacing);
  }
  
  static EdgeInsets getResponsiveSymmetricPadding(BuildContext context, {
    double mobileVertical = md,
    double mobileHorizontal = md,
    double tabletVertical = md,
    double tabletHorizontal = md,
    double desktopVertical = lg,
    double desktopHorizontal = lg,
    double largeDesktopVertical = lg,
    double largeDesktopHorizontal = lg,
  }) {
    final vertical = getResponsiveSpacing(
      context,
      mobile: mobileVertical,
      tablet: tabletVertical,
      desktop: desktopVertical,
      largeDesktop: largeDesktopVertical,
    );
    final horizontal = getResponsiveSpacing(
      context,
      mobile: mobileHorizontal,
      tablet: tabletHorizontal,
      desktop: desktopHorizontal,
      largeDesktop: largeDesktopHorizontal,
    );
    return EdgeInsets.symmetric(vertical: vertical, horizontal: horizontal);
  }
  
  // Common padding patterns - REDUCED
  static EdgeInsets getCardPaddingEdgeInsets(BuildContext context) {
    return getResponsivePadding(
      context,
      mobile: md,      // 12px (was 16px)
      tablet: md,      // 12px (was 24px)
      desktop: lg,     // 15px (was 24px)
      largeDesktop: lg, // 15px (was 32px)
    );
  }
  
  static EdgeInsets getPagePaddingEdgeInsets(BuildContext context) {
    return getResponsivePadding(
      context,
      mobile: md,      // 12px (was 16px)
      tablet: lg,      // 15px (was 24px)
      desktop: lg,     // 15px (was 32px)
      largeDesktop: xl, // 18px (was 48px)
    );
  }

  static EdgeInsets getButtonPaddingEdgeInsets(BuildContext context) {
    return getResponsiveSymmetricPadding(
      context,
      mobileVertical: sm,        // 6px (was 16px)
      mobileHorizontal: md,      // 12px (was 24px)
      tabletVertical: sm,        // 6px (was 16px)
      tabletHorizontal: lg,      // 15px (was 32px)
      desktopVertical: md,       // 12px (was 24px)
      desktopHorizontal: lg,     // 15px (was 32px)
      largeDesktopVertical: md,  // 12px (was 24px)
      largeDesktopHorizontal: xl, // 18px (was 48px)
    );
  }
}