import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../storage/hive_service.dart';
import 'http_interceptor.dart';

class ApiService {
  static const String _baseUrl = AppConfig.baseUrl;
  static const Duration _timeout = Duration(seconds: 30);
  
  /// Get authentication token from storage
  static Future<String?> _getAuthToken() async {
    try {
      return await HiveService.getAccessTokenAsync();
    } catch (e) {
      debugPrint('Failed to get auth token: $e');
      return null;
    }
  }
  
  /// Get common headers for API requests
  static Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (includeAuth) {
      final token = await _getAuthToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    
    return headers;
  }
  
  /// Handle HTTP response
  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final data = json.decode(response.body) as Map<String, dynamic>;
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      } else {
        throw ApiException(
          message: data['message'] ?? 'Request failed',
          statusCode: response.statusCode,
          data: data,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      
      throw ApiException(
        message: 'Failed to parse response: $e',
        statusCode: response.statusCode,
      );
    }
  }
  
  /// POST request
  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data, {
    bool includeAuth = true,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl$endpoint');
      final headers = await _getHeaders(includeAuth: includeAuth);
      
      debugPrint('POST $url');
      debugPrint('Headers: $headers');
      debugPrint('Body: ${json.encode(data)}');
      
      final response = await HttpInterceptor
          .post(
            url,
            headers: headers,
            body: json.encode(data),
          )
          .timeout(_timeout);
      
      debugPrint('Response: ${response.statusCode} ${response.body}');
      
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        message: 'No internet connection',
        statusCode: 0,
      );
    } on TimeoutException {
      throw ApiException(
        message: 'Request timeout',
        statusCode: 0,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      
      throw ApiException(
        message: 'Network error: $e',
        statusCode: 0,
      );
    }
  }
  
  /// GET request
  static Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool includeAuth = true,
  }) async {
    try {
      var url = Uri.parse('$_baseUrl$endpoint');
      
      if (queryParams != null && queryParams.isNotEmpty) {
        url = url.replace(queryParameters: queryParams);
      }
      
      final headers = await _getHeaders(includeAuth: includeAuth);
      
      debugPrint('GET $url');
      debugPrint('Headers: $headers');
      
      final response = await HttpInterceptor
          .get(url, headers: headers)
          .timeout(_timeout);
      
      debugPrint('Response: ${response.statusCode} ${response.body}');
      
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        message: 'No internet connection',
        statusCode: 0,
      );
    } on TimeoutException {
      throw ApiException(
        message: 'Request timeout',
        statusCode: 0,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      
      throw ApiException(
        message: 'Network error: $e',
        statusCode: 0,
      );
    }
  }
  
  /// PUT request
  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data, {
    bool includeAuth = true,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl$endpoint');
      final headers = await _getHeaders(includeAuth: includeAuth);
      
      debugPrint('PUT $url');
      debugPrint('Headers: $headers');
      debugPrint('Body: ${json.encode(data)}');
      
      final response = await HttpInterceptor
          .put(
            url,
            headers: headers,
            body: json.encode(data),
          )
          .timeout(_timeout);
      
      debugPrint('Response: ${response.statusCode} ${response.body}');
      
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        message: 'No internet connection',
        statusCode: 0,
      );
    } on TimeoutException {
      throw ApiException(
        message: 'Request timeout',
        statusCode: 0,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      
      throw ApiException(
        message: 'Network error: $e',
        statusCode: 0,
      );
    }
  }
  
  /// PATCH request
  static Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> data, {
    bool includeAuth = true,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl$endpoint');
      final headers = await _getHeaders(includeAuth: includeAuth);
      final body = json.encode(data);
      
      debugPrint('PATCH $url');
      debugPrint('Headers: $headers');
      debugPrint('Body: $body');
      
      final response = await HttpInterceptor
          .patch(url, headers: headers, body: body)
          .timeout(_timeout);
      
      debugPrint('Response: ${response.statusCode} ${response.body}');
      
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        message: 'No internet connection',
        statusCode: 0,
      );
    } on TimeoutException {
      throw ApiException(
        message: 'Request timeout',
        statusCode: 0,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      
      throw ApiException(
        message: 'Network error: $e',
        statusCode: 0,
      );
    }
  }
  
  /// DELETE request
  static Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool includeAuth = true,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl$endpoint');
      final headers = await _getHeaders(includeAuth: includeAuth);
      
      debugPrint('DELETE $url');
      debugPrint('Headers: $headers');
      
      final response = await HttpInterceptor
          .delete(url, headers: headers)
          .timeout(_timeout);
      
      debugPrint('Response: ${response.statusCode} ${response.body}');
      
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        message: 'No internet connection',
        statusCode: 0,
      );
    } on TimeoutException {
      throw ApiException(
        message: 'Request timeout',
        statusCode: 0,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      
      throw ApiException(
        message: 'Network error: $e',
        statusCode: 0,
      );
    }
  }
}

/// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  final int statusCode;
  final Map<String, dynamic>? data;
  
  const ApiException({
    required this.message,
    required this.statusCode,
    this.data,
  });
  
  @override
  String toString() {
    return 'ApiException: $message (Status: $statusCode)';
  }
  
  /// Check if error is due to network connectivity
  bool get isNetworkError => statusCode == 0;
  
  /// Check if error is client-side (4xx)
  bool get isClientError => statusCode >= 400 && statusCode < 500;
  
  /// Check if error is server-side (5xx)
  bool get isServerError => statusCode >= 500;
  
  /// Check if error is permanent (should not retry)
  bool get isPermanentError => isClientError;
}