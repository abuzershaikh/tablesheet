import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../base/column_type.dart';

/// Amount column type - for currency/money values
class AmountColumnType extends ColumnType {
  final String currency;
  final String currencySymbol;
  final int decimalPlaces;
  
  const AmountColumnType({
    this.currency = 'USD',
    this.currencySymbol = '\$',
    this.decimalPlaces = 2,
  }) : super(
    id: 'amount',
    name: 'Amount',
    description: 'Currency/money values',
    icon: Icons.attach_money,
  );
  
  @override
  bool validate(dynamic value) {
    if (value == null) return true;
    
    if (value is num) return true;
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleaned) != null;
    }
    
    return false;
  }
  
  @override
  String format(dynamic value) {
    if (value == null) return '';
    
    double? number;
    if (value is num) {
      number = value.toDouble();
    } else if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
      number = double.tryParse(cleaned);
    }
    
    if (number == null) return '';
    
    return '$currencySymbol${number.toStringAsFixed(decimalPlaces)}';
  }
  
  @override
  dynamic parse(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleaned);
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
        labelText: 'Amount',
        prefixText: currencySymbol,
        suffixText: currency,
        suffixIcon: const Icon(Icons.account_balance_wallet),
      ),
      onChanged: (value) => onChanged(double.tryParse(value)),
    );
  }
  
  @override
  dynamic get defaultValue => 0.0;
  
  @override
  Color get iconColor => Colors.amber;
}
