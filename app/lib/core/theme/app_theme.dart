import 'package:flutter/material.dart';
import 'theme_manager.dart';

class AppTheme {
  // Light Theme Colors
  static const Color _lightPrimary = Color(0xFF2196F3);
  static const Color _lightSecondary = Color(0xFF03DAC6);
  static const Color _lightSurface = Colors.white;
  static const Color _lightBackground = Color(0xFFF8F9FA);
  static const Color _lightError = Color(0xFFB00020);
  static const Color _lightOnPrimary = Colors.white;
  static const Color _lightOnSurface = Color(0xFF1C1B1F);
  static const Color _lightOnBackground = Color(0xFF1C1B1F);

  // Dark Theme Colors
  static const Color _darkPrimary = Color(0xFF90CAF9);
  static const Color _darkSecondary = Color(0xFF03DAC6);
  static const Color _darkSurface = Color(0xFF1E1E1E);
  static const Color _darkBackground = Color(0xFF121212);
  static const Color _darkError = Color(0xFFCF6679);
  static const Color _darkOnPrimary = Color(0xFF003258);
  static const Color _darkOnSurface = Color(0xFFE6E1E5);
  static const Color _darkOnBackground = Color(0xFFE6E1E5);

  // Status Colors (work for both themes)
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color errorColor = Color(0xFFF44336);
  static const Color infoColor = Color(0xFF2196F3);

  // Pass Status Colors
  static const Color validColor = Color(0xFF4CAF50);
  static const Color blockedColor = Color(0xFFE91E63);
  static const Color usedColor = Color(0xFFFF9800);
  static const Color invalidColor = Color(0xFF9E9E9E);

  /// Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: _lightPrimary,
        secondary: _lightSecondary,
        surface: _lightSurface,
        background: _lightBackground,
        error: _lightError,
        onPrimary: _lightOnPrimary,
        onSecondary: Colors.white,
        onSurface: _lightOnSurface,
        onBackground: _lightOnBackground,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: _lightBackground,

      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: _lightSurface,
        foregroundColor: _lightOnSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _lightOnSurface,
        ),
        iconTheme: const IconThemeData(color: _lightOnSurface),
        actionsIconTheme: const IconThemeData(color: _lightOnSurface),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: _lightSurface,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(8),
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _lightPrimary,
          foregroundColor: _lightOnPrimary,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _lightPrimary,
          side: const BorderSide(color: _lightPrimary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _lightPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lightPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lightError, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: TextStyle(color: Colors.grey[600]),
        hintStyle: TextStyle(color: Colors.grey[500]),
      ),

      // FloatingActionButton Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _lightPrimary,
        foregroundColor: _lightOnPrimary,
        elevation: 4,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _lightSurface,
        selectedItemColor: _lightPrimary,
        unselectedItemColor: Colors.grey[600],
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Drawer Theme
      drawerTheme: const DrawerThemeData(
        backgroundColor: _lightSurface,
        elevation: 16,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: _lightSurface,
        elevation: 24,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _lightOnSurface,
        ),
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF323232),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  /// Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: _darkPrimary,
        secondary: _darkSecondary,
        surface: _darkSurface,
        background: _darkBackground,
        error: _darkError,
        onPrimary: _darkOnPrimary,
        onSecondary: Colors.black,
        onSurface: _darkOnSurface,
        onBackground: _darkOnBackground,
        onError: Colors.black,
      ),
      scaffoldBackgroundColor: _darkBackground,

      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: _darkSurface,
        foregroundColor: _darkOnSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _darkOnSurface,
        ),
        iconTheme: const IconThemeData(color: _darkOnSurface),
        actionsIconTheme: const IconThemeData(color: _darkOnSurface),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: _darkSurface,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(8),
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkPrimary,
          foregroundColor: _darkOnPrimary,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _darkPrimary,
          side: const BorderSide(color: _darkPrimary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _darkPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF404040)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF404040)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkError, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: const TextStyle(color: Color(0xFFB0B0B0)),
        hintStyle: const TextStyle(color: Color(0xFF808080)),
      ),

      // FloatingActionButton Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _darkPrimary,
        foregroundColor: _darkOnPrimary,
        elevation: 4,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _darkSurface,
        selectedItemColor: _darkPrimary,
        unselectedItemColor: Color(0xFF808080),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Drawer Theme
      drawerTheme: const DrawerThemeData(
        backgroundColor: _darkSurface,
        elevation: 16,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: _darkSurface,
        elevation: 24,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _darkOnSurface,
        ),
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF2A2A2A),
        contentTextStyle: const TextStyle(color: _darkOnSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  /// Get theme based on theme manager
  static ThemeData getTheme(bool isDark) {
    return isDark ? darkTheme : lightTheme;
  }

  /// Status Colors Helper
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'valid':
      case 'active':
        return validColor;
      case 'blocked':
        return blockedColor;
      case 'used':
        return usedColor;
      case 'invalid':
      case 'expired':
      case 'deleted':
        return invalidColor;
      default:
        return invalidColor;
    }
  }

  /// Responsive Text Styles
  static TextStyle getHeadingStyle(
    BuildContext context, {
    bool isDark = false,
  }) {
    final fontSize = ResponsiveBreakpoints.getResponsiveValue(
      context: context,
      mobile: 24.0,
      tablet: 28.0,
      desktop: 32.0,
    );

    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: isDark ? _darkOnSurface : _lightOnSurface,
      letterSpacing: 0.5,
    );
  }

  static TextStyle getSubheadingStyle(
    BuildContext context, {
    bool isDark = false,
  }) {
    final fontSize = ResponsiveBreakpoints.getResponsiveValue(
      context: context,
      mobile: 18.0,
      tablet: 20.0,
      desktop: 22.0,
    );

    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: isDark ? _darkOnSurface : _lightOnSurface,
      letterSpacing: 0.3,
    );
  }

  static TextStyle getBodyStyle(BuildContext context, {bool isDark = false}) {
    final fontSize = ResponsiveBreakpoints.getResponsiveValue(
      context: context,
      mobile: 16.0,
      tablet: 16.0,
      desktop: 18.0,
    );

    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      color: isDark ? _darkOnSurface : _lightOnSurface,
      height: 1.5,
    );
  }

  static TextStyle getCaptionStyle(
    BuildContext context, {
    bool isDark = false,
  }) {
    final fontSize = ResponsiveBreakpoints.getResponsiveValue(
      context: context,
      mobile: 14.0,
      tablet: 14.0,
      desktop: 16.0,
    );

    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      color: isDark
          ? _darkOnSurface.withOpacity(0.7)
          : _lightOnSurface.withOpacity(0.7),
      height: 1.4,
    );
  }

  static TextStyle getButtonStyle(BuildContext context) {
    final fontSize = ResponsiveBreakpoints.getResponsiveValue(
      context: context,
      mobile: 16.0,
      tablet: 16.0,
      desktop: 18.0,
    );

    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );
  }

  /// Legacy static styles for backward compatibility
  static const TextStyle headingStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  static const TextStyle subheadingStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle buttonStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  // Color getters for current theme
  static Color primaryColor = _lightPrimary;
  static Color secondaryColor = _lightSecondary;
  static Color backgroundColor = _lightBackground;
  static Color surfaceColor = _lightSurface;
  static Color onSurfaceColor = _lightOnSurface;
  static Color secondaryTextColor = const Color(0xFF757575);

  /// Update colors based on current theme
  static void updateColors(bool isDark) {
    if (isDark) {
      primaryColor = _darkPrimary;
      secondaryColor = _darkSecondary;
      backgroundColor = _darkBackground;
      surfaceColor = _darkSurface;
      onSurfaceColor = _darkOnSurface;
      secondaryTextColor = const Color(0xFFB0B0B0);
    } else {
      primaryColor = _lightPrimary;
      secondaryColor = _lightSecondary;
      backgroundColor = _lightBackground;
      surfaceColor = _lightSurface;
      onSurfaceColor = _lightOnSurface;
      secondaryTextColor = const Color(0xFF757575);
    }
  }
}
