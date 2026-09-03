import 'package:flutter/material.dart';
import 'package:mobile_spreadsheet/domain/entities/template_entity.dart';

final classScheduleTemplate = SheetTemplate(
  id: 'education_class_schedule',
  name: 'Class Schedule',
  description: 'Organize weekly class timetable and schedules from Monday to Saturday.',
  icon: Icons.school,
  iconColor: const Color(0xFF4CAF50),
  categoryId: 'education',
  columns: const [
    TemplateColumn(name: 'Time Slot', typeId: 'time', width: 110),
    TemplateColumn(name: 'Monday', typeId: 'text', width: 120),
    TemplateColumn(name: 'Tuesday', typeId: 'text', width: 120),
    TemplateColumn(name: 'Wednesday', typeId: 'text', width: 120),
    TemplateColumn(name: 'Thursday', typeId: 'text', width: 120),
    TemplateColumn(name: 'Friday', typeId: 'text', width: 120),
    TemplateColumn(name: 'Saturday', typeId: 'text', width: 120),
  ],
  frozenRows: 1,
  frozenColumns: 1,
);
