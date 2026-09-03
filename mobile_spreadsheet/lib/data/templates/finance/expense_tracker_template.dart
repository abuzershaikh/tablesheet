import 'package:flutter/material.dart';
import '../../../domain/entities/template_entity.dart';

final expenseTrackerTemplate = SheetTemplate(
  id: 'finance_expense_tracker',
  name: 'Expense Tracker',
  description: 'Track daily expenses with categories and receipts',
  icon: Icons.payments,
  iconColor: const Color(0xFF2196F3),
  categoryId: 'finance',
  columns: const [
    TemplateColumn(name: 'Date', typeId: 'date', width: 110),
    TemplateColumn(name: 'Description', typeId: 'text', width: 160),
    TemplateColumn(
      name: 'Category',
      typeId: 'selectable',
      width: 120,
      extraConfig: {
        'options': ['Food', 'Transport', 'Utilities', 'Entertainment', 'Shopping', 'Health', 'Other'],
      },
    ),
    TemplateColumn(name: 'Amount', typeId: 'amount', width: 110),
    TemplateColumn(
      name: 'Payment Mode',
      typeId: 'selectable',
      width: 120,
      extraConfig: {
        'options': ['Cash', 'Credit Card', 'Debit Card', 'Bank Transfer', 'UPI'],
      },
    ),
    TemplateColumn(name: 'Receipt', typeId: 'image', width: 100),
    TemplateColumn(name: 'Notes', typeId: 'text', width: 140),
  ],
  frozenRows: 1,
);
