import 'dart:convert';

class SystemLogModel {
  final int id;
  final String actionType;
  final int? userId;
  final String? role;
  final String? ipAddress;
  final String? userAgent;
  final String? details;
  final String result;
  final DateTime createdAt;
  final String? username;
  final String? assignedCategory;

  const SystemLogModel({
    required this.id,
    required this.actionType,
    this.userId,
    this.role,
    this.ipAddress,
    this.userAgent,
    this.details,
    required this.result,
    required this.createdAt,
    this.username,
    this.assignedCategory,
  });

  factory SystemLogModel.fromJson(Map<String, dynamic> json) {
    return SystemLogModel(
      id: json['id'] as int,
      actionType: (json['action_type'] as String?) ?? 'unknown',
      userId: json['user_id'] as int?,
      role: json['role'] as String?,
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
      details: json['details'] != null ? jsonEncode(json['details']) : null,
      result: (json['result'] as String?) ?? 'unknown',
      createdAt: DateTime.parse((json['created_at'] as String?) ?? DateTime.now().toIso8601String()),
      username: json['username'] as String?,
      assignedCategory: json['assigned_category'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action_type': actionType,
      'user_id': userId,
      'role': role,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'details': details,
      'result': result,
      'created_at': createdAt.toIso8601String(),
      'username': username,
      'assigned_category': assignedCategory,
    };
  }

  SystemLogModel copyWith({
    int? id,
    String? actionType,
    int? userId,
    String? role,
    String? ipAddress,
    String? userAgent,
    String? details,
    String? result,
    DateTime? createdAt,
    String? username,
    String? assignedCategory,
  }) {
    return SystemLogModel(
      id: id ?? this.id,
      actionType: actionType ?? this.actionType,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      details: details ?? this.details,
      result: result ?? this.result,
      createdAt: createdAt ?? this.createdAt,
      username: username ?? this.username,
      assignedCategory: assignedCategory ?? this.assignedCategory,
    );
  }

  String get formattedCreatedTime {
    try {
      // Convert to IST (UTC + 5:30)
      final utcTime = createdAt.toUtc();
      final istTime = utcTime.add(const Duration(hours: 5, minutes: 30));
      
      return '${istTime.day.toString().padLeft(2, '0')}/${istTime.month.toString().padLeft(2, '0')}/${istTime.year} '
             '${istTime.hour.toString().padLeft(2, '0')}:${istTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year} '
             '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    }
  }

  String get resultDisplayName {
    switch (result.toLowerCase()) {
      case 'success':
        return 'Success';
      case 'failed':
      case 'failure':
        return 'Failed';
      case 'error':
        return 'Error';
      case 'warning':
        return 'Warning';
      default:
        return result.toUpperCase();
    }
  }

  String get actionDisplayName {
    switch (actionType) {
      case 'login':
        return 'Login';
      case 'logout':
        return 'Logout';
      case 'create_user':
        return 'Create User';
      case 'update_user':
        return 'Update User';
      case 'delete_user':
        return 'Delete User';
      case 'block_user':
        return 'Block User';
      case 'unblock_user':
        return 'Unblock User';
      case 'change_password':
        return 'Change Password';
      case 'create_pass':
        return 'Create Pass';
      case 'bulk_create_pass':
        return 'Bulk Create Pass';
      case 'verify_pass':
        return 'Verify Pass';
      case 'block_pass':
        return 'Block Pass';
      case 'unblock_pass':
        return 'Unblock Pass';
      case 'delete_pass':
        return 'Delete Pass';
      case 'reset_single_pass':
        return 'Reset Single Pass';
      case 'reset_daily_passes':
        return 'Reset Daily Passes';
      case 'create_category':
        return 'Create Category';
      case 'update_category':
        return 'Update Category';
      case 'delete_category':
        return 'Delete Category';
      case 'assign_category':
        return 'Assign Category';
      default:
        return actionType.replaceAll('_', ' ').split(' ').map((word) => 
          word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : word
        ).join(' ');
    }
  }

  @override
  String toString() {
    return 'SystemLogModel(id: $id, actionType: $actionType, result: $result, createdAt: $createdAt)';
  }
}