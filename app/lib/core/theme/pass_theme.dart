import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

class PassTheme {
  // Category Colors (Light Theme Only)
  static const Color _lightSilver = Color(0xFFEBEBEB); // #ebebeb
  static const Color _lightGoldA = Color(0xFFEAC23C); // #eac23c
  static const Color _lightGoldB = Color(0xFFCC802A); // #cc802a
  static const Color _lightPlatinumA = Color(0xFFBCBABB); // #bcbabb
  static const Color _lightPlatinumB = Color(0xFF9AD3A6); // #9ad3a6
  static const Color _lightDiamond = Color(0xFF79B7DE); // #79b7de

  // Pass Type Colors
  static const Color dailyColor = Color(0xFF2196F3); // Light Blue

  // Status Colors (work for both themes)
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFF44336);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color blockedColor = Color(0xFFD32F2F);

  /// Get category color (always light theme)
  static Color getCategoryColor(String? category) {
    if (category == null) return Colors.grey;

    final categoryLower = category.toLowerCase();
    switch (categoryLower) {
      case 'silver':
        return _lightSilver;
      case 'gold a':
        return _lightGoldA;
      case 'gold b':
        return _lightGoldB;
      case 'platinum a':
        return _lightPlatinumA;
      case 'platinum b':
        return _lightPlatinumB;
      case 'diamond':
        return _lightDiamond;
      default:
        return Colors.grey;
    }
  }

  /// Get category gradient (always light theme)
  static LinearGradient getCategoryGradient(String? category) {
    if (category == null) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.grey[300]!, Colors.grey[200]!, Colors.grey[400]!],
      );
    }

    final categoryLower = category.toLowerCase();

    // Light theme gradients
    switch (categoryLower) {
      case 'silver':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEBEBEB), Color(0xFFF5F5F5), Color(0xFFD3D3D3)],
        );
      case 'gold a':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAC23C), Color(0xFFF0D060), Color(0xFFD4A017)],
        );
      case 'gold b':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFCC802A), Color(0xFFE09040), Color(0xFFB8701A)],
        );
      case 'platinum a':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFBCBABB), Color(0xFFD0CECF), Color(0xFFA8A6A7)],
        );
      case 'platinum b':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9AD3A6), Color(0xFFB4E3C0), Color(0xFF80C38C)],
        );
      case 'diamond':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF79B7DE), Color(0xFF93C7E8), Color(0xFF5FA7D4)],
        );
      case 'all access':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C2C2C), Color(0xFF404040), Color(0xFF1A1A1A)],
        );
      default:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey[300]!, Colors.grey[200]!, Colors.grey[400]!],
        );
    }
  }

  /// Get responsive pass background decoration (always light theme)
  static BoxDecoration getPassBackground(
    String? passType,
    String? category, {
    BuildContext? context,
  }) {
    final borderRadius = context != null
        ? ResponsiveSpacing.getBorderRadius(context)
        : 16.0;

    // Default background
    if (passType == null || category == null) {
      return BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(borderRadius),
      );
    }

    // Category-based gradients (higher priority)
    final gradient = getCategoryGradient(category);

    return BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.2),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Get status color based on verification result (always light theme)
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'valid':
      case 'consumed':
        return successColor;
      case 'invalid':
      case 'error':
        return errorColor;
      case 'used':
      case 'expired':
        return warningColor;
      case 'blocked':
        return blockedColor;
      default:
        return Colors.grey;
    }
  }

  /// Get status icon based on verification result
  static IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'valid':
      case 'consumed':
        return Icons.check_circle;
      case 'invalid':
        return Icons.error;
      case 'used':
      case 'expired':
        return Icons.access_time;
      case 'blocked':
        return Icons.block;
      case 'error':
        return Icons.warning;
      default:
        return Icons.help;
    }
  }

  /// Get text color that contrasts well with the background (always light theme)
  static Color getContrastTextColor(String? passType, String? category) {
    if (category == null) {
      return Colors.black87;
    }

    final categoryLower = category.toLowerCase();

    // Special cases for better contrast in light theme
    switch (categoryLower) {
      case 'diamond':
      case 'gold b':
        return Colors.white; // White text on dark backgrounds
      default:
        return Colors.black87;
    }
  }

  /// Get responsive card decoration for pass details (always light theme)
  static BoxDecoration getPassCardDecoration(
    String status, {
    BuildContext? context,
  }) {
    final statusColor = getStatusColor(status);
    final borderRadius = context != null
        ? ResponsiveSpacing.getBorderRadius(context)
        : 16.0;

    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: statusColor, width: 2),
      boxShadow: [
        BoxShadow(
          color: statusColor.withOpacity(0.2),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Get responsive detail card decoration (always light theme)
  static BoxDecoration getDetailCardDecoration(
    Color color, {
    BuildContext? context,
  }) {
    final borderRadius = context != null
        ? ResponsiveSpacing.getBorderRadius(context) * 0.75
        : 12.0;

    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withOpacity(0.08), color.withOpacity(0.12)],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Get responsive padding for pass cards
  static EdgeInsets getPassCardPadding(BuildContext context) {
    return EdgeInsets.all(ResponsiveSpacing.getCardPadding(context));
  }

  /// Get responsive text style for pass titles (always light theme)
  static TextStyle getPassTitleStyle(BuildContext context) {
    final fontSize = ResponsiveBreakpoints.getResponsiveValue(
      context,
      mobile: 18.0,
      tablet: 20.0,
      desktop: 22.0,
    );

    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: Colors.black87,
      letterSpacing: 0.3,
    );
  }

  /// Get responsive text style for pass subtitles (always light theme)
  static TextStyle getPassSubtitleStyle(BuildContext context) {
    final fontSize = ResponsiveBreakpoints.getResponsiveValue(
      context,
      mobile: 14.0,
      tablet: 15.0,
      desktop: 16.0,
    );

    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      color: Colors.black54,
      height: 1.3,
    );
  }

  /// Get responsive text style for pass details (always light theme)
  static TextStyle getPassDetailStyle(BuildContext context) {
    final fontSize = ResponsiveBreakpoints.getResponsiveValue(
      context,
      mobile: 12.0,
      tablet: 13.0,
      desktop: 14.0,
    );

    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      color: Colors.black45,
      height: 1.4,
    );
  }

  /// Legacy method overloads for backward compatibility
  /// These methods maintain the original signatures while supporting the new dark mode features
}
