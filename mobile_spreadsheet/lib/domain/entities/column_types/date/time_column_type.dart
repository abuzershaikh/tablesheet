import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../base/column_type.dart';

/// Time column type - for time values
class TimeColumnType extends ColumnType {
  final String timeFormat;
  final bool use24Hour;
  
  const TimeColumnType({
    this.timeFormat = 'HH:mm',
    this.use24Hour = true,
  }) : super(
    id: 'time',
    name: 'Time',
    description: 'Time values',
    icon: Icons.access_time,
  );
  
  @override
  bool validate(dynamic value) {
    if (value == null) return true;
    if (value is TimeOfDay) return true;
    if (value is String) {
      try {
        DateFormat(timeFormat).parse(value);
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
    
    if (value is TimeOfDay) {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, value.hour, value.minute);
      return DateFormat(timeFormat).format(dt);
    }
    
    return value.toString();
  }
  
  @override
  dynamic parse(String input) {
    try {
      final dt = DateFormat(timeFormat).parse(input);
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    } catch (_) {
      return null;
    }
  }
  
  @override
  Widget getInputWidget({
    required dynamic initialValue,
    required ValueChanged<dynamic> onChanged,
  }) {
    TimeOfDay? currentTime;
    if (initialValue is TimeOfDay) {
      currentTime = initialValue;
    }
    
    return InkWell(
      onTap: () async {
        final BuildContext? context = null; // Need to pass context
        if (context != null) {
          final picked = await showTimePicker(
            context: context,
            initialTime: currentTime ?? TimeOfDay.now(),
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24Hour),
                child: child!,
              );
            },
          );
          if (picked != null) {
            onChanged(picked);
          }
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Time',
          suffixIcon: Icon(Icons.access_time),
        ),
        child: Text(
          currentTime != null ? format(currentTime) : 'Select time',
        ),
      ),
    );
  }
  
  @override
  dynamic get defaultValue => TimeOfDay.now();
  
  @override
  Color get iconColor => Colors.indigo;
}
