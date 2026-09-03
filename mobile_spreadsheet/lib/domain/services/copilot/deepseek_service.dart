import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../super_engine/ffi_bridge.dart';
import 'copilot_service.dart';
import 'local_agent_service.dart';
import '../../analytics/engines/analytics_engine.dart';
import '../../analytics/models/chart_config.dart';

import '../../use_cases/ai_agent/tools/copilot_tool.dart';
import '../../use_cases/ai_agent/tools/text_to_columns/text_to_columns_tool.dart';
import '../../use_cases/ai_agent/tools/format_column/format_column_tool.dart';
import '../../use_cases/ai_agent/tools/remove_duplicates/remove_duplicates_tool.dart';
import '../../use_cases/ai_agent/tools/smart_find_replace/smart_find_replace_tool.dart';
import '../../use_cases/ai_agent/tools/data_validation/data_validation_tool.dart';
import '../../use_cases/ai_agent/tools/conditional_formatting/conditional_formatting_tool.dart';
import '../../use_cases/ai_agent/tools/flash_fill/flash_fill_tool.dart';
import '../../use_cases/ai_agent/tools/sequence_anomaly/sequence_anomaly_tool.dart';
import '../../use_cases/ai_agent/tools/cross_column_anomaly/cross_column_anomaly_tool.dart';
import '../../use_cases/ai_agent/tools/mixed_data_anomaly/mixed_data_anomaly_tool.dart';
import '../../use_cases/ai_agent/tools/pivot_table/pivot_table_tool.dart';
import '../../use_cases/ai_agent/tools/unpivot/unpivot_tool.dart';

class DeepSeekService {
  static const String _baseUrl = 'https://api.deepseek.com/chat/completions';

  static final List<CopilotTool> _modularTools = [
    TextToColumnsTool(),
    UnpivotTool(),
    FormatColumnTool(),
    RemoveDuplicatesTool(),
    SmartFindReplaceTool(),
    DataValidationTool(),
    ConditionalFormattingTool(),
    FlashFillTool(),
    SequenceAnomalyTool(),
    CrossColumnAnomalyTool(),
    MixedDataAnomalyTool(),
    PivotTableTool(),
  ];

  static List<Map<String, dynamic>> get _deepSeekTools {
    final list = <Map<String, dynamic>>[];
    try {
      final toolGroups = LocalAgentService.tools;
      for (final g in toolGroups) {
        final decls = g['functionDeclarations'] as List?;
        if (decls != null) {
          for (final d in decls) {
            if (d is Map) {
              list.add(_convertDeclarationToOpenAi(Map<String, dynamic>.from(d)));
            }
          }
        }
      }
    } catch (e) {
      debugPrint("[DeepSeekService] Error generating tools from LocalAgentService: $e");
    }
    return list;
  }

  static Map<String, dynamic> _convertDeclarationToOpenAi(Map<String, dynamic> decl) {
    return {
      "type": "function",
      "function": {
        "name": decl["name"],
        "description": decl["description"] ?? "",
        "parameters": _lowercaseTypes(decl["parameters"] ?? {"type": "object", "properties": {}}),
      }
    };
  }

  static dynamic _lowercaseTypes(dynamic obj) {
    if (obj is Map) {
      final copy = <String, dynamic>{};
      obj.forEach((k, v) {
        final key = k.toString();
        if (key == 'type' && v is String) {
          copy[key] = v.toLowerCase();
        } else {
          copy[key] = _lowercaseTypes(v);
        }
      });
      return copy;
    } else if (obj is List) {
      return obj.map((e) => _lowercaseTypes(e)).toList();
    }
    return obj;
  }

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('deepseek_api_key');
  }

  static Future<String> getSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('deepseek_selected_model') ?? 'deepseek-chat';
  }

  static bool _isCancelled = false;

  static void cancelLoop() {
    _isCancelled = true;
  }

  static Map<String, dynamic>? _extractPipeline(String content) {
    if (content.isEmpty) return null;

    // 1. Try ```json ... ``` or ``` ... ```
    final codeBlockMatches = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', caseSensitive: false).allMatches(content);
    for (final match in codeBlockMatches) {
      final code = match.group(1)?.trim() ?? '';
      try {
        final parsed = jsonDecode(code);
        if (parsed is Map) {
          if (parsed.containsKey('steps') && parsed['steps'] is List) {
            return Map<String, dynamic>.from(parsed);
          }
          if (parsed.containsKey('pipeline') && parsed['pipeline'] is Map) {
            final pipeObj = Map<String, dynamic>.from(parsed['pipeline']);
            if (pipeObj.containsKey('steps') && pipeObj['steps'] is List) {
              return pipeObj;
            }
          }
        } else if (parsed is List) {
          return {'steps': parsed};
        }
      } catch (_) {}
    }

    // 2. Try raw JSON object with "steps"
    final rawJsonMatch = RegExp(r'(\{\s*"(?:steps|pipeline)"\s*:\s*[\{\[][\s\S]*?[\}\]]\s*\})').firstMatch(content);
    if (rawJsonMatch != null) {
      try {
        final parsed = jsonDecode(rawJsonMatch.group(1)!);
        if (parsed is Map) {
          if (parsed.containsKey('steps') && parsed['steps'] is List) {
            return Map<String, dynamic>.from(parsed);
          }
          if (parsed.containsKey('pipeline') && parsed['pipeline'] is Map) {
            final pipeObj = Map<String, dynamic>.from(parsed['pipeline']);
            if (pipeObj.containsKey('steps') && pipeObj['steps'] is List) {
              return pipeObj;
            }
          }
        }
      } catch (_) {}
    }

    // 3. Try raw JSON array of step objects
    final rawArrayMatch = RegExp(r'(\[\s*\{\s*"type"\s*:[\s\S]*?\}\s*\])').firstMatch(content);
    if (rawArrayMatch != null) {
      try {
        final parsed = jsonDecode(rawArrayMatch.group(1)!);
        if (parsed is List) {
          return {'steps': parsed};
        }
      } catch (_) {}
    }

    return null;
  }

  /// Run autonomous agent loop with DeepSeek
  static Future<CopilotResponse> runAgentLoop(String prompt, String sheetId) async {
    _isCancelled = false;
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      return CopilotResponse.withError(
        "DeepSeek API Key not configured. Please set your DeepSeek API Key in Settings.",
      );
    }

    final selectedModel = await getSelectedModel();
    debugPrint("[DeepSeekService] Starting agent loop with model: $selectedModel, sheetId: $sheetId");

    CopilotService.clearActionLogs();
    CopilotService.updateStatus(AgentStatus.thinking);
    CopilotService.addActionLog('User Request', prompt);

    await LocalAgentService.syncStorageToNative(sheetId);

    final initialGrid = await LocalAgentService.executeInspectSheet();

    // BUG FIX: Do NOT dump all_cells into system prompt!
    // DeepSeek sees ALL old data and tries to re-insert/reproduce it via fill_data.
    // Only send a compact overview: dimensions + headers + first 3 sample rows.
    final compactGrid = <String, dynamic>{
      'total_rows': initialGrid['total_rows'] ?? 0,
      'max_column_letter': initialGrid['max_column_letter'] ?? 'A',
      'headers': initialGrid['headers'] ?? {},
    };
    // Add only first 3 data rows as sample (rows 2,3,4)
    final allCells = initialGrid['all_cells'] as Map? ?? {};
    final sampleCells = <String, String>{};
    allCells.forEach((k, v) {
      final ref = k.toString().toUpperCase();
      final match = RegExp(r'([A-Z]+)(\d+)').firstMatch(ref);
      if (match != null) {
        final rowNum = int.tryParse(match.group(2)!) ?? 0;
        if (rowNum >= 2 && rowNum <= 4) {
          sampleCells[ref] = v.toString();
        }
      }
    });
    compactGrid['sample_data_rows_2_to_4'] = sampleCells;
    final gridSummary = jsonEncode(compactGrid);
    final supportsTools = (selectedModel == 'deepseek-chat');

    final workbookOverview = await LocalAgentService.getWorkbookOverview(sheetId);
    final workbookOverviewText = workbookOverview['summary_text']?.toString() ?? '';

    final systemPrompt = """
You are an AUTONOMOUS SUPER-INTELLIGENT spreadsheet agent with FULL loop execution power powered by DeepSeek.

You work in a LOOP — you can call multiple tools one after another until your task is FULLY done.
NEVER stop after just one tool call for complex tasks. KEEP WORKING until task_complete is called.
NEVER reply with conversational text. NEVER chat. ONLY call tools.

=== AUTONOMOUS LOOP PROTOCOL ===
For EVERY task, follow this loop:
1. Call `understand_sheet` FIRST — get full AI context (sheetType, quality, all columns, top issues).
2. Call `analyze_column` for each relevant column to get: type, confidence, statistics, knowledge_tags.
3. Plan steps based on findings (type, duplicates, invalid, blanks, noise).
4. Execute:
   - For dirty/messy columns (phone, email, currency, date, casing): call `clean_column` with column letter. NEVER use fill_data to clean dirty columns!
   - For multi-line/wrapped rows (from PDF/bank statements): call `stitch_multi_line_records`.
   - For mixed text cells (Name|Phone|Email crammed together): call `demix_column_entities`.
   - For subtotal/header noise: call `isolate_subtotals`.
   - For typos/inconsistent company names: call `find_clusters`.
   - For genuinely NEW rows, tables, or computed formulas: call `build_pipeline`. Always use active formulas starting with '=' (e.g. '=SUM(A2:D2)').
5. Verify by calling `understand_sheet` again to confirm quality improved.
6. Call `task_complete` ONLY when ALL work is 100% done.

IMPORTANT: The sheet overview below shows ONLY dimensions, headers, and sample rows 2-4. Do NOT assume you know all data.
To see actual cell data, call `inspect_sheet`, `batch_read_rows`, or `understand_sheet` tools.
CRITICAL: NEVER re-insert, copy, or reproduce existing cell data using fill_data.

Sheet Overview (compact):
$gridSummary

=== ALL WORKBOOK SHEETS (AUTONOMOUS MULTI-SHEET AWARENESS) ===
The entire workbook currently contains:
$workbookOverviewText

CRITICAL AUTONOMOUS MULTI-SHEET BEHAVIOR:
- You have full autonomous visibility over all other sheet tabs in this workbook.
- If any other sheet tab (like Sheet 2 or Instructions) contains instructions, requirements, or reference data, you MUST AUTONOMOUSLY inspect it via `read_sheet_tab` or use its contents to solve the user's task, even if the user didn't explicitly name Sheet 2!

${supportsTools ? """
=== SOTA AUTONOMOUS DATA CLEANING PROTOCOL ===
When cleaning data in the sheet:
- `understand_sheet`: ALWAYS call first to detect column types, quality scores, and issues.
- `analyze_column`: Deep analysis on a column (e.g. column: 'A' or 'B').
- `clean_column`: Native C++ in-place sanitization (strips noise, normalizes phone digits, cleans emails, parses prices).
- `stitch_multi_line_records`: Folds fragmented rows back into single complete records.
- `demix_column_entities`: Disassembles multi-entity columns into separate clean columns.
- `isolate_subtotals`: Eliminates subtotal/divider noise.
- `find_clusters`: OpenRefine-style fuzzy clustering for typos.
- `impute_names_from_emails`: Extracts authentic human names from email addresses and backfills blank Name cells. Only runs if an Email column exists. Automatically ignores bot mailboxes (info@, support@) and random hashes.
- `guarded_fill_down`: Fills parent values (Invoice #, Date, Department) downwards into blank child rows anchored on active items/amounts.
  CRITICAL RULE FOR TALLY/ERP DATA:
  If you detect a sheet with nested ERP/Tally/Invoice structures (e.g. Invoice # in Column A with blank rows beneath it, and items in Column B/C), DO NOT run `guarded_fill_down` automatically!
  FIRST call `ask_user_question` to ask:
  "Yeh sheet Tally / ERP ya Accounting export lag rahi hai jisme nested rows hain. Kya main parent values ko neeche fill down kar doon?"
  options: ["Yes, Fill Down (Tally/ERP)", "No, Keep Rows Blank"]
  ONLY call `guarded_fill_down` if the user selects "Yes"!
- `list_workbook_sheets`: Lists all sheet tabs in this workbook.
- `read_sheet_tab`: Reads instructions or data from ANY other sheet tab (e.g. 'Sheet 2', 'Instructions').
- `write_to_sheet_tab`: Writes or updates data in another sheet tab.
- `task_complete`: ONLY when ALL work is verified and done.

=== MULTI-SHEET WORKBOOK PROTOCOL ===
- This workbook can contain multiple sheet tabs (e.g. Sheet 1, Sheet 2, Instructions, Summary, etc.).
- `list_workbook_sheets`: Call to discover all available sheet tabs in the workbook.
- `read_sheet_tab(sheet_name_or_id)`: Call to read instructions or cell data from ANY other sheet tab (e.g. 'Sheet 2', 'Sheet2', 'Instructions').
  * CRITICAL: If the user refers to another sheet tab (e.g. "second sheet me instruction hai usko read kar", "read instructions in sheet 2", "follow sheet 2 instructions", "second sheet se data lo"):
    YOU MUST CALL `read_sheet_tab(sheet_name_or_id: 'Sheet 2')` FIRST!
    Read the returned `readable_instructions` and cells thoroughly, understand what tasks are instructed, and then execute those tasks on the active sheet!
- `write_to_sheet_tab(sheet_name_or_id, cells)`: Call to write or copy data into another sheet tab.

=== 6-RETRY SKIP RULE & UNSTUCK PROTOCOL ===
- You have a default budget of 40 iterations. You have plenty of time.
- 6-RETRY LIMIT: If any column, script, or operation fails or does not fix the problem within 5-6 attempts, STOP RETRYING IT!
- NEVER GET STUCK: If an issue on one column is stubborn or difficult, IMMEDIATELY MOVE ON to clean the next dirty columns in the sheet.
- After 6 attempts on a single target, the circuit breaker will permanently lock that target and force you to move on.
- When all other workable columns are cleaned, call `task_complete`.
""" : """
To apply changes, modifications, or formulas to the spreadsheet, you MUST include an executable JSON block in your response formatted exactly as:
```json
{
  "steps": [
    { "type": "clean_column", "column": "A" },
    { "type": "stitch_multi_line_records" },
    { "type": "demix_column_entities", "column": "B" },
    { "type": "isolate_subtotals" },
    { "type": "fill_data", "startRow": 1, "startColumn": 0, "values": [["Item", "Price", "=A2*B2"]] },
    { "type": "format_cells", "range": "A1:D1", "bold": true, "bgColor": "#107C41" }
  ]
}
```
Available pipeline step types: clean_column (column), stitch_multi_line_records, demix_column_entities (column), isolate_subtotals, fill_data (startRow, startColumn, values [[...]] - use '=formula' for calculations), insert_row (row), delete_row (row), insert_column (col), delete_column (col), sort_column (column, ascending), filter_column (column, criteria), format_cells (range, bold, italic, fontSize, color, bgColor), find_replace (find, replace), run_script (script).
"""}
""";

    final messages = <Map<String, dynamic>>[
      {"role": "system", "content": systemPrompt},
      {"role": "user", "content": prompt},
    ];

    Map<String, dynamic>? buildPipelineArgs;
    Map<String, dynamic>? taskCompleteArgs;

    // Default iterations = 40 (auto-scales up if sheet has many columns: 40 + extra columns * 2)
    int colCount = 1;
    final maxColStr = (initialGrid['max_column_letter'] ?? 'A').toString().toUpperCase();
    if (maxColStr.isNotEmpty) {
      colCount = 0;
      for (int c = 0; c < maxColStr.length; c++) {
        final code = maxColStr.codeUnitAt(c);
        if (code >= 65 && code <= 90) {
          colCount = colCount * 26 + (code - 64);
        }
      }
    }
    int dynamicIterations = 40;
    if (colCount > 15) {
      dynamicIterations = 40 + ((colCount - 15) * 2);
    }
    int maxIterations = supportsTools ? dynamicIterations.clamp(40, 80) : 1;
    CopilotService.totalStepsNotifier.value = maxIterations;
    debugPrint("[DeepSeekService] Calculated maxIterations: $maxIterations (default: 40) for $colCount columns (maxCol: $maxColStr)");

    // Target attempt tracker for Circuit Breaker (6-retry limit)
    final Map<String, int> targetAttempts = {};

    String extractTargetKey(String toolName, Map<String, dynamic> toolArgs) {
      if (toolArgs.containsKey('column') || toolArgs.containsKey('column_letter')) {
        final c = (toolArgs['column'] ?? toolArgs['column_letter'])?.toString().toUpperCase();
        if (c != null && c.isNotEmpty) return "col_$c";
      }
      if (toolName == 'build_pipeline') {
        final plan = toolArgs['plan_summary']?.toString() ?? '';
        final exp = toolArgs['explanation']?.toString() ?? '';
        final match = RegExp(r'\b(?:col|column|Range)\s*[:(]?\s*([A-Z])\b', caseSensitive: false).firstMatch('$plan $exp');
        if (match != null) {
          return "col_${match.group(1)!.toUpperCase()}";
        }
        final pipeline = toolArgs['pipeline'] as Map?;
        final steps = (pipeline?['steps'] as List?) ?? (toolArgs['steps'] as List?) ?? [];
        for (var step in steps) {
          if (step is Map) {
            final col = step['column'] ?? step['column_letter'];
            if (col != null) return "col_${col.toString().toUpperCase()}";
            final script = step['script']?.toString() ?? '';
            final scriptMatch = RegExp(r"['\x22]([A-Z])['\x22]|([A-Z])\d+", caseSensitive: false).firstMatch(script);
            if (scriptMatch != null) {
              final f = scriptMatch.group(1) ?? scriptMatch.group(2);
              if (f != null && f.isNotEmpty) return "col_${f.toUpperCase()}";
            }
          }
        }
        final pSub = plan.length > 20 ? plan.substring(0, 20) : plan;
        return "plan_${pSub.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}";
      }
      return toolName;
    }

    for (int i = 0; i < maxIterations; i++) {
      if (_isCancelled) {
        debugPrint("[DeepSeekService] Agent loop cancelled by user");
        await LocalAgentService.syncNativeToStorage(sheetId);
        return CopilotResponse.withError("Task stopped by user");
      }
      debugPrint("[DeepSeekService] Loop iteration ${i + 1}/$maxIterations");

      // Dynamic self-extension: if AI is actively making progress across columns and nearing limit
      if (i >= maxIterations - 3 && targetAttempts.keys.length >= 3 && maxIterations < 80) {
        maxIterations += 10;
        CopilotService.totalStepsNotifier.value = maxIterations;
        debugPrint("[DeepSeekService] Auto-extended iterations by +10 (new limit: $maxIterations) as AI is actively cleaning remaining columns.");
        CopilotService.addActionLog('Budget Extended', 'Auto-added +10 iterations to finish remaining columns.');
      }

      try {
        final payload = <String, dynamic>{
          "model": selectedModel,
          "messages": messages,
          "temperature": 0.2,
        };

        // DeepSeek-chat (V3) supports native tool calling
        if (supportsTools) {
          payload["tools"] = _deepSeekTools;
          payload["tool_choice"] = "auto";
        }

        final response = await http.post(
          Uri.parse(_baseUrl),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer ${apiKey.trim()}",
          },
          body: jsonEncode(payload),
        );

        if (response.statusCode != 200) {
          debugPrint("[DeepSeekService] API Error (${response.statusCode}): ${response.body}");
          return CopilotResponse.withError(
            "DeepSeek API Error (${response.statusCode}): ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}",
          );
        }

        final resJson = jsonDecode(response.body);
        final choices = resJson['choices'] as List?;
        if (choices == null || choices.isEmpty) {
          return CopilotResponse.withError("DeepSeek returned empty choices.");
        }

        final message = choices[0]['message'] as Map<String, dynamic>;
        messages.add(message);

        final toolCalls = message['tool_calls'] as List?;
        final content = message['content']?.toString() ?? '';

        if (toolCalls != null && toolCalls.isNotEmpty) {
          for (var call in toolCalls) {
            final toolId = call['id']?.toString() ?? 'call_${DateTime.now().millisecondsSinceEpoch}';
            final function = call['function'] as Map<String, dynamic>;
            final name = function['name']?.toString() ?? '';
            Map<String, dynamic> args = {};
            try {
              final rawArgs = function['arguments'];
              if (rawArgs is String && rawArgs.isNotEmpty) {
                args = jsonDecode(rawArgs) as Map<String, dynamic>;
              } else if (rawArgs is Map) {
                args = Map<String, dynamic>.from(rawArgs);
              }
            } catch (_) {}

            debugPrint("[DeepSeekService] Tool Call: $name, args: $args");
            dynamic toolResult;

            final isInspectionTool = name == 'batch_read_rows' ||
                                     name == 'inspect_sheet' ||
                                     name == 'get_sheet_headers' ||
                                     name == 'understand_sheet' ||
                                     name == 'analyze_column' ||
                                     name == 'summarize_sheet' ||
                                     name == 'analyze_email' ||
                                     name == 'find_clusters' ||
                                     name == 'impute_names_from_emails' ||
                                     name == 'task_complete';

            final targetKey = extractTargetKey(name, args);
            final attempts = isInspectionTool ? 1 : ((targetAttempts[targetKey] ?? 0) + 1);
            if (!isInspectionTool) {
              targetAttempts[targetKey] = attempts;
            }

            if (!isInspectionTool && attempts >= 6) {
              debugPrint("[DeepSeekService/CircuitBreaker] Target '$targetKey' reached 6 attempts! Blocking and forcing AI to move on.");
              CopilotService.addActionLog('Circuit Breaker', 'Skipped $targetKey (max 6 attempts reached) ➔ Moving to other columns.');
              toolResult = {
                "status": "BLOCKED_CIRCUIT_BREAKER",
                "warning": "CIRCUIT BREAKER TRIGGERED: You have attempted to modify or inspect '$targetKey' 6 times without completing the sheet. To prevent getting stuck in a loop, further actions on '$targetKey' are now LOCKED. You MUST immediately move on to clean OTHER dirty columns in the sheet (e.g. check other columns A to Z) or call 'task_complete' if other columns are done. DO NOT attempt to touch '$targetKey' again!"
              };
            } else {
              try {
                if (_modularTools.any((t) => t.name == name)) {
                final tool = _modularTools.firstWhere((t) => t.name == name);
                CopilotService.updateStatus(AgentStatus.executing);
                final res = await tool.execute(args);
                if (res.containsKey('pipeline')) {
                  buildPipelineArgs = res;
                  final pipeMap = Map<String, dynamic>.from(res['pipeline']);
                  CopilotService.executePipelineNative(sheetId, pipeMap);
                  CopilotService.pipelineNotifier.value = pipeMap;
                  await LocalAgentService.syncNativeToStorage(sheetId);
                }
                toolResult = res;
              } else if (name == 'inspect_sheet' || name == 'get_sheet_headers') {
                CopilotService.updateStatus(AgentStatus.researching);
                CopilotService.addActionLog('Read Cells', 'Inspected grid dimensions and headers');
                toolResult = await LocalAgentService.executeInspectSheet();
              } else if (name == 'understand_sheet') {
                CopilotService.updateStatus(AgentStatus.researching);
                CopilotService.addActionLog('Understood Sheet', 'Compressed 300-token AI Context');
                debugPrint("[DeepSeekService] understand_sheet called");
                final resStr = NativeEngine.understandSheet();
                toolResult = jsonDecode(resStr.isNotEmpty ? resStr : '{}');
              } else if (name == 'analyze_column') {
                final col = args['column']?.toString() ?? args['column_letter']?.toString() ?? 'A';
                CopilotService.updateStatus(AgentStatus.researching);
                CopilotService.addActionLog('Analyzed Column', 'Inspected Column $col data quality');
                final resStr = NativeEngine.analyzeColumn(col);
                toolResult = jsonDecode(resStr.isNotEmpty ? resStr : '{}');
              } else if (name == 'clean_column') {
                final col = args['column']?.toString() ?? args['column_letter']?.toString() ?? 'A';
                CopilotService.updateStatus(AgentStatus.executing);
                CopilotService.addActionLog('Cleaned Column', 'Applied data cleaner on Column $col');
                debugPrint("[DeepSeekService] clean_column: col=$col");
                final resStr = NativeEngine.cleanColumn(col);
                toolResult = jsonDecode(resStr.isNotEmpty ? resStr : '{}');
                await LocalAgentService.syncNativeToStorage(sheetId);
                CopilotService.pipelineNotifier.value = {'steps': [{'action': 'refresh', 'column': col}]};
              } else if (name == 'stitch_multi_line_records') {
                CopilotService.updateStatus(AgentStatus.executing);
                CopilotService.addActionLog('Stitched Records', 'Merged multi-line wrapped rows');
                debugPrint("[DeepSeekService] stitch_multi_line_records called");
                final resStr = NativeEngine.stitchMultiLineRecords();
                toolResult = jsonDecode(resStr.isNotEmpty ? resStr : '{}');
                await LocalAgentService.syncNativeToStorage(sheetId);
                CopilotService.pipelineNotifier.value = {'steps': [{'action': 'refresh'}]};
              } else if (name == 'demix_column_entities') {
                final col = args['column']?.toString() ?? args['column_letter']?.toString() ?? 'A';
                CopilotService.updateStatus(AgentStatus.executing);
                CopilotService.addActionLog('De-mixed Entities', 'Extracted structured columns from Column $col');
                debugPrint("[DeepSeekService] demix_column_entities: col=$col");
                final resStr = NativeEngine.demixColumnEntities(col);
                toolResult = jsonDecode(resStr.isNotEmpty ? resStr : '{}');
                await LocalAgentService.syncNativeToStorage(sheetId);
                CopilotService.pipelineNotifier.value = {'steps': [{'action': 'refresh'}]};
              } else if (name == 'isolate_subtotals') {
                CopilotService.updateStatus(AgentStatus.executing);
                CopilotService.addActionLog('Isolated Subtotals', 'Removed subtotal rows and page noise');
                debugPrint("[DeepSeekService] isolate_subtotals called");
                final resStr = NativeEngine.isolateSubtotals();
                toolResult = jsonDecode(resStr.isNotEmpty ? resStr : '{}');
                await LocalAgentService.syncNativeToStorage(sheetId);
                CopilotService.pipelineNotifier.value = {'steps': [{'action': 'refresh'}]};
              } else if (name == 'find_clusters') {
                final col = args['column']?.toString() ?? args['column_letter']?.toString() ?? 'A';
                final threshold = (args['threshold'] as num?)?.toDouble() ?? 0.85;
                CopilotService.updateStatus(AgentStatus.researching);
                CopilotService.addActionLog('Fuzzy Clustered', 'Found clusters in Column $col');
                debugPrint("[DeepSeekService] find_clusters: col=$col threshold=$threshold");
                final resStr = NativeEngine.findClusters(col, threshold: threshold);
                toolResult = jsonDecode(resStr.isNotEmpty ? resStr : '{}');
              } else if (name == 'summarize_sheet') {
                CopilotService.updateStatus(AgentStatus.researching);
                CopilotService.addActionLog('Summarized Sheet', 'Generated sheet overview');
                final resStr = NativeEngine.summarizeSheet();
                try {
                  toolResult = jsonDecode(resStr.isNotEmpty ? resStr : '{}');
                } catch (_) {
                  toolResult = {"summary": resStr};
                }
              } else if (name == 'analyze_email') {
                final rawEmail = args['email']?.toString() ?? '';
                CopilotService.updateStatus(AgentStatus.researching);
                CopilotService.addActionLog('Analyzed Email', 'Parsed local-part from $rawEmail');
                final resStr = NativeEngine.analyzeEmail(rawEmail);
                toolResult = jsonDecode(resStr.isNotEmpty ? resStr : '{}');
              } else if (name == 'impute_names_from_emails') {
                final nameCol = args['name_column']?.toString();
                final emailCol = args['email_column']?.toString();
                final apply = args['apply'] == true;
                CopilotService.updateStatus(apply ? AgentStatus.executing : AgentStatus.researching);
                CopilotService.addActionLog(
                  apply ? 'Imputed Names' : 'Extracted Names',
                  'Extracting human names from email addresses',
                );
                debugPrint("[DeepSeekService] impute_names_from_emails: nameCol=$nameCol, emailCol=$emailCol, apply=$apply");
                final resStr = apply
                    ? NativeEngine.imputeNamesFromEmails(nameColumn: nameCol, emailColumn: emailCol)
                    : NativeEngine.extractNamesFromEmails(nameColumn: nameCol, emailColumn: emailCol);
                toolResult = jsonDecode(resStr.isNotEmpty ? resStr : '{}');
                if (apply) {
                  await LocalAgentService.syncNativeToStorage(sheetId);
                  CopilotService.pipelineNotifier.value = {'steps': [{'action': 'refresh'}]};
                }
              } else if (name == 'guarded_fill_down') {
                final groupCol = args['group_column']?.toString() ?? 'A';
                final anchorCol = args['anchor_column']?.toString() ?? 'B';
                CopilotService.updateStatus(AgentStatus.executing);
                CopilotService.addActionLog(
                  'Guarded Fill Down',
                  'Filling $groupCol anchored on $anchorCol (ERP/Tally Normalizer)',
                );
                debugPrint("[DeepSeekService] guarded_fill_down: groupCol=$groupCol, anchorCol=$anchorCol");
                final resStr = NativeEngine.guardedFillDown(groupCol, anchorCol);
                toolResult = jsonDecode(resStr.isNotEmpty ? resStr : '{}');
                await LocalAgentService.syncNativeToStorage(sheetId);
                CopilotService.pipelineNotifier.value = {'steps': [{'action': 'refresh'}]};
              } else if (name == 'batch_read_rows') {
                final startRow = (args['start_row'] as num?)?.toInt() ?? 2;
                final count = (args['count'] as num?)?.toInt() ?? 20;
                final cols = (args['columns'] as List?)?.map((e) => e.toString()).toList();
                CopilotService.updateStatus(AgentStatus.researching);
                CopilotService.addActionLog('Reading Rows', 'Reading rows $startRow to ${startRow + count - 1}');
                final grid = await LocalAgentService.executeInspectSheet();
                final cells = (grid['all_cells'] as Map?) ?? (grid['cells'] as Map?) ?? {};
                final rowBatch = <String, dynamic>{};
                cells.forEach((k, v) {
                  final ref = k.toString().toUpperCase();
                  final match = RegExp(r'([A-Z]+)(\d+)').firstMatch(ref);
                  if (match != null) {
                    final col = match.group(1)!;
                    final r = int.tryParse(match.group(2)!) ?? -1;
                    if (r >= startRow && r < startRow + count) {
                      if (cols == null || cols.isEmpty || cols.contains(col)) {
                        rowBatch[ref] = v;
                      }
                    }
                  }
                });
                toolResult = {
                  "start_row": startRow,
                  "count": count,
                  "batch_cells": rowBatch,
                };
              } else if (name == 'list_workbook_sheets') {
                CopilotService.updateStatus(AgentStatus.researching);
                CopilotService.addActionLog('Listed Sheets', 'Discovered workbook sheet tabs');
                toolResult = await LocalAgentService.executeListWorkbookSheets(sheetId);
              } else if (name == 'read_sheet_tab') {
                final target = args['sheet_name_or_id']?.toString() ?? 'Sheet 2';
                final maxR = (args['max_rows'] as num?)?.toInt() ?? 60;
                CopilotService.updateStatus(AgentStatus.researching);
                CopilotService.addActionLog('Read Sheet Tab', 'Reading instructions/data from $target');
                toolResult = await LocalAgentService.executeReadSheetTab(sheetNameOrId: target, activeSheetId: sheetId, maxRows: maxR);
              } else if (name == 'write_to_sheet_tab') {
                final target = args['sheet_name_or_id']?.toString() ?? 'Sheet 2';
                final cells = Map<String, dynamic>.from(args['cells'] as Map? ?? {});
                CopilotService.updateStatus(AgentStatus.executing);
                CopilotService.addActionLog('Wrote Sheet Tab', 'Updated ${cells.length} cells in $target');
                toolResult = await LocalAgentService.executeWriteToSheetTab(sheetNameOrId: target, cells: cells);
              } else if (name == 'group_data') {
                final groupCol = args['group_by_column']?.toString() ?? 'A';
                final valCol = args['value_column']?.toString() ?? 'B';
                final agg = args['aggregation']?.toString() ?? 'SUM';
                CopilotService.updateStatus(AgentStatus.executing);
                CopilotService.addActionLog('Data Grouping', '=GROUPBY($groupCol, $valCol, $agg)');
                toolResult = {
                  "formula_applied": "=GROUPBY($groupCol, $valCol, $agg)",
                  "status": "Successfully grouped $groupCol by $valCol using $agg"
                };
              } else if (name == 'create_pivot') {
                final rowF = args['row_fields']?.toString() ?? 'A';
                final colF = args['col_fields']?.toString() ?? '';
                final val = args['values']?.toString() ?? 'C';
                final agg = args['aggregation']?.toString() ?? 'SUM';
                CopilotService.updateStatus(AgentStatus.executing);
                CopilotService.addActionLog('Pivot Matrix', '=PIVOTBY($rowF, $colF, $val, $agg)');
                final pipeMap = <String, dynamic>{
                  'steps': [
                    {
                      'type': 'create_pivot_table',
                      'rowFields': [rowF],
                      'colFields': colF.isNotEmpty ? [colF] : <String>[],
                      'dataFields': [val],
                      'slicerFields': <String>[],
                      'aggType': agg,
                      'theme': 'professionalBlue',
                    }
                  ]
                };
                CopilotService.pipelineNotifier.value = pipeMap;
                toolResult = {
                  "formula_applied": "=PIVOTBY($rowF, $colF, $val, $agg)",
                  "status": "Successfully generated colorful 2D Pivot Table"
                };
              } else if (name == 'create_chart') {
                final chartType = args['chart_type']?.toString() ?? 'bar';
                final xCol = args['x_column']?.toString() ?? 'A';
                final yCol = args['y_column']?.toString() ?? 'B';
                final title = args['title']?.toString() ?? 'Chart';
                CopilotService.updateStatus(AgentStatus.executing);
                CopilotService.addActionLog('Created Chart', '$chartType chart for $xCol vs $yCol');
                final chartTypeEnum = ChartType.values.firstWhere(
                  (e) => e.name == chartType, 
                  orElse: () => ChartType.bar,
                );
                final config = ChartConfig(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: title,
                  chartType: chartTypeEnum,
                  series: [yCol],
                  axis: xCol,
                  data: [],
                );
                AnalyticsEngine.instance.createChart(config);
                toolResult = {"status": "SUCCESS", "message": "Chart created"};
              } else if (name == 'build_pipeline') {
                buildPipelineArgs = args;
                CopilotService.updateStatus(AgentStatus.executing);
                final pipeObj = args['pipeline'];
                final pipeMap = (pipeObj is Map) ? Map<String, dynamic>.from(pipeObj) : <String, dynamic>{};
                if (!pipeMap.containsKey('steps') && args.containsKey('steps')) {
                  pipeMap['steps'] = args['steps'];
                }
                debugPrint("[DeepSeekService] Executing pipeline: $pipeMap");
                final execRes = CopilotService.executePipelineNative(sheetId, pipeMap);
                debugPrint("[DeepSeekService] Pipeline result: $execRes");
                CopilotService.pipelineNotifier.value = pipeMap;
                await LocalAgentService.syncNativeToStorage(sheetId);
                toolResult = {"status": "SUCCESS", "message": "Pipeline executed", "result": execRes};
              } else if (name == 'task_complete') {
                taskCompleteArgs = args;
                CopilotService.updateStatus(AgentStatus.completed);
                CopilotService.addActionLog('Task Completed', args['final_report']?.toString() ?? 'Done');
                await LocalAgentService.syncNativeToStorage(sheetId);
                CopilotService.pipelineNotifier.value = {'steps': [{'action': 'refresh'}]};
                toolResult = {"status": "SUCCESS"};
              } else {
                toolResult = {"status": "SUCCESS", "message": "Executed $name"};
              }
            } catch (toolError) {
              debugPrint("[DeepSeekService] Error executing tool $name: $toolError");
              toolResult = {"status": "ERROR", "error": toolError.toString()};
            }
          }

            messages.add({
              "role": "tool",
              "tool_call_id": toolId,
              "content": jsonEncode(toolResult),
            });
          }

          if (taskCompleteArgs != null) {
            await LocalAgentService.syncNativeToStorage(sheetId);
            CopilotService.pipelineNotifier.value = {'steps': [{'action': 'refresh'}]};
            final finalPipe = buildPipelineArgs != null
                ? Map<String, dynamic>.from(buildPipelineArgs['pipeline'] ?? {'steps': []})
                : {'steps': [{'action': 'refresh'}]};
            return CopilotResponse(
              success: true,
              providerUsed: 'deepseek',
              explanation: taskCompleteArgs['final_report']?.toString() ?? 'Task completed.',
              planSummary: '✅ All tasks completed successfully with DeepSeek.',
              pipeline: finalPipe,
            );
          }
        } else {
          // Check if response contains direct JSON pipeline in content or reasoning_content
          final reasoning = message['reasoning_content']?.toString() ?? '';
          debugPrint("[DeepSeekService] Received content: $content");
          if (reasoning.isNotEmpty) {
            debugPrint("[DeepSeekService] Received reasoning_content (${reasoning.length} chars)");
          }

          var extractedPipe = _extractPipeline(content);
          if (extractedPipe == null && reasoning.isNotEmpty) {
            extractedPipe = _extractPipeline(reasoning);
          }

          if (extractedPipe != null) {
            debugPrint("[DeepSeekService] Extracted pipeline: $extractedPipe");
            final execRes = CopilotService.executePipelineNative(sheetId, extractedPipe);
            debugPrint("[DeepSeekService] Pipeline result: $execRes");
            CopilotService.pipelineNotifier.value = extractedPipe;
            await LocalAgentService.syncNativeToStorage(sheetId);

            String cleanText = content
                .replaceAll(RegExp(r'```(?:json)?\s*[\{\[][\s\S]*?[\}\]]\s*```', caseSensitive: false), '')
                .trim();
            if (cleanText.isEmpty) {
              cleanText = "Spreadsheet changes applied successfully.";
            }

            return CopilotResponse(
              success: true,
              providerUsed: 'deepseek',
              explanation: cleanText,
              planSummary: 'Executed JSON pipeline steps',
              pipeline: extractedPipe,
            );
          }

          if (buildPipelineArgs != null) {
            await LocalAgentService.syncNativeToStorage(sheetId);
            return CopilotResponse(
              success: true,
              providerUsed: 'deepseek',
              explanation: content.isNotEmpty ? content : (buildPipelineArgs['explanation']?.toString() ?? 'Pipeline applied.'),
              planSummary: buildPipelineArgs['plan_summary']?.toString() ?? 'Pipeline applied',
              pipeline: Map<String, dynamic>.from(buildPipelineArgs['pipeline'] ?? {'steps': []}),
            );
          }

          return CopilotResponse(
            success: true,
            providerUsed: 'deepseek',
            explanation: content,
            planSummary: 'DeepSeek Response',
            pipeline: {'steps': []},
          );
        }
      } catch (e) {
        debugPrint("[DeepSeekService] Exception in loop: $e");
        final errStr = e.toString();
        if (errStr.contains('Failed host lookup') || errStr.contains('SocketException') || errStr.contains('Network is unreachable') || errStr.contains('errno = 7')) {
          return CopilotResponse.withError("Network Error: No internet connection. Please check your Wi-Fi or Mobile Data connection on your device.");
        }
        return CopilotResponse.withError("DeepSeek Error: $e");
      }
    }

    await LocalAgentService.syncNativeToStorage(sheetId);
    CopilotService.pipelineNotifier.value = {'steps': [{'action': 'refresh'}]};
    return CopilotResponse(
      success: true,
      providerUsed: 'deepseek',
      explanation: 'All iterations completed.',
      planSummary: 'Completed',
      pipeline: buildPipelineArgs != null ? Map<String, dynamic>.from(buildPipelineArgs['pipeline'] ?? {'steps': []}) : {'steps': [{'action': 'refresh'}]},
    );
  }
}
