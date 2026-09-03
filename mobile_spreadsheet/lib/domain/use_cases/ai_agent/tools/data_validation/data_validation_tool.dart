import 'dart:convert';
import '../copilot_tool.dart';

class DataValidationTool implements CopilotTool {
  @override
  String get name => 'data_validation';

  @override
  Map<String, dynamic> get declaration => {
        "name": name,
        "description": "Sets data validation (Dropdown Lists) for a range natively.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "range": {
              "type": "STRING",
              "description": "The range, e.g., 'B2:B10'"
            },
            "list_values": {
              "type": "ARRAY",
              "items": {"type": "STRING"},
              "description": "List of allowed values for the dropdown (e.g. ['Pending', 'Done'])"
            }
          },
          "required": ["range", "list_values"]
        }
      };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final rangeStr = args['range']?.toString().toUpperCase() ?? 'A1:A10';
    final listValues = args['list_values'] as List? ?? [];
    
    final jsonList = jsonEncode(listValues);

    final jsScript = '''
var sheet = SpreadsheetApp.getActiveSheet();
var range = sheet.getRange("$rangeStr");
range.setDataValidation($jsonList);
''';

    return {
      'pipeline': {
        'steps': [
          {'type': 'script', 'code': jsScript}
        ]
      },
      'explanation': 'Setting data validation dropdowns in $rangeStr',
      'plan_summary': 'Data Validation pipeline built'
    };
  }
}
