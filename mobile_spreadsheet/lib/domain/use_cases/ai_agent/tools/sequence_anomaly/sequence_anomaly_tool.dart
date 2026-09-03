import '../copilot_tool.dart';

class SequenceAnomalyTool implements CopilotTool {
  @override
  String get name => 'sequence_anomaly';

  @override
  Map<String, dynamic> get declaration => {
        "name": name,
        "description": "Checks a numeric or alphanumeric sequence (like invoices or IDs) for missing numbers or sequence breaks.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "range": {
              "type": "STRING",
              "description": "The range to check for sequence breaks, e.g., 'A1:A100'"
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
var anomalies = range.checkSequenceAnomaly();
for (var i = 0; i < anomalies.length; i++) {
    sheet.getRange(anomalies[i].cellRef).setBackground("#FFCCCC");
}
anomalies; // return the array to the AI agent
''';

    return {
      'pipeline': {
        'steps': [
          {'type': 'script', 'code': jsScript}
        ]
      },
      'explanation': 'Checking sequence anomalies in $rangeStr and highlighting breaks in light red.',
      'plan_summary': 'Sequence Check executed'
    };
  }
}
