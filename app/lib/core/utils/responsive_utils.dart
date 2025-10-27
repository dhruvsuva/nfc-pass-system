import 'package:flutter/material.dart';

class ResponsiveBreakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
  static const double largeDesktop = 1600;

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobile;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobile && width < desktop;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktop;
  }

  static bool isLargeDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= largeDesktop;
  }

  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < tablet;
  }

  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= tablet;
  }

  static T getResponsiveValue<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
    T? largeDesktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    
    if (width >= ResponsiveBreakpoints.largeDesktop && largeDesktop != null) {
      return largeDesktop;
    } else if (width >= ResponsiveBreakpoints.desktop && desktop != null) {
      return desktop;
    } else if (width >= ResponsiveBreakpoints.mobile && tablet != null) {
      return tablet;
    } else {
      return mobile;
    }
  }

  static int getGridCrossAxisCount(BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
    int largeDesktop = 4,
  }) {
    return getResponsiveValue(
      context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
      largeDesktop: largeDesktop,
    );
  }

  static double getChildAspectRatio(BuildContext context, {
    double mobile = 1.0,
    double tablet = 1.2,
    double desktop = 1.4,
    double largeDesktop = 1.6,
  }) {
    return getResponsiveValue(
      context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
      largeDesktop: largeDesktop,
    );
  }
}

class ResponsiveSpacing {
  static double getHorizontalPadding(BuildContext context) {
    return ResponsiveBreakpoints.getResponsiveValue(
      context,
      mobile: 12.0,      // Reduced from 16.0
      tablet: 16.0,      // Reduced from 24.0
      desktop: 20.0,     // Reduced from 32.0
      largeDesktop: 24.0, // Reduced from 48.0
    );
  }

  static double getVerticalPadding(BuildContext context) {
    return ResponsiveBreakpoints.getResponsiveValue(
      context,
      mobile: 12.0,      // Reduced from 16.0
      tablet: 14.0,      // Reduced from 20.0
      desktop: 16.0,     // Reduced from 24.0
      largeDesktop: 20.0, // Reduced from 32.0
    );
  }

  static double getCardPadding(BuildContext context) {
    return ResponsiveBreakpoints.getResponsiveValue(
      context,
      mobile: 12.0,      // Reduced from 16.0
      tablet: 14.0,      // Reduced from 20.0
      desktop: 16.0,     // Reduced from 24.0
      largeDesktop: 18.0, // Reduced from 32.0
    );
  }

  static double getBorderRadius(BuildContext context) {
    return ResponsiveBreakpoints.getResponsiveValue(
      context,
      mobile: 8.0,       // Reduced from 12.0
      tablet: 10.0,      // Reduced from 16.0
      desktop: 12.0,     // Reduced from 20.0
      largeDesktop: 14.0, // New value
    );
  }

  static double getIconSize(BuildContext context) {
    return ResponsiveBreakpoints.getResponsiveValue(
      context,
      mobile: 20.0,      // Reduced from 24.0
      tablet: 22.0,      // Reduced from 28.0
      desktop: 24.0,     // Reduced from 32.0
      largeDesktop: 26.0, // Reduced from 36.0
    );
  }

  static double getSpacing(BuildContext context, {
    double mobile = 6.0,    // Reduced from 8.0
    double tablet = 8.0,    // Reduced from 12.0
    double desktop = 10.0,  // Reduced from 16.0
    double largeDesktop = 12.0, // Reduced from 20.0
  }) {
    return ResponsiveBreakpoints.getResponsiveValue(
      context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
      largeDesktop: largeDesktop,
    );
  }

  static EdgeInsets getPagePadding(BuildContext context) {
    final horizontal = getHorizontalPadding(context);
    final vertical = getVerticalPadding(context);
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }

  static EdgeInsets getCardMargin(BuildContext context) {
    final spacing = getSpacing(context);
    return EdgeInsets.all(spacing);
  }

  static double getAppBarHeight(BuildContext context) {
    return ResponsiveBreakpoints.getResponsiveValue(
      context,
      mobile: 56.0,
      tablet: 64.0,
      desktop: 72.0,
      largeDesktop: 80.0,
    );
  }
}

class ResponsiveText {
  static double getHeadlineSize(BuildContext context) {
    return ResponsiveBreakpoints.getResponsiveValue(
      context,
      mobile: 24.0,
      tablet: 28.0,
      desktop: 32.0,
      largeDesktop: 36.0,
    );
  }

  static double getTitleSize(BuildContext context) {
    return ResponsiveBreakpoints.getResponsiveValue(
      context,
      mobile: 20.0,
      tablet: 22.0,
      desktop: 24.0,
      largeDesktop: 26.0,
    );
  }

  static double getBodySize(BuildContext context) {
    return ResponsiveBreakpoints.getResponsiveValue(
      context,
      mobile: 14.0,
      tablet: 15.0,
      desktop: 16.0,
      largeDesktop: 17.0,
    );
  }

  static double getCaptionSize(BuildContext context) {
    return ResponsiveBreakpoints.getResponsiveValue(
      context,
      mobile: 12.0,
      tablet: 13.0,
      desktop: 14.0,
      largeDesktop: 15.0,
    );
  }

  static TextStyle getHeadlineStyle(BuildContext context) {
    return TextStyle(
      fontSize: getHeadlineSize(context),
      fontWeight: FontWeight.bold,
    );
  }

  static TextStyle getTitleStyle(BuildContext context) {
    return TextStyle(
      fontSize: getTitleSize(context),
      fontWeight: FontWeight.w600,
    );
  }

  static TextStyle getBodyStyle(BuildContext context) {
    return TextStyle(
      fontSize: getBodySize(context),
      fontWeight: FontWeight.normal,
    );
  }

  static TextStyle getCaptionStyle(BuildContext context) {
    return TextStyle(
      fontSize: getCaptionSize(context),
      fontWeight: FontWeight.w400,
    );
  }
}

class ResponsiveLayout {
  static Widget buildResponsiveGrid({
    required BuildContext context,
    required List<Widget> children,
    int? mobileColumns,
    int? tabletColumns,
    int? desktopColumns,
    int? largeDesktopColumns,
    double? childAspectRatio,
    double? crossAxisSpacing,
    double? mainAxisSpacing,
    bool shrinkWrap = true,
    ScrollPhysics? physics,
  }) {
    final crossAxisCount = ResponsiveBreakpoints.getGridCrossAxisCount(
      context,
      mobile: mobileColumns ?? 1,
      tablet: tabletColumns ?? 2,
      desktop: desktopColumns ?? 3,
      largeDesktop: largeDesktopColumns ?? 4,
    );

    final aspectRatio = childAspectRatio ?? 
        ResponsiveBreakpoints.getChildAspectRatio(context);

    final spacing = ResponsiveSpacing.getSpacing(context);

    return GridView.count(
      crossAxisCount: crossAxisCount,
      childAspectRatio: aspectRatio,
      crossAxisSpacing: crossAxisSpacing ?? spacing,
      mainAxisSpacing: mainAxisSpacing ?? spacing,
      shrinkWrap: shrinkWrap,
      physics: physics ?? const NeverScrollableScrollPhysics(),
      children: children,
    );
  }

  static Widget buildResponsiveRow({
    required BuildContext context,
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    bool wrapOnSmallScreen = true,
  }) {
    if (wrapOnSmallScreen && ResponsiveBreakpoints.isSmallScreen(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );
  }

  static Widget buildResponsiveContainer({
    required BuildContext context,
    required Widget child,
    double? maxWidth,
    EdgeInsets? padding,
    EdgeInsets? margin,
  }) {
    final defaultMaxWidth = ResponsiveBreakpoints.getResponsiveValue(
      context,
      mobile: double.infinity,
      tablet: 800.0,
      desktop: 1200.0,
      largeDesktop: 1600.0,
    );

    return Container(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? defaultMaxWidth,
      ),
      padding: padding ?? ResponsiveSpacing.getPagePadding(context),
      margin: margin,
      child: child,
    );
  }

  static Widget buildAdaptiveLayout({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
    Widget? largeDesktop,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveBreakpoints.largeDesktop && largeDesktop != null) {
          return largeDesktop;
        } else if (constraints.maxWidth >= ResponsiveBreakpoints.desktop && desktop != null) {
          return desktop;
        } else if (constraints.maxWidth >= ResponsiveBreakpoints.mobile && tablet != null) {
          return tablet;
        } else {
          return mobile;
        }
      },
    );
  }
}

class ResponsiveHelper {
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static double getSafeAreaTop(BuildContext context) {
    return MediaQuery.of(context).padding.top;
  }

  static double getSafeAreaBottom(BuildContext context) {
    return MediaQuery.of(context).padding.bottom;
  }

  static double getKeyboardHeight(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom;
  }

  static bool isKeyboardVisible(BuildContext context) {
    return getKeyboardHeight(context) > 0;
  }

  static double getUsableHeight(BuildContext context) {
    final screenHeight = getScreenHeight(context);
    final safeAreaTop = getSafeAreaTop(context);
    final safeAreaBottom = getSafeAreaBottom(context);
    final keyboardHeight = getKeyboardHeight(context);
    
    return screenHeight - safeAreaTop - safeAreaBottom - keyboardHeight;
  }
}