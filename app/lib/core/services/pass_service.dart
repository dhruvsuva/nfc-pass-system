import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../network/api_service.dart';
import '../config/app_config.dart';
import '../../models/pass_model.dart';

class PassService {
  static const String _createEndpoint = AppConfig.createPassEndpoint;
  static const String _verifyEndpoint = AppConfig.verifyEndpoint;
  static const String _passListEndpoint = '/api/pass';
  static const String _passDetailsEndpoint = '/api/pass';
  static const String _passSearchEndpoint = '/api/pass/search';

  /// Create a new pass
  static Future<PassModel> createPass({
    required String uid,
    required String passType,
    required String category,
    required int peopleAllowed,
    int? maxUses}) async {
    try {
      final passData = {
        'uid': uid.trim(),
        'pass_type': passType,
        'category': category.trim(),
        'people_allowed': peopleAllowed,
        if (maxUses != null) 'max_uses': maxUses};

      debugPrint('Creating pass with data: $passData');

      final response = await ApiService.post(_createEndpoint, passData);

      if (response['pass'] != null) {
        final pass = PassModel.fromJson(response['pass']);
        
        debugPrint('Pass created successfully: ${pass.uid}');
        return pass;
      } else {
        throw PassServiceException(
          message: response['message'] ?? 'Failed to create pass',
          code: response['code'] ?? 'CREATE_ERROR');
      }
    } on ApiException catch (e) {
      debugPrint('API error creating pass: $e');
      
      // Handle specific error codes
      if (e.data != null && e.data!['code'] == 'DUPLICATE_UID') {
        final existingPass = e.data!['existing_pass'];
        throw PassServiceException(
          message: e.data!['message'] ?? 'This card is already registered',
          code: 'DUPLICATE_UID',
          isDuplicate: true,
          existingPassId: e.data!['existingPassId']?.toString() ?? existingPass?['pass_id']);
      }
      
      throw PassServiceException(
        message: e.message,
        code: e.data?['code'] ?? 'API_ERROR',
        statusCode: e.statusCode);
    } catch (e) {
      debugPrint('Unexpected error creating pass: $e');
      throw PassServiceException(
        message: 'Failed to create pass: $e',
        code: 'UNKNOWN_ERROR');
    }
  }

  /// Verify a pass
  static Future<PassVerificationResult> verifyPass({
    required String uid,
    required String gateId,
    required int scannedBy,
    String? deviceLocalId}) async {
    try {
      final verifyData = {
        'uid': uid.trim(),
        'gate_id': gateId,
        'scanned_by': scannedBy,
        if (deviceLocalId != null) 'device_local_id': deviceLocalId};

      debugPrint('Verifying pass with data: $verifyData');

      final response = await ApiService.post(_verifyEndpoint, verifyData);

      return PassVerificationResult.fromJson(response);
    } on ApiException catch (e) {
      debugPrint('API error verifying pass: $e');
      
      throw PassServiceException(
        message: e.message,
        code: e.data?['code'] ?? 'API_ERROR',
        statusCode: e.statusCode);
    } catch (e) {
      debugPrint('Unexpected error verifying pass: $e');
      throw PassServiceException(
        message: 'Failed to verify pass: $e',
        code: 'UNKNOWN_ERROR');
    }
  }

  /// Get list of passes with filters and pagination
  static Future<PassListResponse> getPassList({
    int page = 1,
    int limit = 20,
    String? status,
    String? passType,
    String? category,
    int? createdBy,
    String? search}) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (status != null) 'status': status,
        if (passType != null) 'pass_type': passType,
        if (category != null) 'category': category,
        if (createdBy != null) 'created_by': createdBy.toString(),
        if (search != null && search.isNotEmpty) 'search': search};

      debugPrint('Getting pass list with params: $queryParams');

      final response = await ApiService.get(
        _passListEndpoint,
        queryParams: queryParams);

      return PassListResponse.fromJson(response);
    } on ApiException catch (e) {
      debugPrint('API error getting pass list: $e');
      
      throw PassServiceException(
        message: e.message,
        code: e.data?['code'] ?? 'API_ERROR',
        statusCode: e.statusCode);
    } catch (e) {
      debugPrint('Unexpected error getting pass list: $e');
      throw PassServiceException(
        message: 'Failed to get pass list: $e',
        code: 'UNKNOWN_ERROR');
    }
  }

  /// Get pass details by ID
  static Future<PassModel> getPassDetails(int passId) async {
    try {
      debugPrint('Getting pass details for ID: $passId');

      final response = await ApiService.get('$_passDetailsEndpoint/$passId');

      if (response['pass'] != null) {
        return PassModel.fromJson(response['pass']);
      } else {
        throw PassServiceException(
          message: response['message'] ?? 'Pass not found',
          code: response['code'] ?? 'PASS_NOT_FOUND');
      }
    } on ApiException catch (e) {
      debugPrint('API error getting pass details: $e');
      
      throw PassServiceException(
        message: e.message,
        code: e.data?['code'] ?? 'API_ERROR',
        statusCode: e.statusCode);
    } catch (e) {
      debugPrint('Unexpected error getting pass details: $e');
      throw PassServiceException(
        message: 'Failed to get pass details: $e',
        code: 'UNKNOWN_ERROR');
    }
  }

  /// Search pass by UID
  static Future<PassModel?> searchPassByUID(String uid) async {
    try {
      debugPrint('Searching pass by UID: $uid');

      final response = await ApiService.get(
        _passSearchEndpoint,
        queryParams: {'uid': uid.trim()});

      if (response['pass'] != null) {
        return PassModel.fromJson(response['pass']);
      } else {
        return null; // Pass not found
      }
    } on ApiException catch (e) {
      debugPrint('API error searching pass: $e');
      
      if (e.statusCode == 404) {
        return null; // Pass not found
      }
      
      throw PassServiceException(
        message: e.message,
        code: e.data?['code'] ?? 'API_ERROR',
        statusCode: e.statusCode);
    } catch (e) {
      debugPrint('Unexpected error searching pass: $e');
      throw PassServiceException(
        message: 'Failed to search pass: $e',
        code: 'UNKNOWN_ERROR');
    }
  }

  /// Get pass details by UID (read-only, doesn't consume the pass)
  static Future<PassDetailsResponse?> getPassDetailsByUID(String uid) async {
    try {
      debugPrint('Getting pass details by UID: $uid');

      final response = await ApiService.get('/api/pass/uid/${uid.trim()}');

      if (response['pass'] != null) {
        return PassDetailsResponse.fromJson(response);
      }
      
      return null;
    } on ApiException catch (e) {
      debugPrint('API error getting pass details by UID: $e');
      debugPrint('Error message: ${e.message}');
      debugPrint('Error data: ${e.data}');
      debugPrint('Error status code: ${e.statusCode}');
      
      if (e.statusCode == 404) {
        return null; // Pass not found
      }
      
      throw PassServiceException(
        message: e.message,
        code: e.data?['code'] ?? 'API_ERROR',
        statusCode: e.statusCode);
    } catch (e) {
      debugPrint('Unexpected error getting pass details by UID: $e');
      throw PassServiceException(
        message: 'Failed to get pass details: $e',
        code: 'UNKNOWN_ERROR');
    }
  }

  /// Check if UID already exists (for duplicate prevention)
  static Future<bool> checkUIDExists(String uid) async {
    try {
      final pass = await searchPassByUID(uid);
      return pass != null;
    } catch (e) {
      debugPrint('Error checking UID existence: $e');
      return false; // Assume doesn't exist if we can't check
    }
  }
  
  /// Delete a pass
  static Future<void> deletePass(int passId) async {
    try {
      debugPrint('Deleting pass with ID: $passId');
      
      await ApiService.delete('/api/pass/$passId');
      
      debugPrint('Pass deleted successfully');
    } on ApiException catch (e) {
      debugPrint('API error deleting pass: $e');
      
      throw PassServiceException(
        message: e.message,
        code: e.data?['code'] ?? 'API_ERROR',
        statusCode: e.statusCode);
    } catch (e) {
      debugPrint('Unexpected error deleting pass: $e');
      throw PassServiceException(
        message: 'Failed to delete pass: $e',
        code: 'UNKNOWN_ERROR');
    }
  }
  
  /// Block a pass
  static Future<void> blockPass(int passId) async {
    try {
      debugPrint('Blocking pass with ID: $passId');
      
      await ApiService.patch('/api/pass/$passId/block', {});
      
      debugPrint('Pass blocked successfully');
    } on ApiException catch (e) {
      debugPrint('API error blocking pass: $e');
      
      throw PassServiceException(
        message: e.message,
        code: e.data?['code'] ?? 'API_ERROR',
        statusCode: e.statusCode);
    } catch (e) {
      debugPrint('Unexpected error blocking pass: $e');
      throw PassServiceException(
        message: 'Failed to block pass: $e',
        code: 'UNKNOWN_ERROR');
    }
  }
  
  /// Unblock a pass
  static Future<void> unblockPass(int passId) async {
    try {
      debugPrint('Unblocking pass with ID: $passId');
      
      await ApiService.patch('/api/pass/$passId/unblock', {});
      
      debugPrint('Pass unblocked successfully');
    } on ApiException catch (e) {
      debugPrint('API error unblocking pass: $e');
      
      throw PassServiceException(
        message: e.message,
        code: e.data?['code'] ?? 'API_ERROR',
        statusCode: e.statusCode);
    } catch (e) {
      debugPrint('Unexpected error unblocking pass: $e');
      throw PassServiceException(
        message: 'Failed to unblock pass: $e',
        code: 'UNKNOWN_ERROR');
    }
  }
  
  /// Consume prompt for multi-use passes
  static Future<PassVerificationResult> consumePrompt({
    required String promptToken,
    required int consumeCount,
    required String gateId,
    required int scannedBy}) async {
    try {
      final consumeData = {
        'prompt_token': promptToken,
        'consume_count': consumeCount,
        'gate_id': gateId,
        'scanned_by': scannedBy};

      debugPrint('Consuming prompt with data: $consumeData');

      final response = await ApiService.post('/api/pass/consume-prompt', consumeData);

      return PassVerificationResult.fromJson(response);
    } on ApiException catch (e) {
      debugPrint('API error consuming prompt: $e');
      
      throw PassServiceException(
        message: e.message,
        code: e.data?['code'] ?? 'API_ERROR',
        statusCode: e.statusCode);
    } catch (e) {
      debugPrint('Unexpected error consuming prompt: $e');
      throw PassServiceException(
        message: 'Failed to consume prompt: $e',
        code: 'UNKNOWN_ERROR');
    }
  }
  
  /// Create bulk passes via NFC streaming
  static Future<Map<String, dynamic>> createBulkPassesNFC({
    required List<String> uids,
    required String passType,
    required String category,
    required int peopleAllowed,
    int? maxUses}) async {
    try {
      // Generate unique scanId for this bulk creation session
      const uuid = Uuid();
      final scanId = uuid.v4();
      
      final bulkData = {
        'uids': uids,
        'pass_type': passType,
        'category': category,
        'people_allowed': peopleAllowed,
        'scan_id': scanId,
        if (maxUses != null) 'max_uses': maxUses};

      debugPrint('Creating bulk passes with data: $bulkData');

      final response = await ApiService.post('/api/pass/create-bulk', bulkData);

      return {
        'total': response['total'] ?? 0,
        'created': response['created'] ?? 0,
        'duplicates': response['duplicates'] ?? 0,
        'errors': response['errors'] ?? [],
        'successful_uids': response['successful_uids'] ?? [],
        'duplicate_uids': response['duplicate_uids'] ?? []};
    } on ApiException catch (e) {
      debugPrint('API error creating bulk passes: $e');
      
      throw PassServiceException(
        message: e.message,
        code: e.data?['code'] ?? 'API_ERROR',
        statusCode: e.statusCode);
    } catch (e) {
      debugPrint('Unexpected error creating bulk passes: $e');
      throw PassServiceException(
        message: 'Failed to create bulk passes: $e',
        code: 'UNKNOWN_ERROR');
    }
  }

  /// Reset a pass with offline support
  static Future<PassResetResult> resetPass({
    required String uid,
    required int resetBy,
    String? reason}) async {
    try {
      debugPrint('Resetting pass: $uid by user $resetBy');

      // First, search for the pass by UID to get the pass ID
      final searchResponse = await ApiService.get('/api/pass/search?uid=${uid.trim()}');
      
      if (searchResponse['pass'] == null) {
        throw PassServiceException(
          message: 'Pass not found with UID: $uid',
          code: 'PASS_NOT_FOUND');
      }
      
      final passData = searchResponse['pass'];
      final passId = passData['id'];
      
      debugPrint('Found pass ID: $passId for UID: $uid');

      final resetData = {
        if (reason != null && reason.isNotEmpty) 'reason': reason
      };

      final response = await ApiService.patch('/api/pass/$passId/reset', resetData);

      final pass = response['pass'] != null ? PassModel.fromJson(response['pass']) : null;
      debugPrint('✅ Pass reset successful: ${response['message']}');
      return PassResetResult(
         success: true,
         message: response['message'] ?? 'Pass reset successfully',
         pass: pass);
      
    } on ApiException catch (e) {
      debugPrint('API error resetting pass: $e');
      
      // Handle specific API errors
      if (e.statusCode == 404) {
        throw PassServiceException(
          message: 'Pass not found',
          code: 'PASS_NOT_FOUND',
          statusCode: e.statusCode);
      } else if (e.statusCode == 400) {
        throw PassServiceException(
          message: e.data?['error'] ?? 'Invalid operation',
          code: e.data?['code'] ?? 'INVALID_OPERATION',
          statusCode: e.statusCode);
      }
      
      throw PassServiceException(
        message: e.message,
        code: e.data?['code'] ?? 'API_ERROR',
        statusCode: e.statusCode);
    } catch (e) {
      if (e is PassServiceException) {
        rethrow;
      }
      
      debugPrint('Unexpected error resetting pass: $e');
      throw PassServiceException(
        message: 'Failed to reset pass: $e',
        code: 'UNKNOWN_ERROR');
    }
  }

  /// Confirm session multi-use
  static Future<PassVerificationResult> confirmSessionMultiUse({
    required String uid,
    required String promptToken,
    required int selectedCount}) async {
    try {
      final confirmData = {
        'uid': uid.trim(),
        'prompt_token': promptToken,
        'selected_count': selectedCount};

      debugPrint('Confirming session multi-use with data: $confirmData');

      final response = await ApiService.post('/api/pass/confirm-multi-use', confirmData);

      return PassVerificationResult.fromJson(response);
    } on ApiException catch (e) {
      debugPrint('API error confirming session multi-use: $e');
      
      throw PassServiceException(
        message: e.message,
        code: e.data?['code'] ?? 'API_ERROR',
        statusCode: e.statusCode);
    } catch (e) {
      debugPrint('Unexpected error confirming session multi-use: $e');
      throw PassServiceException(
        message: 'Failed to confirm session multi-use: $e',
        code: 'UNKNOWN_ERROR');
    }
  }
}

/// Result class for pass reset operations
class PassResetResult {
  final bool success;
  final String message;
  final PassModel? pass;

  PassResetResult({
    required this.success,
    required this.message,
    this.pass});
}

/// Custom exception for pass service errors
class PassServiceException implements Exception {
  final String message;
  final String code;
  final int? statusCode;
  final bool isDuplicate;
  final String? existingPassId;

  const PassServiceException({
    required this.message,
    required this.code,
    this.statusCode,
    this.isDuplicate = false,
    this.existingPassId});

  @override
  String toString() {
    return 'PassServiceException: $message (Code: $code)';
  }

  /// Check if error is due to network connectivity
  bool get isNetworkError => statusCode == 0;

  /// Check if error is client-side (4xx)
  bool get isClientError => statusCode != null && statusCode! >= 400 && statusCode! < 500;

  /// Check if error is server-side (5xx)
  bool get isServerError => statusCode != null && statusCode! >= 500;
}

/// Pass verification result model
class PassVerificationResult {
  final bool success;
  final String status;
  final String message;
  final PassModel? pass;
  final Map<String, dynamic>? additionalData;
  final String? promptToken;
  final int? remainingUses;
  final String? lastUsedAt;

  const PassVerificationResult({
    required this.success,
    required this.status,
    required this.message,
    this.pass,
    this.additionalData,
    this.promptToken,
    this.remainingUses,
    this.lastUsedAt});

  PassVerificationResult copyWith({
    bool? success,
    String? status,
    String? message,
    PassModel? pass,
    Map<String, dynamic>? additionalData,
    String? promptToken,
    int? remainingUses,
    String? lastUsedAt,
  }) {
    return PassVerificationResult(
      success: success ?? this.success,
      status: status ?? this.status,
      message: message ?? this.message,
      pass: pass ?? this.pass,
      additionalData: additionalData ?? this.additionalData,
      promptToken: promptToken ?? this.promptToken,
      remainingUses: remainingUses ?? this.remainingUses,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  factory PassVerificationResult.fromJson(Map<String, dynamic> json) {
    // Extract pass info from the response
    PassModel? passModel;
    String? lastUsedAt;
    
    if (json['pass_info'] != null) {
      // Create PassModel from pass_info
      final passInfo = json['pass_info'] as Map<String, dynamic>;
      passModel = PassModel.fromJson({
        'id': 0, // Not provided in verification response
        'uid': json['uid'] ?? '',
        'pass_id': passInfo['pass_id'] ?? '',
        'pass_type': passInfo['pass_type'] ?? '',
        'category': passInfo['category'] ?? '',
        'people_allowed': passInfo['people_allowed'] ?? 1,
        'status': 'active', // Assume active for verification
        'created_by': 0, // Not provided
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'max_uses': passInfo['max_uses'] is String 
            ? int.tryParse(passInfo['max_uses']) ?? 1 
            : passInfo['max_uses'] ?? 1,
        'used_count': passInfo['used_count'] is String 
            ? int.tryParse(passInfo['used_count']) ?? 0 
            : passInfo['used_count'] ?? 0,
        'remaining_uses': passInfo['remaining_uses'],
        'last_scan_at': passInfo['last_scan_at'],
        'last_used_at': passInfo['last_used_at']});
      lastUsedAt = passInfo['last_used_at'];
    } else if (json['pass'] != null) {
      // Fallback to existing pass structure
      passModel = PassModel.fromJson(json['pass']);
      lastUsedAt = passModel.lastUsedAt;
    }
    
    return PassVerificationResult(
      success: json['success'] ?? false,
      status: json['status'] ?? 'unknown',
      message: json['message'] ?? '',
      pass: passModel,
      additionalData: json,
      promptToken: json['prompt_token'],
      remainingUses: json['remaining_uses'] is String 
          ? int.tryParse(json['remaining_uses']) 
          : json['remaining_uses'] as int?,
      lastUsedAt: lastUsedAt);
  }

  /// Check if pass is valid
  bool get isValid => success && status == 'valid';

  /// Check if pass is used/blocked
  bool get isUsedOrBlocked => status == 'used' || status == 'blocked';

  /// Check if pass is expired
  bool get isExpired => status == 'expired';

  /// Check if pass is not found
  bool get isNotFound => status == 'not_found';
  
  /// Check if this requires multi-use prompt
  bool get requiresMultiUsePrompt => status == 'prompt_multi_use';
}

/// Pass list response model
class PassListResponse {
  final List<PassModel> passes;
  final int totalCount;
  final int currentPage;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;
  final Map<String, dynamic>? filters;

  const PassListResponse({
    required this.passes,
    required this.totalCount,
    required this.currentPage,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
    this.filters});

  factory PassListResponse.fromJson(Map<String, dynamic> json) {
    final passList = json['passes'] as List? ?? [];
    final pagination = json['pagination'] as Map<String, dynamic>? ?? {};

    return PassListResponse(
      passes: passList.map((p) => PassModel.fromJson(p)).toList(),
      totalCount: pagination['total'] ?? 0,
      currentPage: pagination['page'] ?? 1,
      totalPages: pagination['totalPages'] ?? 1,
      hasNextPage: pagination['hasNextPage'] ?? false,
      hasPrevPage: pagination['hasPrevPage'] ?? false,
      filters: json['filters']);
  }
}

/// Pass details response model
class PassDetailsResponse {
  final PassModel pass;
  final List<Map<String, dynamic>>? usageHistory;
  final Map<String, dynamic>? statistics;
  final Map<String, dynamic>? additionalInfo;

  const PassDetailsResponse({
    required this.pass,
    this.usageHistory,
    this.statistics,
    this.additionalInfo});

  factory PassDetailsResponse.fromJson(Map<String, dynamic> json) {
    return PassDetailsResponse(
      pass: PassModel.fromJson(json['pass']),
      usageHistory: json['usage_history'] != null 
          ? List<Map<String, dynamic>>.from(json['usage_history'])
          : null,
      statistics: json['statistics'],
      additionalInfo: json['additional_info']);
  }
}