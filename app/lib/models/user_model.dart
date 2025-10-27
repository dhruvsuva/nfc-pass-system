class UserModel {
  final int id;
  final String username;
  final String role;
  final String status;
  final String? password;
  final String? assignedCategory;
  final String createdAt;
  final String updatedAt;

  const UserModel({
    required this.id,
    required this.username,
    required this.role,
    required this.status,
    this.password,
    this.assignedCategory,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      username: json['username'] as String,
      role: json['role'] as String,
      status: json['status'] as String,
      assignedCategory: json['assigned_category'] as String?,
      createdAt: json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt: json['updated_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'role': role,
      'status': status,
      'assigned_category': assignedCategory,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  UserModel copyWith({
    int? id,
    String? username,
    String? role,
    String? status,
    String? assignedCategory,
    String? createdAt,
    String? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      role: role ?? this.role,
      status: status ?? this.status,
      assignedCategory: assignedCategory ?? this.assignedCategory,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id && other.username == username;
  }

  @override
  int get hashCode => id.hashCode ^ username.hashCode;

  @override
  String toString() {
    return 'UserModel(id: $id, username: $username, role: $role)';
  }
}

// Extension for role checking
extension UserModelExtension on UserModel {
  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager';
  bool get isBouncer => role == 'bouncer';
  bool get isActive => status == 'active';
  
  bool get canCreatePasses => isAdmin || isManager;
  bool get canBulkCreate => isAdmin || isManager;
  bool get canViewAllLogs => isAdmin || isManager;
  bool get canResetPasses => isAdmin || isManager;
  bool get canResetDaily => isAdmin;
  bool get canAccessSettings => isAdmin;
  bool get canBlockPasses => isAdmin;
  
  String get displayRole {
    switch (role) {
      case 'admin':
        return 'Administrator';
      case 'manager':
        return 'Manager';
      case 'bouncer':
        return 'Bouncer';
      default:
        return role.toUpperCase();
    }
  }
}