import '../../domain/entities/cell_entity.dart';

/// Data model for cell - used for database storage
class CellModel {
  final String id;
  final String sheetId;
  final String rowId;
  final String columnId;
  final String? value;
  final String? formula;
  final String type;
  final int formatBold;
  final int formatItalic;
  final int formatUnderline;
  final String? formatTextColor;
  final String? formatBackgroundColor;
  final String? formatAlignment;
  final double? formatFontSize;
  final int updatedAt;

  const CellModel({
    required this.id,
    required this.sheetId,
    required this.rowId,
    required this.columnId,
    this.value,
    this.formula,
    required this.type,
    this.formatBold = 0,
    this.formatItalic = 0,
    this.formatUnderline = 0,
    this.formatTextColor,
    this.formatBackgroundColor,
    this.formatAlignment,
    this.formatFontSize,
    required this.updatedAt,
  });

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sheet_id': sheetId,
      'row_id': rowId,
      'column_id': columnId,
      'value': value,
      'formula': formula,
      'type': type,
      'format_bold': formatBold,
      'format_italic': formatItalic,
      'format_underline': formatUnderline,
      'format_text_color': formatTextColor,
      'format_background_color': formatBackgroundColor,
      'format_alignment': formatAlignment,
      'format_font_size': formatFontSize,
      'updated_at': updatedAt,
    };
  }

  /// Create from database map
  factory CellModel.fromMap(Map<String, dynamic> map) {
    return CellModel(
      id: map['id'] as String,
      sheetId: map['sheet_id'] as String,
      rowId: map['row_id'] as String,
      columnId: map['column_id'] as String,
      value: map['value'] as String?,
      formula: map['formula'] as String?,
      type: map['type'] as String,
      formatBold: map['format_bold'] as int? ?? 0,
      formatItalic: map['format_italic'] as int? ?? 0,
      formatUnderline: map['format_underline'] as int? ?? 0,
      formatTextColor: map['format_text_color'] as String?,
      formatBackgroundColor: map['format_background_color'] as String?,
      formatAlignment: map['format_alignment'] as String?,
      formatFontSize: (map['format_font_size'] as num?)?.toDouble(),
      updatedAt: map['updated_at'] as int,
    );
  }
}
