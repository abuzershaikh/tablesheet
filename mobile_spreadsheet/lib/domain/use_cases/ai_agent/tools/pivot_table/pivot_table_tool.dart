import '../copilot_tool.dart';

class PivotTableTool implements CopilotTool {
  @override
  String get name => 'create_pivot_table';

  @override
  Map<String, dynamic> get declaration => {
        "name": name,
        "description": "Creates an Enterprise Pivot Table with optional Slicers, themes, and aggregation options.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "rowFields": {
              "type": "ARRAY",
              "items": {"type": "STRING"},
              "description": "Column names to group by in rows, e.g. ['Region', 'Category']"
            },
            "dataFields": {
              "type": "ARRAY",
              "items": {"type": "STRING"},
              "description": "Column names to aggregate, e.g. ['Sales']"
            },
            "aggType": {
              "type": "STRING",
              "enum": ["SUM", "AVG", "COUNT", "MIN", "MAX"],
              "description": "Aggregation type (default SUM)"
            },
            "slicerFields": {
              "type": "ARRAY",
              "items": {"type": "STRING"},
              "description": "Column names to convert into interactive Slicers, e.g. ['Category']"
            },
            "theme": {
              "type": "STRING",
              "enum": ["professionalBlue", "dark", "vibrantEmerald", "monochrome", "light"],
              "description": "Design theme for the Pivot Table"
            }
          },
          "required": ["rowFields", "dataFields"]
        }
      };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final rowFields = List<String>.from(args['rowFields'] ?? []);
    final dataFields = List<String>.from(args['dataFields'] ?? []);
    final slicerFields = List<String>.from(args['slicerFields'] ?? []);
    final aggType = args['aggType']?.toString().toUpperCase() ?? 'SUM';
    final theme = args['theme']?.toString() ?? 'professionalBlue';

    return {
      'pipeline': {
        'steps': [
          {
            'type': 'create_pivot_table',
            'rowFields': rowFields,
            'dataFields': dataFields,
            'slicerFields': slicerFields,
            'aggType': aggType,
            'theme': theme
          }
        ]
      },
      'explanation': 'Building Enterprise Pivot Table with ${rowFields.join(", ")} grouped by $dataFields ($aggType)',
      'plan_summary': 'Pivot Table & Slicers Created'
    };
  }
}
