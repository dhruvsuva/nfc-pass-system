import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:intl/intl.dart';

class TimezoneUtils {
  static late tz.Location _kolkataLocation;
  static bool _initialized = false;

  /// Initialize timezone data and set Kolkata as default
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Initialize timezone database
      tz.initializeTimeZones();
      
      // Set Kolkata timezone
      _kolkataLocation = tz.getLocation('Asia/Kolkata');
      
      _initialized = true;
    } catch (e) {
      // Fallback to UTC if Kolkata timezone fails
      _kolkataLocation = tz.UTC;
      _initialized = true;
      print('Warning: Failed to initialize Kolkata timezone, using UTC: $e');
    }
  }

  /// Get current time in Kolkata timezone
  static tz.TZDateTime now() {
    _ensureInitialized();
    return tz.TZDateTime.now(_kolkataLocation);
  }

  /// Convert DateTime to Kolkata timezone
  static tz.TZDateTime toKolkata(DateTime dateTime) {
    _ensureInitialized();
    return tz.TZDateTime.from(dateTime, _kolkataLocation);
  }

  /// Convert string to Kolkata timezone DateTime
  static tz.TZDateTime parseToKolkata(String dateTimeString) {
    _ensureInitialized();
    final dateTime = DateTime.parse(dateTimeString);
    return tz.TZDateTime.from(dateTime, _kolkataLocation);
  }

  /// Format DateTime to Indian format (DD/MM/YYYY HH:MM)
  static String formatIndian(DateTime dateTime) {
    // Convert to Kolkata timezone before formatting
    final kolkataTime = toKolkata(dateTime);
    return DateFormat('dd/MM/yyyy HH:mm').format(kolkataTime);
  }

  /// Format DateTime to Indian date only (DD/MM/YYYY)
  static String formatIndianDate(DateTime dateTime) {
    // Convert to Kolkata timezone before formatting
    final kolkataTime = toKolkata(dateTime);
    return DateFormat('dd/MM/yyyy').format(kolkataTime);
  }

  /// Format DateTime to Indian time only (HH:MM)
  static String formatIndianTime(DateTime dateTime) {
    // Convert to Kolkata timezone before formatting
    final kolkataTime = toKolkata(dateTime);
    return DateFormat('HH:mm').format(kolkataTime);
  }

  /// Format DateTime with relative time (e.g., "2 hours ago", "Just now")
  static String formatRelative(DateTime dateTime) {
    // Convert both times to Kolkata timezone for accurate comparison
    final nowKolkata = now();
    final dateTimeKolkata = toKolkata(dateTime);
    final difference = nowKolkata.difference(dateTimeKolkata);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return formatIndianDate(dateTimeKolkata);
    }
  }

  /// Format DateTime for API requests (ISO format in Kolkata timezone)
  static String formatForAPI(DateTime dateTime) {
    final kolkataTime = toKolkata(dateTime);
    return kolkataTime.toIso8601String();
  }

  /// Parse API response datetime string to local DateTime
  static DateTime parseFromAPI(String dateTimeString) {
    try {
      final parsedDateTime = DateTime.parse(dateTimeString);
      // API returns UTC time, convert to Kolkata timezone
      return toKolkata(parsedDateTime);
    } catch (e) {
      print('Error parsing datetime from API: $e');
      return now();
    }
  }

  /// Get start of day in Kolkata timezone
  static tz.TZDateTime startOfDay([DateTime? date]) {
    _ensureInitialized();
    final targetDate = date ?? DateTime.now();
    final kolkataTime = toKolkata(targetDate);
    return tz.TZDateTime(_kolkataLocation, kolkataTime.year, kolkataTime.month, kolkataTime.day);
  }

  /// Get end of day in Kolkata timezone
  static tz.TZDateTime endOfDay([DateTime? date]) {
    _ensureInitialized();
    final targetDate = date ?? DateTime.now();
    final kolkataTime = toKolkata(targetDate);
    return tz.TZDateTime(_kolkataLocation, kolkataTime.year, kolkataTime.month, kolkataTime.day, 23, 59, 59, 999);
  }

  /// Check if two dates are the same day in Kolkata timezone
  static bool isSameDay(DateTime date1, DateTime date2) {
    final kolkata1 = toKolkata(date1);
    final kolkata2 = toKolkata(date2);
    return kolkata1.year == kolkata2.year &&
           kolkata1.month == kolkata2.month &&
           kolkata1.day == kolkata2.day;
  }

  /// Get timezone offset string (+05:30)
  static String getTimezoneOffset() {
    _ensureInitialized();
    final offset = _kolkataLocation.currentTimeZone.offset;
    final hours = offset ~/ Duration.millisecondsPerHour;
    final minutes = (offset % Duration.millisecondsPerHour) ~/ Duration.millisecondsPerMinute;
    return '${hours >= 0 ? '+' : '-'}${hours.abs().toString().padLeft(2, '0')}:${minutes.abs().toString().padLeft(2, '0')}';
  }

  /// Ensure timezone is initialized
  static void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('TimezoneUtils not initialized. Call TimezoneUtils.initialize() first.');
    }
  }

  /// Get Kolkata location (for advanced usage)
  static tz.Location get kolkataLocation {
    _ensureInitialized();
    return _kolkataLocation;
  }
}