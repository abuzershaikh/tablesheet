import 'package:flutter/material.dart';
import 'package:mobile_spreadsheet/domain/entities/template_entity.dart';

final taskTrackerTemplate = SheetTemplate(
  id: 'project_task_tracker',
  name: 'Task Tracker',
  description: 'Track task assignments, priorities, statuses, and deadlines across your project.',
  icon: Icons.assignment,
  iconColor: const Color(0xFF009688),
  categoryId: 'project',
  columns: const [
    TemplateColumn(name: 'Task ID', typeId: 'text', width: 90),
    TemplateColumn(name: 'Task Name', typeId: 'text', width: 160),
    TemplateColumn(name: 'Assigned To', typeId: 'text', width: 130),
    TemplateColumn(name: 'Priority', typeId: 'selectable', width: 100),
    TemplateColumn(name: 'Status', typeId: 'selectable', width: 110),
    TemplateColumn(name: 'Start Date', typeId: 'date', width: 110),
    TemplateColumn(name: 'Due Date', typeId: 'date', width: 110),
    TemplateColumn(name: 'Notes', typeId: 'text', width: 150),
  ],
  frozenRows: 1,
);
