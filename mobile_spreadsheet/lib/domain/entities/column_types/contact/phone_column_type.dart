import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../base/column_type.dart';

/// Phone column type - for phone numbers
class PhoneColumnType extends ColumnType {
  final String countryCode;
  
  const PhoneColumnType({
    this.countryCode = '+1',
  }) : super(
    id: 'phone',
    name: 'Phone',
    description: 'Phone numbers',
    icon: Icons.phone,
  );
  
  @override
  bool validate(dynamic value) {
    if (value == null) return true;
    
    final str = value.toString().replaceAll(RegExp(r'[^\d]'), '');
    return str.length >= 10 && str.length <= 15;
  }
  
  @override
  String format(dynamic value) {
    if (value == null) return '';
    
    final str = value.toString().replaceAll(RegExp(r'[^\d+]'), '');
    if (str.length >= 10) {
      // Format as: +1 (555) 123-4567
      final digits = str.replaceAll('+', '');
      if (digits.length == 10) {
        return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
      }
    }
    
    return str;
  }
  
  @override
  dynamic parse(String input) {
    return input.replaceAll(RegExp(r'[^\d+]'), '');
  }
  
  @override
  Widget getInputWidget({
    required dynamic initialValue,
    required ValueChanged<dynamic> onChanged,
  }) {
    return TextField(
      controller: TextEditingController(text: initialValue?.toString() ?? ''),
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-\(\)\+]')),
      ],
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: 'Phone Number',
        prefixText: countryCode.isNotEmpty ? '$countryCode ' : null,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.call),
              onPressed: () {
                // TODO: Make call
              },
            ),
            IconButton(
              icon: const Icon(Icons.message),
              onPressed: () {
                // TODO: Send SMS
              },
            ),
          ],
        ),
      ),
      onChanged: onChanged,
    );
  }
  
  @override
  dynamic get defaultValue => '';
  
  @override
  Color get iconColor => Colors.cyan;
}
