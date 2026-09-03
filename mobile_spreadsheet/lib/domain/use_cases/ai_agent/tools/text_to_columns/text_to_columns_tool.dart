import '../copilot_tool.dart';

class TextToColumnsTool implements CopilotTool {
  @override
  String get name => 'text_to_columns';

  @override
  Map<String, dynamic> get declaration => {
        "name": name,
        "description": "Splits text in a column into multiple columns based on a delimiter (e.g., comma, space). This will overwrite adjacent columns.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "column_letter": {
              "type": "STRING",
              "description": "The column letter to split, e.g. 'A', 'B'"
            },
            "delimiter": {
              "type": "STRING",
              "description": "The delimiter to split by, e.g. ',', ' ', '-'"
            }
          },
          "required": ["column_letter", "delimiter"]
        }
      };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final column = args['column_letter']?.toString().toUpperCase() ?? 'A';
    final delimiter = args['delimiter']?.toString() ?? ',';

    final jsScript = '''
var sheet = SpreadsheetApp.getActiveSheet();
var lastRow = sheet.getLastRow();
if (lastRow > 0) {
  var range = sheet.getRange("$column" + "1:$column" + lastRow);
  var values = range.getValues();
  var newValues = [];
  var maxCols = 1;
  
  for (var i = 0; i < values.length; i++) {
    var val = values[i][0] ? values[i][0].toString() : "";
    var splitVals = val.split("$delimiter");
    if (splitVals.length > maxCols) {
      maxCols = splitVals.length;
    }
    newValues.push(splitVals);
  }
  
  // Pad rows that have fewer columns
  for (var i = 0; i < newValues.length; i++) {
    while (newValues[i].length < maxCols) {
      newValues[i].push("");
    }
  }
  
  var targetRange = sheet.getRange(1, range.getColumn(), lastRow, maxCols);
  targetRange.setValues(newValues);
}
''';

    return {
      'pipeline': {
        'steps': [
          {
            'type': 'script',
            'code': jsScript
          }
        ]
      },
      'explanation': 'Splitting column $column by "$delimiter"',
      'plan_summary': 'Text-to-Columns pipeline built successfully'
    };
  }
}
