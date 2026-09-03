import 'package:flutter/material.dart';
import '../base/column_type.dart';

/// Selectable column type - dropdown with predefined options
class SelectableColumnType extends ColumnType {
  final List<String> options;
  final bool allowMultiple;
  
  const SelectableColumnType({
    required this.options,
    this.allowMultiple = false,
  }) : super(
    id: 'selectable',
    name: 'Selectable',
    description: 'Dropdown selection from options',
    icon: Icons.arrow_drop_down_circle,
  );
  
  @override
  bool validate(dynamic value) {
    if (value == null) return true;
    
    if (allowMultiple) {
      if (value is! List) return false;
      return (value as List).every((item) => options.contains(item.toString()));
    } else {
      return options.contains(value.toString());
    }
  }
  
  @override
  String format(dynamic value) {
    if (value == null) return '';
    
    if (allowMultiple && value is List) {
      return value.join(', ');
    }
    
    return value.toString();
  }
  
  @override
  dynamic parse(String input) {
    if (allowMultiple) {
      return input.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return input;
  }
  
  @override
  Widget getInputWidget({
    required dynamic initialValue,
    required ValueChanged<dynamic> onChanged,
  }) {
    if (allowMultiple) {
      return Wrap(
        spacing: 8,
        children: options.map((option) {
          final isSelected = initialValue is List && initialValue.contains(option);
          return FilterChip(
            label: Text(option),
            selected: isSelected,
            onSelected: (selected) {
              List<String> current = initialValue is List 
                  ? List<String>.from(initialValue) 
                  : [];
              if (selected) {
                current.add(option);
              } else {
                current.remove(option);
              }
              onChanged(current);
            },
          );
        }).toList(),
      );
    }
    
    return DropdownButtonFormField<String>(
      value: initialValue?.toString(),
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: 'Select option',
      ),
      items: options.map((option) {
        return DropdownMenuItem(
          value: option,
          child: Text(option),
        );
      }).toList(),
      onChanged: (value) => onChanged(value),
    );
  }
  
  @override
  dynamic get defaultValue => options.isNotEmpty ? options.first : '';
  
  @override
  Color get iconColor => Colors.orange;
}
