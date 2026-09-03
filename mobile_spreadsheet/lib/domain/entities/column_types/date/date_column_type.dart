import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../base/column_type.dart';

/// Date column type - for date values
class DateColumnType extends ColumnType {
  final String dateFormat;
  
  const DateColumnType({
    this.dateFormat = 'yyyy-MM-dd',
  }) : super(
    id: 'date',
    name: 'Date',
    description: 'Date values',
    icon: Icons.calendar_today,
  );
  
  @override
  bool validate(dynamic value) {
    if (value == null) return true;
    if (value is DateTime) return true;
    if (value is String) {
      try {
        DateFormat(dateFormat).parse(value);
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }
  
  @override
  String format(dynamic value) {
    if (value == null) return '';
    
    DateTime? date;
    if (value is DateTime) {
      date = value;
    } else if (value is String) {
      try {
        date = DateFormat(dateFormat).parse(value);
      } catch (_) {
        return value;
      }
    }
    
    if (date == null) return '';
    return DateFormat(dateFormat).format(date);
  }
  
  @override
  dynamic parse(String input) {
    try {
      return DateFormat(dateFormat).parse(input);
    } catch (_) {
      return null;
    }
  }
  
  @override
  Widget getInputWidget({
    required dynamic initialValue,
    required ValueChanged<dynamic> onChanged,
  }) {
    DateTime? currentDate;
    if (initialValue is DateTime) {
      currentDate = initialValue;
    } else if (initialValue is String) {
      try {
        currentDate = DateFormat(dateFormat).parse(initialValue);
      } catch (_) {}
    }
    
    return InkWell(
      onTap: () async {
        final BuildContext? context = null; // Need to pass context
        if (context != null) {
          final picked = await showDatePicker(
            context: context,
            initialDate: currentDate ?? DateTime.now(),
            firstDate: DateTime(1900),
            lastDate: DateTime(2100),
          );
          if (picked != null) {
            onChanged(picked);
          }
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Date',
          suffixIcon: Icon(Icons.calendar_today),
        ),
        child: Text(
          currentDate != null ? DateFormat(dateFormat).format(currentDate) : 'Select date',
        ),
      ),
    );
  }
  
  @override
  dynamic get defaultValue => DateTime.now();
  
  @override
  Color get iconColor => Colors.purple;
}
