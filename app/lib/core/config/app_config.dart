class AppConfig {
  static const String appName = 'NFC Pass Manager';
  static const String appVersion = '1.0.0';

  // Backend Configuration
  // Using your system's IP for wireless device testing
  static const String baseUrl = 'http://10.248.82.101:3000';
  static const String socketUrl = 'http://10.248.82.101:3000';
  
  // Force configuration refresh - remove this comment after testing
  static const bool debugMode = true;

  // API Endpoints
  static const String loginEndpoint = '/auth/login';
  static const String refreshEndpoint = '/auth/refresh';
  static const String createPassEndpoint = '/api/pass/create';
  static const String bulkCreateEndpoint = '/api/pass/create-bulk';
  static const String verifyEndpoint = '/api/pass/verify';
  static const String syncLogsEndpoint = '/api/pass/sync-logs';
  static const String logsEndpoint = '/api/system-logs';
  static const String myLogsEndpoint = '/api/logs/mine';
  static const String resetPassEndpoint = '/api/pass/{id}/reset';
  static const String resetDailyEndpoint = '/api/admin/reset-daily';
  static const String statsEndpoint = '/api/admin/stats';

  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';

  // Hive Box Names
  static const String activePassesBox = 'active_passes';
  static const String settingsBox = 'settings';

  // SQLite Tables
  static const String syncQueueTable = 'sync_queue';
  static const String logsTable = 'logs';

  // NFC Configuration
  static const String nfcChannelName = 'com.nfcpass.manager/nfc';
  static const String nfcEventChannelName = 'com.nfcpass.manager/nfc_events';

  // Background Tasks
  static const String cacheRefreshTaskName = 'refreshPassCache';

  // UI Configuration
  static const Duration splashDuration = Duration(seconds: 2);
  static const Duration nfcScanTimeout = Duration(seconds: 10);
  static const Duration apiTimeout = Duration(seconds: 30);

  // Validation
  static const int minUidLength = 4;
  static const int maxUidLength = 128;
  static const int maxPeopleAllowed = 100;

  // Audio Settings
  static const String successSoundPath = 'sounds/success.mp3';
  static const String errorSoundPath = 'sounds/error.mp3';
  static const Duration vibrationDuration = Duration(milliseconds: 200);
  static const bool enableHapticFeedback = true;
  static const bool enableAudioFeedback = true;
}
