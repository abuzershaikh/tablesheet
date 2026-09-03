import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../base/column_type.dart';

/// Number column type - for numeric values
class NumberColumnType extends ColumnType {
  final int? decimalPlaces;
  final double? minValue;
  final double? maxValue;
  
  const NumberColumnType({
    this.decimalPlaces = 2,
    this.minValue,
    this.maxValue,
  }) : super(
    id: 'number',
    name: 'Number',
    description: 'Numeric values',
    icon: Icons.numbers,
  );
  
  @override
  bool validate(dynamic value) {
    if (value == null) return true;
    
    double? number;
    if (value is num) {
      number = value.toDouble();
    } else if (value is String) {
      number = double.tryParse(value);
      if (number == null) return false;
    } else {
      return false;
    }
    
    if (minValue != null && number < minValue!) return false;
    if (maxValue != null && number > maxValue!) return false;
    
    return true;
  }
  
  @override
  String format(dynamic value) {
    if (value == null) return '';
    
    final number = value is num ? value.toDouble() : double.tryParse(value.toString());
    if (number == null) return '';
    
    return number.toStringAsFixed(decimalPlaces ?? 2);
  }
  
  @override
  dynamic parse(String input) {
    return double.tryParse(input);
  }
  
  @override
  Widget getInputWidget({
    required dynamic initialValue,
    required ValueChanged<dynamic> onChanged,
  }) {
    return TextField(
      controller: TextEditingController(text: initialValue?.toString() ?? ''),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: 'Number',
        suffixIcon: const Icon(Icons.calculate),
        helperText: minValue != null || maxValue != null
            ? 'Range: ${minValue ?? '∞'} - ${maxValue ?? '∞'}'
            : null,
      ),
      onChanged: (value) => onChanged(double.tryParse(value)),
    );
  }
  
  @override
  dynamic get defaultValue => 0.0;
  
  @override
  Color get iconColor => Colors.green;
}
