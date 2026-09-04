import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../super_engine/ffi_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'deepseek_service.dart';
import 'local_agent_service.dart';


class CopilotQuestionPayload {
  final String question;
  final List<String> options;
  final String? defaultOption;

  CopilotQuestionPayload({
    required this.question,
    required this.options,
    this.defaultOption,
  });

  factory CopilotQuestionPayload.fromJson(Map<String, dynamic> json) {
    return CopilotQuestionPayload(
      question: json['question']?.toString() ?? '',
      options: (json['options'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      defaultOption: json['default_option']?.toString(),
    );
  }
}

class CopilotResponse {
  final bool success;
  final String providerUsed;
  final String explanation;
  final String planSummary;
  final Map<String, dynamic>? pipeline;
  final CopilotQuestionPayload? questionPayload;
  final String? error;

  CopilotResponse({
    required this.success,
    required this.providerUsed,
    required this.explanation,
    required this.planSummary,
    this.pipeline,
    this.questionPayload,
    this.error,
  });

  factory CopilotResponse.fromJson(Map<String, dynamic> json) {
    final success = json['success'] ?? false;
    final providerUsed = json['provider_used'] ?? 'unknown';
    final data = json['data'] ?? {};
    
    CopilotQuestionPayload? qPayload;
    if (data['question_payload'] != null && data['question_payload'] is Map) {
      qPayload = CopilotQuestionPayload.fromJson(Map<String, dynamic>.from(data['question_payload']));
    }

    return CopilotResponse(
      success: success,
      providerUsed: providerUsed,
      explanation: data['explanation'] ?? '',
      planSummary: data['plan_summary'] ?? '',
      pipeline: data['pipeline'],
      questionPayload: qPayload,
    );
  }

  factory CopilotResponse.withError(String errorMsg) {
    return CopilotResponse(
      success: false,
      providerUsed: 'none',
      explanation: '',
      planSummary: '',
      error: errorMsg,
    );
  }
}


enum AgentStatus {
  idle,
  thinking,
  planning,
  researching,
  executing,
  waiting,
  paused,
  completed,
  failed
}

class AgentActionLog {
  final String title;
  final String detail;
  final DateTime timestamp;

  AgentActionLog({required this.title, required this.detail, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}

class CopilotService {
  static String cloudflareWorkerUrl = "https://sheet-copilot-whisper-stt.zestbizar.workers.dev";
  static String vpsServerUrl = "http://127.0.0.1:8000";
  static bool useCloudflareWorkerForAI = false;
  static String selectedProvider = "gemini";

  static final ValueNotifier<AgentStatus> agentStatusNotifier = ValueNotifier(AgentStatus.idle);
  static final ValueNotifier<List<AgentActionLog>> actionLogsNotifier = ValueNotifier([]);
  static final ValueNotifier<int> progressStepNotifier = ValueNotifier(0);
  static final ValueNotifier<int> totalStepsNotifier = ValueNotifier(1);
  static final ValueNotifier<Map<String, dynamic>?> pipelineNotifier = ValueNotifier(null);

  /// Notifier that increments every time the AI agent modifies the native grid.
  /// EditorScreen listens to this to refresh the sheet with live changes.
  static final ValueNotifier<int> gridRefreshNotifier = ValueNotifier(0);

  /// Whether the agent is currently running (not idle, paused, completed, or failed)
  static bool get isAgentRunning {
    final s = agentStatusNotifier.value;
    return s == AgentStatus.thinking || s == AgentStatus.planning ||
           s == AgentStatus.researching || s == AgentStatus.executing ||
           s == AgentStatus.waiting;
  }

  /// Tracks all sheets in the current open workbook
  static List<Map<String, String>> currentWorkbookSheets = [];
  static String? currentSpreadsheetId;

  /// The sheet ID on which the AI agent is currently actively working.
  /// Used by EditorScreen to prevent cross-sheet UI bleeding.
  static String? activeAgentSheetId;

  /// Callback registered by EditorScreen to execute real sheet tab operations
  static Future<Map<String, dynamic>> Function(String action, String sheetName)? onManageSheets;

  /// Execute sheet management action (create, switch, delete, list)
  static Future<Map<String, dynamic>> executeManageSheets({
    required String action,
    required String sheetName,
  }) async {
    if (onManageSheets != null) {
      try {
        return await onManageSheets!(action, sheetName);
      } catch (e) {
        debugPrint("[CopilotService] onManageSheets error: $e");
      }
    }
    // Fallback if UI is not registered
    final currentNames = currentWorkbookSheets.map((s) => s['name'] ?? '').toList();
    return {
      "status": "warning",
      "action": action,
      "sheet_name": sheetName,
      "message": "Sheet operation executed in workbook context.",
      "sheets": currentNames.isNotEmpty ? currentNames : ["Sheet1", sheetName],
    };
  }

  /// Update the current workbook context (sheets list and spreadsheet ID)
  static void updateWorkbookContext({
    required String spreadsheetId,
    required List<Map<String, String>> sheets,
  }) {
    currentSpreadsheetId = spreadsheetId;
    currentWorkbookSheets = List<Map<String, String>>.from(sheets);
    debugPrint("[CopilotService] Workbook context updated: spreadsheetId=$spreadsheetId, sheetsCount=${sheets.length} (${sheets.map((s) => s['name']).join(', ')})");
  }

  /// Notify listeners that the native grid was modified by the agent
  static void notifyGridChanged() {
    gridRefreshNotifier.value++;
  }

  static void updateStatus(AgentStatus status) {
    agentStatusNotifier.value = status;
    if (status == AgentStatus.completed || status == AgentStatus.idle || status == AgentStatus.failed || status == AgentStatus.paused) {
      activeAgentSheetId = null;
    }
  }

  static void addActionLog(String title, String detail) {
    final list = List<AgentActionLog>.from(actionLogsNotifier.value);
    list.add(AgentActionLog(title: title, detail: detail));
    actionLogsNotifier.value = list;
  }

  static void clearActionLogs() {
    actionLogsNotifier.value = [];
    progressStepNotifier.value = 0;
    totalStepsNotifier.value = 1;
    agentStatusNotifier.value = AgentStatus.idle;
    activeAgentSheetId = null;
  }

  /// Stop running agent loop
  static void stopAgentLoop() {
    LocalAgentService.cancelLoop();
    DeepSeekService.cancelLoop();
    activeAgentSheetId = null;
    updateStatus(AgentStatus.paused);
  }

  /// Send audio file bytes to Local Gemini API
  static Future<String?> transcribeAudioBytes(Uint8List audioBytes) async {
    return await LocalAgentService.transcribeAudioBytes(audioBytes);
  }

  /// Send prompt to AI Agent Loop Locally (Gemini or DeepSeek)
  static Future<CopilotResponse> sendPrompt({
    required String prompt,
    String sheetId = 'Sheet1',
    String context = "",
    String? provider,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final effectiveProvider = provider ?? prefs.getString('ai_agent_provider') ?? 'gemini';

    activeAgentSheetId = sheetId;
    if (effectiveProvider == 'deepseek') {
      return await DeepSeekService.runAgentLoop(prompt, sheetId);
    } else {
      return await LocalAgentService.runAgentLoop(prompt, sheetId);
    }
  }

  /// Normalizes pipeline map so step fields match C++ expectations
  static Map<String, dynamic> normalizePipeline(Map<String, dynamic> pipelineMap) {
    final copy = Map<String, dynamic>.from(pipelineMap);
    final rawSteps = copy['steps'];
    if (rawSteps is List) {
      final cleanSteps = <Map<String, dynamic>>[];
      for (final s in rawSteps) {
        if (s is Map) {
          final step = Map<String, dynamic>.from(s);
          
          // Normalize type
          if (!step.containsKey('type') || step['type'] == null || step['type'].toString().isEmpty) {
            final t = step['action'] ?? step['name'] ?? step['operation'] ?? step['step'] ?? step['command'];
            if (t != null) {
              step['type'] = t.toString();
            }
          }

          // Normalize cell ref e.g. "cell": "A1" -> row: 1, col: 1
          if (step.containsKey('cell') && (!step.containsKey('row') || !step.containsKey('col'))) {
            final cellStr = step['cell'].toString().toUpperCase();
            final match = RegExp(r'([A-Z]+)(\d+)').firstMatch(cellStr);
            if (match != null) {
              final colLetters = match.group(1)!;
              final rowNum = int.tryParse(match.group(2)!);
              int colNum = 0;
              for (int i = 0; i < colLetters.length; i++) {
                colNum = colNum * 26 + (colLetters.codeUnitAt(i) - 64);
              }
              if (rowNum != null) {
                step['row'] = rowNum;
                step['col'] = colNum;
              }
            }
          }

          // Normalize column
          if (step.containsKey('column_letter') && !step.containsKey('column')) {
            step['column'] = step['column_letter'];
          }

          // Normalize fill_data schema (support row/col/value, cell/value, and startRow/startColumn/values)
          if (step['type'] == 'fill_data') {
            int startRow = 0;
            if (step.containsKey('startRow')) {
              startRow = (step['startRow'] as num).toInt();
            } else if (step.containsKey('row')) {
              final r = (step['row'] as num).toInt();
              startRow = r > 0 ? r - 1 : 0; // Convert 1-indexed to 0-indexed
            }
            step['startRow'] = startRow;

            int startCol = 0;
            if (step.containsKey('startColumn')) {
              startCol = (step['startColumn'] as num).toInt();
            } else if (step.containsKey('col') || step.containsKey('column')) {
              final c = step['col'] ?? step['column'];
              if (c is num) {
                startCol = c.toInt() > 0 ? c.toInt() - 1 : 0; // Convert 1-indexed to 0-indexed
              } else if (c is String) {
                final colStr = c.trim().toUpperCase();
                int idx = 0;
                for (int i = 0; i < colStr.length; i++) {
                  idx = idx * 26 + (colStr.codeUnitAt(i) - 64);
                }
                startCol = idx > 0 ? idx - 1 : 0;
              }
            }
            step['startColumn'] = startCol;

            if (!step.containsKey('values') || step['values'] == null) {
              if (step.containsKey('value')) {
                step['values'] = [
                  [step['value']?.toString() ?? '']
                ];
              }
            }
          }

          // Normalize run_script
          if (step['type'] == 'run_script' || step['type'] == 'script' || step['type'] == 'javascript') {
            step['type'] = 'run_script';
            if (step.containsKey('script') && !step.containsKey('code')) {
              step['code'] = step['script'];
            }
          }

          cleanSteps.add(step);
        }
      }
      copy['steps'] = cleanSteps;
    }
    return copy;
  }

  /// Execute Pipeline JSON via Native C++ Engine
  static Map<String, dynamic> executePipelineNative(String sheetId, Map<String, dynamic> pipelineMap) {
    final normalized = normalizePipeline(pipelineMap);

    // Execute any data cleaning steps natively before/alongside pipeline
    final rawSteps = normalized['steps'];
    if (rawSteps is List) {
      for (final s in rawSteps) {
        if (s is Map) {
          final type = s['type']?.toString();
          if (type == 'clean_column') {
            final col = s['column']?.toString() ?? s['column_letter']?.toString() ?? 'A';
            NativeEngine.cleanColumn(col);
          } else if (type == 'stitch_multi_line_records' || type == 'stitch_records') {
            NativeEngine.stitchMultiLineRecords();
          } else if (type == 'demix_column_entities' || type == 'demix_column') {
            final col = s['column']?.toString() ?? s['column_letter']?.toString() ?? 'A';
            NativeEngine.demixColumnEntities(col);
          } else if (type == 'isolate_subtotals') {
            NativeEngine.isolateSubtotals();
          }
        }
      }
    }

    final jsonStr = jsonEncode(normalized);
    final rawRes = NativeEngine.pipelineExecute(sheetId, jsonStr);
    try {
      return jsonDecode(rawRes) as Map<String, dynamic>;
    } catch (_) {
      return {"status": "FATAL_ERROR", "message": "Failed to parse result"};
    }
  }
}

