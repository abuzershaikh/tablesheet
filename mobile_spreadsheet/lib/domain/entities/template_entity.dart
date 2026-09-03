import 'package:flutter/material.dart';

/// Represents a single column definition in a template
class TemplateColumn {
  final String name;
  final String typeId; // matches ColumnTypeEnum: text, number, amount, date, time, checkbox, selectable, image, audio, pdf, phone, link, address, location
  final double width;
  final Map<String, dynamic>? extraConfig; // e.g. selectable options, number format

  const TemplateColumn({
    required this.name,
    required this.typeId,
    this.width = 120.0,
    this.extraConfig,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'typeId': typeId,
    'width': width,
    if (extraConfig != null) 'extraConfig': extraConfig,
  };

  factory TemplateColumn.fromJson(Map<String, dynamic> json) {
    return TemplateColumn(
      name: json['name'] as String,
      typeId: json['typeId'] as String,
      width: (json['width'] as num?)?.toDouble() ?? 120.0,
      extraConfig: json['extraConfig'] as Map<String, dynamic>?,
    );
  }
}

/// A complete sheet template with pre-configured columns and optional sample data
class SheetTemplate {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color iconColor;
  final String categoryId;
  final List<TemplateColumn> columns;
  final Map<String, String>? sampleData; // cell key -> value (e.g. "0,0" -> "John")
  final int frozenRows;
  final int frozenColumns;

  const SheetTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.categoryId,
    required this.columns,
    this.sampleData,
    this.frozenRows = 0,
    this.frozenColumns = 0,
  });

  int get columnCount => columns.length;
}

/// A category that groups related templates together
class TemplateCategory {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;
  final List<SheetTemplate> templates;

  const TemplateCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.gradientColors,
    required this.templates,
  });

  int get templateCount => templates.length;
}
