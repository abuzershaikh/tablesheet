/// Data model for sheet - used for database storage
class SheetModel {
  final String id;
  final String spreadsheetId;
  final String name;
  final int position;
  final int createdAt;
  final int updatedAt;

  const SheetModel({
    required this.id,
    required this.spreadsheetId,
    required this.name,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'spreadsheet_id': spreadsheetId,
      'name': name,
      'position': position,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  /// Create from database map
  factory SheetModel.fromMap(Map<String, dynamic> map) {
    return SheetModel(
      id: map['id'] as String,
      spreadsheetId: map['spreadsheet_id'] as String,
      name: map['name'] as String,
      position: map['position'] as int,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }
}