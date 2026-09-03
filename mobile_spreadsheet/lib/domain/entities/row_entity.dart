import 'package:equatable/equatable.dart';

/// Row entity representing a spreadsheet row
class RowEntity extends Equatable {
  final String rowId; // UUID
  final String sheetId; // UUID
  final int displayPosition; // 0-based position for display (0 = row 1)
  final double height; // Height in logical pixels (default: 40.0)
  final bool isHidden; // Whether row is hidden

  const RowEntity({
    required this.rowId,
    required this.sheetId,
    required this.displayPosition,
    this.height = 40.0,
    this.isHidden = false,
  });

  /// Get display row number (1-based)
  int get displayNumber => displayPosition + 1;

  @override
  List<Object?> get props => [
        rowId,
        sheetId,
        displayPosition,
        height,
        isHidden,
      ];

  RowEntity copyWith({
    String? rowId,
    String? sheetId,
    int? displayPosition,
    double? height,
    bool? isHidden,
  }) {
    return RowEntity(
      rowId: rowId ?? this.rowId,
      sheetId: sheetId ?? this.sheetId,
      displayPosition: displayPosition ?? this.displayPosition,
      height: height ?? this.height,
      isHidden: isHidden ?? this.isHidden,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rowId': rowId,
      'sheetId': sheetId,
      'displayPosition': displayPosition,
      'height': height,
      'isHidden': isHidden,
    };
  }

  factory RowEntity.fromJson(Map<String, dynamic> json) {
    return RowEntity(
      rowId: json['rowId'] as String,
      sheetId: json['sheetId'] as String,
      displayPosition: json['displayPosition'] as int,
      height: (json['height'] as num?)?.toDouble() ?? 40.0,
      isHidden: json['isHidden'] as bool? ?? false,
    );
  }
}
