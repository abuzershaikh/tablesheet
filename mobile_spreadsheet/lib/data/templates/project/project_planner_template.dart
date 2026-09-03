import 'package:flutter/material.dart';
import 'package:mobile_spreadsheet/domain/entities/template_entity.dart';

final projectPlannerTemplate = SheetTemplate(
  id: 'project_planner',
  name: 'Project Planner',
  description: 'Plan project milestones, timelines, owners, progress, and statuses.',
  icon: Icons.assignment,
  iconColor: const Color(0xFF009688),
  categoryId: 'project',
  columns: const [
    TemplateColumn(name: 'Milestone', typeId: 'text', width: 140),
    TemplateColumn(name: 'Description', typeId: 'text', width: 180),
    TemplateColumn(name: 'Owner', typeId: 'text', width: 120),
    TemplateColumn(name: 'Start Date', typeId: 'date', width: 110),
    TemplateColumn(name: 'End Date', typeId: 'date', width: 110),
    TemplateColumn(name: 'Progress', typeId: 'number', width: 100),
    TemplateColumn(name: 'Status', typeId: 'selectable', width: 110),
  ],
  frozenRows: 1,
);
