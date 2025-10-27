import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/category_model.dart';
import '../core/config/app_config.dart';
import '../core/storage/hive_service.dart';
import '../core/network/http_interceptor.dart';

class CategoriesService {
  static const String _baseUrl = AppConfig.baseUrl;

  /// Get all categories
  static Future<List<CategoryModel>> getCategories() async {
    try {
      final token = await HiveService.getAccessTokenAsync();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await HttpInterceptor.get(
        Uri.parse('$_baseUrl/api/categories'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> categoriesJson = data['data'] ?? [];
        
        return categoriesJson
            .map((json) => CategoryModel.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching categories: $e');
    }
  }

  /// Create a new category
  static Future<CategoryModel> createCategory(CategoryModel category) async {
    try {
      final token = await HiveService.getAccessTokenAsync();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await HttpInterceptor.post(
        Uri.parse('$_baseUrl/api/categories'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(category.toCreateJson()),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        return CategoryModel.fromJson(data['data']);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to create category');
      }
    } catch (e) {
      throw Exception('Error creating category: $e');
    }
  }

  /// Update an existing category
  static Future<CategoryModel> updateCategory(int id, CategoryModel category) async {
    try {
      final token = await HiveService.getAccessTokenAsync();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await HttpInterceptor.put(
        Uri.parse('$_baseUrl/api/categories/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(category.toUpdateJson()),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return CategoryModel.fromJson(data['data']);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update category');
      }
    } catch (e) {
      throw Exception('Error updating category: $e');
    }
  }

  /// Delete a category
  static Future<void> deleteCategory(int id) async {
    try {
      final token = await HiveService.getAccessTokenAsync();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await HttpInterceptor.delete(
        Uri.parse('$_baseUrl/api/categories/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to delete category');
      }
    } catch (e) {
      throw Exception('Error deleting category: $e');
    }
  }

  /// Get category by ID
  static Future<CategoryModel> getCategoryById(int id) async {
    try {
      final token = await HiveService.getAccessTokenAsync();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await HttpInterceptor.get(
        Uri.parse('$_baseUrl/api/categories/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return CategoryModel.fromJson(data['data']);
      } else {
        throw Exception('Failed to load category: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching category: $e');
    }
  }
}