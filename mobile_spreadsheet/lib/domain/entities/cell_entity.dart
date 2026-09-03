import 'package:equatable/equatable.dart';

/// Cell entity representing a single spreadsheet cell
class CellEntity extends Equatable {
  final String cellId;  // UUID
  final String sheetId;  // UUID
  final String rowId;  // UUID
  final String columnId;  // UUID
  final String? value;
  final String? formula;
  final CellDataType dataType;
  final CellFormat? format;
  final DateTime createdAt;
  final DateTime modifiedAt;

  const CellEntity({
    required this.cellId,
    required this.sheetId,
    required this.rowId,
    required this.columnId,
    this.value,
    this.formula,
    required this.dataType,
    this.format,
    required this.createdAt,
    required this.modifiedAt,
  });

  /// Cell address in format: {sheetId}:{rowId}:{columnId}
  String get address => '$sheetId:$rowId:$columnId';

  /// Display value (formula result or raw value)
  String get displayValue => value ?? '';

  /// Check if cell contains formula
  bool get hasFormula => formula != null && formula!.isNotEmpty;

  /// Check if cell is empty
  bool get isEmpty => (value == null || value!.isEmpty) && !hasFormula;

  @override
  List<Object?> get props => [
        cellId,
        sheetId,
        rowId,
        columnId,
        value,
        formula,
        dataType,
        format,
        createdAt,
        modifiedAt,
      ];

  CellEntity copyWith({
    String? cellId,
    String? sheetId,
    String? rowId,
    String? columnId,
    String? value,
    String? formula,
    CellDataType? dataType,
    CellFormat? format,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) {
    return CellEntity(
      cellId: cellId ?? this.cellId,
      sheetId: sheetId ?? this.sheetId,
      rowId: rowId ?? this.rowId,
      columnId: columnId ?? this.columnId,
      value: value ?? this.value,
      formula: formula ?? this.formula,
      dataType: dataType ?? this.dataType,
      format: format ?? this.format,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cellId': cellId,
      'sheetId': sheetId,
      'rowId': rowId,
      'columnId': columnId,
      'value': value,
      'formula': formula,
      'dataType': dataType.name,
      'format': format?.toJson(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'modifiedAt': modifiedAt.millisecondsSinceEpoch,
    };
  }

  factory CellEntity.fromJson(Map<String, dynamic> json) {
    return CellEntity(
      cellId: json['cellId'] as String,
      sheetId: json['sheetId'] as String,
      rowId: json['rowId'] as String,
      columnId: json['columnId'] as String,
      value: json['value'] as String?,
      formula: json['formula'] as String?,
      dataType: CellDataType.values.firstWhere(
        (e) => e.name == json['dataType'],
        orElse: () => CellDataType.text,
      ),
      format: json['format'] != null
          ? CellFormat.fromJson(json['format'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(json['modifiedAt'] as int),
    );
  }
}

/// Cell data types
enum CellDataType {
  text,
  number,
  date,
  time,
  boolean,
  formula,
  error,
}

/// Cell formatting information
class CellFormat extends Equatable {
  final bool bold;
  final bool italic;
  final bool underline;
  final String? backgroundColor;
  final String? textColor;
  final TextAlignment horizontalAlignment;
  final VerticalAlignment verticalAlignment;
  final bool textWrap;
  final String? numberFormat;
  final double? fontSize;
  final String? fontFamily;

  const CellFormat({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.backgroundColor,
    this.textColor,
    this.horizontalAlignment = TextAlignment.left,
    this.verticalAlignment = VerticalAlignment.middle,
    this.textWrap = false,
    this.numberFormat,
    this.fontSize,
    this.fontFamily,
  });

  @override
  List<Object?> get props => [
        bold,
        italic,
        underline,
        backgroundColor,
        textColor,
        horizontalAlignment,
        verticalAlignment,
        textWrap,
        numberFormat,
        fontSize,
        fontFamily,
      ];

  CellFormat copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    String? backgroundColor,
    String? textColor,
    TextAlignment? horizontalAlignment,
    VerticalAlignment? verticalAlignment,
    bool? textWrap,
    String? numberFormat,
    double? fontSize,
    String? fontFamily,
  }) {
    return CellFormat(
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      horizontalAlignment: horizontalAlignment ?? this.horizontalAlignment,
      verticalAlignment: verticalAlignment ?? this.verticalAlignment,
      textWrap: textWrap ?? this.textWrap,
      numberFormat: numberFormat ?? this.numberFormat,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bold': bold,
      'italic': italic,
      'underline': underline,
      'backgroundColor': backgroundColor,
      'textColor': textColor,
      'horizontalAlignment': horizontalAlignment.name,
      'verticalAlignment': verticalAlignment.name,
      'textWrap': textWrap,
      'numberFormat': numberFormat,
      'fontSize': fontSize,
      'fontFamily': fontFamily,
    };
  }

  factory CellFormat.fromJson(Map<String, dynamic> json) {
    return CellFormat(
      bold: json['bold'] as bool? ?? false,
      italic: json['italic'] as bool? ?? false,
      underline: json['underline'] as bool? ?? false,
      backgroundColor: json['backgroundColor'] as String?,
      textColor: json['textColor'] as String?,
      horizontalAlignment: TextAlignment.values.firstWhere(
        (e) => e.name == json['horizontalAlignment'],
        orElse: () => TextAlignment.left,
      ),
      verticalAlignment: VerticalAlignment.values.firstWhere(
        (e) => e.name == json['verticalAlignment'],
        orElse: () => VerticalAlignment.middle,
      ),
      textWrap: json['textWrap'] as bool? ?? false,
      numberFormat: json['numberFormat'] as String?,
      fontSize: (json['fontSize'] as num?)?.toDouble(),
      fontFamily: json['fontFamily'] as String?,
    );
  }
}

/// Text horizontal alignment
enum TextAlignment {
  left,
  center,
  right,
}

/// Text vertical alignment
enum VerticalAlignment {
  top,
  middle,
  bottom,
}
