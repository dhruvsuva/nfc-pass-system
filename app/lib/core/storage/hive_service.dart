import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Simple token storage service using flutter_secure_storage
/// Replaces the previous Hive-based offline storage for online-only operation
class HiveService {
  static const _storage = FlutterSecureStorage();
  
  // Token storage keys
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userDataKey = 'user_data';
  
  /// Save authentication tokens
  static Future<void> saveAuthTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }
  
  /// Get access token
  static String? getAccessToken() {
    // Note: This is synchronous in the original implementation
    // For compatibility, we'll need to handle this differently
    // This is a simplified version - in production, consider using async methods
    return null; // Will be handled by async version
  }
  
  /// Get access token (async version)
  static Future<String?> getAccessTokenAsync() async {
    return await _storage.read(key: _accessTokenKey);
  }
  
  /// Get refresh token
  static String? getRefreshToken() {
    return null; // Will be handled by async version
  }
  
  /// Get refresh token (async version)
  static Future<String?> getRefreshTokenAsync() async {
    return await _storage.read(key: _refreshTokenKey);
  }
  
  /// Save user data
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _storage.write(key: _userDataKey, value: json.encode(userData));
  }
  
  /// Get user data
  static Map<String, dynamic>? getUserData() {
    return null; // Will be handled by async version
  }
  
  /// Get user data (async version)
  static Future<Map<String, dynamic>?> getUserDataAsync() async {
    final userDataString = await _storage.read(key: _userDataKey);
    if (userDataString != null) {
      return json.decode(userDataString);
    }
    return null;
  }
  
  /// Clear all authentication data
  static Future<void> clearAuthData() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userDataKey);
  }
  
  /// Settings storage (simplified)
  static Future<void> setSetting(String key, dynamic value) async {
    await _storage.write(key: 'setting_$key', value: value.toString());
  }
  
  /// Get setting
  static T? getSetting<T>(String key) {
    // Simplified synchronous version - returns null
    // Use async version for actual implementation
    return null;
  }
  
  /// Get setting (async version)
  static Future<T?> getSettingAsync<T>(String key) async {
    final value = await _storage.read(key: 'setting_$key');
    if (value != null) {
      if (T == String) return value as T;
      if (T == int) return int.tryParse(value) as T?;
      if (T == bool) return (value == 'true') as T;
    }
    return null;
  }
  
  // Deprecated offline methods - kept for compatibility but do nothing
  static Future<void> addActivePass(String uid, dynamic pass) async {
    // No-op: offline storage not needed
  }
  
  static Future<void> clearAllActivePasses() async {
    // No-op: offline storage not needed
  }
}