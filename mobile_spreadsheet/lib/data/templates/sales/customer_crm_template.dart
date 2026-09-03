import 'package:flutter/material.dart';
import 'package:mobile_spreadsheet/domain/entities/template_entity.dart';

final customerCrmTemplate = SheetTemplate(
  id: 'customer_crm',
  name: 'Customer CRM',
  description: 'Manage customer contacts, leads, deals, and communication notes',
  icon: Icons.trending_up,
  iconColor: const Color(0xFFF44336),
  categoryId: 'sales',
  columns: const [
    TemplateColumn(name: 'Customer Name', typeId: 'text', width: 150),
    TemplateColumn(name: 'Phone', typeId: 'phone', width: 120),
    TemplateColumn(name: 'Email', typeId: 'link', width: 150),
    TemplateColumn(name: 'Company', typeId: 'text', width: 140),
    TemplateColumn(name: 'Last Contact', typeId: 'date', width: 110),
    TemplateColumn(
      name: 'Status',
      typeId: 'selectable',
      width: 110,
      extraConfig: {
        'options': ['Lead', 'Contacted', 'Qualified', 'Proposal', 'Customer', 'Inactive'],
      },
    ),
    TemplateColumn(name: 'Notes', typeId: 'text', width: 160),
  ],
  frozenRows: 1,
);
