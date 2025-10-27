import '../network/api_service.dart';
import '../config/app_config.dart';
import '../../models/log_model.dart';

class LogsService {
  static Future<SystemLogsResponse> getSystemLogs({
    int page = 1,
    int limit = 20,
    String? actionType,
    String? result,
    String? role,
    String? search,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final uri =
          '/api/logs/system?${Uri(queryParameters: {'page': page.toString(), 'limit': limit.toString(), if (actionType != null && actionType != 'All') 'action_type': actionType, if (result != null && result != 'All') 'result': result, if (role != null && role != 'All') 'role': role, if (search != null && search.isNotEmpty) 'search': search, if (startDate != null) 'start_date': startDate.toIso8601String(), if (endDate != null) 'end_date': endDate.toIso8601String()}).query}';

      final response = await ApiService.get(uri);
      return SystemLogsResponse.fromJson(response);
    } catch (e) {
      throw Exception('Error fetching system logs: $e');
    }
  }

  static Future<DailyLogsResponse> getDailyLogs({
    int page = 1,
    int limit = 20,
    String? actionType,
    String? result,
    String? role,
    String? search,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final uri =
          '/api/logs/daily?${Uri(queryParameters: {'page': page.toString(), 'limit': limit.toString(), if (actionType != null && actionType != 'All') 'action_type': actionType, if (result != null && result != 'All') 'result': result, if (role != null && role != 'All') 'role': role, if (search != null && search.isNotEmpty) 'search': search, if (startDate != null) 'start_date': startDate.toIso8601String(), if (endDate != null) 'end_date': endDate.toIso8601String()}).query}';

      final response = await ApiService.get(uri);
      return DailyLogsResponse.fromJson(response);
    } catch (e) {
      throw Exception('Error fetching daily logs: $e');
    }
  }

  static Future<CombinedLogsResponse> getCombinedLogs({
    int page = 1,
    int limit = 20,
    String? actionType,
    String? result,
    String? role,
    String? search,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final uri =
          '/api/logs/combined?${Uri(queryParameters: {'page': page.toString(), 'limit': limit.toString(), if (actionType != null && actionType != 'All') 'action_type': actionType, if (result != null && result != 'All') 'result': result, if (role != null && role != 'All') 'role': role, if (search != null && search.isNotEmpty) 'search': search, if (startDate != null) 'start_date': startDate.toIso8601String(), if (endDate != null) 'end_date': endDate.toIso8601String()}).query}';

      final response = await ApiService.get(uri);
      return CombinedLogsResponse.fromJson(response);
    } catch (e) {
      throw Exception('Error fetching combined logs: $e');
    }
  }
}
