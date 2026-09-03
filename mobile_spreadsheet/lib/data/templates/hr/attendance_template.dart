import 'package:flutter/material.dart';
import '../../../domain/entities/template_entity.dart';

final attendanceTemplate = SheetTemplate(
  id: 'hr_attendance',
  name: 'Attendance Register',
  description: 'Track daily employee attendance, check-in and check-out times, and working hours',
  icon: Icons.people,
  iconColor: const Color(0xFF9C27B0),
  categoryId: 'hr',
  columns: const [
    TemplateColumn(name: 'Emp ID', typeId: 'text', width: 90),
    TemplateColumn(name: 'Employee Name', typeId: 'text', width: 150),
    TemplateColumn(name: 'Date', typeId: 'date', width: 110),
    TemplateColumn(name: 'Check In', typeId: 'time', width: 100),
    TemplateColumn(name: 'Check Out', typeId: 'time', width: 100),
    TemplateColumn(
      name: 'Status',
      typeId: 'selectable',
      width: 110,
      extraConfig: {
        'options': ['Present', 'Absent', 'Half Day', 'On Leave', 'Work From Home'],
      },
    ),
    TemplateColumn(name: 'Hours Worked', typeId: 'number', width: 110),
    TemplateColumn(name: 'Notes', typeId: 'text', width: 140),
  ],
  frozenRows: 1,
);
