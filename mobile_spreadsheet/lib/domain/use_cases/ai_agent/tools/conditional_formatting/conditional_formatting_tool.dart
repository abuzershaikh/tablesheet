import 'package:mobile_spreadsheet/domain/services/conditional_formatting_service.dart';
import '../../../../services/copilot/copilot_service.dart';
import '../copilot_tool.dart';

class ConditionalFormattingTool implements CopilotTool {
  @override
  String get name => 'conditional_formatting';

  @override
  Map<String, dynamic> get declaration => {
        "name": name,
        "description": "Adds a conditional formatting color rule to a range natively.",
        "parameters": {
          "type": "OBJECT",
          "properties": {
            "range": {
              "type": "STRING",
              "description": "The range, e.g., 'C1:C100'"
            },
            "rule_type": {
              "type": "STRING",
              "description": "Type of rule, e.g. 'GREATER_THAN', 'LESS_THAN', 'TEXT_CONTAINS'"
            },
            "value": {
              "type": "STRING",
              "description": "The condition value, e.g. '100' or 'Failed'"
            },
            "color_hex": {
              "type": "STRING",
              "description": "The hex color to highlight with, e.g. '#FF0000' for red."
            }
          },
          "required": ["range", "rule_type", "value"]
        }
      };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final rangeStr = args['range']?.toString().toUpperCase() ?? 'A1';
    final type = args['rule_type']?.toString() ?? 'GREATER_THAN';
    final val = args['value']?.toString() ?? '';
    final color = args['color_hex']?.toString() ?? '#FFFF00';

    String cfType = 'Greater than';
    if (type.contains('LESS')) cfType = 'Less than';
    else if (type.contains('EQUAL')) cfType = 'Is equal to';
    else if (type.contains('CONTAINS') || type.contains('TEXT')) cfType = 'Text contains';
    else if (type.contains('BETWEEN')) cfType = 'Is between';

    final hexClean = color.replaceAll('#', '');
    final resolvedSheetId = args['sheet_id']?.toString() ?? CopilotService.activeAgentSheetId ?? 'Sheet1';
    final ruleJson = {
      'sheetId': resolvedSheetId,
      'range': rangeStr,
      'type': cfType,
      'value1': val,
      'value2': '',
      'style': {
        'bgColor': hexClean.length == 6 ? 'FF$hexClean' : hexClean,
        'textColor': 'FF000000',
        'bold': false,
        'italic': false,
        'underline': false,
      },
    };

    ConditionalFormattingService.addRule(resolvedSheetId, ruleJson);

    return {
      'pipeline': {
        'steps': [
          {
            'type': 'conditional_format',
            'range': rangeStr,
            'condition': type,
            'value': val,
            'bgColor': color,
          }
        ]
      },
      'explanation': 'Highlighting cells in $rangeStr based on $type ($val) with $color',
      'plan_summary': 'Conditional Formatting rule applied successfully'
    };
  }
}
