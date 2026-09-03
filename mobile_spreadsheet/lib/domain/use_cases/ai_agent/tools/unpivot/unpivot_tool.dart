import '../copilot_tool.dart';

class UnpivotTool implements CopilotTool {
  @override
  String get name => 'unpivot_columns';

  @override
  Map<String, dynamic> get declaration => {
        "name": name,
        "description": "Unpivots (flattens) wide data columns into a tall table format (e.g., converts monthly sales columns Jan-Dec into [Month, Sales] rows).",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "id_columns_count": {
              "type": "INTEGER",
              "description": "Number of leading fixed identifier columns to keep intact, e.g. 1 or 2 (Product, Category)"
            },
            "attribute_header": {
              "type": "STRING",
              "description": "Header name for the unpivoted attribute column, e.g. 'Month' or 'Attribute'"
            },
            "value_header": {
              "type": "STRING",
              "description": "Header name for the unpivoted value column, e.g. 'Sales' or 'Amount'"
            }
          },
          "required": ["id_columns_count"]
        }
      };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final idCols = (args['id_columns_count'] as num?)?.toInt() ?? 1;
    final attrHeader = args['attribute_header']?.toString() ?? 'Attribute';
    final valHeader = args['value_header']?.toString() ?? 'Value';

    final jsScript = '''
var sheet = SpreadsheetApp.getActiveSheet();
var dataRange = sheet.getDataRange();
var values = dataRange.getValues();

if (values.length > 1) {
  var headers = values[0];
  var totalCols = headers.length;
  var idCount = $idCols;
  
  if (totalCols > idCount) {
    var newRows = [];
    
    // New Header
    var newHeader = [];
    for (var c = 0; c < idCount; c++) {
      newHeader.push(headers[c]);
    }
    newHeader.push("$attrHeader");
    newHeader.push("$valHeader");
    newRows.push(newHeader);
    
    // Unpivot Data Rows
    for (var r = 1; r < values.length; r++) {
      var row = values[r];
      var hasId = false;
      for (var c = 0; c < idCount; c++) {
        if (row[c] !== "" && row[c] !== null && row[c] !== undefined) {
          hasId = true;
          break;
        }
      }
      if (!hasId) continue;
      
      for (var col = idCount; col < totalCols; col++) {
        var cellVal = row[col];
        if (cellVal !== "" && cellVal !== null && cellVal !== undefined) {
          var unpivotedRow = [];
          for (var c = 0; c < idCount; c++) {
            unpivotedRow.push(row[c]);
          }
          unpivotedRow.push(headers[col]);
          unpivotedRow.push(cellVal);
          newRows.push(unpivotedRow);
        }
      }
    }
    
    // Clear and write unpivoted dataset
    sheet.clear();
    var outRange = sheet.getRange(1, 1, newRows.length, newHeader.length);
    outRange.setValues(newRows);
  }
}
''';

    return {
      'pipeline': {
        'steps': [
          {'type': 'script', 'code': jsScript}
        ]
      },
      'explanation': 'Unpivoting wide columns with $idCols identifier columns into [$attrHeader, $valHeader]',
      'plan_summary': 'Unpivot transformation executed'
    };
  }
}
