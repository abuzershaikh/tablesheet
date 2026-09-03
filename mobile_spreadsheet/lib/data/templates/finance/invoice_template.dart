import 'package:flutter/material.dart';
import '../../../domain/entities/template_entity.dart';

final invoiceTemplate = SheetTemplate(
  id: 'finance_invoice',
  name: 'Invoice',
  description: 'Create professional invoices and track client payments',
  icon: Icons.receipt_long,
  iconColor: const Color(0xFF2196F3),
  categoryId: 'finance',
  columns: const [
    TemplateColumn(name: 'Invoice #', typeId: 'text', width: 100),
    TemplateColumn(name: 'Date', typeId: 'date', width: 110),
    TemplateColumn(name: 'Customer Name', typeId: 'text', width: 140),
    TemplateColumn(name: 'Item Description', typeId: 'text', width: 160),
    TemplateColumn(name: 'Quantity', typeId: 'number', width: 90),
    TemplateColumn(name: 'Unit Price', typeId: 'amount', width: 110),
    TemplateColumn(name: 'Total Amount', typeId: 'amount', width: 120),
    TemplateColumn(
      name: 'Payment Status',
      typeId: 'selectable',
      width: 120,
      extraConfig: {
        'options': ['Paid', 'Pending', 'Overdue', 'Draft'],
      },
    ),
  ],
  frozenRows: 1,
);
