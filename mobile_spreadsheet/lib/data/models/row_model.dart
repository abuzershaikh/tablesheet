/// Data model for row - used for database storage
class RowModel {
  final String id;
  final String sheetId;
  final int displayPosition;
  final double height;
  final int isHidden;

  const RowModel({
    required this.id,
    required this.sheetId,
    required this.displayPosition,
    this.height = 40.0,
    this.isHidden = 0,
  });

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sheet_id': sheetId,
      'display_position': displayPosition,
      'height': height,
      'is_hidden': isHidden,
    };
  }

  /// Create from database map
  factory RowModel.fromMap(Map<String, dynamic> map) {
    return RowModel(
      id: map['id'] as String,
      sheetId: map['sheet_id'] as String,
      displayPosition: map['display_position'] as int,
      height: (map['height'] as num?)?.toDouble() ?? 40.0,
      isHidden: map['is_hidden'] as int? ?? 0,
    );
  }
}