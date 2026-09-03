import '../copilot_tool.dart';

class CrossColumnAnomalyTool implements CopilotTool {
  @override
  String get name => 'cross_column_anomaly';

  @override
  Map<String, dynamic> get declaration => {
        "name": name,
        "description": "Compares two columns logically (e.g. Order Date vs Delivery Date) for temporal or logical anomalies.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "primaryRange": {
              "type": "STRING",
              "description": "The primary range (e.g. Order Date 'A:A')"
            },
            "secondaryRange": {
              "type": "STRING",
              "description": "The secondary range to compare against primary (e.g. Delivery Date 'B:B')"
            }
          },
          "required": ["primaryRange", "secondaryRange"]
        }
      };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final pRange = args['primaryRange']?.toString().toUpperCase() ?? 'A:A';
    final sRange = args['secondaryRange']?.toString().toUpperCase() ?? 'B:B';

    final jsScript = '''
var sheet = SpreadsheetApp.getActiveSheet();
var range1 = sheet.getRange("$pRange");
var anomalies = range1.checkRelationalAnomaly("$sRange");
for (var i = 0; i < anomalies.length; i++) {
    sheet.getRange(anomalies[i].secondaryCellRef).setBackground("#FFCCCC");
}
anomalies; // return the array to the AI agent
''';

    return {
      'pipeline': {
        'steps': [
          {'type': 'script', 'code': jsScript}
        ]
      },
      'explanation': 'Checking logic between $pRange and $sRange. Highlighting anomalies.',
      'plan_summary': 'Cross Column Check executed'
    };
  }
}
