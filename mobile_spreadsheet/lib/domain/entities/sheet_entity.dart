import 'package:equatable/equatable.dart';
import 'excel_image_entity.dart';

/// Sheet entity representing a single worksheet in a spreadsheet
class SheetEntity extends Equatable {
  final String sheetId; // UUID
  final String spreadsheetId; // UUID of parent spreadsheet
  final String name; // Sheet name (e.g., "Sheet1", "Sales Data")
  final int position; // Position in tab order (0-based)
  final DateTime createdAt;
  final DateTime updatedAt;
  final SheetMetadata? metadata;
  final List<ExcelImageEntity> images;

  const SheetEntity({
    required this.sheetId,
    required this.spreadsheetId,
    required this.name,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
    this.images = const [],
  });

  @override
  List<Object?> get props => [
        sheetId,
        spreadsheetId,
        name,
        position,
        createdAt,
        updatedAt,
        metadata,
        images,
      ];

  SheetEntity copyWith({
    String? sheetId,
    String? spreadsheetId,
    String? name,
    int? position,
    DateTime? createdAt,
    DateTime? updatedAt,
    SheetMetadata? metadata,
    List<ExcelImageEntity>? images,
  }) {
    return SheetEntity(
      sheetId: sheetId ?? this.sheetId,
      spreadsheetId: spreadsheetId ?? this.spreadsheetId,
      name: name ?? this.name,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
      images: images ?? this.images,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sheetId': sheetId,
      'spreadsheetId': spreadsheetId,
      'name': name,
      'position': position,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'metadata': metadata?.toJson(),
      'images': images.map((e) => e.toJson()).toList(),
    };
  }

  factory SheetEntity.fromJson(Map<String, dynamic> json) {
    return SheetEntity(
      sheetId: json['sheetId'] as String,
      spreadsheetId: json['spreadsheetId'] as String,
      name: json['name'] as String,
      position: json['position'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
      metadata: json['metadata'] != null
          ? SheetMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : null,
      images: json['images'] != null
          ? (json['images'] as List).map((e) => ExcelImageEntity.fromJson(e as Map<String, dynamic>)).toList()
          : [],
    );
  }
}

/// Configuration for the generic summary footer
class SheetFooterConfig extends Equatable {
  final bool enabled;
  final String type; // 'sum', 'avg', 'count', 'min', 'max'
  final int? targetColumnIndex; 
  final String label;
  final String? backgroundColor;
  final String? textColor;

  const SheetFooterConfig({
    this.enabled = false,
    this.type = 'sum',
    this.targetColumnIndex,
    this.label = 'Total',
    this.backgroundColor,
    this.textColor,
  });

  @override
  List<Object?> get props => [
        enabled,
        type,
        targetColumnIndex,
        label,
        backgroundColor,
        textColor,
      ];

  SheetFooterConfig copyWith({
    bool? enabled,
    String? type,
    int? targetColumnIndex,
    String? label,
    String? backgroundColor,
    String? textColor,
  }) {
    return SheetFooterConfig(
      enabled: enabled ?? this.enabled,
      type: type ?? this.type,
      targetColumnIndex: targetColumnIndex ?? this.targetColumnIndex,
      label: label ?? this.label,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'type': type,
      'targetColumnIndex': targetColumnIndex,
      'label': label,
      'backgroundColor': backgroundColor,
      'textColor': textColor,
    };
  }

  factory SheetFooterConfig.fromJson(Map<String, dynamic> json) {
    return SheetFooterConfig(
      enabled: json['enabled'] as bool? ?? false,
      type: json['type'] as String? ?? 'sum',
      targetColumnIndex: json['targetColumnIndex'] as int?,
      label: json['label'] as String? ?? 'Total',
      backgroundColor: json['backgroundColor'] as String?,
      textColor: json['textColor'] as String?,
    );
  }
}

/// Sheet metadata for additional information
class SheetMetadata extends Equatable {
  final int rowCount; // Total number of rows
  final int columnCount; // Total number of columns
  final String? gridColor; // Grid line color
  final bool showGridLines; // Whether to show grid lines
  final bool isProtected; // Whether sheet is protected from edits
  final double zoomLevel; // Zoom level (0.5 to 2.0)
  final SheetFooterConfig? footerConfig; // Footer configuration

  const SheetMetadata({
    this.rowCount = 1000,
    this.columnCount = 26,
    this.gridColor,
    this.showGridLines = true,
    this.isProtected = false,
    this.zoomLevel = 1.0,
    this.footerConfig,
  });

  @override
  List<Object?> get props => [
        rowCount,
        columnCount,
        gridColor,
        showGridLines,
        isProtected,
        zoomLevel,
        footerConfig,
      ];

  SheetMetadata copyWith({
    int? rowCount,
    int? columnCount,
    String? gridColor,
    bool? showGridLines,
    bool? isProtected,
    double? zoomLevel,
    SheetFooterConfig? footerConfig,
  }) {
    return SheetMetadata(
      rowCount: rowCount ?? this.rowCount,
      columnCount: columnCount ?? this.columnCount,
      gridColor: gridColor ?? this.gridColor,
      showGridLines: showGridLines ?? this.showGridLines,
      isProtected: isProtected ?? this.isProtected,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      footerConfig: footerConfig ?? this.footerConfig,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rowCount': rowCount,
      'columnCount': columnCount,
      'gridColor': gridColor,
      'showGridLines': showGridLines,
      'isProtected': isProtected,
      'zoomLevel': zoomLevel,
      'footerConfig': footerConfig?.toJson(),
    };
  }

  factory SheetMetadata.fromJson(Map<String, dynamic> json) {
    return SheetMetadata(
      rowCount: json['rowCount'] as int? ?? 1000,
      columnCount: json['columnCount'] as int? ?? 26,
      gridColor: json['gridColor'] as String?,
      showGridLines: json['showGridLines'] as bool? ?? true,
      isProtected: json['isProtected'] as bool? ?? false,
      zoomLevel: (json['zoomLevel'] as num?)?.toDouble() ?? 1.0,
      footerConfig: json['footerConfig'] != null
          ? SheetFooterConfig.fromJson(json['footerConfig'] as Map<String, dynamic>)
          : null,
    );
  }
}
