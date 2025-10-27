import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../storage/hive_service.dart';

class ThemeManager extends ChangeNotifier {
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal();

  ThemeMode _themeMode = ThemeMode.system;
  bool _isDarkMode = false;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _isDarkMode;
  bool get isLightMode => !_isDarkMode;

  /// Initialize theme from stored preferences
  Future<void> initialize() async {
    try {
      final storedTheme = await HiveService.getSettingAsync<String>('theme_mode');
      _themeMode = _parseThemeMode(storedTheme);
      _updateDarkModeStatus();
      notifyListeners();
    } catch (e) {
      // Default to system theme if error
      _themeMode = ThemeMode.system;
      _updateDarkModeStatus();
    }
  }

  /// Toggle between light and dark mode
  Future<void> toggleTheme() async {
    switch (_themeMode) {
      case ThemeMode.light:
        await setThemeMode(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        await setThemeMode(ThemeMode.light);
        break;
      case ThemeMode.system:
        // If system, toggle to opposite of current system setting
        final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
        if (brightness == Brightness.dark) {
          await setThemeMode(ThemeMode.light);
        } else {
          await setThemeMode(ThemeMode.dark);
        }
        break;
    }
  }

  /// Set specific theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      _updateDarkModeStatus();
      await _saveThemeMode();
      _updateSystemUI();
      notifyListeners();
    }
  }

  /// Update dark mode status based on current theme mode
  void _updateDarkModeStatus() {
    switch (_themeMode) {
      case ThemeMode.light:
        _isDarkMode = false;
        break;
      case ThemeMode.dark:
        _isDarkMode = true;
        break;
      case ThemeMode.system:
        final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
        _isDarkMode = brightness == Brightness.dark;
        break;
    }
  }

  /// Save theme mode to storage
  Future<void> _saveThemeMode() async {
    try {
      await HiveService.setSetting('theme_mode', _themeMode.toString());
    } catch (e) {
      debugPrint('Failed to save theme mode: $e');
    }
  }

  /// Update system UI overlay style based on theme
  void _updateSystemUI() {
    final brightness = _isDarkMode ? Brightness.dark : Brightness.light;
    final statusBarBrightness = _isDarkMode ? Brightness.light : Brightness.dark;
    
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: statusBarBrightness,
      statusBarIconBrightness: statusBarBrightness,
      systemNavigationBarColor: _isDarkMode ? const Color(0xFF121212) : Colors.white,
      systemNavigationBarIconBrightness: statusBarBrightness,
    ));
  }

  /// Parse theme mode from string
  ThemeMode _parseThemeMode(String? themeString) {
    switch (themeString) {
      case 'ThemeMode.light':
        return ThemeMode.light;
      case 'ThemeMode.dark':
        return ThemeMode.dark;
      case 'ThemeMode.system':
      default:
        return ThemeMode.system;
    }
  }

  /// Get theme mode display name
  String get themeModeDisplayName {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  /// Get theme mode icon
  IconData get themeModeIcon {
    switch (_themeMode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }
}

/// Responsive breakpoints
class ResponsiveBreakpoints {
  static const double mobile = 480;
  static const double tablet = 768;
  static const double desktop = 1024;
  static const double largeDesktop = 1440;

  /// Check if screen is mobile size
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobile;
  }

  /// Check if screen is tablet size
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobile && width < desktop;
  }

  /// Check if screen is desktop size
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktop;
  }

  /// Get responsive value based on screen size
  static T getResponsiveValue<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    
    if (width >= ResponsiveBreakpoints.desktop) {
      return desktop ?? tablet ?? mobile;
    } else if (width >= ResponsiveBreakpoints.mobile) {
      return tablet ?? mobile;
    } else {
      return mobile;
    }
  }
}

/// Responsive spacing utility
class ResponsiveSpacing {
  static double getHorizontalPadding(BuildContext context) {
    return ResponsiveBreakpoints.getResponsiveValue(
      context: context,
      mobile: 16.0,
      tablet: 24.0,
      desktop: 32.0,
    );
  }

  static double getVerticalPadding(BuildContext context) {
    return ResponsiveBreakpoints.getResponsiveValue(
      context: context,
      mobile: 16.0,
      tablet: 20.0,
      desktop: 24.0,
    );
  }

  static double getCardPadding(BuildContext context) {
    return ResponsiveBreakpoints.getResponsiveValue(
      context: context,
      mobile: 16.0,
      tablet: 20.0,
      desktop: 24.0,
    );
  }

  static double getBorderRadius(BuildContext context) {
    return ResponsiveBreakpoints.getResponsiveValue(
      context: context,
      mobile: 12.0,
      tablet: 16.0,
      desktop: 20.0,
    );
  }
}