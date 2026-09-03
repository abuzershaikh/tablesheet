import 'package:flutter/material.dart';
import 'package:mobile_spreadsheet/domain/entities/template_entity.dart';

final salesTrackerTemplate = SheetTemplate(
  id: 'sales_tracker',
  name: 'Sales Tracker',
  description: 'Track sales transactions, products, customer orders, and status',
  icon: Icons.trending_up,
  iconColor: const Color(0xFFF44336),
  categoryId: 'sales',
  columns: const [
    TemplateColumn(name: 'Date', typeId: 'date', width: 110),
    TemplateColumn(name: 'Customer', typeId: 'text', width: 140),
    TemplateColumn(name: 'Product', typeId: 'text', width: 140),
    TemplateColumn(name: 'Quantity', typeId: 'number', width: 90),
    TemplateColumn(name: 'Unit Price', typeId: 'amount', width: 110),
    TemplateColumn(name: 'Total Sale', typeId: 'amount', width: 120),
    TemplateColumn(name: 'Salesperson', typeId: 'text', width: 120),
    TemplateColumn(
      name: 'Status',
      typeId: 'selectable',
      width: 110,
      extraConfig: {
        'options': ['Pending', 'Completed', 'Cancelled', 'Refunded'],
      },
    ),
  ],
  frozenRows: 1,
);
