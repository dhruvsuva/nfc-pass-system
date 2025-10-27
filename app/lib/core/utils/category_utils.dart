class CategoryUtils {
  // Standard category names - use these for all comparisons
  static const List<String> standardCategories = [
    'Platinum A',
    'Platinum B',
    'Diamond',
    'Gold A',
    'Gold B',
    'Silver',
  ];

  /// Normalize category name for comparison
  /// Removes extra spaces, converts to lowercase for comparison
  static String normalizeCategory(String? category) {
    if (category == null || category.isEmpty) return '';
    return category.trim().toLowerCase();
  }

  /// Check if two categories match (case-insensitive, trimmed)
  static bool categoriesMatch(String? category1, String? category2) {
    if (category1 == null || category2 == null) return false;
    return normalizeCategory(category1) == normalizeCategory(category2);
  }

  /// Check if bouncer can verify a pass based on category
  static bool canBouncerVerifyPass(
    String? bouncerCategory,
    String? passCategory,
  ) {
    if (bouncerCategory == null || passCategory == null) return false;

    // Regular bouncer - check if categories match
    return categoriesMatch(bouncerCategory, passCategory);
  }

  /// Get category display name (properly formatted)
  static String getDisplayName(String? category) {
    if (category == null || category.isEmpty) return 'No Category';

    // Find the standard category that matches
    final normalized = normalizeCategory(category);
    for (final standard in standardCategories) {
      if (normalizeCategory(standard) == normalized) {
        return standard;
      }
    }

    // If no match found, return the original trimmed
    return category.trim();
  }

  /// Validate if category is valid
  static bool isValidCategory(String? category) {
    if (category == null || category.isEmpty) return false;
    return standardCategories.any(
      (standard) => normalizeCategory(standard) == normalizeCategory(category),
    );
  }
}
