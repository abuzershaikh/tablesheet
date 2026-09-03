import 'package:mobile_spreadsheet/presentation/editor/modules/number_format/number_format_model.dart';
import 'package:mobile_spreadsheet/presentation/editor/modules/number_format/number_format_service.dart';
import '../copilot_tool.dart';

class FormatColumnTool implements CopilotTool {
  @override
  String get name => 'format_column';

  @override
  Map<String, dynamic> get declaration => {
        "name": name,
        "description": "Changes the data type or format of a column (e.g., Currency, Date, Number, Plain Text).",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "column_letter": {
              "type": "STRING",
              "description": "The column letter to format, e.g. 'A', 'B'"
            },
            "format": {
              "type": "STRING",
              "description": "The format string to apply. e.g. '\$#,##0.00' for currency, 'MM/DD/YYYY' for date, '0.00' for number, '@' for plain text."
            }
          },
          "required": ["column_letter", "format"]
        }
      };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final column = args['column_letter']?.toString().toUpperCase() ?? 'A';
    final formatStr = args['format']?.toString() ?? '@';

    CellFormat targetFmt = CellFormat.general;
    if (formatStr.contains('\$') || formatStr.contains('₹') || formatStr.toLowerCase().contains('currency')) {
      targetFmt = CellFormat.currency;
    } else if (formatStr.contains('%')) {
      targetFmt = CellFormat.percentage;
    } else if (formatStr.contains('YYYY') || formatStr.contains('MM') || formatStr.contains('DD')) {
      targetFmt = CellFormat.shortDate;
    } else if (formatStr.contains('0.00') || formatStr.contains('#,##0')) {
      targetFmt = CellFormat.number;
    }

    int colIndex = 0;
    for (int i = 0; i < column.length; i++) {
      colIndex = colIndex * 26 + (column.codeUnitAt(i) - 65);
    }

    final cellKeys = <String>[];
    for (int r = 0; r < 200; r++) {
      cellKeys.add('$r:$colIndex');
    }

    await NumberFormatService.instance.saveFormats('Sheet1', cellKeys, targetFmt);

    return {
      'pipeline': {
        'steps': [
          {
            'type': 'format_cells',
            'range': '${column}1:${column}1000',
            'format': formatStr,
          }
        ]
      },
      'explanation': 'Formatting column $column to "$formatStr"',
      'plan_summary': 'Format Column pipeline built successfully'
    };
  }
}
