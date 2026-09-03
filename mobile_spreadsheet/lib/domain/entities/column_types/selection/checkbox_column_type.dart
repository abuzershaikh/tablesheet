import 'package:flutter/material.dart';
import '../base/column_type.dart';

/// Checkbox column type - for boolean/yes-no values
class CheckboxColumnType extends ColumnType {
  final String trueLabel;
  final String falseLabel;
  
  const CheckboxColumnType({
    this.trueLabel = 'Yes',
    this.falseLabel = 'No',
  }) : super(
    id: 'checkbox',
    name: 'Checkbox',
    description: 'Yes/No or True/False values',
    icon: Icons.check_box,
  );
  
  @override
  bool validate(dynamic value) {
    if (value == null) return true;
    return value is bool;
  }
  
  @override
  String format(dynamic value) {
    if (value == null) return falseLabel;
    if (value is bool) return value ? trueLabel : falseLabel;
    return falseLabel;
  }
  
  @override
  dynamic parse(String input) {
    final lower = input.toLowerCase();
    return lower == 'true' || 
           lower == 'yes' || 
           lower == '1' || 
           lower == trueLabel.toLowerCase();
  }
  
  @override
  Widget getInputWidget({
    required dynamic initialValue,
    required ValueChanged<dynamic> onChanged,
  }) {
    return CheckboxListTile(
      title: Text(initialValue == true ? trueLabel : falseLabel),
      value: initialValue == true,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
  
  @override
  dynamic get defaultValue => false;
  
  @override
  Color get iconColor => Colors.teal;
}
