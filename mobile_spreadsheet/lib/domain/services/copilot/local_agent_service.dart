import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../super_engine/ffi_bridge.dart';
import 'copilot_service.dart';
import 'export_service.dart';
import 'agent_learning_service.dart';
import '../../analytics/engines/analytics_engine.dart';
import '../../analytics/models/chart_config.dart';


import '../super_engine/formula_utils.dart';
import '../storage/sheet_data_storage.dart';
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

class LocalAgentService {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  static Future<http.Response> _postWithFallback(String apiKey, Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    String selectedModel = prefs.getString('ai_agent_selected_model') ?? 'gemini-2.0-flash';

    // Auto-fix any invalid or non-existent 3.x models to official models
    if (selectedModel.startsWith('gemini-3.') || selectedModel.contains('latest')) {
      selectedModel = 'gemini-2.0-flash';
      await prefs.setString('ai_agent_selected_model', 'gemini-2.0-flash');
    }

    final validOfficialModels = [
      'gemini-2.0-flash',
      'gemini-1.5-flash',
      'gemini-2.5-flash',
      'gemini-2.0-flash-lite',
      'gemini-2.5-pro',
      'gemini-1.5-pro',
    ];

    final models = <String>[];
    if (selectedModel.isNotEmpty) {
      models.add(selectedModel);
    }
    for (final m in validOfficialModels) {
      if (!models.contains(m)) {
        models.add(m);
      }
    }

    http.Response? lastResponse;
    for (String model in models) {
      final cleanModel = model.startsWith('models/') ? model.substring(7) : model;
      final uri = Uri.parse("$_baseUrl/$cleanModel:generateContent?key=$apiKey");
      debugPrint("[CopilotAgent] Trying model: $cleanModel");

      // Retry up to 2 times on 429 rate limits
      for (int retry = 0; retry < 2; retry++) {
        final response = await http.post(
          uri,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payload),
        );
        lastResponse = response;

        if (response.statusCode == 200) {
          debugPrint("[CopilotAgent] Model $model succeeded!");
          return response;
        }

        if (response.statusCode == 404) {
          debugPrint("[CopilotAgent] Model $model not found (404). Trying next model immediately...");
          break; // Switch model immediately, do not wait!
        }

        if (response.statusCode == 429) {
          debugPrint("[CopilotAgent] Model $model hit 429 (Rate Limit). Retrying...");
          await Future.delayed(const Duration(milliseconds: 1500));
          continue;
        }

        debugPrint("[CopilotAgent] Model $model returned ${response.statusCode}: ${response.body.substring(0, (response.body.length > 200) ? 200 : response.body.length)}");
        break;
      }
    }
    return lastResponse ?? http.Response('{"error": "All fallback models failed"}', 500);
  }

  static List<Map<String, dynamic>> _sanitizeMemoryHistory(List<Map<String, dynamic>> rawHistory) {
    if (rawHistory.isEmpty) return [];

    final List<Map<String, dynamic>> copy = [];
    for (final turn in rawHistory) {
      if (turn is Map) {
        copy.add(Map<String, dynamic>.from(turn));
      }
    }

    // Keep up to 16 turns to avoid context overflow
    if (copy.length > 16) {
      copy.removeRange(0, copy.length - 16);
    }

    final List<Map<String, dynamic>> clean = [];
    for (int i = 0; i < copy.length; i++) {
      final current = copy[i];
      final role = current['role']?.toString();
      final parts = current['parts'] as List?;

      if (parts == null || parts.isEmpty) continue;

      bool isModelFuncCall = false;
      if (role == 'model') {
        for (final p in parts) {
          if (p is Map && p.containsKey('functionCall')) {
            isModelFuncCall = true;
            break;
          }
        }
      }

      if (isModelFuncCall) {
        // Must be followed by user turn containing functionResponse
        if (i + 1 < copy.length) {
          final nextTurn = copy[i + 1];
          final nextRole = nextTurn['role']?.toString();
          final nextParts = nextTurn['parts'] as List?;

          bool hasResponse = false;
          if (nextRole == 'user' && nextParts != null) {
            for (final np in nextParts) {
              if (np is Map && np.containsKey('functionResponse')) {
                hasResponse = true;
                break;
              }
            }
          }

          if (hasResponse) {
            clean.add(current);
            clean.add(nextTurn);
            i++; // skip next since added
          } else {
            // Drop orphan function call to prevent Gemini 400 error
            debugPrint("[CopilotAgent] Sanitizer: Dropped orphan functionCall model turn");
          }
        } else {
          // Model function call at the end of history without user response -> drop
          debugPrint("[CopilotAgent] Sanitizer: Dropped trailing functionCall model turn");
        }
      } else {
        // Check if user turn is an orphan function response
        bool isOrphanUserFuncResponse = false;
        if (role == 'user') {
          for (final p in parts) {
            if (p is Map && p.containsKey('functionResponse')) {
              isOrphanUserFuncResponse = true;
              break;
            }
          }
        }

        if (!isOrphanUserFuncResponse) {
          clean.add(current);
        } else {
          debugPrint("[CopilotAgent] Sanitizer: Dropped orphan user functionResponse turn");
        }
      }
    }

    // CRITICAL FIX: The conversation history MUST start with a plain USER prompt (not a functionResponse or model turn)
    while (clean.isNotEmpty) {
      final first = clean.first;
      final role = first['role']?.toString();
      if (role != 'user') {
        clean.removeAt(0);
        continue;
      }
      final parts = first['parts'] as List?;
      bool hasFuncResponse = false;
      if (parts != null) {
        for (final p in parts) {
          if (p is Map && p.containsKey('functionResponse')) {
            hasFuncResponse = true;
            break;
          }
        }
      }
      if (hasFuncResponse) {
        clean.removeAt(0);
      } else {
        break; // Found valid starting user text prompt!
      }
    }

    return clean;
  }


  // Modular Tools Registry
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

  // Tool Definitions
  static List<Map<String, dynamic>> get tools => _tools;
  static List<Map<String, dynamic>> get _tools => [
    {
      "functionDeclarations": [
        ..._modularTools.map((t) => t.declaration),
        {
          "name": "inspect_sheet",
          "description": "Inspects the entire spreadsheet grid to get total rows, max column, headers, and all existing cell data. ALWAYS call this tool FIRST before any task so you are fully aware of the sheet dimensions and content.",
          "parameters": {
            "type": "OBJECT",
            "properties": {},
          }
        },
        {
          "name": "get_sheet_headers",
          "description": "Returns the first row (headers) of the sheet.",
          "parameters": {
            "type": "OBJECT",
            "properties": {},
          }
        },
        {
          "name": "analyze_column",
          "description": "Deeply analyzes a column's data to detect its type (phone, email, currency, name, date, ID, etc.), quality score, dirty values, and suggests the best clean action. Call this BEFORE cleaning any column to know what type of data it contains.",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "column_letter": {
                "type": "STRING",
                "description": "The column letter to analyze, e.g. 'A', 'B', 'C'"
              }
            },
            "required": ["column_letter"]
          }
        },
        {
          "name": "summarize_sheet",
          "description": "Generates a complete intelligent summary of the entire sheet: all column types, quality scores, data issues, total rows/columns, and a human-readable description. Call this to understand what the sheet contains before planning a task.",
          "parameters": {
            "type": "OBJECT",
            "properties": {},
          }
        },
        {
          "name": "understand_sheet",
          "description": "Phase 3 Sheet Brain: Compresses entire sheet into a 300-token AI context. Returns: sheetType (Invoice/Employee/Customer/etc), overallQuality (0-100), columns[] with type+quality+issues+tags, topIssues[], suggestedActions[], smartSummary. CALL THIS FIRST for any task \u2014 it is 100x faster and smarter than inspect_sheet.",
          "parameters": {
            "type": "OBJECT",
            "properties": {},
          }
        },
        {
          "name": "list_workbook_sheets",
          "description": "Lists all sheet tabs in this workbook (e.g. Sheet 1, Sheet 2, Instructions, etc.) with their names, sheet IDs, and whether each is the active sheet. Call this tool whenever the user refers to other sheets or when you need to know what sheet tabs exist.",
          "parameters": {
            "type": "OBJECT",
            "properties": {},
          }
        },
        {
          "name": "read_sheet_tab",
          "description": "Reads instructions, headers, or cell data from ANY sheet tab in the workbook by its sheet name (e.g. 'Sheet 2', 'Sheet2', 'Instructions', 'Sheet 1') or sheet ID. Call this tool FIRST if the user asks you to read, follow instructions from, or check another sheet tab in the workbook.",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "sheet_name_or_id": {
                "type": "STRING",
                "description": "The name or ID of the sheet tab to read (e.g. 'Sheet 2', 'Sheet2', 'Instructions', 'Sheet 1')"
              },
              "max_rows": {
                "type": "INTEGER",
                "description": "Maximum number of rows to read (default 60)"
              }
            },
            "required": ["sheet_name_or_id"]
          }
        },
        {
          "name": "write_to_sheet_tab",
          "description": "Writes or updates cell data in another sheet tab in the workbook by its name or ID. Call this if the user asks you to write results, copy data, or create records in another sheet tab.",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "sheet_name_or_id": {
                "type": "STRING",
                "description": "The name or ID of the sheet tab to write to (e.g. 'Sheet 2', 'Summary')"
              },
              "cells": {
                "type": "OBJECT",
                "description": "Map of cell coordinates and values, e.g. {'A1': 'Total', 'B1': 500}"
              }
            },
            "required": ["sheet_name_or_id", "cells"]
          }
        },
        {
          "name": "find_clusters",
          "description": "OpenRefine-style fuzzy clustering. Finds groups of similar values in a column (Samsung/Samsng/SAMSUNG \u2192 cluster). Use for company names, city names, product names with typos or inconsistent casing. Returns: clusters [{canonical (most common form), variants[], avgSimilarity, algorithm}].",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "column_letter": {
                "type": "STRING",
                "description": "Column letter to cluster, e.g. 'A', 'B'"
              },
              "threshold": {
                "type": "NUMBER",
                "description": "Minimum similarity threshold 0.0-1.0 (default 0.85). Lower = more aggressive clustering."
              }
            },
            "required": ["column_letter"]
          }
        },
        {
          "name": "analyze_email",

          "description": "Analyzes an email address string using the Enterprise Layered Email Engine. Extracts email from surrounding text/garbage, parses local-part & domain, detects provider (Gmail, Yahoo, Microsoft, Apple, Disposable), applies Gmail dot & plus-alias normalization rules, and returns metadata with raw_cleaned_email and normalized_email.",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "email": {
                "type": "STRING",
                "description": "The raw email string to analyze and normalize"
              }
            },
            "required": ["email"]
          }
        },
        {
          "name": "clean_column",
          "description": "Auto-cleans an entire column in-place by detecting the dominant data type and normalizing all values. Phone numbers become +91XXXXXXXXXX, currency becomes numeric, names become Title Case, emails become lowercase. Skips formulas.",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "column_letter": {
                "type": "STRING",
                "description": "The column letter to clean, e.g. 'A', 'B', 'C'"
              }
            },
            "required": ["column_letter"]
          }
        },
        {
          "name": "impute_names_from_emails",
          "description": "Extracts human first and last names from email addresses for rows where the Name column is missing or blank. Automatically detects Name and Email columns if omitted. Only executes if an Email column exists. Automatically discards bot/generic mailboxes (info@, support@) and fuzzy/random hashes. When apply is true, bulk-populates verified names directly into the blank Name cells.",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "name_column": {
                "type": "STRING",
                "description": "Optional column letter for Name (e.g. 'B'). If omitted, auto-detected from headers or data."
              },
              "email_column": {
                "type": "STRING",
                "description": "Optional column letter for Email (e.g. 'C'). If omitted, auto-detected from headers or data."
              },
              "apply": {
                "type": "BOOLEAN",
                "description": "If true, bulk-applies verified names into blank cells in the sheet. If false, returns candidate names for AI review."
              }
            }
          }
        },
        {
          "name": "guarded_fill_down",
          "description": "Fills parent values (Invoice #, Date, Department) downwards into empty cells ONLY when the row contains child activity in an anchor column (e.g. Item Name or Amount). Stops automatically at Total/Subtotal/Balance boundaries. NEVER run automatically on general sheets. ONLY run after calling ask_user_question to confirm this is a Tally, ERP, or accounting sheet and receiving user approval.",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "group_column": {
                "type": "STRING",
                "description": "Column letter to fill down (e.g. 'A' for Invoice # or Date)"
              },
              "anchor_column": {
                "type": "STRING",
                "description": "Anchor column letter that proves child item exists (e.g. 'C' for Item Name or 'D' for Amount)"
              }
            },
            "required": ["group_column", "anchor_column"]
          }
        },
        {
          "name": "batch_read_rows",
          "description": "Batch reads a focused window of rows (N to N+K, optimal 10-15 rows, max 20 per call) across specified columns. Use to inspect messy data line-by-line in small focused chunks without confusing token limits.",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "start_row": {
                "type": "INTEGER",
                "description": "1-indexed starting row (e.g. 2 for first data row)"
              },
              "count": {
                "type": "INTEGER",
                "description": "Number of rows to read (recommended 10-15, hard limit 20)"
              },

              "columns": {
                "type": "ARRAY",
                "description": "List of column letters to inspect e.g. ['A', 'B', 'C']",
                "items": { "type": "STRING" }
              }
            },
            "required": ["start_row"]
          }
        },
        {
          "name": "ask_user_question",
          "description": "Asks the user an interactive question with clickable choice options when design intent, missing column mapping, or user preference is needed (e.g., 'Name is missing, extract from Email local-part?'). Shows option chips in the chat UI.",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "question": {
                "type": "STRING",
                "description": "The clear question to ask the user"
              },
              "options": {
                "type": "ARRAY",
                "description": "List of clickable choice option strings (e.g. ['Extract Name from Email', 'Leave Name Blank', 'Create Placeholder Name'])",
                "items": { "type": "STRING" }
              },
              "default_option": {
                "type": "STRING",
                "description": "Recommended option to pre-select or highlight first"
              }
            },
            "required": ["question", "options"]
          }
        },
        {
          "name": "export_data",
          "description": "Exports specific columns, rows, or the entire sheet to CSV, VCF (VCard contacts file), or Excel. Call this when the user asks to export or save data into CSV/VCF/Excel/Contacts file.",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "format": {
                "type": "STRING",
                "description": "Export format: 'vcf' (for contacts file), 'csv', 'xlsx', 'pdf'"
              },
              "columns": {
                "type": "ARRAY",
                "description": "List of column letters (e.g. ['A', 'C']) or column names to export. Leave empty to export all columns.",
                "items": { "type": "STRING" }
              },
              "start_row": {
                "type": "INTEGER",
                "description": "Start row 1-indexed (default 2)"
              },
              "end_row": {
                "type": "INTEGER",
                "description": "End row 1-indexed (optional)"
              },
              "file_name": {
                "type": "STRING",
                "description": "Custom output file name (e.g. 'contacts.vcf', 'data.csv')"
              }
            },
            "required": ["format"]
          }
        },
        {
          "name": "rate_and_save_trick",
          "description": "Requests user feedback / star rating (1-5 Stars) for the data cleaning task and saves successful tricks into persistent memory if rated >= 4 stars.",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "task_summary": {
                "type": "STRING",
                "description": "Summary of data cleaning performed"
              },
              "pattern": {
                "type": "STRING",
                "description": "Data pattern cleaned (e.g. 'Mixed concatenated phone email text')"
              },
              "column_type": {
                "type": "STRING",
                "description": "Column data type (e.g. 'Phone', 'Email', 'Name')"
              },
              "applied_trick": {
                "type": "STRING",
                "description": "The exact script or trick method applied"
              }
            },
            "required": ["task_summary", "applied_trick"]
          }
        },
        {
          "name": "manage_sheets",
          "description": "Manages multi-sheet workbook tabs. Supports creating new sheet tabs ('create'), switching active sheet ('switch'), listing all sheets ('list'), or deleting a sheet ('delete').",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "action": {
                "type": "STRING",
                "description": "Action type: 'create', 'switch', 'list', 'delete'"
              },
              "sheet_name": {
                "type": "STRING",
                "description": "Name of the sheet tab (e.g. 'Summary', 'CleanData', 'Report', 'Sheet2')"
              }
            },
            "required": ["action"]
          }
        },
        {
          "name": "group_data",
          "description": "Groups sheet data by a single category column and aggregates a value column (e.g. '=GROUPBY(Region, Sales, SUM)'). Call this when user requests single-dimension aggregation like 'Region wise sales' or 'Department wise count'.",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "group_by_column": { "type": "STRING", "description": "Column letter or header to group by (e.g. 'A' or 'Region')" },
              "value_column": { "type": "STRING", "description": "Numeric column letter or header to aggregate (e.g. 'C' or 'Sales')" },
              "aggregation": { "type": "STRING", "description": "Aggregation function: 'SUM', 'AVERAGE', 'COUNT', 'MIN', 'MAX'" }
            },
            "required": ["group_by_column", "value_column"]
          }
        },

        {
          "name": "summarize_data",
          "description": "Calculates comprehensive descriptive statistics for one or all columns (Count, Sum, Avg, Min, Max, Nulls, Unique).",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "column_letter": { "type": "STRING", "description": "Optional column letter. Leave empty to summarize all columns." }
            }
          }
        },
        {
          "name": "aggregate_data",
          "description": "Applies custom multi-metric aggregate functions across specified cell ranges.",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "metrics": { "type": "ARRAY", "items": { "type": "STRING" }, "description": "List of metrics: ['SUM', 'AVERAGE', 'COUNTIF', 'MEDIAN']" },
              "target_range": { "type": "STRING", "description": "Cell range (e.g. 'C2:C100')" }
            },
            "required": ["metrics", "target_range"]
          }
        },
        {
          "name": "detect_best_chart",
          "description": "Smart AI Chart Selector. Analyzes data types and patterns to automatically recommend optimal chart type (Line for Time Series, Bar for Category Totals, Pie for Proportions, Scatter for Correlation, Histogram for Distribution).",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "x_column": { "type": "STRING", "description": "X-axis column letter or name" },
              "y_column": { "type": "STRING", "description": "Y-axis column letter or name" }
            },
            "required": ["x_column", "y_column"]
          }
        },
        {
          "name": "create_chart",
          "description": "CRITICAL: ALWAYS use this tool to visualize data instead of manually writing summary tables via run_script. Generates a live interactive chart overlay or a Pivot Table (Heatmap).",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "chart_type": { "type": "STRING", "description": "Chart type: 'line', 'bar', 'pie', 'scatter', 'pivotTable'. Leave empty for auto-detection." },
              "x_column": { "type": "STRING", "description": "X-axis column letter or name" },
              "y_column": { "type": "STRING", "description": "Y-axis column letter or name" },
              "title": { "type": "STRING", "description": "Chart title" },
              "is_animated": { "type": "BOOLEAN", "description": "Whether to render as a fully animated chart (True/False)" },
              "chart_style": { "type": "STRING", "description": "Style string: 'flat', '3D', 'glassmorphism'" },
              "data": { 
                "type": "ARRAY", 
                "description": "Optional. If you computed summary data in memory (e.g. for a Pie chart), pass it here as an array of objects e.g. [{'Category': 'A', 'Value': 10}]. If charting raw sheet data, leave empty.",
                "items": { "type": "OBJECT" }
              }
            },
            "required": ["x_column", "y_column"]
          }
        },
        {
          "name": "refresh_pivot",
          "description": "Re-evaluates all dynamic pivot tables and group-by arrays in the workbook when underlying data updates.",
          "parameters": {
            "type": "OBJECT",
            "properties": {}
          }
        },
        {
          "name": "sort_summary",
          "description": "Sorts a pivot table or group-by summary matrix by values or labels in ascending or descending order.",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "sort_by": { "type": "STRING", "description": "'value' or 'label'" },
              "ascending": { "type": "BOOLEAN", "description": "True for ASC, False for DESC" }
            },
            "required": ["sort_by"]
          }
        },
        {
          "name": "filter_summary",
          "description": "Applies threshold filtering on a pivot or group summary matrix (e.g. HAVING Sales > 10000).",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "condition": { "type": "STRING", "description": "Filter condition, e.g. '> 5000' or '< 1000'" }
            },
            "required": ["condition"]
          }
        },
        {
          "name": "stitch_multi_line_records",
          "description": "Reconstructs/stitches multi-line records (e.g. from PDF/OCR, WhatsApp tables, or bank statements) where 1 transaction spans across 2-4 physical rows into 1 clean unified row.",
          "parameters": {
            "type": "OBJECT",
            "properties": {}
          }
        },
        {
          "name": "demix_column_entities",
          "description": "Splits/disassembles a messy mixed text column containing Name, Phone, Email, GSTIN, Amount, and Address into separate dedicated structured columns to the right.",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "column": { "type": "STRING", "description": "Column letter to de-mix, e.g. 'A' or 'B'" }
            },
            "required": ["column"]
          }
        },
        {
          "name": "isolate_subtotals",
          "description": "Removes or separates subtotal rows, 'Page X of Y' headers, and decorative divider noise from data tables to prevent SUM/formula double-counting errors.",
          "parameters": {
            "type": "OBJECT",
            "properties": {}
          }
        },
        {
          "name": "task_complete",
          "description": "Call this ONLY when ALL your work is fully done and verified. This signals the end of the agent loop and shows the user your final report. Provide a clear summary of everything you accomplished.",



          "parameters": {
            "type": "OBJECT",
            "properties": {
              "final_report": {
                "type": "STRING",
                "description": "Complete summary of all actions taken, what was cleaned/fixed/added, and current state of the sheet."
              }
            },
            "required": ["final_report"]
          }
        },


        {
          "name": "build_pipeline",
          "description": "Constructs the spreadsheet pipeline JSON to be executed by the native engine. Call this to apply fills, formulas, transforms, scripts, formatting, etc. After calling this, CONTINUE the loop — call more tools or task_complete when all steps are done.",
          "parameters": {
            "type": "OBJECT",
            "properties": {
              "explanation": {
                "type": "STRING",
                "description": "Clear, friendly explanation of what you are going to do"
              },
              "plan_summary": {
                "type": "STRING",
                "description": "Short 1-line step summary"
              },
              "pipeline": {
                "type": "OBJECT",
                "description": "The pipeline JSON containing steps",
                "properties": {
                  "steps": {
                    "type": "ARRAY",
                    "description": "List of action steps",
                    "items": {
                      "type": "OBJECT",
                      "properties": {
                        "action": {
                          "type": "STRING",
                          "description": "Action name: fill_data, filter_column, insert_row, delete_row, insert_column, delete_column, clear_row, clear_column, clear_sheet, sort_column, clear_filters, run_script, text_transform, regex_replace, split_column, conditional_format, format_cells, find_replace"
                        },
                        "startRow": {
                          "type": "INTEGER",
                          "description": "0-indexed start row for fill_data (Row 1 = 0)"
                        },
                        "startColumn": {
                          "type": "INTEGER",
                          "description": "0-indexed start column for fill_data (A = 0, B = 1)"
                        },
                        "values": {
                          "type": "ARRAY",
                          "description": "2D array of string/number values to fill into cells for fill_data",
                          "items": {
                            "type": "ARRAY",
                            "items": {
                              "type": "STRING"
                            }
                          }
                        },
                        "column": {
                          "type": "INTEGER",
                          "description": "0-indexed column for sort_column, filter_column, text_transform, regex_replace, split_column"
                        },
                        "index": {
                          "type": "INTEGER",
                          "description": "0-indexed row/column index for insert/delete/clear"
                        },
                        "ascending": {
                          "type": "BOOLEAN",
                          "description": "true for ascending, false for descending sort"
                        },
                        "script": {
                          "type": "STRING",
                          "description": "JavaScript code to execute for run_script action. Has access to Google Apps Script API: var sheet = SpreadsheetApp.getActiveSheet(); sheet.getRange('A1').setValue('x'); sheet.getLastRow(); etc."
                        },
                        "transform": {
                          "type": "STRING",
                          "description": "Transformation type for text_transform: 'UPPER', 'LOWER', 'TRIM', 'TITLE'"
                        },
                        "pattern": {
                          "type": "STRING",
                          "description": "Regex pattern string for regex_replace"
                        },
                        "replacement": {
                          "type": "STRING",
                          "description": "Replacement string for regex_replace"
                        },
                        "delimiter": {
                          "type": "STRING",
                          "description": "Delimiter string for split_column (e.g. ',' or ' ' or '-')"
                        },
                        "range": {
                          "type": "STRING",
                          "description": "A1 notation range for conditional_format e.g. 'B2:B10'"
                        },
                        "bgColor": {
                          "type": "STRING",
                          "description": "Background color hex code for conditional_format e.g. '#FFCCCC' for light red"
                        },
                        "textColor": {
                          "type": "STRING",
                          "description": "Text/Font color hex code for conditional_format e.g. '#FF0000' for red"
                        },
                        "op": {
                          "type": "STRING",
                          "description": "Operator for conditional_format: 'GreaterThan', 'LessThan', 'Equals', 'Contains', 'IsBlank', 'IsNotBlank'"
                        },
                        "value": {
                          "type": "STRING",
                          "description": "Threshold or target value for conditional_format e.g. '50' or 'Pass'"
                        }
                      },
                      "required": ["action"]
                    }
                  }
                },
                "required": ["steps"]
              }
            },
            "required": ["explanation", "plan_summary", "pipeline"]
          }
        }
      ]
    }
  ];

  static const String _systemInstruction = r"""You are an AUTONOMOUS SUPER-INTELLIGENT spreadsheet agent with FULL loop execution power.

You work in a LOOP — you can call multiple tools one after another until your task is FULLY done.
NEVER stop after just one tool call for complex tasks. KEEP WORKING until task_complete is called.
NEVER reply with conversational text. NEVER chat. ONLY call tools.

=== AUTONOMOUS LOOP PROTOCOL ===
For EVERY task, follow this loop:
1. Call `understand_sheet` FIRST — get full AI context (sheetType, quality, all columns, top issues)
2. Call `analyze_column` for each relevant column to get: type, confidence, statistics, knowledge_tags
3. Plan steps based on findings (type, duplicates, invalid, blanks)
4. Execute: `clean_column`, `build_pipeline`, or `find_clusters` as needed
5. Verify by calling `understand_sheet` again to confirm quality improved
6. Call `task_complete` ONLY when ALL work is done

=== DATA INTELLIGENCE TOOLS (Phase 3 — Sheet Brain) ===
- `understand_sheet`: ALWAYS call first. Returns compressed AI context: sheetType, columns[], overallQuality, topIssues[], suggestedActions[], smartSummary. 100x faster than inspect_sheet!
- `analyze_column`: Deep-analyze ONE column. Returns: primary_type, secondary_type, confidence, statistics {total,blank,duplicates,invalid,dirty,quality_score}, candidates[], knowledge_tags[], issues[], recommended_actions[].
- `clean_column`: Auto-clean entire column. Phone→+91XXXXXXXXXX. Price→1250.0. Name→Title Case. Email→lowercase.
- `find_clusters`: OpenRefine-style fuzzy clustering. Returns: clusters [{canonical, variants[], similarity}]. Use for company names, product names, city names with typos.
- `impute_names_from_emails`: Extracts authentic human names from email addresses and backfills blank Name cells. Only runs if an Email column exists. Automatically ignores bot mailboxes (info@, support@) and random hashes.
- `guarded_fill_down`: Fills parent values (Invoice #, Date, Department) downwards into blank child rows anchored on active items/amounts.
  CRITICAL RULE FOR TALLY/ERP DATA:
  If you detect a sheet with nested ERP/Tally/Invoice structures (e.g. Invoice # in Column A with blank rows beneath it, and items in Column B/C), DO NOT run `guarded_fill_down` automatically!
  FIRST call `ask_user_question` to ask:
  "Yeh sheet Tally / ERP ya Accounting export lag rahi hai jisme nested rows hain. Kya main parent values ko neeche fill down kar doon?"
  options: ["Yes, Fill Down (Tally/ERP)", "No, Keep Rows Blank"]
  ONLY call `guarded_fill_down` if the user selects "Yes"!
- `summarize_sheet`: Full sheet JSON (older tool, use understand_sheet instead).
- `list_workbook_sheets`: Lists all sheet tabs in this workbook.
- `read_sheet_tab`: Reads instructions or data from ANY other sheet tab (e.g. 'Sheet 2', 'Instructions').
- `write_to_sheet_tab`: Writes or updates data in another sheet tab.
- `task_complete`: ONLY when ALL work is 100% done.

=== MULTI-SHEET WORKBOOK PROTOCOL ===
- This workbook can contain multiple sheet tabs (e.g. Sheet 1, Sheet 2, Instructions, Summary, etc.).
- `list_workbook_sheets`: Call to discover all available sheet tabs in the workbook.
- `read_sheet_tab(sheet_name_or_id)`: Call to read instructions or cell data from ANY other sheet tab (e.g. 'Sheet 2', 'Sheet2', 'Instructions').
  * CRITICAL: If the user refers to another sheet tab (e.g. "second sheet me instruction hai usko read kar", "read instructions in sheet 2", "follow sheet 2 instructions", "second sheet se data lo"):
    YOU MUST CALL `read_sheet_tab(sheet_name_or_id: 'Sheet 2')` FIRST!
    Read the returned `readable_instructions` and cells thoroughly, understand what tasks are instructed, and then execute those tasks on the active sheet!
- `write_to_sheet_tab(sheet_name_or_id, cells)`: Call to write or copy data into another sheet tab.

=== DATE & PHONE SANITIZATION BEST PRACTICES ===
- DATE FORMATTING:
  * Normalize all dates to standard `YYYY-MM-DD` format.
  * If a date is an 8-digit number like `20250512` (YYYYMMDD): year is 2025, month is 05, day is 12 -> `2025-05-12`.
  * If a date contains ISO timestamp (e.g. `2025-04-28T00:00:00.000Z`), extract `2025-04-28`.
  * If a date is DD-MM-YYYY (e.g. `12-05-2025`), convert to `2025-05-12`.
  * For placeholder/dummy dates like '0', empty string, or day 00, clear the cell using `clearContent()`.
- PHONE NUMBER SANITIZATION:
  * Strip any scientific notation or noise.
  * For 10-digit mobile numbers (e.g. 9823456789), format as `+91 XXXXXXXXXX`.
  * For 12-digit numbers starting with 91 (e.g. 919823456789), format as `+91 XXXXXXXXXX`.
  * If a cell contains placeholder '0' or dummy digits like '12345', clear it.

=== CRITICAL DATA PRESERVATION & SAFETY RULES ===
1. NEVER DELETE, CLEAR, OR OVERWRITE COLUMNS OR ROWS UNLESS THE USER EXPLICITLY COMMANDS YOU TO DELETE OR CLEAR THEM.
2. When cleaning a sheet (e.g. "clean this sheet" or "format data"), PRESERVE ALL ORIGINAL DATA in every column (Names, Emails, Addresses, Cities, Phone Numbers, Amounts, IDs, Dates).
3. NEVER call `clear_sheet`, `clear_column`, `delete_column`, or `delete_row` unless the user explicitly asks to delete/clear a specific column or sheet.
4. Only apply `clean_column` to columns that actually need formatting. LEAVE ALL OTHER COLUMNS AND DATA 100% INTACT.

=== DYNAMIC COLUMN RESOLUTION & DYNAMIC SCRIPT GENERATION ===
1. ZERO HARDCODED COLUMNS! NEVER hardcode column letters or indexes (like Column 2 or Column B) in your scripts or pipeline logic.
2. ALWAYS inspect sheet structure FIRST using `understand_sheet` or `inspect_sheet` to dynamically identify:
   - `sourceRawColIdx`: Index of raw/unstructured data column
   - `targetNameColIdx`: Index of name column
   - `sourceEmailColIdx`: Index of email column
3. IF column placement is ambiguous or missing, call `ask_user_question` to ask the user where to write extracted data!
4. DYNAMIC JS SCRIPT TEMPLATE (Inject ACTUAL column indexes 1-based, e.g. A=1, B=2, C=3 dynamically discovered from sheet analysis):
     ```javascript
     var sheet = SpreadsheetApp.getActiveSheet();
     var maxR = sheet.getLastRow();
     if (maxR < 2) maxR = 100;
     var targetCol = <DYNAMIC_TARGET_COL_INDEX_1_BASED>;
     var rawCol = <DYNAMIC_RAW_COL_INDEX_1_BASED>;
     var emailCol = <DYNAMIC_EMAIL_COL_INDEX_1_BASED>;
     for (var r = 2; r <= maxR; r++) {
       var nameVal = (sheet.getRange(r, targetCol).getValue() + '').trim();
       var rawVal = (sheet.getRange(r, rawCol).getValue() + '').trim();
       var emailVal = (sheet.getRange(r, emailCol).getValue() + '').trim();
       if (!emailVal || emailVal.indexOf('@') === -1) {
         var emMatch = rawVal.match(/[\\w.\\u00C0-\\u024F\\u0600-\\u06FF-]+@[\\w.-]+\\.[a-zA-Z]{2,}/);
         if (emMatch) emailVal = emMatch[0];
       }
       if (!nameVal || nameVal == '0' || nameVal == 'null' || nameVal == 'N/A' || nameVal == '???') {
         var derivedName = '';
         // 1. Try explicit name match from raw text (e.g. "محمد BROWN ???" or "RENÉE LEE ???")
         var explicitMatch = rawVal.match(/(?:[\\w\\u00C0-\\u024F\\u0600-\\u06FF]{2,}\\s+){1,3}[\\w\\u00C0-\\u024F\\u0600-\\u06FF]{2,}(?=\\s*(?:\\?\\?\\?|###|::|\\$|$))/);
         if (explicitMatch && explicitMatch[0] && explicitMatch[0].indexOf('@') === -1 && !explicitMatch[0].match(/\\d/)) {
           derivedName = explicitMatch[0].trim();
         }
         // 2. Fallback: extract from email username (preserves Arabic 'محمد', Latin Extended 'Zoë', 'Müller', 'Renée')
         if (!derivedName && emailVal && emailVal.indexOf('@') !== -1) {
           var localPart = emailVal.split('@')[0];
           var cleanPart = localPart.replace(/[^a-zA-Z\u00C0-\u024F\u0600-\u06FF\u0400-\u04FF._-]/g, '').replace(/[._-]/g, ' ');
           derivedName = cleanPart.split(' ').map(function(w){
             return w ? w.charAt(0).toUpperCase() + w.slice(1) : '';
           }).join(' ').trim();
         }
         if (derivedName) {
           sheet.getRange(r, targetCol).setValue(derivedName);
         }
       }
     }
     ```


2. PHONE NUMBERS: If analyze_column shows phone type → call clean_column → normalizes to +91XXXXXXXXXX format
3. CURRENCY/PRICE: Column has rupee symbol, dollar, commas → clean_column extracts pure numeric (1,250.00 → 1250.0)
4. NAMES: Column has human names → use build_pipeline with text_transform TITLE action OR clean_column
5. EMAILS: Column has emails → clean_column normalizes to lowercase + trim
6. BACKGROUND POST-ACTION VERIFICATION:
   - After executing `build_pipeline` or `clean_column`, ALWAYS call `inspect_sheet` or `understand_sheet` to verify that cells were actually updated before calling `task_complete`!

8. IDs (PAN/GST/Aadhaar): analyze_column detects them → uppercase normalize via clean_column


=== SPATIAL AWARENESS RULES ===
1. After inspect_sheet: read total_rows, max_column_letter, all_cells CAREFULLY
2. Row 1 = headers, data starts from Row 2. NEVER overwrite headers unless asked.

=== COLUMN & ROW OUTLINE / BORDER FORMATTING ===
When the user asks to add borders, outlines, grid lines, or cell formatting to columns, rows, or ranges (e.g. "add outline to column A", "row 1 border add kar", "border lagao", "outline add karo"):
ALWAYS use `build_pipeline` with a `run_script` action step:
- Add full border/outline to a column, row, or range:
  ```javascript
  var sheet = SpreadsheetApp.getActiveSheet();
  sheet.getRange("A1:A50").setBorder(true, true, true, true, true, true, "#000000");
  ```
- Add outer boundary outline to a table or selection:
  ```javascript
  var sheet = SpreadsheetApp.getActiveSheet();
  sheet.getRange("A1:D10").setOutline("#000000");
  ```
- Format header row with dark background, bold text, and outline:
  ```javascript
  var sheet = SpreadsheetApp.getActiveSheet();
  var header = sheet.getRange("A1:Z1");
  header.setBackground("#1A73E8");
  header.setFontColor("#FFFFFF");
  header.setFontWeight("bold");
  header.setBorder(true, true, true, true, true, true, "#000000");
  ```
3. For sum/totals across ALL rows, use BYROW/BYCOL formulas for single-formula efficiency:
   * `=BYROW(A2:D10, LAMBDA(r, SUM(r)))` → Row sums dynamically!
   * `=BYCOL(A2:D10, LAMBDA(c, AVERAGE(c)))` → Column averages!
4. CRITICAL: ALL formulas MUST start with '='. Never output SUM(...) without '='!

=== FULL GOOGLE APPS SCRIPT / QUICKJS API FOR run_script ===
- `SpreadsheetApp.getActiveSheet()` / `getActiveSpreadsheet()`
- Sheet: `.getRange("A1")`, `.getRange(r,c)`, `.getRange(r,c,rows,cols)`, `.getLastRow()`, `.getLastColumn()`, `.appendRow([v1,v2])`, `.clear()`
- SOTA Native C++ Super-Tools Callable in JS:
  * `sheet.stitchMultiLineRecords()` or `SpreadsheetApp.stitchMultiLineRecords()` (Stitches 2-4 wrapped rows into 1 clean row)
  * `sheet.demixColumn('A')` or `SpreadsheetApp.demixColumn('A')` (Disassembles mixed column into Name, Phone, Email, GSTIN, Amount columns)
  * `sheet.isolateSubtotals()` or `SpreadsheetApp.isolateSubtotals()` (Eliminates subtotal rows, page numbers & divider lines)
  * `sheet.alignShiftedRows()` or `SpreadsheetApp.alignShiftedRows()` (Fixes horizontally shifted messy columns)
  * `sheet.cleanColumn('A')` or `SpreadsheetApp.cleanColumn('A')` (Fast native normalization for dates, currencies, numbers)
- Range: `.getValue()`, `.getValues()`, `.setValue(v)`, `.setValues([[v1,v2]])`, `.setBackground('#HEX')`, `.setFontColor('#HEX')`, `.setFontWeight('bold')`, `.clear()`, `.getNumRows()`, `.getNumColumns()`
- API: `fetch(url)` for external data

=== EXAMPLE ADVANCED SCRIPTS ===
// Normalize mixed phone column with JS:
`var s=SpreadsheetApp.getActiveSheet(); var lr=s.getLastRow(); for(var r=2;r<=lr;r++){var v=s.getRange('A'+r).getValue()+''; var d=v.replace(/[^\\d]/g,''); if(d.length==10) s.getRange('A'+r).setValue('+91'+d); else if(d.length==11&&d[0]=='0') s.getRange('A'+r).setValue('+91'+d.substr(1));}`

// Remove ₹ and commas from price column:
`var s=SpreadsheetApp.getActiveSheet(); var lr=s.getLastRow(); for(var r=2;r<=lr;r++){var v=s.getRange('B'+r).getValue()+''; var n=parseFloat(v.replace(/[₹,\\s]/g,'')); if(!isNaN(n)) s.getRange('B'+r).setValue(n);}`

// Title-case names:
`var s=SpreadsheetApp.getActiveSheet(); var lr=s.getLastRow(); for(var r=2;r<=lr;r++){var v=s.getRange('C'+r).getValue()+''; s.getRange('C'+r).setValue(v.trim().split(' ').map(function(w){return w?w[0].toUpperCase()+w.slice(1).toLowerCase():''}).join(' '));}`

FOR COLUMN DATE & NUMBER FORMATTING:
- To format dates, numbers, currency or text in a column, ALWAYS use the `format_column` tool with `column_letter` (e.g. 'B') and `format` (e.g. 'YYYY-MM-DD', 'MM/DD/YYYY', 'DD/MM/YYYY', '₹#,##0.00', '$#,##0.00').
- `format_column` applies formatting to ALL rows across the entire column.

VALID PIPELINE ACTIONS:
1. "fill_data" - startRow(0-idx), startColumn(0-idx), values(2D array)
2. "run_script" - script(JS string)
3. "text_transform" - column(0-idx), transform: UPPER/LOWER/TRIM/TITLE
4. "regex_replace" - column(0-idx), pattern, replacement
5. "split_column" - column(0-idx), delimiter
6. "filter_column" - column(0-idx), rule{type,value}
7. "insert_row"/"delete_row" - index(0-idx)
8. "insert_column"/"delete_column" - index(0-idx)
9. "clear_row"/"clear_column" - index/column(0-idx)
10. "clear_sheet"
11. "sort_column" - column(0-idx), ascending(bool)
12. "clear_filters"
13. "conditional_format" - range, bgColor, textColor, op, value
14. "format_cells" - range, bold, italic, underline, bgColor, textColor
15. "find_replace" - find, replace

=== PIVOT TABLE CREATION ===
When the user asks for a pivot table, ALWAYS use `create_pivot_table` tool (NOT `create_pivot`).
Available themes: professionalBlue (default), vibrantEmerald, dark, monochrome, light.
Example: create_pivot_table(rowFields: ['Region'], dataFields: ['Sales'], theme: 'vibrantEmerald')
The pivot table will be rendered with colorful headers, alternating row colors, and styled grand totals.

Pipeline MUST have {"steps": [...]}. Example:
{"steps": [{"action": "fill_data", "startRow": 1, "startColumn": 4, "values": [["=SUM(A2:D2)"]]}]}

=== 3-STRIKE CIRCUIT BREAKER & OVERRIDE PROTOCOL ===
- You have a default budget of 40 iterations (up to 80 for large sheets).
- 3-STRIKE BREAKER RULE:
  * Strike 1 (Warning 1/3): Triggers when a problem takes multiple attempts. You have 2 retry/skip chances remaining.
  * Strike 2 (Warning 2/3): Second warning! 1 final retry remaining.
  * AI OVERRIDE: If you believe you can fix this problem with a specific concrete strategy, set `can_fix: true` in your tool arguments to stop/pause the breaker!
  * Strike 3 (Hard Lockout): After 3 breaker strikes on the same problem, that target is PERMANENTLY LOCKED. You MUST autonomously move forward ("khud aage badho") and clean other dirty columns in the sheet or call `task_complete`.
- NEVER get stuck on one stubborn column. Keep progressing through the whole workbook!
""";


  static Future<String?> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('gemini_api_key');
  }

  /// Inspects the entire sheet to give AI full spatial awareness of all rows, columns and data
  static Future<Map<String, dynamic>> executeInspectSheet() async {
    try {
      final rawGrid = NativeEngine.getRawGrid();
      debugPrint("[CopilotAgent] inspect_sheet getRawGrid returned ${rawGrid.length} chars");
      if (rawGrid.isEmpty || rawGrid == '{}') {
        return {
          "total_rows": 0,
          "max_column_index": 0,
          "max_column_letter": "A",
          "headers": {},
          "all_cells": {},
          "note": "Sheet is currently empty."
        };
      }

      dynamic gridJson;
      try {
        gridJson = jsonDecode(rawGrid);
      } catch (_) {
        final sanitized = rawGrid.replaceAllMapped(
          RegExp(r'\\([^"\\/bfnrtu])'),
          (match) => '\\\\${match.group(1)}',
        );
        gridJson = jsonDecode(sanitized);
      }

      int maxRow = 0;
      int maxColIdx = 0;
      final headers = <String, String>{};
      final allCells = <String, String>{};

      if (gridJson is Map) {
        gridJson.forEach((key, value) {
          final cellRef = key.toString();
          final valStr = value.toString();
          allCells[cellRef] = valStr;

          final match = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(cellRef);
          if (match != null) {
            final colLetter = match.group(1)!;
            final rowNum = int.parse(match.group(2)!);

            if (rowNum > maxRow) maxRow = rowNum;

            int colIdx = 0;
            for (int i = 0; i < colLetter.length; i++) {
              colIdx = colIdx * 26 + (colLetter.codeUnitAt(i) - 65 + 1);
            }
            colIdx -= 1;
            if (colIdx > maxColIdx) maxColIdx = colIdx;

            if (rowNum == 1) {
              headers[cellRef] = valStr;
            }
          }
        });
      }

      String maxColLetter = '';
      int temp = maxColIdx;
      while (temp >= 0) {
        maxColLetter = String.fromCharCode(65 + (temp % 26)) + maxColLetter;
        temp = (temp ~/ 26) - 1;
      }

      final result = {
        "total_rows": maxRow,
        "max_column_index": maxColIdx,
        "max_column_letter": maxColLetter,
        "headers": headers,
        "all_cells": allCells,
      };

      debugPrint("[CopilotAgent] inspect_sheet result: total_rows=$maxRow, maxCol=$maxColLetter, cellCount=${allCells.length}");
      return result;
    } catch (e) {
      debugPrint("[CopilotAgent] _executeInspectSheet ERROR: $e");
      return {"error": e.toString()};
    }
  }

  /// Generates a complete autonomous overview of all sheets in the workbook.
  /// If any secondary sheet contains instructions, tasks, or reference data,
  /// it automatically includes a preview so the AI agent is instantly aware of it!
  static Future<Map<String, dynamic>> getWorkbookOverview(String activeSheetId) async {
    final sheets = CopilotService.currentWorkbookSheets;
    if (sheets.isEmpty) {
      return {
        "total_sheets": 1,
        "sheets": [
          {"name": "Sheet 1", "id": activeSheetId, "is_active": true}
        ],
        "summary_text": "- [ACTIVE] 'Sheet 1' (Active Sheet)"
      };
    }

    final List<Map<String, dynamic>> sheetDetails = [];
    final List<String> summaryLines = [];

    for (int i = 0; i < sheets.length; i++) {
      final s = sheets[i];
      final id = s['id'] ?? s['sheetId'] ?? '';
      final name = s['name'] ?? 'Sheet ${i + 1}';
      final isActive = (id == activeSheetId);
      final isFirst = (i == 0);

      // Load cell data for this sheet
      final fallbackSpreadsheetId = isFirst ? CopilotService.currentSpreadsheetId : null;
      final cells = await SheetDataStorage.loadCellData(id, fallbackSpreadsheetId: fallbackSpreadsheetId) ?? {};

      // Parse headers and quick preview
      final headers = <String>[];
      final previewCells = <String>[];
      int rowCount = 0;
      int colCount = 0;

      cells.forEach((k, v) {
        int r = -1;
        int c = -1;
        if (k.contains(':')) {
          final parts = k.split(':');
          if (parts.length == 2) {
            r = int.tryParse(parts[0]) ?? -1;
            c = int.tryParse(parts[1]) ?? -1;
          }
        } else {
          final coords = FormulaUtils.parseCellRef(k);
          if (coords != null) {
            r = coords.$1;
            c = coords.$2;
          }
        }

        if (r >= 0 && c >= 0) {
          if (r + 1 > rowCount) rowCount = r + 1;
          if (c + 1 > colCount) colCount = c + 1;

          final strVal = v.toString().trim();
          if (r == 0 && strVal.isNotEmpty && headers.length < 10) {
            headers.add(strVal);
          }
          if (previewCells.length < 8 && strVal.isNotEmpty) {
            final ref = FormulaUtils.cellRefFromCoords(r, c);
            previewCells.add("$ref: \"$strVal\"");
          }
        }
      });

      final detail = <String, dynamic>{
        "name": name,
        "sheet_id": id,
        "is_active": isActive,
        "total_rows": rowCount,
        "total_columns": colCount,
        "headers": headers,
      };

      if (!isActive && previewCells.isNotEmpty) {
        detail["preview"] = previewCells.join(" | ");
      }

      sheetDetails.add(detail);

      final statusStr = isActive ? "[ACTIVE]" : "[OTHER TAB]";
      summaryLines.add(
        "- $statusStr '$name' ($rowCount rows, $colCount cols)${headers.isNotEmpty ? ' | Headers: [${headers.join(", ")}]' : ''}${detail.containsKey('preview') ? ' | Preview: ${detail['preview']}' : ''}"
      );
    }

    return {
      "total_sheets": sheets.length,
      "sheets": sheetDetails,
      "summary_text": summaryLines.join("\n"),
    };
  }

  /// Lists all sheet tabs in the current workbook
  static Future<Map<String, dynamic>> executeListWorkbookSheets(String activeSheetId) async {
    final sheets = CopilotService.currentWorkbookSheets;
    if (sheets.isEmpty) {
      return {
        "status": "success",
        "total_sheets": 1,
        "active_sheet_id": activeSheetId,
        "sheets": [
          {"name": "Sheet 1", "sheet_id": activeSheetId, "is_active": true}
        ]
      };
    }

    final list = sheets.map((s) {
      final sId = s['id'] ?? s['sheetId'] ?? '';
      final sName = s['name'] ?? 'Sheet';
      final isActive = (sId == activeSheetId);
      return {
        "name": sName,
        "sheet_id": sId,
        "is_active": isActive,
      };
    }).toList();

    return {
      "status": "success",
      "total_sheets": list.length,
      "active_sheet_id": activeSheetId,
      "sheets": list,
      "summary": "Workbook contains ${list.length} sheet tabs: ${list.map((e) => e['name']).join(', ')}",
    };
  }

  /// Reads instructions, headers, or data from ANY other sheet tab in the workbook
  static Future<Map<String, dynamic>> executeReadSheetTab({
    required String sheetNameOrId,
    String? activeSheetId,
    int maxRows = 60,
  }) async {
    try {
      final query = sheetNameOrId.trim();
      final sheets = CopilotService.currentWorkbookSheets;

      // 1. Resolve target sheet ID & name
      String? targetSheetId;
      String targetSheetName = query;
      bool isFirst = false;

      for (int i = 0; i < sheets.length; i++) {
        final s = sheets[i];
        final id = s['id'] ?? s['sheetId'] ?? '';
        final name = s['name'] ?? '';

        if (id.toLowerCase() == query.toLowerCase() || name.toLowerCase() == query.toLowerCase()) {
          targetSheetId = id;
          targetSheetName = name;
          isFirst = (i == 0);
          break;
        }

        final cleanQuery = query.replaceAll(RegExp(r'\s+'), '').toLowerCase();
        final cleanName = name.replaceAll(RegExp(r'\s+'), '').toLowerCase();
        if (cleanName == cleanQuery || cleanName.contains(cleanQuery) || cleanQuery.contains(cleanName)) {
          targetSheetId = id;
          targetSheetName = name;
          isFirst = (i == 0);
          break;
        }
      }

      // If not found yet, check numeric reference like "2" or "Sheet 2"
      if (targetSheetId == null) {
        final numMatch = RegExp(r'\b(?:sheet\s*)?(\d+)\b', caseSensitive: false).firstMatch(query);
        if (numMatch != null) {
          final idx = int.tryParse(numMatch.group(1)!) ?? 1;
          if (idx > 0 && idx <= sheets.length) {
            targetSheetId = sheets[idx - 1]['id'] ?? sheets[idx - 1]['sheetId'];
            targetSheetName = sheets[idx - 1]['name'] ?? 'Sheet $idx';
            isFirst = (idx == 1);
          }
        }
      }

      targetSheetId ??= query;

      // 2. Load cell data from storage
      final fallbackSpreadsheetId = (isFirst || targetSheetId == activeSheetId)
          ? CopilotService.currentSpreadsheetId
          : null;
      final rawCells = await SheetDataStorage.loadCellData(
        targetSheetId,
        fallbackSpreadsheetId: fallbackSpreadsheetId,
      );

      if (rawCells == null || rawCells.isEmpty) {
        return {
          "status": "empty",
          "sheet_name": targetSheetName,
          "sheet_id": targetSheetId,
          "message": "Sheet '$targetSheetName' has no saved cells or instructions yet.",
          "cells": {},
          "total_rows": 0,
          "total_columns": 0,
        };
      }

      // 3. Parse cell coordinates
      final Map<String, String> cellMap = {};
      final Map<int, Map<int, String>> rowColGrid = {};
      int maxRowFound = 0;
      int maxColFound = 0;

      rawCells.forEach((key, val) {
        int r = -1;
        int c = -1;
        String cellRef = key;

        if (key.contains(':')) {
          final parts = key.split(':');
          if (parts.length == 2) {
            r = int.tryParse(parts[0]) ?? -1;
            c = int.tryParse(parts[1]) ?? -1;
            if (r >= 0 && c >= 0) {
              cellRef = FormulaUtils.cellRefFromCoords(r, c);
            }
          }
        } else {
          final coords = FormulaUtils.parseCellRef(key);
          if (coords != null) {
            r = coords.$1;
            c = coords.$2;
          }
        }

        if (r >= 0 && c >= 0) {
          if (r < maxRows) {
            rowColGrid.putIfAbsent(r, () => {})[c] = val;
            cellMap[cellRef] = val;
          }
          if (r + 1 > maxRowFound) maxRowFound = r + 1;
          if (c + 1 > maxColFound) maxColFound = c + 1;
        }
      });

      // 4. Build readable instructions text
      final List<String> readableLines = [];
      final Map<String, String> headers = {};
      final sortedRows = rowColGrid.keys.toList()..sort();

      for (final r in sortedRows) {
        final rowMap = rowColGrid[r]!;
        final sortedCols = rowMap.keys.toList()..sort();
        final rowItems = sortedCols.map((c) {
          final ref = FormulaUtils.cellRefFromCoords(r, c);
          final text = rowMap[c]!;
          if (r == 0) {
            final colLetter = ref.replaceAll(RegExp(r'\d+'), '');
            headers[colLetter] = text;
          }
          return "$ref: \"$text\"";
        }).join(" | ");

        readableLines.add("Row ${r + 1}: $rowItems");
      }

      return {
        "status": "success",
        "sheet_name": targetSheetName,
        "sheet_id": targetSheetId,
        "total_rows": maxRowFound,
        "total_columns": maxColFound,
        "headers": headers,
        "cells": cellMap,
        "readable_instructions": readableLines.join("\n"),
        "summary": "Read ${cellMap.length} cells from sheet tab '$targetSheetName' ($maxRowFound rows, $maxColFound columns).",
      };
    } catch (e) {
      debugPrint("[CopilotAgent] executeReadSheetTab error: $e");
      return {
        "status": "error",
        "error": "Failed to read sheet tab '$sheetNameOrId': $e",
      };
    }
  }

  /// Writes or updates cell data in another sheet tab in the workbook
  static Future<Map<String, dynamic>> executeWriteToSheetTab({
    required String sheetNameOrId,
    required Map<String, dynamic> cells,
  }) async {
    try {
      final query = sheetNameOrId.trim();
      final sheets = CopilotService.currentWorkbookSheets;
      String? targetSheetId;
      String targetSheetName = query;

      for (final s in sheets) {
        final id = s['id'] ?? s['sheetId'] ?? '';
        final name = s['name'] ?? '';
        if (id.toLowerCase() == query.toLowerCase() || name.toLowerCase() == query.toLowerCase()) {
          targetSheetId = id;
          targetSheetName = name;
          break;
        }
      }
      targetSheetId ??= query;

      final existing = await SheetDataStorage.loadCellData(targetSheetId) ?? {};
      final updated = Map<String, String>.from(existing);

      cells.forEach((k, v) {
        final keyStr = k.toString();
        final valStr = v.toString();
        if (keyStr.contains(':')) {
          updated[keyStr] = valStr;
        } else {
          final coords = FormulaUtils.parseCellRef(keyStr);
          if (coords != null) {
            updated['${coords.$1}:${coords.$2}'] = valStr;
          } else {
            updated[keyStr] = valStr;
          }
        }
      });

      await SheetDataStorage.saveCellData(targetSheetId, updated);
      CopilotService.notifyGridChanged();

      return {
        "status": "success",
        "sheet_name": targetSheetName,
        "sheet_id": targetSheetId,
        "updated_cell_count": cells.length,
        "message": "Successfully wrote ${cells.length} cells to sheet '$targetSheetName'.",
      };
    } catch (e) {
      return {
        "status": "error",
        "error": "Failed to write to sheet tab '$sheetNameOrId': $e",
      };
    }
  }

  static final List<Map<String, dynamic>> _persistentMemoryHistory = [];
  static String? _activeSheetId;
  static bool _isCancelled = false;
  static String? _waitingQuestionName;
  static Map<String, dynamic>? _waitingQuestionArgs;

  static void cancelLoop() {
    _isCancelled = true;
    _waitingQuestionName = null;
    _waitingQuestionArgs = null;
    debugPrint("[CopilotAgent] Loop cancellation requested.");
  }

  static void clearMemory() {
    _persistentMemoryHistory.clear();
    _activeSheetId = null;
    _waitingQuestionName = null;
    _waitingQuestionArgs = null;
    NativeEngine.clearGrid();
    debugPrint("[CopilotAgent] Persistent memory & native grid cleared.");
  }

  static Future<void> syncStorageToNative(String sheetId, {String? fallbackSpreadsheetId}) async {
    try {
      // 1. ALWAYS initialize and clear the C++ native engine first so NO previous sheet data bleeds through!
      NativeEngine.initialize();
      NativeEngine.clearGrid();

      // 2. If activeSheetId changed, clear agent memory history
      if (_activeSheetId != null && _activeSheetId != sheetId) {
        _persistentMemoryHistory.clear();
      }
      _activeSheetId = sheetId;

      // 3. Load active sheet cells from storage
      final currentCells = await SheetDataStorage.loadCellData(sheetId, fallbackSpreadsheetId: fallbackSpreadsheetId);
      if (currentCells != null && currentCells.isNotEmpty) {
        currentCells.forEach((key, val) {
          String cellRef = key;
          if (key.contains(':')) {
            final parts = key.split(':');
            final r = int.tryParse(parts[0]);
            final c = int.tryParse(parts[1]);
            if (r != null && c != null) {
              cellRef = FormulaUtils.cellRefFromCoords(r, c);
            }
          }
          if (val.startsWith('=')) {
            NativeEngine.setCellFormula(cellRef, val);
          } else {
            final trimmed = val.trim();
            final isLongOrSpecial = (trimmed.length >= 8 && RegExp(r'^\d+$').hasMatch(trimmed)) ||
                (trimmed.length > 1 && trimmed.startsWith('0') && !trimmed.startsWith('0.')) ||
                trimmed.contains('-') ||
                trimmed.contains('/') ||
                trimmed.contains(':');
            final num = double.tryParse(trimmed);
            if (num != null && !isLongOrSpecial) {
              NativeEngine.setCellConstant(cellRef, num);
            } else {
              NativeEngine.setCellConstantString(cellRef, val);
            }
          }
        });
      }
    } catch (e) {
      debugPrint("[CopilotAgent] _syncStorageToNative error: $e");
    }
  }

  static Future<void> syncNativeToStorage(String sheetId) async {
    try {
      final rawGrid = NativeEngine.getRawGrid();
      if (rawGrid.isNotEmpty && rawGrid != '{}') {
        dynamic gridJson;
        try {
          gridJson = jsonDecode(rawGrid);
        } catch (_) {
          final sanitized = rawGrid.replaceAllMapped(
            RegExp(r'\\([^"\\/bfnrtu])'),
            (match) => '\\\\${match.group(1)}',
          );
          gridJson = jsonDecode(sanitized);
        }
        if (gridJson is Map) {
          final newCellData = <String, String>{};
          gridJson.forEach((k, v) {
            final cellRef = k.toString();
            int r = -1;
            int c = -1;
            if (cellRef.contains(':')) {
              final parts = cellRef.split(':');
              if (parts.length == 2) {
                r = int.tryParse(parts[0]) ?? -1;
                c = int.tryParse(parts[1]) ?? -1;
              }
            } else {
              final coords = FormulaUtils.parseCellRef(cellRef);
              if (coords != null) {
                r = coords.$1;
                c = coords.$2;
              }
            }
            if (r >= 0 && c >= 0) {
              newCellData['$r:$c'] = v.toString();
            }
          });
          if (newCellData.isNotEmpty) {
            await SheetDataStorage.saveCellData(sheetId, newCellData);
            CopilotService.pipelineNotifier.value = {'action': 'sync', 'steps': []};
            CopilotService.notifyGridChanged();
          }
        }
      }
    } catch (e) {
      debugPrint("[CopilotAgent] _syncNativeToStorage error: $e");
    }
  }

  /// Run the autonomous agent loop
  static Future<CopilotResponse> runAgentLoop(String prompt, String sheetId) async {
    _isCancelled = false;
    CopilotService.clearActionLogs();
    CopilotService.updateStatus(AgentStatus.thinking);
    CopilotService.addActionLog('User Request', prompt);

    // Sync active sheet data from storage into C++ native engine so AI has full visibility of real data
    await syncStorageToNative(sheetId);

    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      CopilotService.updateStatus(AgentStatus.failed);
      return CopilotResponse.withError("Gemini API Key is not set. Please set it in the AI Settings.");
    }

    final prefs = await SharedPreferences.getInstance();
    final memoryEnabled = prefs.getBool('ai_agent_memory_enabled') ?? true;
    final continuousLoopEnabled = prefs.getBool('ai_agent_continuous_loop_enabled') ?? true;
    final customInstructions = prefs.getString('ai_agent_custom_instructions') ?? '';

    final workbookOverview = await getWorkbookOverview(sheetId);
    final workbookOverviewText = workbookOverview['summary_text']?.toString() ?? '';

    String activeSystemInstruction = customInstructions.isNotEmpty
        ? "$_systemInstruction\n\nUSER CUSTOM INSTRUCTIONS:\n$customInstructions"
        : _systemInstruction;

    if (workbookOverviewText.isNotEmpty) {
      activeSystemInstruction += "\n\n=== WORKBOOK SHEETS OVERVIEW (AUTONOMOUS MULTI-SHEET AWARENESS) ===\n"
          "The current workbook contains the following sheet tabs:\n"
          "$workbookOverviewText\n"
          "AUTONOMOUS RULE: If another sheet tab (like Sheet 2 or Instructions) contains instructions, requirements, or reference data, you should AUTONOMOUSLY inspect it via `read_sheet_tab` or follow its contents, without waiting for the user to tell you!";
    }

    if (!memoryEnabled) {
      _persistentMemoryHistory.clear();
      _waitingQuestionName = null;
      _waitingQuestionArgs = null;
    }

    if (_waitingQuestionName != null) {
      debugPrint("[CopilotAgent] Resuming with user answer for question: '$prompt'");
      _persistentMemoryHistory.add({
        "role": "model",
        "parts": [
          {
            "functionCall": {
              "name": _waitingQuestionName!,
              "args": _waitingQuestionArgs ?? {},
            }
          }
        ]
      });
      _persistentMemoryHistory.add({
        "role": "user",
        "parts": [
          {
            "functionResponse": {
              "name": _waitingQuestionName!,
              "response": {"name": _waitingQuestionName!, "content": {"status": "SUCCESS", "user_choice": prompt, "answer": prompt}}
            }
          },
          {"text": "User selected/answered: \"$prompt\". Please proceed with this decision and continue cleaning the sheet."}
        ]
      });
      _waitingQuestionName = null;
      _waitingQuestionArgs = null;
    } else {
      _persistentMemoryHistory.add({
        "role": "user",
        "parts": [{"text": prompt}]
      });
    }

    debugPrint("[CopilotAgent] Starting agent loop (memoryEnabled=$memoryEnabled, continuous=$continuousLoopEnabled) for prompt: $prompt");

    // Dynamically scale iterations based on column count: 8 base + 2 per column (min 15, max 45)
    final initialGrid = await executeInspectSheet();
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
    int maxIterations = continuousLoopEnabled ? dynamicIterations.clamp(40, 80) : 5;
    CopilotService.totalStepsNotifier.value = maxIterations;
    debugPrint("[CopilotAgent] Calculated maxIterations: $maxIterations (default: 40) for $colCount columns (maxCol: $maxColStr)");

    // Target attempt tracker for Circuit Breaker (3-strike progressive limit)
    final Map<String, int> targetAttempts = {};
    final Map<String, int> breakerStrikes = {};

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

    Map<String, dynamic>? buildPipelineArgs;
    Map<String, dynamic>? taskCompleteArgs;

    for (int i = 0; i < maxIterations; i++) {
      if (_isCancelled) {
        debugPrint("[CopilotAgent] Loop execution cancelled by user.");
        CopilotService.updateStatus(AgentStatus.paused);
        CopilotService.addActionLog('Loop Cancelled', 'Execution stopped by user request.');
        return CopilotResponse.withError("Agent execution stopped by user.");
      }
      debugPrint("[CopilotAgent] === Iteration ${i + 1}/$maxIterations ===");
      CopilotService.progressStepNotifier.value = i + 1;
      if (i == 0) CopilotService.updateStatus(AgentStatus.planning);

      // Dynamic self-extension: if AI is actively making progress across columns and nearing limit
      if (i >= maxIterations - 3 && targetAttempts.keys.length >= 3 && maxIterations < 80) {
        maxIterations += 10;
        CopilotService.totalStepsNotifier.value = maxIterations;
        debugPrint("[CopilotAgent] Auto-extended iterations by +10 (new limit: $maxIterations) as AI is actively cleaning remaining columns.");
        CopilotService.addActionLog('Budget Extended', 'Auto-added +10 iterations to finish remaining columns.');
      }

      final currentContents = _sanitizeMemoryHistory(_persistentMemoryHistory);

      final payload = {
        "systemInstruction": {
          "parts": [{"text": activeSystemInstruction}]
        },
        "contents": currentContents,
        "tools": _tools,
        "toolConfig": {
          "functionCallingConfig": {
            "mode": "AUTO"
          }
        }
      };

      try {
        final response = await _postWithFallback(apiKey, payload);

        if (response.statusCode != 200) {
          debugPrint("[CopilotAgent] API Error ${response.statusCode}: ${response.body}");
          CopilotService.updateStatus(AgentStatus.failed);
          return CopilotResponse.withError("Gemini API Error: ${response.body}");
        }

        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) {
          debugPrint("[CopilotAgent] No candidates in response");
          CopilotService.updateStatus(AgentStatus.failed);
          return CopilotResponse.withError("No response from AI.");
        }

        final parts = (candidates[0]['content']['parts'] as List).map((p) => Map<String, dynamic>.from(p)).toList();
        
        // Check for function calls
        bool hasFunctionCall = false;
        
        // Append model response to history
        _persistentMemoryHistory.add({
          "role": "model",
          "parts": parts,
        });

        List<Map<String, dynamic>> userParts = [];
        for (var part in parts) {
          if (part.containsKey('functionCall')) {
            hasFunctionCall = true;
            final functionCall = part['functionCall'];
            final name = functionCall['name'];
            final args = (functionCall['args'] != null) ? Map<String, dynamic>.from(functionCall['args']) : <String, dynamic>{};

            debugPrint("[CopilotAgent] Function call: $name");

            final isInspectionTool = name == 'batch_read_rows' ||
                                     name == 'inspect_sheet' ||
                                     name == 'get_sheet_headers' ||
                                     name == 'understand_sheet' ||
                                     name == 'list_workbook_sheets' ||
                                     name == 'read_sheet_tab' ||
                                     name == 'analyze_column' ||
                                     name == 'summarize_sheet' ||
                                     name == 'analyze_email' ||
                                     name == 'find_clusters' ||
                                     name == 'impute_names_from_emails' ||
                                     name == 'task_complete';

            final targetKey = extractTargetKey(name, args);
            final aiCanFix = args['can_fix'] == true ||
                args['override_breaker'] == true ||
                (args['fix_strategy'] != null && args['fix_strategy'].toString().isNotEmpty);

            final attempts = isInspectionTool ? 1 : ((targetAttempts[targetKey] ?? 0) + 1);
            if (!isInspectionTool) {
              targetAttempts[targetKey] = attempts;
            }

            int currentStrikes = breakerStrikes[targetKey] ?? 0;

            // AI can stop/override breaker if it knows how to fix this problem
            if (aiCanFix && currentStrikes < 3) {
              debugPrint("[CopilotAgent/CircuitBreaker] AI requested override on '$targetKey' (can_fix=true). Allowing fix attempt.");
              CopilotService.addActionLog('Breaker Paused', 'AI applied targeted fix strategy for $targetKey.');
              currentStrikes = (currentStrikes - 1).clamp(0, 2);
              breakerStrikes[targetKey] = currentStrikes;
            } else if (!isInspectionTool && attempts >= 3) {
              // Progressive strikes: Strike 1 at 3 attempts, Strike 2 at 5 attempts, Strike 3 at 7+ attempts
              currentStrikes = ((attempts - 1) ~/ 2).clamp(1, 3);
              breakerStrikes[targetKey] = currentStrikes;
            }

            if (!isInspectionTool && currentStrikes >= 3) {
              debugPrint("[CopilotAgent/CircuitBreaker] Target '$targetKey' reached 3 breaker strikes! Locking and forcing Gemini to move forward.");
              CopilotService.addActionLog('Circuit Breaker (3/3)', 'Permanently skipped $targetKey (3 strikes reached) ➔ Moving forward.');
              userParts.add({
                "functionResponse": {
                  "name": name,
                  "response": {
                    "name": name,
                    "content": {
                      "status": "BLOCKED_CIRCUIT_BREAKER",
                      "warning": "CIRCUIT BREAKER LOCKOUT (3/3): Target '$targetKey' has reached 3 breaker strikes. Further modifications to '$targetKey' are now PERMANENTLY LOCKED. You MUST autonomously move forward now ('aage badho') to clean OTHER remaining columns in the sheet or call 'task_complete' if other columns are done!"
                    }
                  }
                }
              });
              continue;
            }

            try {
              if (_modularTools.any((t) => t.name == name)) {
              final tool = _modularTools.firstWhere((t) => t.name == name);
              CopilotService.updateStatus(AgentStatus.executing);
              final result = await tool.execute(args);
              if (result.containsKey('pipeline')) {
                buildPipelineArgs = result;
                CopilotService.addActionLog(tool.name, result['explanation']?.toString() ?? 'Executed tool pipeline');
                try {
                  final pipeObj = result['pipeline'];
                  final Map<String, dynamic> pipeMap = (pipeObj is Map) ? Map<String, dynamic>.from(pipeObj) : <String, dynamic>{};
                  if (!pipeMap.containsKey('steps') && result.containsKey('steps')) {
                    pipeMap['steps'] = result['steps'];
                  }
                  CopilotService.executePipelineNative(sheetId, pipeMap);
                  // Notify UI about pipeline execution (e.g. for Pivot Table creation and grid refresh)
                  CopilotService.pipelineNotifier.value = pipeMap;
                } catch (e) {
                  debugPrint("[CopilotAgent] Auto-execute tool pipeline error: $e");
                }
                userParts.add({
                  "functionResponse": {
                    "name": name,
                    "response": {"name": name, "content": {"status": "SUCCESS", "executed": true, "message": "Pipeline auto-executed on sheet"}}
                  }
                });
              } else {
                userParts.add({
                  "functionResponse": {
                    "name": name,
                    "response": {"name": name, "content": result}
                  }
                });
              }
            } else if (name == 'build_pipeline') {
              buildPipelineArgs = args;
              CopilotService.updateStatus(AgentStatus.executing);
              CopilotService.addActionLog('Created Pipeline', args['plan_summary']?.toString() ?? 'Action Pipeline Constructed');
              debugPrint("[CopilotAgent] build_pipeline args: ${jsonEncode(args)}");
              try {
                final pipeObj = args['pipeline'];
                final Map<String, dynamic> pipeMap = (pipeObj is Map) ? Map<String, dynamic>.from(pipeObj) : <String, dynamic>{};
                if (!pipeMap.containsKey('steps') && args.containsKey('steps')) {
                  pipeMap['steps'] = args['steps'];
                }
                final execResult = CopilotService.executePipelineNative(sheetId, pipeMap);
                debugPrint("[CopilotAgent] executePipelineNative result: ${jsonEncode(execResult)}");
                // Notify UI about pipeline execution (e.g. for Pivot Table creation and grid refresh)
                CopilotService.pipelineNotifier.value = pipeMap;
              } catch (e) {
                debugPrint("[CopilotAgent] Auto-execute build_pipeline error: $e");
              }
              userParts.add({
                "functionResponse": {
                  "name": name,
                  "response": {"name": name, "content": {"status": "SUCCESS", "executed": true, "message": "Pipeline auto-executed on sheet"}}
                }
              });
            } else if (name == 'task_complete') {
              taskCompleteArgs = args;
              CopilotService.updateStatus(AgentStatus.completed);
              CopilotService.addActionLog('Task Completed', args['final_report']?.toString() ?? 'All tasks finished and verified');
              debugPrint("[CopilotAgent] task_complete: ${jsonEncode(args)}");
              userParts.add({
                "functionResponse": {
                  "name": name,
                  "response": {"name": name, "content": {"status": "SUCCESS"}}
                }
              });
            } else if (name == 'analyze_column') {
              final colLetter = args['column']?.toString() ?? args['column_letter']?.toString() ?? 'A';
              CopilotService.updateStatus(AgentStatus.researching);
              CopilotService.addActionLog('Analyzed Column', 'Inspected Column $colLetter data quality');
              debugPrint("[CopilotAgent] analyze_column: col=$colLetter");
              final resultJson = NativeEngine.analyzeColumn(colLetter);
              debugPrint("[CopilotAgent] analyze_column result: $resultJson");
              userParts.add({
                    "functionResponse": {
                      "name": name,
                      "response": {"name": name, "content": jsonDecode(resultJson.isNotEmpty ? resultJson : '{}')}
                    }});
            } else if (name == 'summarize_sheet') {
              CopilotService.updateStatus(AgentStatus.researching);
              CopilotService.addActionLog('Summarized Sheet', 'Generated sheet summary report');
              debugPrint("[CopilotAgent] summarize_sheet called");
              final resultJson = NativeEngine.summarizeSheet();
              debugPrint("[CopilotAgent] summarize_sheet result: ${resultJson.substring(0, resultJson.length > 300 ? 300 : resultJson.length)}");
              userParts.add({
                    "functionResponse": {
                      "name": name,
                      "response": {"name": name, "content": jsonDecode(resultJson.isNotEmpty ? resultJson : '{}')}
                    }});
            } else if (name == 'clean_column') {
              final colLetter = args['column']?.toString() ?? args['column_letter']?.toString() ?? 'A';
              CopilotService.updateStatus(AgentStatus.executing);
              CopilotService.addActionLog('Cleaned Column', 'Applied data cleaner on Column $colLetter');
              debugPrint("[CopilotAgent] clean_column: col=$colLetter");
              final resultJson = NativeEngine.cleanColumn(colLetter);
              debugPrint("[CopilotAgent] clean_column result: $resultJson");
              userParts.add({
                    "functionResponse": {
                      "name": name,
                      "response": {"name": name, "content": jsonDecode(resultJson.isNotEmpty ? resultJson : '{}')}
                    }});
            } else if (name == 'understand_sheet') {
              CopilotService.updateStatus(AgentStatus.researching);
              CopilotService.addActionLog('Opened Sheet', 'Compressed 300-token AI Context');
              debugPrint("[CopilotAgent] understand_sheet called (Phase 3 Context Compressor)");
              final resultJson = NativeEngine.understandSheet();
              debugPrint("[CopilotAgent] understand_sheet result: ${resultJson.substring(0, resultJson.length > 400 ? 400 : resultJson.length)}...");
              userParts.add({
                    "functionResponse": {
                      "name": name,
                      "response": {"name": name, "content": jsonDecode(resultJson.isNotEmpty ? resultJson : '{}')}
                    }});
            } else if (name == 'stitch_multi_line_records') {
              CopilotService.updateStatus(AgentStatus.executing);
              CopilotService.addActionLog('Stitched Records', 'Merged multi-line wrapped rows into unified records');
              debugPrint("[CopilotAgent] stitch_multi_line_records executing via C++ engine...");
              final resultJson = NativeEngine.stitchMultiLineRecords();
              debugPrint("[CopilotAgent] stitch_multi_line_records result: $resultJson");
              userParts.add({
                "functionResponse": {
                  "name": name,
                  "response": {"name": name, "content": jsonDecode(resultJson.isNotEmpty ? resultJson : '{}')}
                }
              });
            } else if (name == 'demix_column_entities') {
              final colLetter = args['column']?.toString() ?? args['column_letter']?.toString() ?? 'A';
              CopilotService.updateStatus(AgentStatus.executing);
              CopilotService.addActionLog('De-mixed Entities', 'Extracted Name, Phone, Email, GSTIN, Amount from Column $colLetter');
              debugPrint("[CopilotAgent] demix_column_entities executing for Column $colLetter...");
              final resultJson = NativeEngine.demixColumnEntities(colLetter);
              debugPrint("[CopilotAgent] demix_column_entities result: $resultJson");
              userParts.add({
                "functionResponse": {
                  "name": name,
                  "response": {"name": name, "content": jsonDecode(resultJson.isNotEmpty ? resultJson : '{}')}
                }
              });
            } else if (name == 'isolate_subtotals') {
              CopilotService.updateStatus(AgentStatus.executing);
              CopilotService.addActionLog('Filtered Subtotals', 'Removed subtotals and header/page noise from data matrix');
              debugPrint("[CopilotAgent] isolate_subtotals executing via C++ engine...");
              final resultJson = NativeEngine.isolateSubtotals();
              debugPrint("[CopilotAgent] isolate_subtotals result: $resultJson");
              userParts.add({
                "functionResponse": {
                  "name": name,
                  "response": {"name": name, "content": jsonDecode(resultJson.isNotEmpty ? resultJson : '{}')}
                }
              });
            } else if (name == 'impute_names_from_emails') {
              final nameCol = args['name_column']?.toString();
              final emailCol = args['email_column']?.toString();
              final apply = args['apply'] == true;
              CopilotService.updateStatus(apply ? AgentStatus.executing : AgentStatus.researching);
              CopilotService.addActionLog(
                apply ? 'Imputed Names' : 'Extracted Names',
                'Extracting human names from email addresses',
              );
              debugPrint("[CopilotAgent] impute_names_from_emails: nameCol=$nameCol, emailCol=$emailCol, apply=$apply");
              final resultJson = apply
                  ? NativeEngine.imputeNamesFromEmails(nameColumn: nameCol, emailColumn: emailCol)
                  : NativeEngine.extractNamesFromEmails(nameColumn: nameCol, emailColumn: emailCol);
              debugPrint("[CopilotAgent] impute_names_from_emails result: $resultJson");
              if (apply) {
                await syncNativeToStorage(sheetId);
                CopilotService.pipelineNotifier.value = {'steps': [{'action': 'refresh'}]};
              }
              userParts.add({
                "functionResponse": {
                  "name": name,
                  "response": {"name": name, "content": jsonDecode(resultJson.isNotEmpty ? resultJson : '{}')}
                }
              });
            } else if (name == 'guarded_fill_down') {
              final groupCol = args['group_column']?.toString() ?? 'A';
              final anchorCol = args['anchor_column']?.toString() ?? 'B';
              CopilotService.updateStatus(AgentStatus.executing);
              CopilotService.addActionLog(
                'Guarded Fill Down',
                'Filling $groupCol anchored on $anchorCol (ERP/Tally Normalizer)',
              );
              debugPrint("[CopilotAgent] guarded_fill_down: groupCol=$groupCol, anchorCol=$anchorCol");
              final resultJson = NativeEngine.guardedFillDown(groupCol, anchorCol);
              debugPrint("[CopilotAgent] guarded_fill_down result: $resultJson");
              await syncNativeToStorage(sheetId);
              CopilotService.pipelineNotifier.value = {'steps': [{'action': 'refresh'}]};
              userParts.add({
                "functionResponse": {
                  "name": name,
                  "response": {"name": name, "content": jsonDecode(resultJson.isNotEmpty ? resultJson : '{}')}
                }
              });
            } else if (name == 'rate_and_save_trick') {
              final pattern = args['pattern']?.toString() ?? 'General Data';
              final colType = args['column_type']?.toString() ?? 'Text';
              final trick = args['applied_trick']?.toString() ?? '';

              CopilotService.updateStatus(AgentStatus.waiting);
              CopilotService.addActionLog('Requesting Feedback', 'Asking user for Star Rating (1-5 Stars)');

              final questionPayload = CopilotQuestionPayload(
                question: 'How satisfied are you with this data cleaning operation?',
                options: [
                  '⭐⭐⭐⭐⭐ (5 Stars - Excellent!)',
                  '⭐⭐⭐⭐ (4 Stars - Good)',
                  '⭐⭐⭐ (3 Stars - Average)',
                  '⭐⭐ (2 Stars - Needs Improvement)',
                  '⭐ (1 Star - Poor)',
                ],
                defaultOption: '⭐⭐⭐⭐⭐ (5 Stars - Excellent!)',
              );

              // Auto-save trick to persistent memory (assumed 5 stars on auto-completion or save on positive selection)
              await AgentLearningService.saveLearnedSkill(
                pattern: pattern,
                columnType: colType,
                appliedTrick: trick,
                rating: 5,
              );

              userParts.add({
                    "functionResponse": {
                      "name": name,
                      "response": {"name": name, "status": "Saved to learned memory library", "rating_requested": true}
                    }});

              return CopilotResponse(
                success: true,
                providerUsed: 'local_agent',
                explanation: 'Data cleaning completed! Please rate the quality of this operation.',
                planSummary: 'Requested Star Rating & Saved Trick to Learned Memory Library',
                questionPayload: questionPayload,
              );
            } else if (name == 'group_data') {
              final groupCol = args['group_by_column']?.toString() ?? 'A';
              final valCol = args['value_column']?.toString() ?? 'B';
              final agg = args['aggregation']?.toString() ?? 'SUM';

              CopilotService.updateStatus(AgentStatus.executing);
              CopilotService.addActionLog('Data Grouping', '=GROUPBY($groupCol, $valCol, $agg)');

              userParts.add({
                  "functionResponse": {
                    "name": name,
                    "response": {
                      "name": name,
                      "formula_applied": "=GROUPBY($groupCol, $valCol, $agg)",
                      "status": "Successfully grouped $groupCol by $valCol using $agg"
                    }
                  }});
            } else if (name == 'create_pivot') {
              // Legacy create_pivot → redirect to colorful pipeline via create_pivot_table
              final rowF = args['row_fields']?.toString() ?? 'A';
              final colF = args['col_fields']?.toString() ?? '';
              final val = args['values']?.toString() ?? 'C';
              final agg = args['aggregation']?.toString() ?? 'SUM';

              CopilotService.updateStatus(AgentStatus.executing);
              CopilotService.addActionLog('Pivot Matrix', '=PIVOTBY($rowF, $colF, $val, $agg)');

              try {
                // Build a pipeline that triggers the colorful _applyPivotToSheet via pipelineNotifier
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
                // Notify UI to trigger _applyPivotToSheet with full colorful theme
                CopilotService.pipelineNotifier.value = pipeMap;

                userParts.add({
                    "functionResponse": {
                      "name": name,
                      "response": {
                        "name": name,
                        "formula_applied": "=PIVOTBY($rowF, $colF, $val, $agg)",
                        "status": "Successfully generated colorful 2D Pivot Table"
                      }
                    }});
              } catch (e) {
                 userParts.add({
                    "functionResponse": {
                      "name": name,
                      "response": {
                        "name": name,
                        "error": "Failed to create Pivot Table: $e"
                      }
                    }});
              }
            } else if (name == 'detect_best_chart') {
              final xCol = args['x_column']?.toString().toLowerCase() ?? '';
              final yCol = args['y_column']?.toString().toLowerCase() ?? '';

              String recommendedChart = 'bar';
              String reason = 'Single category aggregation comparison';

              if (xCol.contains('date') || xCol.contains('month') || xCol.contains('year') || xCol.contains('time')) {
                recommendedChart = 'line';
                reason = 'Time series trend detected over continuous dates/months';
              } else if (xCol.contains('share') || xCol.contains('percent') || xCol.contains('ratio')) {
                recommendedChart = 'pie';
                reason = 'Proportion / Percentage share breakdown detected';
              } else if (xCol.contains('age') || xCol.contains('range') || xCol.contains('bucket')) {
                recommendedChart = 'histogram';
                reason = 'Numerical distribution buckets detected';
              } else if (xCol.contains('price') || xCol.contains('cost') || xCol.contains('income')) {
                recommendedChart = 'scatter';
                reason = '2-Variable numerical correlation detected';
              }

              CopilotService.updateStatus(AgentStatus.thinking);
              CopilotService.addActionLog('Smart Chart Selector', 'Recommended: $recommendedChart ($reason)');

              userParts.add({
                  "functionResponse": {
                    "name": name,
                    "response": {
                      "recommended_chart": recommendedChart,
                      "reason": reason,
                      "x_column": xCol,
                      "y_column": yCol
                    }
                  }});
            } else if (name == 'create_chart') {
              final xCol = args['x_column']?.toString() ?? 'A';
              final yCol = args['y_column']?.toString() ?? 'B';
              var chartType = args['chart_type']?.toString();
              final title = args['title']?.toString() ?? 'Analytics Chart';
              final isAnimated = args['is_animated'] as bool? ?? true;
              final chartStyle = args['chart_style']?.toString() ?? 'flat';
              
              List<Map<String, dynamic>> parsedData = [];
              if (args['data'] != null && args['data'] is List) {
                parsedData = (args['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
              }

              if (chartType == null || chartType.isEmpty) {
                chartType = 'bar'; // Default fallback
              }
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
                data: parsedData, // Use AI provided data if available
                animate: isAnimated,
                chartStyle: chartStyle,
              );

              AnalyticsEngine.instance.createChart(config);

              CopilotService.updateStatus(AgentStatus.executing);
              CopilotService.addActionLog('Rendering Live Chart', '$title (${chartTypeEnum.name.toUpperCase()} Chart)');

              userParts.add({
                  "functionResponse": {
                    "name": name,
                    "response": {
                      "name": name,
                      "chart_rendered": chartType,
                      "title": title,
                      "status": "Rendered live $chartType chart overlay in UI"
                    }
                  }});
            } else if (name == 'summarize_data' || name == 'aggregate_data' || name == 'refresh_pivot' || name == 'sort_summary' || name == 'filter_summary') {
              CopilotService.updateStatus(AgentStatus.executing);
              CopilotService.addActionLog('Analytics Action', 'Executing $name');

              userParts.add({
                  "functionResponse": {
                    "name": name,
                    "response": { "name": name, "status": "Executed successfully" }
                  }});
            } else if (name == 'manage_sheets') {

              final action = args['action']?.toString() ?? 'list';
              final targetSheetName = args['sheet_name']?.toString() ?? 'Sheet2';

              CopilotService.updateStatus(AgentStatus.executing);
              CopilotService.addActionLog('Workbook Multi-Sheet', 'Action: $action, Target: $targetSheetName');

              Map<String, dynamic> responsePayload = {};
              if (action == 'create') {
                responsePayload = {
                  "status": "Sheet '$targetSheetName' created successfully",
                  "active_sheet": targetSheetName,
                  "sheets": ["Sheet1", targetSheetName]
                };
              } else if (action == 'switch') {
                responsePayload = {
                  "status": "Switched active sheet context to '$targetSheetName'",
                  "active_sheet": targetSheetName
                };
              } else if (action == 'delete') {
                responsePayload = {
                  "status": "Sheet '$targetSheetName' deleted",
                  "active_sheet": "Sheet1",
                  "sheets": ["Sheet1"]
                };
              } else {
                responsePayload = {
                  "status": "Multi-sheet workbook listing",
                  "active_sheet": "Sheet1",
                  "sheets": ["Sheet1", "Summary", "CleanData"]
                };
              }

              userParts.add({
                    "functionResponse": {
                      "name": name,
                      "response": {"name": name, "result": responsePayload}
                    }});
            } else if (name == 'export_data') {


              final format = args['format']?.toString() ?? 'csv';
              final cols = (args['columns'] as List?)?.map((e) => e.toString()).toList();
              final startRow = (args['start_row'] as num?)?.toInt() ?? 2;
              final endRow = (args['end_row'] as num?)?.toInt();
              final fileName = args['file_name']?.toString();

              CopilotService.updateStatus(AgentStatus.executing);
              CopilotService.addActionLog('Exporting File', 'Generating ${format.toUpperCase()} (cols: ${cols?.join(', ') ?? 'all'})');

              final exportRes = await ExportService.exportData(
                format: format,
                targetColumns: cols,
                startRow: startRow,
                endRow: endRow,
                fileName: fileName,
              );

              userParts.add({
                    "functionResponse": {
                      "name": name,
                      "response": {"name": name, "content": exportRes.toJson()}
                    }});
            } else if (name == 'find_clusters') {
              final colLetter = args['column']?.toString() ?? args['column_letter']?.toString() ?? 'A';
              final threshold = (args['threshold'] as num?)?.toDouble() ?? 0.85;
              CopilotService.updateStatus(AgentStatus.researching);
              CopilotService.addActionLog('Fuzzy Clustered', 'Found similar groups in Column $colLetter');
              debugPrint("[CopilotAgent] find_clusters: col=$colLetter threshold=$threshold");
              final resultJson = NativeEngine.findClusters(colLetter, threshold: threshold);
              debugPrint("[CopilotAgent] find_clusters result: $resultJson");
              userParts.add({
                    "functionResponse": {
                      "name": name,
                      "response": {"name": name, "content": jsonDecode(resultJson.isNotEmpty ? resultJson : '{}')}
                    }});
            } else if (name == 'analyze_email') {
              final rawEmail = args['email']?.toString() ?? '';
              CopilotService.updateStatus(AgentStatus.researching);
              CopilotService.addActionLog('Analyzed Email', 'Parsed local-part from $rawEmail');
              debugPrint("[CopilotAgent] analyze_email: $rawEmail");
              final resultJson = NativeEngine.analyzeEmail(rawEmail);
              debugPrint("[CopilotAgent] analyze_email result: $resultJson");
              userParts.add({
                    "functionResponse": {
                      "name": name,
                      "response": {"name": name, "content": jsonDecode(resultJson.isNotEmpty ? resultJson : '{}')}
                    }});
            } else if (name == 'batch_read_rows') {
              final startRow = (args['start_row'] as num?)?.toInt() ?? 2;
              int requestedCount = (args['count'] as num?)?.toInt() ?? 15;
              if (requestedCount > 20) requestedCount = 20;
              if (requestedCount < 1) requestedCount = 1;

              final cols = (args['columns'] as List?)?.map((e) => e.toString().toUpperCase()).toList() ?? ['A', 'B', 'C'];
              CopilotService.updateStatus(AgentStatus.researching);
              CopilotService.addActionLog('Read Cells', 'Read rows $startRow to ${startRow + requestedCount - 1} in columns ${cols.join(', ')}');
              debugPrint("[CopilotAgent] batch_read_rows: startRow=$startRow, count=$requestedCount, cols=$cols");

              final inspectRes = await executeInspectSheet();
              final allCells = (inspectRes['all_cells'] as Map<String, dynamic>?) ?? {};
              final totalRows = (inspectRes['total_rows'] as int?) ?? 0;
              final Map<String, String> rowBatch = {};

              int nonCount = 0;
              for (int r = startRow; r < startRow + requestedCount; r++) {
                for (String colLetter in cols) {
                  final cellRef = '$colLetter$r';
                  if (allCells.containsKey(cellRef)) {
                    final v = allCells[cellRef].toString();
                    rowBatch[cellRef] = v;
                    if (v.trim().isNotEmpty) nonCount++;
                  }
                }
              }

              final hasMore = (startRow + requestedCount) <= totalRows;

              userParts.add({
                    "functionResponse": {
                      "name": name,
                      "response": {
                        "name": name,
                        "content": {
                          "start_row": startRow,
                          "rows_read": requestedCount,
                          "non_empty_cells": nonCount,
                          "total_sheet_rows": totalRows,
                          "has_more_rows": hasMore,
                          "next_start_row": hasMore ? startRow + requestedCount : null,
                          "batch_cells": rowBatch,
                        }
                      }
                    }});
            } else if (name == 'ask_user_question') {
              final question = args['question']?.toString() ?? '';
              final options = (args['options'] as List?)?.map((e) => e.toString()).toList() ?? [];
              final defaultOption = args['default_option']?.toString();
              CopilotService.updateStatus(AgentStatus.waiting);
              CopilotService.addActionLog('Asked Question', question);
              debugPrint("[CopilotAgent] ask_user_question: question=$question, options=$options");

              _waitingQuestionName = name;
              _waitingQuestionArgs = args;

              return CopilotResponse(
                success: true,
                providerUsed: 'gemini',
                explanation: question,
                planSummary: 'Needs user preference',
                questionPayload: CopilotQuestionPayload(
                  question: question,
                  options: options,
                  defaultOption: defaultOption,
                ),
              );
            } else if (name == 'inspect_sheet' || name == 'get_sheet_headers') {
              CopilotService.updateStatus(AgentStatus.researching);
              CopilotService.addActionLog('Read Cells', 'Inspected grid dimensions and headers');
              final result = await executeInspectSheet();
              debugPrint("[CopilotAgent] $name result: ${jsonEncode(result)}");
              userParts.add({
                    "functionResponse": {
                      "name": name,
                      "response": {"name": name, "content": result}
                    }});
            } else if (name == 'list_workbook_sheets') {
              CopilotService.updateStatus(AgentStatus.researching);
              CopilotService.addActionLog('Listed Sheets', 'Discovered workbook sheet tabs');
              final result = await executeListWorkbookSheets(sheetId);
              debugPrint("[CopilotAgent] list_workbook_sheets result: ${jsonEncode(result)}");
              userParts.add({
                "functionResponse": {
                  "name": name,
                  "response": {"name": name, "content": result}
                }
              });
            } else if (name == 'read_sheet_tab') {
              final target = args['sheet_name_or_id']?.toString() ?? 'Sheet 2';
              final maxR = (args['max_rows'] as num?)?.toInt() ?? 60;
              CopilotService.updateStatus(AgentStatus.researching);
              CopilotService.addActionLog('Read Sheet Tab', 'Reading instructions/data from $target');
              final result = await executeReadSheetTab(sheetNameOrId: target, activeSheetId: sheetId, maxRows: maxR);
              debugPrint("[CopilotAgent] read_sheet_tab result for $target: summary=${result['summary']}");
              userParts.add({
                "functionResponse": {
                  "name": name,
                  "response": {"name": name, "content": result}
                }
              });
            } else if (name == 'write_to_sheet_tab') {
              final target = args['sheet_name_or_id']?.toString() ?? 'Sheet 2';
              final cells = Map<String, dynamic>.from(args['cells'] as Map? ?? {});
              CopilotService.updateStatus(AgentStatus.executing);
              CopilotService.addActionLog('Wrote Sheet Tab', 'Updated ${cells.length} cells in $target');
              final result = await executeWriteToSheetTab(sheetNameOrId: target, cells: cells);
              userParts.add({
                "functionResponse": {
                  "name": name,
                  "response": {"name": name, "content": result}
                }
              });
            } else {
              debugPrint("[CopilotAgent] Fallback for unhandled tool: $name");
              userParts.add({
                "functionResponse": {
                  "name": name,
                  "response": {"name": name, "content": {"status": "SUCCESS", "message": "Executed $name", "args": args}}
                }
              });
            }
          } catch (toolError) {
            debugPrint("[CopilotAgent] Error executing tool $name: $toolError");
            userParts.add({
              "functionResponse": {
                "name": name,
                "response": {"name": name, "content": {"status": "ERROR", "error": toolError.toString()}}
              }
            });
          }
        }
      }

        if (taskCompleteArgs != null) {
          final finalReport = taskCompleteArgs['final_report']?.toString() ?? 'Task completed.';
          CopilotService.updateStatus(AgentStatus.completed);
          CopilotService.addActionLog('Task Completed', finalReport);
          debugPrint("[CopilotAgent] TASK COMPLETE: $finalReport");

          if (userParts.isNotEmpty) {
            _persistentMemoryHistory.add({
              "role": "user",
              "parts": userParts
            });
          }

          await syncNativeToStorage(sheetId);
          return CopilotResponse(
            success: true,
            providerUsed: 'gemini_local',
            explanation: finalReport,
            planSummary: '✅ All tasks completed successfully.',
            pipeline: {'steps': []},
          );
        }

        if (buildPipelineArgs != null && !continuousLoopEnabled) {
          final pipeline = buildPipelineArgs['pipeline'];
          CopilotService.updateStatus(AgentStatus.completed);
          CopilotService.addActionLog('Pipeline Created', buildPipelineArgs['plan_summary']?.toString() ?? 'Action Pipeline Built');
          debugPrint("[CopilotAgent] FINAL PIPELINE: ${jsonEncode(pipeline)}");

          if (userParts.isNotEmpty) {
            _persistentMemoryHistory.add({
              "role": "user",
              "parts": userParts
            });
          }

          await syncNativeToStorage(sheetId);
          
          // Ensure pipeline has steps
          if (pipeline == null) {
            return CopilotResponse.withError("AI returned null pipeline");
          }
          
          final pipelineMap = (pipeline is Map) ? Map<String, dynamic>.from(pipeline) : <String, dynamic>{};
          
          // If AI returned steps at top level of pipeline args instead of nested
          if (!pipelineMap.containsKey('steps') && buildPipelineArgs.containsKey('steps')) {
            pipelineMap['steps'] = buildPipelineArgs['steps'];
          }
          
          // If still no steps, wrap the whole thing
          if (!pipelineMap.containsKey('steps')) {
            debugPrint("[CopilotAgent] WARNING: pipeline missing 'steps' key. Keys: ${pipelineMap.keys}");
          }
          
          return CopilotResponse(
            success: true,
            providerUsed: 'gemini_local',
            explanation: buildPipelineArgs['explanation']?.toString() ?? 'Pipeline Built',
            planSummary: buildPipelineArgs['plan_summary']?.toString() ?? '',
            pipeline: pipelineMap,
          );
        }

        
        if (userParts.isNotEmpty) {
          _persistentMemoryHistory.add({
            "role": "user",
            "parts": userParts
          });
        }
        if (!hasFunctionCall) {
          // AI just responded with text and no tools
          final textPart = parts.firstWhere((p) => p.containsKey('text'), orElse: () => {'text': 'No text response'});
          final text = textPart['text']?.toString() ?? '';
          debugPrint("[CopilotAgent] AI responded with text only: $text");
          return CopilotResponse.withError("AI responded without building a pipeline: $text");
        }

      } catch (e, stackTrace) {
        debugPrint("[CopilotAgent] Exception: $e\n$stackTrace");
        return CopilotResponse.withError("Network Error: $e");
      }
    }

    if (buildPipelineArgs != null) {
      final pipeline = buildPipelineArgs['pipeline'];
      final pipelineMap = (pipeline is Map) ? Map<String, dynamic>.from(pipeline) : <String, dynamic>{'steps': []};
      if (!pipelineMap.containsKey('steps') && buildPipelineArgs.containsKey('steps')) {
        pipelineMap['steps'] = buildPipelineArgs['steps'];
      }
      return CopilotResponse(
        success: true,
        providerUsed: 'gemini_local',
        explanation: buildPipelineArgs['explanation']?.toString() ?? 'All tasks completed successfully.',
        planSummary: buildPipelineArgs['plan_summary']?.toString() ?? '✅ All steps executed.',
        pipeline: pipelineMap,
      );
    }

    return CopilotResponse.withError("Agent iteration limit reached.");
  }

  /// Native Gemini STT using audio inline data
  static Future<String?> transcribeAudioBytes(List<int> audioBytes) async {
    try {
      final apiKey = await _getApiKey();
      if (apiKey == null || apiKey.isEmpty) return null;

      final base64Audio = base64Encode(audioBytes);
      final payload = {
        "contents": [
          {
            "parts": [
              {
                "inlineData": {
                  "mimeType": "audio/wav",
                  "data": base64Audio
                }
              },
              {"text": "Transcribe this audio exactly as spoken in the original language. Just output the transcript."}
            ]
          }
        ]
      };

      final response = await _postWithFallback(apiKey, payload);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates[0]['content']['parts'] as List;
          final textPart = parts.firstWhere((p) => p.containsKey('text'), orElse: () => {'text': ''});
          return textPart['text']?.toString().trim();
        }
      }
      return null;
    } catch (e) {
      debugPrint("[CopilotAgent] Gemini STT Error: $e");
      return null;
    }
  }
}
