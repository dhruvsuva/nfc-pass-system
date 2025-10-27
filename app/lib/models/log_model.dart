class SystemLog {
  final int id;
  final String action;
  final DateTime createdAt;
  final String? username;
  final String? role;
  final String status;
  final String? details;
  final String? ipAddress;
  final String? userAgent;

  SystemLog({
    required this.id,
    required this.action,
    required this.createdAt,
    this.username,
    this.role,
    required this.status,
    this.details,
    this.ipAddress,
    this.userAgent,
  });

  factory SystemLog.fromJson(Map<String, dynamic> json) {
    return SystemLog(
      id: json['id'] ?? 0,
      action: json['action'] ?? '',
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      username: json['username'],
      role: json['role'],
      status: json['status'] ?? '',
      details: json['details'],
      ipAddress: json['ip_address'],
      userAgent: json['user_agent'],
    );
  }
}

class DailyLog {
  final int id;
  final String actionType;
  final DateTime createdAt;
  final DateTime? scannedAt;
  final int? scannedBy;
  final String result;
  final int? remainingUses;
  final int? consumedCount;
  final String? category;
  final String? passType;
  final int? userId;
  final String? role;
  final String? passId;
  final String? uid;
  final String? details;
  final String? errorMessage;
  final String? ipAddress;
  final String? userAgent;

  DailyLog({
    required this.id,
    required this.actionType,
    required this.createdAt,
    this.scannedAt,
    this.scannedBy,
    required this.result,
    this.remainingUses,
    this.consumedCount,
    this.category,
    this.passType,
    this.userId,
    this.role,
    this.passId,
    this.uid,
    this.details,
    this.errorMessage,
    this.ipAddress,
    this.userAgent,
  });

  factory DailyLog.fromJson(Map<String, dynamic> json) {
    return DailyLog(
      id: json['id'] ?? 0,
      actionType: json['action_type'] ?? '',
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      scannedAt: json['scanned_at'] != null
          ? DateTime.parse(json['scanned_at'])
          : null,
      scannedBy: json['scanned_by'],
      result: json['result'] ?? '',
      remainingUses: json['remaining_uses'],
      consumedCount: json['consumed_count'],
      category: json['category'],
      passType: json['pass_type'],
      userId: json['user_id'],
      role: json['role'],
      passId: json['pass_id'],
      uid: json['uid'],
      details: json['details'],
      errorMessage: json['error_message'],
      ipAddress: json['ip_address'],
      userAgent: json['user_agent'],
    );
  }
}

class SystemLogsResponse {
  final List<SystemLog> logs;
  final PaginationInfo pagination;

  SystemLogsResponse({required this.logs, required this.pagination});

  factory SystemLogsResponse.fromJson(Map<String, dynamic> json) {
    return SystemLogsResponse(
      logs: (json['logs'] as List<dynamic>? ?? [])
          .map((log) => SystemLog.fromJson(log))
          .toList(),
      pagination: PaginationInfo.fromJson(json['pagination'] ?? {}),
    );
  }

  bool get hasNextPage => pagination.hasNextPage;
}

class DailyLogsResponse {
  final List<DailyLog> logs;
  final PaginationInfo pagination;

  DailyLogsResponse({required this.logs, required this.pagination});

  factory DailyLogsResponse.fromJson(Map<String, dynamic> json) {
    return DailyLogsResponse(
      logs: (json['logs'] as List<dynamic>? ?? [])
          .map((log) => DailyLog.fromJson(log))
          .toList(),
      pagination: PaginationInfo.fromJson(json['pagination'] ?? {}),
    );
  }

  bool get hasNextPage => pagination.hasNextPage;
}

class CombinedLogsResponse {
  final List<SystemLog> systemLogs;
  final List<DailyLog> dailyLogs;
  final PaginationInfo pagination;

  CombinedLogsResponse({
    required this.systemLogs,
    required this.dailyLogs,
    required this.pagination,
  });

  factory CombinedLogsResponse.fromJson(Map<String, dynamic> json) {
    return CombinedLogsResponse(
      systemLogs: (json['system_logs'] as List<dynamic>? ?? [])
          .map((log) => SystemLog.fromJson(log))
          .toList(),
      dailyLogs: (json['daily_logs'] as List<dynamic>? ?? [])
          .map((log) => DailyLog.fromJson(log))
          .toList(),
      pagination: PaginationInfo.fromJson(json['pagination'] ?? {}),
    );
  }

  bool get hasNextPage => pagination.hasNextPage;
}

class PaginationInfo {
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;

  PaginationInfo({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 20,
      total: json['total'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
      hasNextPage: json['hasNextPage'] ?? false,
      hasPrevPage: json['hasPrevPage'] ?? false,
    );
  }
}
