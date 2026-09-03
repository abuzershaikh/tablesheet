import 'package:equatable/equatable.dart';
import 'sheet_entity.dart';

/// Spreadsheet entity representing the entire spreadsheet document
class SpreadsheetEntity extends Equatable {
  final String spreadsheetId; // UUID
  final String name; // Spreadsheet name
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SheetEntity> sheets; // List of sheets in this spreadsheet
  final String? thumbnailPath; // Path to thumbnail image (optional)
  final Map<String, String>? transientCellData; // Transient data for imported CSV

  const SpreadsheetEntity({
    required this.spreadsheetId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.sheets = const [],
    this.thumbnailPath,
    this.transientCellData,
  });

  /// Get active/default sheet (first sheet)
  SheetEntity? get activeSheet => sheets.isNotEmpty ? sheets.first : null;

  /// Get sheet count
  int get sheetCount => sheets.length;

  /// Find sheet by ID
  SheetEntity? findSheetById(String sheetId) {
    try {
      return sheets.firstWhere((sheet) => sheet.sheetId == sheetId);
    } catch (e) {
      return null;
    }
  }

  /// Find sheet by name
  SheetEntity? findSheetByName(String name) {
    try {
      return sheets.firstWhere((sheet) => sheet.name == name);
    } catch (e) {
      return null;
    }
  }

  @override
  List<Object?> get props => [
        spreadsheetId,
        name,
        createdAt,
        updatedAt,
        sheets,
        thumbnailPath,
        transientCellData,
      ];

  SpreadsheetEntity copyWith({
    String? spreadsheetId,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<SheetEntity>? sheets,
    String? thumbnailPath,
    Map<String, String>? transientCellData,
  }) {
    return SpreadsheetEntity(
      spreadsheetId: spreadsheetId ?? this.spreadsheetId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sheets: sheets ?? this.sheets,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      transientCellData: transientCellData ?? this.transientCellData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'spreadsheetId': spreadsheetId,
      'name': name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'sheets': sheets.map((sheet) => sheet.toJson()).toList(),
      'thumbnailPath': thumbnailPath,
    };
  }

  factory SpreadsheetEntity.fromJson(Map<String, dynamic> json) {
    return SpreadsheetEntity(
      spreadsheetId: json['spreadsheetId'] as String,
      name: json['name'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
      sheets: (json['sheets'] as List<dynamic>?)
              ?.map((sheet) => SheetEntity.fromJson(sheet as Map<String, dynamic>))
              .toList() ??
          [],
      thumbnailPath: json['thumbnailPath'] as String?,
    );
  }
}
