import 'package:flutter/material.dart';
import '../../../domain/entities/template_entity.dart';

final budgetTemplate = SheetTemplate(
  id: 'finance_budget',
  name: 'Budget Planner',
  description: 'Plan and monitor your budget vs actual spending',
  icon: Icons.account_balance_wallet,
  iconColor: const Color(0xFF2196F3),
  categoryId: 'finance',
  columns: const [
    TemplateColumn(name: 'Category', typeId: 'text', width: 130),
    TemplateColumn(name: 'Sub-Category', typeId: 'text', width: 130),
    TemplateColumn(name: 'Budgeted Amount', typeId: 'amount', width: 130),
    TemplateColumn(name: 'Actual Spent', typeId: 'amount', width: 130),
    TemplateColumn(name: 'Difference', typeId: 'amount', width: 120),
    TemplateColumn(name: 'Notes', typeId: 'text', width: 160),
  ],
  frozenRows: 1,
);
