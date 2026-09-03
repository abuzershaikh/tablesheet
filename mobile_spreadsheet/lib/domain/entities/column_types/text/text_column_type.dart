import 'package:flutter/material.dart';
import '../base/column_type.dart';

/// Text column type - for general text input
class TextColumnType extends ColumnType {
  final int? maxLength;
  final bool multiline;
  
  const TextColumnType({
    this.maxLength,
    this.multiline = false,
  }) : super(
    id: 'text',
    name: 'Text',
    description: 'Plain text content',
    icon: Icons.text_fields,
  );
  
  @override
  bool validate(dynamic value) {
    if (value == null) return true;
    if (value is! String) return false;
    if (maxLength != null && value.length > maxLength!) return false;
    return true;
  }
  
  @override
  String format(dynamic value) {
    return value?.toString() ?? '';
  }
  
  @override
  dynamic parse(String input) {
    return input;
  }
  
  @override
  Widget getInputWidget({
    required dynamic initialValue,
    required ValueChanged<dynamic> onChanged,
  }) {
    return TextField(
      controller: TextEditingController(text: initialValue?.toString() ?? ''),
      maxLength: maxLength,
      maxLines: multiline ? null : 1,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: 'Text',
      ),
      onChanged: onChanged,
    );
  }
  
  @override
  dynamic get defaultValue => '';
  
  @override
  Color get iconColor => Colors.blue;
}
