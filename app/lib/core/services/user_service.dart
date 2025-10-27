import 'package:flutter/foundation.dart';
import '../../models/user_model.dart';
import '../network/api_service.dart';

class UserServiceException implements Exception {
  final String message;
  final String code;
  final int? statusCode;
  
  const UserServiceException({
    required this.message,
    required this.code,
    this.statusCode,
  });
  
  @override
  String toString() => 'UserServiceException: $message (Code: $code)';
}

class UserService {
  static const String _usersEndpoint = '/api/users';
  
  /// Get all users with search, filter, and pagination
  static Future<Map<String, dynamic>> getAllUsers({
    int page = 1,
    int limit = 20,
    String? search,
    String? role,
    String? status,
    String sortBy = 'created_at',
    String sortOrder = 'DESC',
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        'sortBy': sortBy,
        'sortOrder': sortOrder,
      };
      
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (role != null && role.isNotEmpty) {
        queryParams['role'] = role;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      
      debugPrint('Getting users with params: $queryParams');
      
      final response = await ApiService.get(_usersEndpoint, queryParams: queryParams);
      
      final data = response['data'] ?? {};
      final List<dynamic> usersData = data['users'] ?? [];
      final Map<String, dynamic> pagination = data['pagination'] ?? {};
      
      return {
        'users': usersData.map((userData) => UserModel.fromJson(userData)).toList(),
        'pagination': pagination,
      };
    } catch (e) {
      debugPrint('API error getting users: $e');
      
      if (e.toString().contains('ApiException')) {
        throw UserServiceException(
          message: e.toString(),
          code: 'API_ERROR',
          statusCode: 0,
        );
      }
      
      throw UserServiceException(
        message: 'Failed to get users: $e',
        code: 'UNKNOWN_ERROR',
      );
    }
  }
  
  /// Get user by ID
  static Future<UserModel> getUserById(int userId) async {
    try {
      debugPrint('Getting user by ID: $userId');
      
      final response = await ApiService.get('$_usersEndpoint/$userId');
      
      final userData = response['data']?['user'] ?? response['data'];
      return UserModel.fromJson(userData);
    } catch (e) {
      debugPrint('API error getting user: $e');
      
      throw UserServiceException(
        message: 'Failed to get user: $e',
        code: 'UNKNOWN_ERROR',
      );
    }
  }
  
  /// Create a new user
  static Future<UserModel> createUser(UserModel user) async {
    try {
      final userData = {
        'username': user.username,
        'password': user.password,
        'role': user.role,
        'status': user.status,
        if (user.assignedCategory != null) 'assigned_category': user.assignedCategory,
      };
      
      debugPrint('Creating user with data: $userData');
      
      final response = await ApiService.post(_usersEndpoint, userData);
      
      final userResponseData = response['data'];
      return UserModel.fromJson(userResponseData);
    } catch (e) {
      debugPrint('Error creating user: $e');
      throw UserServiceException(
        message: 'Failed to create user: $e',
        code: 'UNKNOWN_ERROR',
      );
    }
  }
  
  /// Update an existing user
  static Future<UserModel> updateUser(UserModel user) async {
    try {
      final userData = {
        'username': user.username,
        'role': user.role,
        'status': user.status,
        if (user.assignedCategory != null) 'assigned_category': user.assignedCategory,
      };
      
      debugPrint('Updating user ${user.id} with data: $userData');
      
      final response = await ApiService.patch('$_usersEndpoint/${user.id}', userData);
      
      final userResponseData = response['data']?['user'] ?? response['data'];
      return UserModel.fromJson(userResponseData);
    } catch (e) {
      debugPrint('Error updating user: $e');
      throw UserServiceException(
        message: 'Failed to update user: $e',
        code: 'UNKNOWN_ERROR',
      );
    }
  }
  
  /// Change user password
  static Future<void> changePassword(int userId, String newPassword) async {
    try {
      final passwordData = {'password': newPassword};
      
      debugPrint('Changing password for user: $userId');
      
      await ApiService.patch('$_usersEndpoint/$userId/password', passwordData);
    } catch (e) {
      debugPrint('Error changing password: $e');
      throw UserServiceException(
        message: 'Failed to change password: $e',
        code: 'UNKNOWN_ERROR',
      );
    }
  }
  
  /// Block a user
  static Future<void> blockUser(int userId, {String? reason}) async {
    try {
      final blockData = <String, dynamic>{};
      if (reason != null && reason.isNotEmpty) {
        blockData['reason'] = reason;
      }
      
      debugPrint('Blocking user: $userId');
      
      await ApiService.patch('$_usersEndpoint/$userId/block', blockData);
    } catch (e) {
      debugPrint('Error blocking user: $e');
      throw UserServiceException(
        message: 'Failed to block user: $e',
        code: 'UNKNOWN_ERROR',
      );
    }
  }
  
  /// Unblock a user
  static Future<void> unblockUser(int userId) async {
    try {
      debugPrint('Unblocking user: $userId');
      
      await ApiService.patch('$_usersEndpoint/$userId/unblock', {});
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      throw UserServiceException(
        message: 'Failed to unblock user: $e',
        code: 'UNKNOWN_ERROR',
      );
    }
  }
  
  /// Delete a user
  static Future<void> deleteUser(int userId) async {
    try {
      debugPrint('Deleting user: $userId');
      
      await ApiService.delete('$_usersEndpoint/$userId');
    } catch (e) {
      debugPrint('Error deleting user: $e');
      throw UserServiceException(
        message: 'Failed to delete user: $e',
        code: 'UNKNOWN_ERROR',
      );
    }
  }
  
  /// Delete all users except admins
  static Future<Map<String, dynamic>> deleteAllUsers() async {
    try {
      debugPrint('Deleting all non-admin users');
      
      final response = await ApiService.delete(_usersEndpoint);
      
      return {
        'message': response['message'] ?? 'Users deleted successfully',
        'deletedCount': response['deletedCount'] ?? 0,
      };
    } catch (e) {
      debugPrint('Error deleting all users: $e');
      throw UserServiceException(
        message: 'Failed to delete all users: $e',
        code: 'UNKNOWN_ERROR',
      );
    }
  }
  
  /// Get user statistics
  static Future<Map<String, dynamic>> getUserStats() async {
    try {
      debugPrint('Getting user statistics');
      
      final response = await ApiService.get('$_usersEndpoint/stats');
      
      return response['data']?['stats'] ?? {};
    } catch (e) {
      debugPrint('Error getting user stats: $e');
      throw UserServiceException(
        message: 'Failed to get user stats: $e',
        code: 'UNKNOWN_ERROR',
      );
    }
  }
}

// Complete User Management API Functions:
// 1. getAllUsers() - Get users with search, filter, pagination
// 2. getUserById() - Get specific user details
// 3. createUser() - Create new user
// 4. updateUser() - Update user details
// 5. changePassword() - Change user password
// 6. blockUser() - Block user account
// 7. unblockUser() - Unblock user account
// 8. deleteUser() - Delete individual user
// 9. deleteAllUsers() - Delete all non-admin users
// 10. getUserStats() - Get user statistics