import 'package:flutter/material.dart';
import 'package:mobile_spreadsheet/domain/entities/template_entity.dart';

final habitTrackerTemplate = SheetTemplate(
  id: 'personal_habit_tracker',
  name: 'Habit Tracker',
  description: 'Track weekly habits, daily completions, and streak progress.',
  icon: Icons.person,
  iconColor: const Color(0xFF3F51B5),
  categoryId: 'personal',
  columns: const [
    TemplateColumn(name: 'Habit', typeId: 'text', width: 150),
    TemplateColumn(name: 'Mon', typeId: 'checkbox', width: 70),
    TemplateColumn(name: 'Tue', typeId: 'checkbox', width: 70),
    TemplateColumn(name: 'Wed', typeId: 'checkbox', width: 70),
    TemplateColumn(name: 'Thu', typeId: 'checkbox', width: 70),
    TemplateColumn(name: 'Fri', typeId: 'checkbox', width: 70),
    TemplateColumn(name: 'Sat', typeId: 'checkbox', width: 70),
    TemplateColumn(name: 'Sun', typeId: 'checkbox', width: 70),
    TemplateColumn(name: 'Streak', typeId: 'number', width: 80),
  ],
  frozenRows: 1,
  frozenColumns: 1,
);
