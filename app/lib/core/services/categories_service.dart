import 'package:flutter/foundation.dart';
import '../network/api_service.dart';
import '../../models/category_model.dart';

class CategoriesServiceException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  const CategoriesServiceException({
    required this.message,
    this.code,
    this.statusCode,
  });

  @override
  String toString() => 'CategoriesServiceException: $message';
}

class CategoriesService {
  static const String _cacheKey = 'categories_cache';
  static List<CategoryModel>? _cachedCategories;
  static DateTime? _lastFetchTime;
  static const Duration _cacheExpiry = Duration(minutes: 30);

  /// Get all categories with caching
  static Future<List<CategoryModel>> getCategories({bool forceRefresh = false}) async {
    try {
      // Check cache first
      if (!forceRefresh && _cachedCategories != null && _lastFetchTime != null) {
        final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);
        if (timeSinceLastFetch < _cacheExpiry) {
          debugPrint('Returning cached categories');
          return _cachedCategories!;
        }
      }

      debugPrint('Fetching categories from API');
      final response = await ApiService.get('/api/categories');

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> categoriesData = response['data'];
        final categories = categoriesData
            .map((json) => CategoryModel.fromJson(json))
            .toList();

        // Sort categories alphabetically
        categories.sort((a, b) => a.name.compareTo(b.name));

        // Update cache
        _cachedCategories = categories;
        _lastFetchTime = DateTime.now();

        debugPrint('Fetched ${categories.length} categories');
        return categories;
      } else {
        throw CategoriesServiceException(
          message: response['message'] ?? 'Failed to fetch categories',
          code: 'API_ERROR',
        );
      }
    } on ApiException catch (e) {
      debugPrint('API error fetching categories: $e');
      throw CategoriesServiceException(
        message: e.message,
        code: e.data?['code'] ?? 'API_ERROR',
        statusCode: e.statusCode,
      );
    } catch (e) {
      debugPrint('Unexpected error fetching categories: $e');
      throw CategoriesServiceException(
        message: 'Failed to fetch categories: $e',
        code: 'UNKNOWN_ERROR',
      );
    }
  }



  /// Create a new category (Admin only)
  static Future<CategoryModel> createCategory({
    required String name,
    required String colorCode,
    String? description,
  }) async {
    try {
      final data = {
        'name': name,
        'color_code': colorCode,
        if (description != null) 'description': description,
      };

      debugPrint('Creating category: $data');
      final response = await ApiService.post('/api/categories', data);

      if (response['success'] == true && response['data'] != null) {
        final category = CategoryModel.fromJson(response['data']);
        
        // Clear cache to force refresh
        _cachedCategories = null;
        _lastFetchTime = null;
        
        debugPrint('Category created: ${category.name}');
        return category;
      } else {
        throw CategoriesServiceException(
          message: response['message'] ?? 'Failed to create category',
          code: 'API_ERROR',
        );
      }
    } on ApiException catch (e) {
      debugPrint('API error creating category: $e');
      throw CategoriesServiceException(
        message: e.message,
        code: e.data?['code'] ?? 'API_ERROR',
        statusCode: e.statusCode,
      );
    } catch (e) {
      debugPrint('Unexpected error creating category: $e');
      throw CategoriesServiceException(
        message: 'Failed to create category: $e',
        code: 'UNKNOWN_ERROR',
      );
    }
  }

  /// Update an existing category (Admin only)
  static Future<CategoryModel> updateCategory(int id, CategoryModel category) async {
    try {
      final data = category.toUpdateJson();

      debugPrint('Updating category $id: $data');
      final response = await ApiService.patch('/api/categories/$id', data);

      if (response['success'] == true && response['data'] != null) {
        final updatedCategory = CategoryModel.fromJson(response['data']);
        
        // Clear cache to force refresh
        _cachedCategories = null;
        _lastFetchTime = null;
        
        debugPrint('Category updated: ${updatedCategory.name}');
        return updatedCategory;
      } else {
        throw CategoriesServiceException(
          message: response['message'] ?? 'Failed to update category',
          code: 'API_ERROR',
        );
      }
    } on ApiException catch (e) {
      debugPrint('API error updating category: $e');
      throw CategoriesServiceException(
        message: e.message,
        code: e.data?['code'] ?? 'API_ERROR',
        statusCode: e.statusCode,
      );
    } catch (e) {
      debugPrint('Unexpected error updating category: $e');
      throw CategoriesServiceException(
        message: 'Failed to update category: $e',
        code: 'UNKNOWN_ERROR',
      );
    }
  }

  /// Delete a category (Admin only)
  static Future<void> deleteCategory(int id) async {
    try {
      debugPrint('Deleting category $id');
      final response = await ApiService.delete('/api/categories/$id');

      if (response['success'] == true) {
        // Clear cache to force refresh
        _cachedCategories = null;
        _lastFetchTime = null;
        
        debugPrint('Category deleted successfully');
      } else {
        throw CategoriesServiceException(
          message: response['message'] ?? 'Failed to delete category',
          code: 'API_ERROR',
        );
      }
    } on ApiException catch (e) {
      debugPrint('API error deleting category: $e');
      throw CategoriesServiceException(
        message: e.message,
        code: e.data?['code'] ?? 'API_ERROR',
        statusCode: e.statusCode,
      );
    } catch (e) {
      debugPrint('Unexpected error deleting category: $e');
      throw CategoriesServiceException(
        message: 'Failed to delete category: $e',
        code: 'UNKNOWN_ERROR',
      );
    }
  }

  /// Clear categories cache
  static void clearCache() {
    _cachedCategories = null;
    _lastFetchTime = null;
    debugPrint('Categories cache cleared');
  }

  /// Get cached categories (if available)
  static List<CategoryModel>? getCachedCategories() {
    return _cachedCategories;
  }

  /// Check if cache is valid
  static bool isCacheValid() {
    if (_cachedCategories == null || _lastFetchTime == null) return false;
    final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);
    return timeSinceLastFetch < _cacheExpiry;
  }
}