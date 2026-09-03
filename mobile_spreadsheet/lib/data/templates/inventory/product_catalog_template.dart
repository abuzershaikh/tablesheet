import 'package:flutter/material.dart';
import 'package:mobile_spreadsheet/domain/entities/template_entity.dart';

final productCatalogTemplate = SheetTemplate(
  id: 'inventory_product_catalog',
  name: 'Product Catalog',
  description: 'Maintain a detailed catalog of products with images, prices, SKUs, and stock availability.',
  icon: Icons.inventory_2,
  iconColor: const Color(0xFFFF9800),
  categoryId: 'inventory',
  columns: const [
    TemplateColumn(name: 'Product ID', typeId: 'text', width: 100),
    TemplateColumn(name: 'Product Name', typeId: 'text', width: 150),
    TemplateColumn(name: 'Image', typeId: 'image', width: 100),
    TemplateColumn(name: 'Description', typeId: 'text', width: 180),
    TemplateColumn(name: 'Price', typeId: 'amount', width: 110),
    TemplateColumn(name: 'SKU', typeId: 'text', width: 100),
    TemplateColumn(name: 'In Stock', typeId: 'checkbox', width: 90),
  ],
  frozenRows: 1,
);
