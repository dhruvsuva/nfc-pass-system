class PassModel {
  final int id;
  final String uid;
  final String passId;
  final String passType;
  final String category;
  final int peopleAllowed;
  final String status;
  final int createdBy;
  final String createdAt;
  final String updatedAt;
  final String? createdByUsername;
  final int maxUses;
  final int usedCount;
  final int? remainingUses;
  final String? lastScanAt;
  final int? lastScanBy;
  final String? lastUsedAt;
  final int? lastUsedBy;
  final String? lastUsedByUsername;

  const PassModel({
    required this.id,
    required this.uid,
    required this.passId,
    required this.passType,
    required this.category,
    required this.peopleAllowed,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.createdByUsername,
    required this.maxUses,
    required this.usedCount,
    this.remainingUses,
    this.lastScanAt,
    this.lastScanBy,
    this.lastUsedAt,
    this.lastUsedBy,
    this.lastUsedByUsername});

  factory PassModel.fromJson(Map<String, dynamic> json) {
    return PassModel(
      id: json['id'] as int,
      uid: json['uid'] as String,
      passId: json['pass_id'] as String,
      passType: json['pass_type'] as String,
      category: json['category'] as String,
      peopleAllowed: json['people_allowed'] as int,
      status: json['status'] as String,
      createdBy: json['created_by'] as int,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      createdByUsername: json['created_by_username'] as String?,
      maxUses: json['max_uses'] as int? ?? 1,
      usedCount: json['used_count'] as int? ?? 0,
      remainingUses: json['remaining_uses'] is String 
          ? int.tryParse(json['remaining_uses']) 
          : json['remaining_uses'] as int?,
      lastScanAt: json['last_scan_at'] as String?,
      lastScanBy: json['last_scan_by'] is String 
          ? int.tryParse(json['last_scan_by']) 
          : json['last_scan_by'] as int?,
      lastUsedAt: json['last_used_at'] as String?,
      lastUsedBy: json['last_used_by'] is String 
          ? int.tryParse(json['last_used_by']) 
          : json['last_used_by'] as int?,
      lastUsedByUsername: json['last_used_by_username'] as String?);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'pass_id': passId,
      'pass_type': passType,
      'category': category,
      'people_allowed': peopleAllowed,
      'status': status,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'created_by_username': createdByUsername,
      'max_uses': maxUses,
      'used_count': usedCount,
      'remaining_uses': remainingUses,
      'last_scan_at': lastScanAt,
      'last_scan_by': lastScanBy,
      'last_used_at': lastUsedAt,
      'last_used_by': lastUsedBy,
      'last_used_by_username': lastUsedByUsername};
  }

  PassModel copyWith({
    int? id,
    String? uid,
    String? passId,
    String? passType,
    String? category,
    int? peopleAllowed,
    String? status,
    int? createdBy,
    String? createdAt,
    String? updatedAt,
    String? createdByUsername,
    int? maxUses,
    int? usedCount,
    int? remainingUses,
    String? lastScanAt,
    int? lastScanBy}) {
    return PassModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      passId: passId ?? this.passId,
      passType: passType ?? this.passType,
      category: category ?? this.category,
      peopleAllowed: peopleAllowed ?? this.peopleAllowed,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdByUsername: createdByUsername ?? this.createdByUsername,
      maxUses: maxUses ?? this.maxUses,
      usedCount: usedCount ?? this.usedCount,
      remainingUses: remainingUses ?? this.remainingUses,
      lastScanAt: lastScanAt ?? this.lastScanAt,
      lastScanBy: lastScanBy ?? this.lastScanBy);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PassModel && other.id == id && other.uid == uid;
  }

  @override
  int get hashCode => id.hashCode ^ uid.hashCode;

  @override
  String toString() {
    return 'PassModel(id: $id, uid: $uid, status: $status)';
  }
}

// Extension for status checking
extension PassModelExtension on PassModel {
  bool get isActive => status == 'active';
  bool get isBlocked => status == 'blocked';
  bool get isUsed => status == 'used';
  bool get isExpired => status == 'expired';
  bool get isDeleted => status == 'deleted';
  
  bool get isValid {
    return isActive;
  }
  
  String get displayStatus {
    switch (status) {
      case 'active':
        return isValid ? 'Active' : 'Expired';
      case 'blocked':
        return 'Blocked';
      case 'used':
        return 'Used';
      case 'expired':
        return 'Expired';
      case 'deleted':
        return 'Deleted';
      default:
        return status.toUpperCase();
    }
  }
}