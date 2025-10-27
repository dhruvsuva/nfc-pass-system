import 'dart:convert';

import '../../../core/config/app_config.dart';
import '../../../core/network/http_interceptor.dart';
import '../../../core/storage/hive_service.dart';
import '../../../models/user_model.dart';

class AuthState {
  final bool isAuthenticated;
  final UserModel? user;
  final String? accessToken;
  final bool isLoading;
  final String? error;
  final String? errorType;

  const AuthState({
    this.isAuthenticated = false,
    this.user,
    this.accessToken,
    this.isLoading = false,
    this.error,
    this.errorType,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    UserModel? user,
    String? accessToken,
    bool? isLoading,
    String? error,
    String? errorType,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
    );
  }
}

class AuthNotifier {
  AuthState _state = const AuthState();
  
  AuthState get state => _state;
  
  void _setState(AuthState newState) {
    _state = newState;
    // TODO: Add proper state management notification
  }

  Future<bool> login(String username, String password) async {
    try {
      _setState(_state.copyWith(isLoading: true, error: null, errorType: null));

      print('Making login request for username: $username');

      // Make actual API call to login endpoint
      final response = await HttpInterceptor.post(
        Uri.parse('${AppConfig.baseUrl}${AppConfig.loginEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );
      
      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['user'] == null || data['accessToken'] == null) {
          _setState(_state.copyWith(
            isLoading: false,
            error: 'Invalid response from server',
            errorType: 'error',
          ));
          return false;
        }
        
        final user = UserModel(
          id: data['user']['id'],
          username: data['user']['username'],
          role: data['user']['role'],
          status: data['user']['status'],
          assignedCategory: data['user']['assigned_category'],
          createdAt: data['user']['created_at'] ?? DateTime.now().toIso8601String(),
          updatedAt: data['user']['updated_at'] ?? DateTime.now().toIso8601String(),
        );
        
        final accessToken = data['accessToken'];
        final refreshToken = data['refreshToken'];
        
        // Store tokens and user data
        await HiveService.saveAuthTokens(accessToken, refreshToken);
        await HiveService.saveUserData(user.toJson());
        
        _setState(_state.copyWith(
          isAuthenticated: true,
          user: user,
          accessToken: accessToken,
          isLoading: false,
          error: null,
          errorType: null,
        ));
        
        print('Login successful for user: ${user.username}');
        return true;
      } else {
        final errorData = json.decode(response.body);
        String errorMessage = 'Login failed';
        String errorType = 'error';
        
        if (response.statusCode == 401) {
          errorMessage = errorData['error'] ?? 'Invalid username or password';
          errorType = 'error';
        } else if (response.statusCode == 403) {
          errorMessage = errorData['error'] ?? 'Account blocked. Contact administrator';
          errorType = 'blocked';
        } else if (response.statusCode == 429) {
          errorMessage = 'Too many login attempts. Please try again later';
          errorType = 'error';
        } else if (response.statusCode >= 500) {
          errorMessage = 'Server error. Please try again later';
          errorType = 'error';
        } else {
          errorMessage = errorData['error'] ?? 'Login failed. Please try again';
          errorType = 'error';
        }
        
        _setState(_state.copyWith(
          isLoading: false,
          error: errorMessage,
          errorType: errorType,
        ));
        
        print('Login failed: $errorMessage');
        return false;
      }
    } catch (e) {
      String errorMessage = 'Network error. Please check your connection and try again.';
      String errorType = 'network';
      
      if (e.toString().contains('SocketException') || 
          e.toString().contains('HandshakeException') ||
          e.toString().contains('Connection refused')) {
        errorMessage = 'Cannot connect to server. Please check your internet connection.';
        errorType = 'network';
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Request timed out. Please try again.';
        errorType = 'network';
      }
      
      _setState(_state.copyWith(
        isLoading: false,
        error: errorMessage,
        errorType: errorType,
      ));
      
      print('Login exception: $e');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      // Get current token for logout request
      final token = _state.accessToken;
      
      if (token != null) {
        // Make logout request to server
        try {
          await HttpInterceptor.post(
            Uri.parse('${AppConfig.baseUrl}/auth/logout'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );
        } catch (e) {
          print('Logout request failed: $e');
          // Continue with local logout even if server request fails
        }
      }
      
      // Clear local storage
      await HiveService.clearAuthData();
      
      _setState(const AuthState());
      
      print('User logged out successfully');
    } catch (e) {
      print('Logout error: $e');
      // Force logout even if there's an error
      await HiveService.clearAuthData();
      _setState(const AuthState());
    }
  }

  Future<bool> refreshToken() async {
    try {
      final refreshToken = await HiveService.getRefreshToken();
      if (refreshToken == null) {
        return false;
      }

      final response = await HttpInterceptor.post(
        Uri.parse('${AppConfig.baseUrl}/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'refreshToken': refreshToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final accessToken = data['accessToken'];
        
        await HiveService.saveAuthTokens(accessToken, refreshToken);
        
        _setState(_state.copyWith(accessToken: accessToken));
        return true;
      } else {
        await logout();
        return false;
      }
    } catch (e) {
      print('Token refresh failed: $e');
      await logout();
      return false;
    }
  }

  Future<void> loadStoredAuth() async {
    try {
      final userData = await HiveService.getUserData();
      final accessToken = await HiveService.getAccessToken();
      
      if (userData != null && accessToken != null) {
        final user = UserModel.fromJson(userData);
        
        _setState(_state.copyWith(
          isAuthenticated: true,
          user: user,
          accessToken: accessToken,
        ));
        
        print('Loaded stored auth for user: ${user.username}');
      }
    } catch (e) {
      print('Error loading stored auth: $e');
      await HiveService.clearAuthData();
    }
  }

  void clearError() {
    _setState(_state.copyWith(error: null, errorType: null));
  }
}

// Global auth provider instance
final authProvider = AuthNotifier();