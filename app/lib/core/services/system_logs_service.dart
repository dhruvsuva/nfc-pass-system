import 'dart:async';
import 'package:flutter/foundation.dart';

import '../network/api_service.dart';
import '../config/app_config.dart';
import '../../models/system_log_model.dart';

class SystemLogsService {
  static const String _systemLogsEndpoint = AppConfig.logsEndpoint; // '/api/system-logs'

  /// Get system logs with filters and pagination
  static Future<SystemLogsResponse> getSystemLogs({
    String? actionType,
    int? userId,
    String? role,
    String? result,
    String? startDate,
    String? endDate,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      // Add filters if provided
      if (actionType != null) queryParams['action_type'] = actionType;
      if (userId != null) queryParams['user_id'] = userId.toString();
      if (role != null) queryParams['role'] = role;
      if (result != null) queryParams['result'] = result;
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
      if (search != null) queryParams['search'] = search;

      debugPrint('Getting system logs with params: $queryParams');

      final response = await ApiService.get(
        _systemLogsEndpoint,
        queryParams: queryParams,
      );

      return SystemLogsResponse.fromJson(response);
    } on ApiException catch (e) {
      debugPrint('API error getting system logs: $e');
      
      throw SystemLogsServiceException(
        message: e.message,
        code: e.data?['code'] ?? 'API_ERROR',
        statusCode: e.statusCode,
      );
    } catch (e) {
      debugPrint('Unexpected error getting system logs: $e');
      throw SystemLogsServiceException(
        message: 'Failed to get system logs: $e',
        code: 'UNKNOWN_ERROR',
      );
    }
  }

  /// Get system log by ID
  static Future<SystemLogModel> getSystemLogById(int id) async {
    try {
      debugPrint('Getting system log by ID: $id');

      final response = await ApiService.get('$_systemLogsEndpoint/$id');

      return SystemLogModel.fromJson(response['log']);
    } on ApiException catch (e) {
      debugPrint('API error getting system log by ID: $e');
      
      throw SystemLogsServiceException(
        message: e.message,
        code: e.data?['code'] ?? 'API_ERROR',
        statusCode: e.statusCode,
      );
    } catch (e) {
      debugPrint('Unexpected error getting system log by ID: $e');
      throw SystemLogsServiceException(
        message: 'Failed to get system log: $e',
        code: 'UNKNOWN_ERROR',
      );
    }
  }

  /// Get system logs statistics
  static Future<SystemLogsStats> getSystemLogsStats() async {
    try {
      debugPrint('Getting system logs statistics');

      final response = await ApiService.get('$_systemLogsEndpoint/stats');

      return SystemLogsStats.fromJson(response);
    } on ApiException catch (e) {
      debugPrint('API error getting system logs stats: $e');
      
      throw SystemLogsServiceException(
        message: e.message,
        code: e.data?['code'] ?? 'API_ERROR',
        statusCode: e.statusCode,
      );
    } catch (e) {
      debugPrint('Unexpected error getting system logs stats: $e');
      throw SystemLogsServiceException(
        message: 'Failed to get system logs statistics: $e',
        code: 'UNKNOWN_ERROR',
      );
    }
  }

  /// Get available action types
  static Future<List<String>> getAvailableActionTypes() async {
    try {
      debugPrint('Getting available action types');

      final response = await ApiService.get('$_systemLogsEndpoint/actions');

      return List<String>.from(response['actions'] ?? []);
    } on ApiException catch (e) {
      debugPrint('API error getting action types: $e');
      
      throw SystemLogsServiceException(
        message: e.message,
        code: e.data?['code'] ?? 'API_ERROR',
        statusCode: e.statusCode,
      );
    } catch (e) {
      debugPrint('Unexpected error getting action types: $e');
      throw SystemLogsServiceException(
        message: 'Failed to get action types: $e',
        code: 'UNKNOWN_ERROR',
      );
    }
  }
}

class SystemLogsResponse {
  final List<SystemLogModel> logs;
  final SystemLogsPagination pagination;
  final Map<String, dynamic> filters;

  const SystemLogsResponse({
    required this.logs,
    required this.pagination,
    required this.filters,
  });

  factory SystemLogsResponse.fromJson(Map<String, dynamic> json) {
    return SystemLogsResponse(
      logs: (json['logs'] as List<dynamic>?)
          ?.map((log) => SystemLogModel.fromJson(log as Map<String, dynamic>))
          .toList() ?? [],
      pagination: SystemLogsPagination.fromJson(json['pagination'] as Map<String, dynamic>),
      filters: json['filters'] as Map<String, dynamic>? ?? {},
    );
  }

  // Add total property for compatibility
  int get total => pagination.total;
}

class SystemLogsPagination {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  const SystemLogsPagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory SystemLogsPagination.fromJson(Map<String, dynamic> json) {
    return SystemLogsPagination(
      page: json['page'] as int,
      limit: json['limit'] as int,
      total: json['total'] as int,
      totalPages: json['totalPages'] as int,
    );
  }
}

class SystemLogsStats {
  final int totalLogs;
  final int todayLogs;
  final int successLogs;
  final int errorLogs;
  final Map<String, int> actionTypeCounts;
  final Map<String, int> roleCounts;

  const SystemLogsStats({
    required this.totalLogs,
    required this.todayLogs,
    required this.successLogs,
    required this.errorLogs,
    required this.actionTypeCounts,
    required this.roleCounts,
  });

  factory SystemLogsStats.fromJson(Map<String, dynamic> json) {
    return SystemLogsStats(
      totalLogs: json['totalLogs'] as int? ?? 0,
      todayLogs: json['todayLogs'] as int? ?? 0,
      successLogs: json['successLogs'] as int? ?? 0,
      errorLogs: json['errorLogs'] as int? ?? 0,
      actionTypeCounts: Map<String, int>.from(json['actionTypeCounts'] ?? {}),
      roleCounts: Map<String, int>.from(json['roleCounts'] ?? {}),
    );
  }
}

class SystemLogsServiceException implements Exception {
  final String message;
  final String code;
  final int? statusCode;

  const SystemLogsServiceException({
    required this.message,
    required this.code,
    this.statusCode,
  });

  @override
  String toString() => 'SystemLogsServiceException: $message (Code: $code)';
}