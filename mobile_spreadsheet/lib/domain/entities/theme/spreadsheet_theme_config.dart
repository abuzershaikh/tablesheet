import 'package:flutter/material.dart';

/// Spreadsheet Theme Configuration Entity
/// Supports Header-only customization or Full Sheet visual theme styling.
class SpreadsheetThemeConfig {
  final String presetId;
  final Color headerBgColor;
  final Color headerTextColor;
  final Color rowHeaderBgColor;
  final Color rowHeaderTextColor;
  final Color gridBgColor;
  final Color borderColor;
  final Color selectionColor;
  final Color accentColor;
  final bool isHeaderOnly;

  const SpreadsheetThemeConfig({
    this.presetId = 'default',
    this.headerBgColor = const Color(0xFFF5F5F5), // Colors.grey[100]
    this.headerTextColor = const Color(0xFF212121), // Colors.black87
    this.rowHeaderBgColor = const Color(0xFFF5F5F5),
    this.rowHeaderTextColor = const Color(0xFF212121),
    this.gridBgColor = const Color(0xFFFFFFFF),
    this.borderColor = const Color(0xFFE0E0E0), // Colors.grey[300]
    this.selectionColor = const Color(0xFFE3F2FD), // Colors.blue[50]
    this.accentColor = const Color(0xFF2196F3), // Colors.blue
    this.isHeaderOnly = false,
  });

  /// Default Excel Style Theme
  static const SpreadsheetThemeConfig defaultTheme = SpreadsheetThemeConfig();

  SpreadsheetThemeConfig copyWith({
    String? presetId,
    Color? headerBgColor,
    Color? headerTextColor,
    Color? rowHeaderBgColor,
    Color? rowHeaderTextColor,
    Color? gridBgColor,
    Color? borderColor,
    Color? selectionColor,
    Color? accentColor,
    bool? isHeaderOnly,
  }) {
    return SpreadsheetThemeConfig(
      presetId: presetId ?? this.presetId,
      headerBgColor: headerBgColor ?? this.headerBgColor,
      headerTextColor: headerTextColor ?? this.headerTextColor,
      rowHeaderBgColor: rowHeaderBgColor ?? this.rowHeaderBgColor,
      rowHeaderTextColor: rowHeaderTextColor ?? this.rowHeaderTextColor,
      gridBgColor: gridBgColor ?? this.gridBgColor,
      borderColor: borderColor ?? this.borderColor,
      selectionColor: selectionColor ?? this.selectionColor,
      accentColor: accentColor ?? this.accentColor,
      isHeaderOnly: isHeaderOnly ?? this.isHeaderOnly,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'presetId': presetId,
      'headerBgColor': headerBgColor.value,
      'headerTextColor': headerTextColor.value,
      'rowHeaderBgColor': rowHeaderBgColor.value,
      'rowHeaderTextColor': rowHeaderTextColor.value,
      'gridBgColor': gridBgColor.value,
      'borderColor': borderColor.value,
      'selectionColor': selectionColor.value,
      'accentColor': accentColor.value,
      'isHeaderOnly': isHeaderOnly,
    };
  }

  factory SpreadsheetThemeConfig.fromJson(Map<String, dynamic> json) {
    return SpreadsheetThemeConfig(
      presetId: json['presetId'] as String? ?? 'default',
      headerBgColor: Color(json['headerBgColor'] as int? ?? 0xFFF5F5F5),
      headerTextColor: Color(json['headerTextColor'] as int? ?? 0xFF212121),
      rowHeaderBgColor: Color(json['rowHeaderBgColor'] as int? ?? 0xFFF5F5F5),
      rowHeaderTextColor: Color(json['rowHeaderTextColor'] as int? ?? 0xFF212121),
      gridBgColor: Color(json['gridBgColor'] as int? ?? 0xFFFFFFFF),
      borderColor: Color(json['borderColor'] as int? ?? 0xFFE0E0E0),
      selectionColor: Color(json['selectionColor'] as int? ?? 0xFFE3F2FD),
      accentColor: Color(json['accentColor'] as int? ?? 0xFF2196F3),
      isHeaderOnly: json['isHeaderOnly'] as bool? ?? false,
    );
  }
}
