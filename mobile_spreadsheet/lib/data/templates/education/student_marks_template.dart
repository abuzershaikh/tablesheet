import 'package:flutter/material.dart';
import 'package:mobile_spreadsheet/domain/entities/template_entity.dart';

final studentMarksTemplate = SheetTemplate(
  id: 'education_student_marks',
  name: 'Student Marks Sheet',
  description: 'Track and calculate student marks, totals, and grades across multiple subjects.',
  icon: Icons.school,
  iconColor: const Color(0xFF4CAF50),
  categoryId: 'education',
  columns: const [
    TemplateColumn(name: 'Roll No', typeId: 'number', width: 80),
    TemplateColumn(name: 'Student Name', typeId: 'text', width: 150),
    TemplateColumn(name: 'Subject 1', typeId: 'number', width: 100),
    TemplateColumn(name: 'Subject 2', typeId: 'number', width: 100),
    TemplateColumn(name: 'Subject 3', typeId: 'number', width: 100),
    TemplateColumn(name: 'Subject 4', typeId: 'number', width: 100),
    TemplateColumn(name: 'Total', typeId: 'number', width: 100),
    TemplateColumn(name: 'Grade', typeId: 'text', width: 80),
  ],
  frozenRows: 1,
  frozenColumns: 1,
);
