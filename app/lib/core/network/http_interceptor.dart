import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../services/toast_service.dart';
import '../../features/auth/providers/auth_provider.dart';

class HttpInterceptor {
  static BuildContext? _globalContext;

  static void setGlobalContext(BuildContext context) {
    _globalContext = context;
  }

  static void clearGlobalContext() {
    _globalContext = null;
  }

  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final response = await http.get(url, headers: headers);
    return await interceptResponse(response, requestUrl: url.toString());
  }

  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final response = await http.post(url, headers: headers, body: body);
    return await interceptResponse(response, requestUrl: url.toString());
  }

  static Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final response = await http.put(url, headers: headers, body: body);
    return await interceptResponse(response, requestUrl: url.toString());
  }

  static Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final response = await http.patch(url, headers: headers, body: body);
    return await interceptResponse(response, requestUrl: url.toString());
  }

  static Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final response = await http.delete(url, headers: headers);
    return await interceptResponse(response, requestUrl: url.toString());
  }

  static Future<http.Response> interceptResponse(http.Response response, {String? requestUrl}) async {
    // Don't handle 401 for login requests - let the auth provider handle it
    if (response.statusCode == 401 && requestUrl != null && requestUrl.contains('/auth/login')) {
      return response;
    }
    
    // Handle 401 Unauthorized (Token expired)
    if (response.statusCode == 401) {
      await _handleTokenExpired();
      return response;
    }
    
    // Handle 403 Forbidden (User blocked)
    if (response.statusCode == 403) {
      await _handleUserBlocked(response);
      return response;
    }
    
    return response;
  }

  static Future<void> _handleTokenExpired() async {
    try {
      print('🔄 Token expired, logging out user...');
      
      // Update auth state
      await authProvider.logout();
      
      // Show toast message
      ToastService.showError("Session expired, please login again");
      
      // Redirect to login page
      _redirectToLogin();
    } catch (e) {
      print('❌ Error handling token expiry: $e');
    }
  }

  static Future<void> _handleUserBlocked(http.Response response) async {
    try {
      print('🚫 User blocked, logging out...');
      
      // Parse error message from response
      String errorMessage = "Account blocked. Contact administrator";
      try {
        final errorData = json.decode(response.body);
        errorMessage = errorData['error'] ?? errorMessage;
      } catch (e) {
        print('⚠️ Could not parse error message: $e');
      }
      
      // Update auth state
      await authProvider.logout();
      
      // Show specific blocked message
      ToastService.showError(errorMessage);
      
      // Redirect to login page
      _redirectToLogin();
    } catch (e) {
      print('❌ Error handling user blocked: $e');
    }
  }

  static void _redirectToLogin() {
    try {
      if (_globalContext != null && _globalContext!.mounted) {
        print('🔄 Redirecting to login page...');
        Navigator.of(_globalContext!).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      } else {
        print('⚠️ Cannot redirect: context is null or not mounted');
      }
    } catch (e) {
      print('❌ Error redirecting to login: $e');
    }
  }
}