/// Data model for column - used for database storage
class ColumnModel {
  final String id;
  final String sheetId;
  final int displayPosition;
  final String name;
  final double width;
  final String type;
  final int isHidden;

  const ColumnModel({
    required this.id,
    required this.sheetId,
    required this.displayPosition,
    required this.name,
    this.width = 120.0,
    this.type = 'text',
    this.isHidden = 0,
  });

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sheet_id': sheetId,
      'display_position': displayPosition,
      'name': name,
      'width': width,
      'type': type,
      'is_hidden': isHidden,
    };
  }

  /// Create from database map
  factory ColumnModel.fromMap(Map<String, dynamic> map) {
    return ColumnModel(
      id: map['id'] as String,
      sheetId: map['sheet_id'] as String,
      displayPosition: map['display_position'] as int,
      name: map['name'] as String,
      width: (map['width'] as num?)?.toDouble() ?? 120.0,
      type: map['type'] as String? ?? 'text',
      isHidden: map['is_hidden'] as int? ?? 0,
    );
  }
}