import '../copilot_tool.dart';

class MixedDataAnomalyTool implements CopilotTool {
  @override
  String get name => 'mixed_data_anomaly';

  @override
  Map<String, dynamic> get declaration => {
        "name": name,
        "description": "Scans a column for mixed data types (e.g., text hiding in a numeric column) and generates automatic repair suggestions with confidence scores.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "range": {
              "type": "STRING",
              "description": "The range to check, e.g., 'C1:C100'"
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
var anomalies = range.detectAnomalies();
var repairs = range.getRepairSuggestions();

for (var i = 0; i < anomalies.length; i++) {
    sheet.getRange(anomalies[i].cellRef).setBackground("#FFEB9C"); // Yellow for mixed data
}
for (var i = 0; i < repairs.length; i++) {
    // If high confidence, we could auto-apply, but for now just mark green for suggested repair
    sheet.getRange(repairs[i].cellRef).setBackground("#C6EFCE");
}
var result = { anomalies: anomalies, repairs: repairs };
result;
''';

    return {
      'pipeline': {
        'steps': [
          {'type': 'script', 'code': jsScript}
        ]
      },
      'explanation': 'Scanning $rangeStr for mixed data and calculating repair suggestions.',
      'plan_summary': 'Mixed Data Scan executed'
    };
  }
}
