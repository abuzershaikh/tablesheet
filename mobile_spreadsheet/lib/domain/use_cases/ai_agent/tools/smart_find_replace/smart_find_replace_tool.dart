import '../copilot_tool.dart';

class SmartFindReplaceTool implements CopilotTool {
  @override
  String get name => 'smart_find_replace';

  @override
  Map<String, dynamic> get declaration => {
        "name": name,
        "description": "Smart Find and Replace across a range using Regex or Exact Match.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "range": {
              "type": "STRING",
              "description": "The range, e.g., 'A1:B10'"
            },
            "pattern": {
              "type": "STRING",
              "description": "The text or Regex pattern to find"
            },
            "replacement": {
              "type": "STRING",
              "description": "The replacement text"
            },
            "is_regex": {
              "type": "BOOLEAN",
              "description": "True if pattern is a regular expression"
            }
          },
          "required": ["range", "pattern", "replacement"]
        }
      };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final rangeStr = args['range']?.toString().toUpperCase() ?? 'A1:A100';
    final pattern = args['pattern']?.toString() ?? '';
    final replacement = args['replacement']?.toString() ?? '';
    final isRegex = args['is_regex'] == true;

    final jsScript = '''
var sheet = SpreadsheetApp.getActiveSheet();
var range = sheet.getRange("$rangeStr");
range.findAndReplace("$pattern", "$replacement", $isRegex);
''';

    return {
      'pipeline': {
        'steps': [
          {'type': 'script', 'code': jsScript}
        ]
      },
      'explanation': 'Replacing "$pattern" with "$replacement" in $rangeStr',
      'plan_summary': 'Find and Replace pipeline built'
    };
  }
}
