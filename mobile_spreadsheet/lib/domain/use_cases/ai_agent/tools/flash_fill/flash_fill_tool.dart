import '../copilot_tool.dart';

class FlashFillTool implements CopilotTool {
  @override
  String get name => 'flash_fill';

  @override
  Map<String, dynamic> get declaration => {
        "name": name,
        "description": "Applies Flash Fill native heuristics to auto-fill a target range based on a pattern from a source range.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "source_range": {
              "type": "STRING",
              "description": "The source range containing original data, e.g., 'A1:A10'"
            },
            "target_range": {
              "type": "STRING",
              "description": "The target range where the first cell has the pattern example and the rest are empty, e.g., 'B1:B10'"
            }
          },
          "required": ["source_range", "target_range"]
        }
      };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final srcStr = args['source_range']?.toString().toUpperCase() ?? 'A1:A10';
    final tgtStr = args['target_range']?.toString().toUpperCase() ?? 'B1:B10';

    final jsScript = '''
var sheet = SpreadsheetApp.getActiveSheet();
var targetRange = sheet.getRange("$tgtStr");
targetRange.flashFill("$srcStr");
''';

    return {
      'pipeline': {
        'steps': [
          {'type': 'script', 'code': jsScript}
        ]
      },
      'explanation': 'Applying Flash Fill from $srcStr to $tgtStr',
      'plan_summary': 'Flash Fill pipeline built'
    };
  }
}
