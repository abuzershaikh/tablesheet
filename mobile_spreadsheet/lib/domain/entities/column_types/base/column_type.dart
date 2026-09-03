import 'package:flutter/material.dart';

/// Base abstract class for all column types
abstract class ColumnType {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  
  const ColumnType({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });
  
  /// Validate cell value for this column type
  bool validate(dynamic value);
  
  /// Format value for display
  String format(dynamic value);
  
  /// Parse input string to typed value
  dynamic parse(String input);
  
  /// Get input widget for this column type
  Widget getInputWidget({
    required dynamic initialValue,
    required ValueChanged<dynamic> onChanged,
  });
  
  /// Get default value for new cells
  dynamic get defaultValue;
  
  /// Can this column be sorted
  bool get isSortable => true;
  
  /// Can this column be filtered
  bool get isFilterable => true;
  
  /// Get icon color
  Color get iconColor;
}

/// Enum for all available column types
enum ColumnTypeEnum {
  text,
  number,
  amount,
  date,
  time,
  checkbox,
  selectable,
  image,
  audio,
  pdf,
  phone,
  link,
  address,
  location,
}
