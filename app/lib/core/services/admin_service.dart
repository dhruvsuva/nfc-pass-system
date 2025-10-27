import 'dart:async';
import 'package:flutter/foundation.dart';

import '../network/api_service.dart';

class AdminService {
  static const String _rebuildCacheEndpoint = '/api/admin/rebuild-cache';
  static const String _clearCacheEndpoint = '/api/admin/clear-cache';
  static const String _cacheStatsEndpoint = '/api/admin/cache-stats';
  static const String _systemInfoEndpoint = '/api/admin/system-info';
  static const String _settingsEndpoint = '/api/admin/settings';

  /// Rebuild cache
  static Future<Map<String, dynamic>> rebuildCache() async {
    try {
      debugPrint('Rebuilding cache...');
      
      final response = await ApiService.post(_rebuildCacheEndpoint, {});
      
      debugPrint('Cache rebuild response: $response');
      
      return {
        'success': true,
        'message': response['message'] ?? 'Cache rebuilt successfully',
        'data': response,
      };
    } catch (e) {
      debugPrint('API error rebuilding cache: $e');
      
      throw AdminServiceException(
        message: 'Failed to rebuild cache: $e',
        code: 'REBUILD_CACHE_ERROR',
      );
    }
  }

  /// Clear cache for specific user or all
  static Future<Map<String, dynamic>> clearCache({String? uid}) async {
    try {
      final endpoint = uid != null ? '$_clearCacheEndpoint/$uid' : _clearCacheEndpoint;
      
      debugPrint('Clearing cache for: ${uid ?? 'all'}');
      
      final response = await ApiService.post(endpoint, {});
      
      debugPrint('Cache clear response: $response');
      
      return {
        'success': true,
        'message': response['message'] ?? 'Cache cleared successfully',
        'data': response,
      };
    } catch (e) {
      debugPrint('API error clearing cache: $e');
      
      throw AdminServiceException(
        message: 'Failed to clear cache: $e',
        code: 'CLEAR_CACHE_ERROR',
      );
    }
  }

  /// Get system information
  static Future<Map<String, dynamic>> getSystemInfo() async {
    try {
      debugPrint('Getting system information...');
      
      final response = await ApiService.get(_systemInfoEndpoint);
      
      debugPrint('System info response: $response');
      
      return {
        'success': true,
        'systemInfo': response['systemInfo'] ?? {},
        'timestamp': response['timestamp'],
      };
    } catch (e) {
      debugPrint('API error getting system info: $e');
      
      throw AdminServiceException(
        message: 'Failed to get system information: $e',
        code: 'SYSTEM_INFO_ERROR',
      );
    }
  }

  /// Get cache statistics
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      debugPrint('Getting cache statistics...');
      
      final response = await ApiService.get(_cacheStatsEndpoint);
      
      debugPrint('Cache stats response: $response');
      
      return {
        'success': true,
        'redis_status': response['redis_status'] ?? 'Unknown',
        'total_keys': response['total_keys'] ?? 0,
        'memory_usage': response['memory_usage'] ?? 'N/A',
        'active_passes': response['active_passes'] ?? 0,
        'blocked_passes': response['blocked_passes'] ?? 0,
        'lock_keys': response['lock_keys'] ?? 0,
        'timestamp': response['timestamp'],
      };
    } catch (e) {
      debugPrint('API error getting cache stats: $e');
      
      throw AdminServiceException(
        message: 'Failed to get cache statistics: $e',
        code: 'CACHE_STATS_ERROR',
      );
    }
  }

  /// Get admin settings
  static Future<Map<String, dynamic>> getSettings() async {
    try {
      debugPrint('Getting admin settings...');
      
      final response = await ApiService.get(_settingsEndpoint);
      
      debugPrint('Settings response: $response');
      
      return {
        'success': true,
        'settings': response['settings'] ?? {},
        'timestamp': response['timestamp'],
      };
    } catch (e) {
      debugPrint('API error getting settings: $e');
      
      throw AdminServiceException(
        message: 'Failed to get settings: $e',
        code: 'GET_SETTINGS_ERROR',
      );
    }
  }
}

class AdminServiceException implements Exception {
  final String message;
  final String code;
  final int? statusCode;
  final Map<String, dynamic>? data;

  const AdminServiceException({
    required this.message,
    required this.code,
    this.statusCode,
    this.data,
  });

  @override
  String toString() => 'AdminServiceException: $message (Code: $code)';
}