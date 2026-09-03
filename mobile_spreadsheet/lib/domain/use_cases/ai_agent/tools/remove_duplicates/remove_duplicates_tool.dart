import '../copilot_tool.dart';

class RemoveDuplicatesTool implements CopilotTool {
  @override
  String get name => 'remove_duplicates';

  @override
  Map<String, dynamic> get declaration => {
        "name": name,
        "description": "Removes duplicate rows from a specified range natively using the C++ engine.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "range": {
              "type": "STRING",
              "description": "The range to remove duplicates from, e.g., 'A1:C100' or 'A:A'"
            }
          },
          "required": ["range"]
        }
      };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final rangeStr = args['range']?.toString().toUpperCase() ?? 'A:A';

    final jsScript = '''
var sheet = SpreadsheetApp.getActiveSheet();
var range = sheet.getRange("$rangeStr");
range.removeDuplicates();
''';

    return {
      'pipeline': {
        'steps': [
          {'type': 'script', 'code': jsScript}
        ]
      },
      'explanation': 'Removing duplicates in range $rangeStr natively',
      'plan_summary': 'Remove Duplicates pipeline built'
    };
  }
}
