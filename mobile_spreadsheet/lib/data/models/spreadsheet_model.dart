/// Data model for spreadsheet - used for database storage
class SpreadsheetModel {
  final String id;
  final String name;
  final int createdAt;
  final int updatedAt;
  final String? thumbnail;

  const SpreadsheetModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.thumbnail,
  });

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'thumbnail': thumbnail,
    };
  }

  /// Create from database map
  factory SpreadsheetModel.fromMap(Map<String, dynamic> map) {
    return SpreadsheetModel(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      thumbnail: map['thumbnail'] as String?,
    );
  }
}