import 'package:flutter/material.dart';
import '../../../domain/entities/template_entity.dart';

final employeeDirectoryTemplate = SheetTemplate(
  id: 'hr_employee_directory',
  name: 'Employee Directory',
  description: 'Manage employee details, contact information, and department assignments',
  icon: Icons.people,
  iconColor: const Color(0xFF9C27B0),
  categoryId: 'hr',
  columns: const [
    TemplateColumn(name: 'Emp ID', typeId: 'text', width: 90),
    TemplateColumn(name: 'Full Name', typeId: 'text', width: 150),
    TemplateColumn(name: 'Phone', typeId: 'phone', width: 120),
    TemplateColumn(name: 'Email', typeId: 'link', width: 150),
    TemplateColumn(
      name: 'Department',
      typeId: 'selectable',
      width: 120,
      extraConfig: {
        'options': ['Engineering', 'HR', 'Sales', 'Marketing', 'Finance', 'Operations'],
      },
    ),
    TemplateColumn(name: 'Designation', typeId: 'text', width: 130),
    TemplateColumn(name: 'Join Date', typeId: 'date', width: 110),
    TemplateColumn(name: 'Address', typeId: 'address', width: 180),
  ],
  frozenRows: 1,
  frozenColumns: 1,
);
