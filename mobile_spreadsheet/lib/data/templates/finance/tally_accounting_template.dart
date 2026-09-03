import 'package:flutter/material.dart';
import '../../../domain/entities/template_entity.dart';

final tallyAccountingTemplate = SheetTemplate(
  id: 'finance_tally_accounting',
  name: 'Tally Accounting & Vouchers',
  description: 'Double-entry & Voucher accounting with instant PDF Receipts, Party Ledgers & Cash Balance tracking',
  icon: Icons.account_balance,
  iconColor: const Color(0xFF1E88E5),
  categoryId: 'finance',
  columns: const [
    TemplateColumn(
      name: 'Receipt No.',
      typeId: 'text',
      width: 100,
    ),
    TemplateColumn(
      name: 'Date',
      typeId: 'date',
      width: 110,
    ),
    TemplateColumn(
      name: 'Voucher Type',
      typeId: 'selectable',
      width: 120,
      extraConfig: {
        'options': ['Sales', 'Purchase', 'Receipt', 'Payment'],
      },
    ),
    TemplateColumn(
      name: 'Party Name',
      typeId: 'text',
      width: 140,
    ),
    TemplateColumn(
      name: 'Item / Narration',
      typeId: 'text',
      width: 170,
    ),
    TemplateColumn(
      name: 'Amount (₹)',
      typeId: 'amount',
      width: 120,
    ),
    TemplateColumn(
      name: 'Payment Mode',
      typeId: 'selectable',
      width: 120,
      extraConfig: {
        'options': ['Cash', 'Bank/UPI', 'Credit'],
      },
    ),
  ],
  frozenRows: 1,
  frozenColumns: 1,
);
