import 'package:flutter/material.dart';
import 'package:mobile_spreadsheet/domain/entities/template_entity.dart';

final stockManagementTemplate = SheetTemplate(
  id: 'inventory_stock_management',
  name: 'Stock Management',
  description: 'Track inventory stock levels, unit prices, total value, and reorder alerts.',
  icon: Icons.inventory_2,
  iconColor: const Color(0xFFFF9800),
  categoryId: 'inventory',
  columns: const [
    TemplateColumn(name: 'Item Code', typeId: 'text', width: 100),
    TemplateColumn(name: 'Item Name', typeId: 'text', width: 150),
    TemplateColumn(
      name: 'Category',
      typeId: 'selectable',
      width: 120,
      extraConfig: {
        'options': ['Electronics', 'Clothing', 'Food & Beverage', 'Office Supplies', 'Hardware', 'Other'],
      },
    ),
    TemplateColumn(name: 'Quantity', typeId: 'number', width: 90),
    TemplateColumn(name: 'Unit Price', typeId: 'amount', width: 110),
    TemplateColumn(name: 'Total Value', typeId: 'amount', width: 120),
    TemplateColumn(name: 'Reorder Level', typeId: 'number', width: 110),
    TemplateColumn(name: 'Supplier', typeId: 'text', width: 140),
  ],
  frozenRows: 1,
  frozenColumns: 1,
);
