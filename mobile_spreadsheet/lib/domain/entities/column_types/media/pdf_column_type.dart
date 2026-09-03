import 'package:flutter/material.dart';
import '../base/column_type.dart';

/// PDF Column Type - for PDF attachments
class PdfColumnType extends ColumnType {
  const PdfColumnType() : super(
    id: 'pdf',
    name: 'PDF Attachment',
    description: 'Attach PDF document files',
    icon: Icons.picture_as_pdf,
  );

  @override
  bool validate(dynamic value) {
    if (value == null) return true;
    final str = value.toString().toLowerCase();
    return str.isEmpty || str.endsWith('.pdf');
  }

  @override
  String format(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  @override
  dynamic parse(String input) => input;

  @override
  Widget getInputWidget({
    required dynamic initialValue,
    required ValueChanged<dynamic> onChanged,
  }) {
    return Container();
  }

  @override
  dynamic get defaultValue => '';

  @override
  Color get iconColor => Colors.red;
}
