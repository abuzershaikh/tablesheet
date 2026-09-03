import 'package:equatable/equatable.dart';

/// Column entity representing a spreadsheet column
class ColumnEntity extends Equatable {
  final String columnId; // UUID
  final String sheetId; // UUID
  final int displayPosition; // 0-based position (0 = column A)
  final String name; // Column name/header (e.g., "A", "Name", "Email")
  final double width; // Width in logical pixels (default: 120.0)
  final ColumnType type; // Column data type
  final bool isHidden; // Whether column is hidden

  const ColumnEntity({
    required this.columnId,
    required this.sheetId,
    required this.displayPosition,
    required this.name,
    this.width = 120.0,
    this.type = ColumnType.text,
    this.isHidden = false,
  });

  /// Get column letter (A, B, C, ..., Z, AA, AB, ...)
  String get columnLetter {
    int position = displayPosition;
    String letter = '';
    
    while (position >= 0) {
      letter = String.fromCharCode(65 + (position % 26)) + letter;
      position = (position ~/ 26) - 1;
    }
    
    return letter;
  }

  /// Get display name (uses name if not empty, otherwise column letter)
  String get displayName => name.isNotEmpty ? name : columnLetter;

  @override
  List<Object?> get props => [
        columnId,
        sheetId,
        displayPosition,
        name,
        width,
        type,
        isHidden,
      ];

  ColumnEntity copyWith({
    String? columnId,
    String? sheetId,
    int? displayPosition,
    String? name,
    double? width,
    ColumnType? type,
    bool? isHidden,
  }) {
    return ColumnEntity(
      columnId: columnId ?? this.columnId,
      sheetId: sheetId ?? this.sheetId,
      displayPosition: displayPosition ?? this.displayPosition,
      name: name ?? this.name,
      width: width ?? this.width,
      type: type ?? this.type,
      isHidden: isHidden ?? this.isHidden,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'columnId': columnId,
      'sheetId': sheetId,
      'displayPosition': displayPosition,
      'name': name,
      'width': width,
      'type': type.name,
      'isHidden': isHidden,
    };
  }

  factory ColumnEntity.fromJson(Map<String, dynamic> json) {
    return ColumnEntity(
      columnId: json['columnId'] as String,
      sheetId: json['sheetId'] as String,
      displayPosition: json['displayPosition'] as int,
      name: json['name'] as String,
      width: (json['width'] as num?)?.toDouble() ?? 120.0,
      type: ColumnType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ColumnType.text,
      ),
      isHidden: json['isHidden'] as bool? ?? false,
    );
  }
}

/// Column data types for validation and formatting
enum ColumnType {
  text,
  number,
  currency,
  percentage,
  date,
  time,
  boolean,
  dropdown,
  pdf,
}
