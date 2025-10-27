class CategoryModel {
  final int id;
  final String name;
  final String colorCode;
  final String? description;
  final String createdAt;
  final String updatedAt;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.colorCode,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as int,
      name: json['name'] as String,
      colorCode: json['color_code'] as String,
      description: json['description'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color_code': colorCode,
      'description': description,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'name': name,
      'color_code': colorCode,
      if (description != null) 'description': description,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'color_code': colorCode,
      'description': description ?? '',
    };
  }

  CategoryModel copyWith({
    int? id,
    String? name,
    String? colorCode,
    String? description,
    String? createdAt,
    String? updatedAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      colorCode: colorCode ?? this.colorCode,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryModel &&
        other.id == id &&
        other.name == name &&
        other.colorCode == colorCode &&
        other.description == description;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        colorCode.hashCode ^
        description.hashCode;
  }

  @override
  String toString() {
    return 'CategoryModel(id: $id, name: $name, colorCode: $colorCode, description: $description)';
  }

  // All Access category removed - isAllAccess property no longer needed
}