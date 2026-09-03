import 'package:flutter/material.dart';
import 'package:mobile_spreadsheet/domain/entities/template_entity.dart';

final todoListTemplate = SheetTemplate(
  id: 'personal_todo_list',
  name: 'Todo List',
  description: 'Track daily tasks, set priorities, manage due dates, and monitor completion status.',
  icon: Icons.person,
  iconColor: const Color(0xFF3F51B5),
  categoryId: 'personal',
  columns: const [
    TemplateColumn(name: 'Task', typeId: 'text', width: 180),
    TemplateColumn(
      name: 'Priority',
      typeId: 'selectable',
      width: 100,
      extraConfig: {
        'options': ['High', 'Medium', 'Low'],
      },
    ),
    TemplateColumn(name: 'Due Date', typeId: 'date', width: 110),
    TemplateColumn(name: 'Done', typeId: 'checkbox', width: 80),
    TemplateColumn(
      name: 'Category',
      typeId: 'selectable',
      width: 110,
      extraConfig: {
        'options': ['Work', 'Personal', 'Shopping', 'Health', 'Other'],
      },
    ),
    TemplateColumn(name: 'Notes', typeId: 'text', width: 150),
  ],
  frozenRows: 1,
);
