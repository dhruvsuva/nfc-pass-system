class BulkJobModel {
  final String bulkId;
  final int total;
  final int processed;
  final int successCount;
  final int errorCount;
  final String status;
  final List<String> errors;
  final String createdAt;
  final String? completedAt;

  const BulkJobModel({
    required this.bulkId,
    required this.total,
    required this.processed,
    required this.successCount,
    required this.errorCount,
    required this.status,
    required this.errors,
    required this.createdAt,
    this.completedAt,
  });

  factory BulkJobModel.fromJson(Map<String, dynamic> json) {
    return BulkJobModel(
      bulkId: json['bulk_id'] as String,
      total: json['total'] as int,
      processed: json['processed'] as int,
      successCount: json['success_count'] as int,
      errorCount: json['error_count'] as int,
      status: json['status'] as String,
      errors: List<String>.from(json['errors'] as List? ?? []),
      createdAt: json['created_at'] as String,
      completedAt: json['completed_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bulk_id': bulkId,
      'total': total,
      'processed': processed,
      'success_count': successCount,
      'error_count': errorCount,
      'status': status,
      'errors': errors,
      'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
    };
  }

  BulkJobModel copyWith({
    String? bulkId,
    int? total,
    int? processed,
    int? successCount,
    int? errorCount,
    String? status,
    List<String>? errors,
    String? createdAt,
    String? completedAt,
  }) {
    return BulkJobModel(
      bulkId: bulkId ?? this.bulkId,
      total: total ?? this.total,
      processed: processed ?? this.processed,
      successCount: successCount ?? this.successCount,
      errorCount: errorCount ?? this.errorCount,
      status: status ?? this.status,
      errors: errors ?? this.errors,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BulkJobModel && other.bulkId == bulkId;
  }

  @override
  int get hashCode => bulkId.hashCode;

  @override
  String toString() {
    return 'BulkJobModel(bulkId: $bulkId, status: $status, processed: $processed/$total)';
  }
}

// Extension for status checking
extension BulkJobModelExtension on BulkJobModel {
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isCancelled => status == 'cancelled';
  
  double get progressPercentage {
    if (total == 0) return 0.0;
    return (processed / total) * 100;
  }
  
  int get remainingCount => total - processed;
  
  bool get hasErrors => errors.isNotEmpty;
  
  String get displayStatus {
    switch (status) {
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.toUpperCase();
    }
  }
  
  String get progressText {
    return '$processed / $total';
  }
  
  String get summaryText {
    if (isCompleted) {
      return 'Completed: $successCount successful, $errorCount failed';
    } else if (isInProgress) {
      return 'Processing: $processed of $total';
    } else {
      return displayStatus;
    }
  }
  
  Duration? get duration {
    if (completedAt == null) return null;
    
    final start = DateTime.tryParse(createdAt);
    final end = DateTime.tryParse(completedAt!);
    
    if (start == null || end == null) return null;
    
    return end.difference(start);
  }
}