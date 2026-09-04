import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/spreadsheet_entity.dart';
import '../../domain/entities/sheet_entity.dart';
import '../../domain/services/storage/sheet_data_storage.dart';
import 'widgets/top_app_bar.dart';
import 'widgets/formula_bar.dart';
import 'widgets/column_headers.dart';
import 'widgets/row_headers.dart';
import 'widgets/grid_widget.dart';
import 'widgets/bottom_toolbar.dart';
import 'widgets/search_toolbar.dart';
import 'widgets/tally_summary_bar.dart';
import 'bottom_sheets/editor_bottom_sheet.dart';
import 'top_sheets/editor_top_drawer.dart';
import 'widgets/audio_recorder_dialog.dart';
import 'widgets/formula_helper_sheet.dart';
import 'widgets/sheet_tabs/sheet_tabs_bar.dart';
import 'widgets/column_swipe_menu.dart';
import 'widgets/column_properties/column_properties_sheet.dart';
import 'widgets/theme/spreadsheet_theme_sheet.dart';
import 'widgets/footer/sheet_footer_widget.dart';
import 'widgets/footer/footer_settings_sheet.dart';
import 'widgets/receipt_pdf_generator.dart';
import 'widgets/smart_text_parser_dialog.dart';
import 'widgets/tally_summary_bar.dart';
import 'widgets/quick_share_dialog.dart';
import '../invoice/invoice_customizer_screen.dart';
import 'editor_controller.dart';
import '../../domain/services/super_engine/ffi_bridge.dart';
import '../../domain/services/conditional_formatting_service.dart';
import 'powerscript/powerscript_studio_screen.dart';
import 'widgets/conditional_formatting/cf_manager_sheet.dart' as cf_widgets;
import 'modules/text_to_columns/text_to_columns_screen.dart';
import 'modules/number_format/number_format_model.dart';
import 'modules/number_format/number_format_service.dart';
import '../analytics/pivot_designer/pivot_designer_drawer.dart';
import '../analytics/renderers/pivot_table_renderer.dart';
import '../../domain/analytics/models/chart_config.dart';
import '../../domain/analytics/models/pivot_theme.dart';
import '../../domain/analytics/models/aggregation_type.dart';
import '../../domain/analytics/engines/pivot_engine.dart';

import '../../domain/services/copilot/copilot_service.dart';
import '../../domain/services/copilot/local_agent_service.dart';
import '../../domain/services/copilot/copilot_session_service.dart';
import '../copilot/widgets/sheetpro_ai_floating_bot.dart';

/// Editor screen for editing spreadsheets
class EditorScreen extends StatefulWidget {
  final SpreadsheetEntity spreadsheet;
  final Function(String)? onRename;

  const EditorScreen({
    Key? key,
    required this.spreadsheet,
    this.onRename,
  }) : super(key: key);

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with WidgetsBindingObserver {
  final GlobalKey<GridWidgetState> _gridKey = GlobalKey<GridWidgetState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  
  List<String> _pivotAvailableColumns = [];
  bool _isSearching = false;
  int _searchMatchCurrent = 0;
  int _searchMatchTotal = 0;
  List<int>? _visibleRows;
  Map<String, String> _cellData = {};
  Map<String, CellFormat> _formatMap = {};

  bool _isTopDrawerOpen = false;
  bool _showFloatingAiBot = true;
  int? _lastSuggestedColumn;

  Future<void> _handlePipelineApplied(Map<String, dynamic> pipeline) async {
    _gridKey.currentState?.syncFromNative();
    final currentSheetId = widget.spreadsheet.spreadsheetId;
    final savedFormats = await NumberFormatService.instance.loadFormats(currentSheetId);
    final sheet1Formats = await NumberFormatService.instance.loadFormats('Sheet1');
    final mergedFormats = Map<String, CellFormat>.from(savedFormats)..addAll(sheet1Formats);
    if (mounted) {
      setState(() {
        _formatMap = mergedFormats;
      });
    }
    await ConditionalFormattingService.restoreRules(currentSheetId);
    await ConditionalFormattingService.restoreRules('Sheet1');
    _gridKey.currentState?.syncFromNative();
  }

  void _openPowerScriptStudio() {
    setState(() => _isTopDrawerOpen = false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => PowerScriptStudioScreen(
          sheetId: widget.spreadsheet.spreadsheetId,
          spreadsheetName: widget.spreadsheet.name,
          onSheetUpdated: () async {
            final data = await SheetDataStorage.loadCellData(widget.spreadsheet.spreadsheetId);
            if (data != null && mounted) {
              setState(() {
                _cellData = data;
              });
            }
            _gridKey.currentState?.setState(() {});
          },
        ),
      ),
    );
  }

  Future<void> _saveToDevice({String format = 'csv'}) async {
    final controller = Provider.of<EditorController>(context, listen: false);
    final sheetName = controller.spreadsheet?.name ?? 'Spreadsheet';
    final cellData = _cellData;

    try {
      // 1. Save internal JSON state
      await SheetDataStorage.saveCellData(widget.spreadsheet.spreadsheetId, cellData);

      // 2. Ensure all 3 subfolders exist in Documents/Spreadsheet pro/
      await SheetDataStorage.getSpreadsheetProDir('csv');
      await SheetDataStorage.getSpreadsheetProDir('excel');
      await SheetDataStorage.getSpreadsheetProDir('xlsx');

      // 3. Export to target subfolder
      final subFolder = (format == 'excel' || format == 'xls') ? 'excel' : (format == 'xlsx' ? 'xlsx' : 'csv');
      final targetDir = await SheetDataStorage.getSpreadsheetProDir(subFolder);

      final sanitizedName = sheetName.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
      final ext = subFolder == 'csv' ? 'csv' : (subFolder == 'excel' ? 'xls' : 'xlsx');
      final file = File('${targetDir.path}/$sanitizedName.$ext');

      int maxRow = 0;
      int maxCol = 0;
      cellData.forEach((key, value) {
        final parts = key.split(':');
        if (parts.length == 2) {
          final r = int.tryParse(parts[0]) ?? 0;
          final c = int.tryParse(parts[1]) ?? 0;
          if (r > maxRow) maxRow = r;
          if (c > maxCol) maxCol = c;
        }
      });

      StringBuffer csvBuf = StringBuffer();
      for (int r = 0; r <= maxRow; r++) {
        List<String> rowCells = [];
        for (int c = 0; c <= maxCol; c++) {
          String val = cellData['$r:$c'] ?? '';
          if (val.contains(',') || val.contains('"') || val.contains('\n')) {
            val = '"${val.replaceAll('"', '""')}"';
          }
          rowCells.add(val);
        }
        csvBuf.writeln(rowCells.join(','));
      }

      await file.writeAsString(csvBuf.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Saved to: Documents/Spreadsheet pro/$subFolder/${file.path.split('/').last}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF107C41),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  ({int row, int column})? _selectionAnchor(EditorController controller) {
    if (controller.selectedFullRow != null) {
      return (row: controller.selectedFullRow!, column: 0);
    }
    if (controller.selectedFullColumn != null) {
      return (row: 0, column: controller.selectedFullColumn!);
    }
    if (controller.selectedCells.isNotEmpty) {
      final cell = controller.selectedCells.first;
      return (row: cell.row, column: cell.column);
    }
    return null;
  }

  ({int startRow, int startCol, int endRow, int endCol})? _selectionBounds(EditorController controller) {
    if (controller.selectedFullRow != null) {
      final row = controller.selectedFullRow!;
      final colCount = controller.currentSheet?.metadata?.columnCount ?? 26;
      if (colCount <= 0) return null;
      return (
        startRow: row,
        startCol: 0,
        endRow: row,
        endCol: colCount - 1,
      );
    }

    if (controller.selectedFullColumn != null) {
      final col = controller.selectedFullColumn!;
      final rowCount = controller.currentSheet?.metadata?.rowCount ?? 1000;
      if (rowCount <= 0) return null;
      return (
        startRow: 0,
        startCol: col,
        endRow: rowCount - 1,
        endCol: col,
      );
    }

    final gridSelection = _gridKey.currentState?.currentSelection;
    if (gridSelection != null) {
      return (
        startRow: gridSelection.startRow,
        startCol: gridSelection.startCol,
        endRow: gridSelection.endRow,
        endCol: gridSelection.endCol,
      );
    }

    if (controller.selectedCells.isNotEmpty) {
      var startRow = controller.selectedCells.first.row;
      var endRow = controller.selectedCells.first.row;
      var startCol = controller.selectedCells.first.column;
      var endCol = controller.selectedCells.first.column;

      for (final cell in controller.selectedCells.skip(1)) {
        if (cell.row < startRow) startRow = cell.row;
        if (cell.row > endRow) endRow = cell.row;
        if (cell.column < startCol) startCol = cell.column;
        if (cell.column > endCol) endCol = cell.column;
      }

      return (startRow: startRow, startCol: startCol, endRow: endRow, endCol: endCol);
    }

    return null;
  }

  Future<void> _copySelection(EditorController controller) async {
    final bounds = _selectionBounds(controller);
    if (bounds == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a cell or column first to copy')),
      );
      return;
    }

    try {
      final text = await NativeEngine.copyDataBlockAsync(
        bounds.startRow,
        bounds.startCol,
        bounds.endRow,
        bounds.endCol,
      );
      if (text.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copied to clipboard!'), duration: Duration(seconds: 1)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copy failed: $e')),
        );
      }
    }
  }

  Future<void> _pasteSelection(EditorController controller) async {
    final bounds = _selectionBounds(controller);
    if (bounds == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a cell or column first to paste')),
      );
      return;
    }

    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text == null || text.isEmpty) return;

      await _gridKey.currentState?.pasteData(bounds.startRow, bounds.startCol, text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pasting data...'), duration: Duration(milliseconds: 500)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paste failed: $e')),
        );
      }
    }
  }

  String? _selectionText(EditorController controller) {
    final bounds = _selectionBounds(controller);
    if (bounds == null) return null;

    final buffer = StringBuffer();
    for (int row = bounds.startRow; row <= bounds.endRow; row++) {
      for (int col = bounds.startCol; col <= bounds.endCol; col++) {
        final value = _gridKey.currentState?.getCellValue(row, col) ?? _cellData['$row:$col'] ?? '';
        buffer.write(value);
        if (col < bounds.endCol) buffer.write('\t');
      }
      if (row < bounds.endRow) buffer.write('\n');
    }
    return buffer.toString();
  }

  Future<void> _autoFillSelection(EditorController controller) async {
    final bounds = _selectionBounds(controller);
    if (bounds == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a row or column first to autofill')),
      );
      return;
    }

    final text = _selectionText(controller);
    if (text == null || text.isEmpty) return;

    try {
      final rowCount = controller.currentSheet?.metadata?.rowCount ?? 1000;
      final colCount = controller.currentSheet?.metadata?.columnCount ?? 26;

      if (controller.selectedFullRow != null || bounds.startRow == bounds.endRow) {
        if (bounds.endRow + 1 >= rowCount) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No space below to autofill row')),
          );
          return;
        }
        await _gridKey.currentState?.pasteData(bounds.endRow + 1, bounds.startCol, text);
      } else {
        if (bounds.endCol + 1 >= colCount) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No space on right to autofill column')),
          );
          return;
        }
        await _gridKey.currentState?.pasteData(bounds.startRow, bounds.endCol + 1, text);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AutoFill applied'), duration: Duration(milliseconds: 800)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AutoFill failed: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Hide bottom navigation buttons when sheet opens
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top]);
    
    _cellData = widget.spreadsheet.transientCellData ?? {};
    CopilotService.pipelineNotifier.addListener(_onCopilotPipelineTriggered);
    CopilotService.gridRefreshNotifier.addListener(_onAgentGridRefresh);
    CopilotService.onManageSheets = _handleCopilotManageSheets;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = context.read<EditorController>();
      controller.loadSpreadsheet(widget.spreadsheet);
      controller.addListener(_onControllerChanged);
      
      if (controller.currentSheet != null) {
        final sheets = controller.spreadsheet?.sheets ?? [];
        final currentIndex = sheets.indexWhere((s) => s.sheetId == controller.currentSheet!.sheetId);
        final fallbackId = currentIndex == 0 ? widget.spreadsheet.spreadsheetId : null;
        
        final data = await SheetDataStorage.loadCellData(controller.currentSheet!.sheetId, fallbackSpreadsheetId: fallbackId);
        final initialData = data ?? {};
        if (mounted) {
           setState(() => _cellData = Map<String, String>.from(initialData));
           _gridKey.currentState?.loadNewData(initialData);
        }

        // Restore Conditional Formatting Rules into C++ engine across app restarts
        await ConditionalFormattingService.restoreRules(controller.currentSheet!.sheetId);
        if (fallbackId != null) {
          await ConditionalFormattingService.restoreRules(fallbackId);
        }
        await ConditionalFormattingService.restoreRules('Sheet1');
        if (mounted) {
          setState(() {});
        }
      }

      // Load saved number formats
      final savedFormats = await NumberFormatService.instance
          .loadFormats(widget.spreadsheet.spreadsheetId);
      if (mounted && savedFormats.isNotEmpty) {
        setState(() => _formatMap = savedFormats);
      }

      _syncCopilotWorkbookContext();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Restore bottom navigation buttons when leaving sheet
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    
    // STOP the AI agent when leaving the workbook entirely
    CopilotService.stopAgentLoop();

    // Clear C++ native grid and Copilot memory so it NEVER bleeds into the next spreadsheet
    NativeEngine.clearGrid();
    LocalAgentService.clearMemory();
    CopilotSessionService.instance.clearTab('task');
    CopilotService.clearActionLogs();

    CopilotService.onManageSheets = null;
    CopilotService.gridRefreshNotifier.removeListener(_onAgentGridRefresh);
    CopilotService.pipelineNotifier.removeListener(_onCopilotPipelineTriggered);
    context.read<EditorController>().removeListener(_onControllerChanged);
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  /// Called whenever the AI agent modifies the native grid — refresh sheet live
  /// Multi-sheet race guard: ONLY refresh UI if the agent's active sheet matches the currently displayed sheet!
  void _onAgentGridRefresh() {
    if (!mounted) return;
    final currentSheetId = context.read<EditorController>().currentSheet?.sheetId ?? widget.spreadsheet.spreadsheetId;
    if (CopilotService.activeAgentSheetId == null || CopilotService.activeAgentSheetId == currentSheetId) {
      _gridKey.currentState?.syncFromNative();
    } else {
      debugPrint("[EditorScreen] Suppressed live grid refresh: Agent is working on sheet '${CopilotService.activeAgentSheetId}', while UI is displaying '$currentSheetId'");
    }
  }

  /// Real execution of sheet creation, switching, deletion, and listing requested by AI Agent
  Future<Map<String, dynamic>> _handleCopilotManageSheets(String action, String sheetName) async {
    if (!mounted) {
      return {
        "status": "error",
        "error": "Editor is not active",
      };
    }
    final controller = context.read<EditorController>();
    final sheets = controller.spreadsheet?.sheets ?? widget.spreadsheet.sheets;

    if (action == 'create') {
      final currentSheet = controller.currentSheet;
      if (currentSheet != null) {
        await SheetDataStorage.saveCellData(currentSheet.sheetId, _cellData);
      }
      controller.addSheet(sheetName);
      final newSheets = controller.spreadsheet?.sheets ?? [];
      final createdSheet = newSheets.isNotEmpty ? newSheets.last : null;
      final newSheetId = createdSheet?.sheetId ?? DateTime.now().millisecondsSinceEpoch.toString();
      await SheetDataStorage.saveCellData(newSheetId, {});
      if (mounted) {
        setState(() {
          _cellData = {};
        });
        _gridKey.currentState?.loadNewData({});
      }
      _syncCopilotWorkbookContext();
      return {
        "status": "SUCCESS",
        "action": "create",
        "sheet_id": newSheetId,
        "sheet_name": sheetName,
        "sheets": newSheets.map((s) => s.name).toList(),
        "message": "Sheet '$sheetName' created successfully in workbook."
      };
    } else if (action == 'switch') {
      final query = sheetName.trim().toLowerCase();
      final targetIndex = sheets.indexWhere(
        (s) => s.sheetId.toLowerCase() == query || s.name.toLowerCase() == query
      );
      if (targetIndex >= 0) {
        final currentSheet = controller.currentSheet;
        if (currentSheet != null) {
          await SheetDataStorage.saveCellData(currentSheet.sheetId, _cellData);
        }
        final targetSheet = sheets[targetIndex];
        controller.switchSheet(targetSheet);
        final fallbackId = targetIndex == 0 ? widget.spreadsheet.spreadsheetId : null;
        final newData = await SheetDataStorage.loadCellData(targetSheet.sheetId, fallbackSpreadsheetId: fallbackId) ?? {};
        if (mounted) {
          setState(() {
            _cellData = newData;
          });
          _gridKey.currentState?.loadNewData(newData);
        }
        _syncCopilotWorkbookContext();
        return {
          "status": "SUCCESS",
          "action": "switch",
          "active_sheet": targetSheet.name,
          "sheet_id": targetSheet.sheetId,
          "sheets": sheets.map((s) => s.name).toList(),
        };
      } else {
        return {
          "status": "ERROR",
          "error": "Sheet '$sheetName' not found in workbook.",
          "available_sheets": sheets.map((s) => s.name).toList(),
        };
      }
    } else if (action == 'delete') {
      if (sheets.length <= 1) {
        return {
          "status": "ERROR",
          "error": "Cannot delete the only sheet in the workbook."
        };
      }
      final query = sheetName.trim().toLowerCase();
      final targetIndex = sheets.indexWhere(
        (s) => s.sheetId.toLowerCase() == query || s.name.toLowerCase() == query
      );
      if (targetIndex >= 0) {
        final targetSheet = sheets[targetIndex];
        controller.deleteSheet(targetIndex);
        final remaining = controller.spreadsheet?.sheets ?? [];
        if (remaining.isNotEmpty) {
          final newData = await SheetDataStorage.loadCellData(remaining.first.sheetId) ?? {};
          if (mounted) {
            setState(() => _cellData = newData);
            _gridKey.currentState?.loadNewData(newData);
          }
        }
        _syncCopilotWorkbookContext();
        return {
          "status": "SUCCESS",
          "action": "delete",
          "deleted_sheet": targetSheet.name,
          "remaining_sheets": remaining.map((s) => s.name).toList(),
        };
      } else {
        return {
          "status": "ERROR",
          "error": "Sheet '$sheetName' not found to delete.",
          "available_sheets": sheets.map((s) => s.name).toList(),
        };
      }
    } else {
      return {
        "status": "SUCCESS",
        "action": "list",
        "sheets": sheets.map((s) => s.name).toList(),
        "active_sheet": controller.currentSheet?.name ?? 'Sheet1',
      };
    }
  }

  /// Synchronize the list of workbook sheet tabs with CopilotService so AI is multi-sheet aware
  void _syncCopilotWorkbookContext() {
    try {
      final sheets = context.read<EditorController>().spreadsheet?.sheets ?? widget.spreadsheet.sheets;
      CopilotService.updateWorkbookContext(
        spreadsheetId: widget.spreadsheet.spreadsheetId,
        sheets: sheets.map((s) => {'id': s.sheetId, 'name': s.name}).toList(),
      );
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      final controller = context.read<EditorController>();
      
      // If currently editing, commit it via controller
      controller.commitCellEdit();
      
      final currentSheetId = controller.currentSheet?.sheetId ?? widget.spreadsheet.spreadsheetId;
      SheetDataStorage.saveCellData(currentSheetId, _cellData);
      final isFirstSheet = controller.currentSheet?.sheetId == widget.spreadsheet.activeSheet?.sheetId;
      if (isFirstSheet && currentSheetId != widget.spreadsheet.spreadsheetId) {
        SheetDataStorage.saveCellData(widget.spreadsheet.spreadsheetId, _cellData);
      }
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final controller = context.read<EditorController>();
    if (controller.footerConfig.enabled) return;

    final targetCol = controller.selectedFullColumn;
    if (targetCol != null && targetCol != _lastSuggestedColumn) {
      _lastSuggestedColumn = targetCol;
      
      int numericCount = 0;
      int totalCount = 0;
      final maxRow = controller.currentSheet?.metadata?.rowCount ?? 1000;
      
      for (int r = 0; r < maxRow; r++) {
        final key = '$r:$targetCol';
        final val = _cellData[key];
        if (val != null && val.trim().isNotEmpty) {
          totalCount++;
          if (double.tryParse(val.trim().replaceAll(',', '')) != null) {
            numericCount++;
          }
        }
      }
      
      if (totalCount > 2 && numericCount / totalCount > 0.7) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Add Summary Footer for Column ${EditorController.getColumnLetter(targetCol)}?'),
            action: SnackBarAction(
              label: 'ENABLE',
              textColor: controller.themeConfig.accentColor,
              onPressed: () {
                final updatedConfig = controller.footerConfig.copyWith(
                  enabled: true,
                  targetColumnIndex: targetCol,
                );
                controller.updateFooterConfig(updatedConfig);
                _showFooterOptions(context, controller, targetColumn: targetCol);
              },
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showThemeOptions(BuildContext context, EditorController controller) {
    SpreadsheetThemeSheet.show(
      context,
      initialConfig: controller.themeConfig,
      onApply: (newConfig) {
        controller.updateThemeConfig(newConfig);
      },
    );
  }

  void _showFooterOptions(BuildContext context, EditorController controller, {int? targetColumn}) {
    final resolvedTargetCol = targetColumn ??
        controller.footerConfig.targetColumnIndex ??
        _selectionAnchor(controller)?.column ??
        0;

    final initialConfig = controller.footerConfig.copyWith(
      targetColumnIndex: resolvedTargetCol,
    );

    FooterSettingsSheet.show(
      context,
      initialConfig: initialConfig,
      themeConfig: controller.themeConfig,
      columnCount: controller.currentSheet?.metadata?.columnCount ?? 26,
      onApply: (newConfig) {
        controller.updateFooterConfig(newConfig);
      },
    );
  }

  void _showSmartTextParser(BuildContext context, EditorController controller) {
    SmartTextParserDialog.show(context, (parsedData) {
      int targetRow = controller.selectedFullRow ?? _selectionAnchor(controller)?.row ?? 0;

      final maxRows = controller.currentSheet?.metadata?.rowCount ?? 1000;
      if (controller.selectedFullRow == null && controller.selectedCells.isEmpty) {
        for (int r = 0; r < maxRows; r++) {
          if ((_cellData['$r:0'] ?? '').isEmpty && (_cellData['$r:3'] ?? '').isEmpty) {
            targetRow = r;
            break;
          }
        }
      }

      _gridKey.currentState?.updateCellValue(targetRow, 0, parsedData.receiptNo);
      _gridKey.currentState?.updateCellValue(targetRow, 1, parsedData.date);
      _gridKey.currentState?.updateCellValue(targetRow, 2, parsedData.voucherType);
      _gridKey.currentState?.updateCellValue(targetRow, 3, parsedData.partyName);
      _gridKey.currentState?.updateCellValue(targetRow, 4, parsedData.narration);
      _gridKey.currentState?.updateCellValue(targetRow, 5, parsedData.amount);
      _gridKey.currentState?.updateCellValue(targetRow, 6, parsedData.paymentMode);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Voucher added for ${parsedData.partyName} (Row ${targetRow + 1})'),
          backgroundColor: const Color(0xFF28C76F),
        ),
      );
    });
  }

  void _showReceiptPdfForRow(BuildContext context, int row) {
    final Map<String, String> rowDataMap = {};
    final controller = context.read<EditorController>();
    final colCount = controller.currentSheet?.metadata?.columnCount ?? 26;

    for (int col = 0; col < colCount; col++) {
      final headerName = controller.getColumnName(col) ?? EditorController.getColumnLetter(col);
      final cellVal = _gridKey.currentState?.getCellValue(row, col) ?? _cellData['$row:$col'] ?? '';
      rowDataMap[headerName] = cellVal;
    }

    ReceiptPdfDialog.show(context, rowDataMap, row);
  }

  void _showQuickShareForRow(BuildContext context, int row) {
    final Map<String, String> rowDataMap = {};
    final controller = context.read<EditorController>();
    final colCount = controller.currentSheet?.metadata?.columnCount ?? 26;

    for (int col = 0; col < colCount; col++) {
      final headerName = controller.getColumnName(col) ?? EditorController.getColumnLetter(col);
      final cellVal = _gridKey.currentState?.getCellValue(row, col) ?? _cellData['$row:$col'] ?? '';
      rowDataMap[headerName] = cellVal;
    }

    QuickShareDialog.show(context, rowDataMap, row);
  }

  void _showColumnSwipeMenu(int columnIndex, SwipeActionType type) {
    if (!mounted) return;
    
    // Find the current X position of this column
    final controller = context.read<EditorController>();
    double leftX = 50.0; // corner cell width
    for (int i = 0; i < columnIndex; i++) {
      leftX += controller.getColumnWidth(i);
    }
    
    final currentOffset = _horizontalController.hasClients ? _horizontalController.offset : 0.0;
    final screenX = leftX - currentOffset;

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: Stack(
            children: [
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                right: 0,
                child: ColumnSwipeMenu(
                  columnIndex: columnIndex,
                  actionType: type,
                  horizontalOffset: screenX,
                  onDismiss: () => overlayEntry.remove(),
                  onSelectColumn: () {
                    controller.selectFullColumn(columnIndex);
                    overlayEntry.remove();
                  },
                  onDelete: () {
                    controller.deleteColumn(columnIndex);
                    _gridKey.currentState?.deleteColumnData(columnIndex);
                    overlayEntry.remove();
                  },
                  onHide: () {
                    // Coming soon
                    overlayEntry.remove();
                  },
                  onSort: () {
                    // Coming soon
                    overlayEntry.remove();
                  },
                  onFilter: () {
                    // Coming soon
                    overlayEntry.remove();
                  },
                  onInsertLeft: () {
                    controller.insertColumnAt(columnIndex);
                    _gridKey.currentState?.insertColumnData(columnIndex);
                    overlayEntry.remove();
                  },
                  onInsertRight: () {
                    controller.insertColumnAt(columnIndex + 1);
                    _gridKey.currentState?.insertColumnData(columnIndex + 1);
                    overlayEntry.remove();
                  },
                  onDuplicate: () {
                    controller.duplicateColumn(columnIndex);
                    _gridKey.currentState?.duplicateColumnData(columnIndex);
                    overlayEntry.remove();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    overlay.insert(overlayEntry);
  }

  Future<void> _showExitConfirmationDialog() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.save_outlined, color: Colors.amberAccent, size: 22),
              SizedBox(width: 8),
              Text(
                'Exit Spreadsheet?',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Do you want to save your changes before exiting, or close now?',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('cancel'),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('close_now'),
              child: const Text(
                'Close Now',
                style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF107C41),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(dialogContext).pop('save_and_exit'),
              child: const Text(
                'Save & Exit',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (result == 'save_and_exit') {
      final controller = context.read<EditorController>();
      controller.commitCellEdit();
      final currentSheetId = controller.currentSheet?.sheetId ?? widget.spreadsheet.spreadsheetId;
      await SheetDataStorage.saveCellData(currentSheetId, _cellData);
      final isFirstSheet = controller.currentSheet?.sheetId == widget.spreadsheet.activeSheet?.sheetId;
      if (isFirstSheet && currentSheetId != widget.spreadsheet.spreadsheetId) {
        await SheetDataStorage.saveCellData(widget.spreadsheet.spreadsheetId, _cellData);
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else if (result == 'close_now') {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitConfirmationDialog();
      },
      child: Scaffold(
        key: _scaffoldKey,
        resizeToAvoidBottomInset: false,
        endDrawer: PivotDesignerDrawer(
        availableColumns: _pivotAvailableColumns.isEmpty ? ['Region', 'Category', 'Product', 'Sales', 'Quantity'] : _pivotAvailableColumns,
        selectedRowFields: _pivotAvailableColumns.isNotEmpty ? [_pivotAvailableColumns.first] : ['Region'],
        selectedColFields: const [],
        selectedDataFields: _pivotAvailableColumns.length > 1 ? [_pivotAvailableColumns.last] : ['Sales'],
        selectedSlicerFields: _pivotAvailableColumns.length > 2 ? [_pivotAvailableColumns[1]] : [],
        aggType: AggregationType.sum,
        themeMode: PivotThemeMode.professionalBlue,
        onApply: (rowFields, colFields, dataFields, slicerFields, aggType, themeMode) {
          Navigator.pop(context); // close drawer
          _applyPivotToSheet(context, _pivotAvailableColumns.isEmpty ? ['Region', 'Category', 'Product', 'Sales', 'Quantity'] : _pivotAvailableColumns, rowFields, colFields, dataFields, slicerFields, aggType, themeMode);
        },
        onClose: () => Navigator.pop(context),
      ),
      body: Consumer<EditorController>(
        builder: (context, controller, child) {
          if (controller.columnToEdit != null) {
            final colIndex = controller.columnToEdit!;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              controller.clearEditColumnRequest();
                ColumnPropertiesSheet.show(
                context,
                columnIndex: colIndex,
                columnName: (controller.getColumnName(colIndex) != null && controller.getColumnName(colIndex)!.isNotEmpty)
                    ? controller.getColumnName(colIndex)
                    : EditorController.getColumnLetter(colIndex),
                columnType: controller.getColumnType(colIndex),
                columnWidth: controller.getColumnWidth(colIndex),
                onSave: (name, type, width) {
                  controller.updateColumnProperties(colIndex, name, type, width);
                },
                onInsertLeft: () {
                  controller.addColumn();
                  _gridKey.currentState?.insertColumn(colIndex);
                },
                onInsertRight: () {
                  controller.addColumn();
                  _gridKey.currentState?.insertColumn(colIndex + 1);
                },
                onCopy: () => _copySelection(controller),
                onAutoFill: () => _autoFillSelection(controller),
              );
            });
          }

          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${controller.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      controller.loadSpreadsheet(widget.spreadsheet);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Stack(
            children: [
              SafeArea(
                bottom: true,
                child: Column(
              children: [
                // Top App Bar
                EditorTopAppBar(
                  title: controller.spreadsheet?.name ?? 'Spreadsheet',
                  onRename: (newName) {
                    controller.renameSpreadsheet(newName);
                    widget.onRename?.call(newName);
                  },
                  onBack: _showExitConfirmationDialog,
                  onSearch: _showSearch,
                  onShare: () {},
                  onMoreOptions: () => _showMoreOptionsMenu(context, controller),
                  onSaveToDevice: _saveToDevice,
                  onToggleTopDrawer: () {
                    setState(() {
                      _isTopDrawerOpen = !_isTopDrawerOpen;
                    });
                  },
                  isTopDrawerOpen: _isTopDrawerOpen,
                  copyAction: IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white),
                    onPressed: () => _copySelection(controller),
                  ),
                  pasteAction: IconButton(
                    icon: const Icon(Icons.paste, color: Colors.white),
                    onPressed: () => _pasteSelection(controller),
                  ),
                ),

                // Formula Bar
                Consumer<EditorController>(
                  builder: (context, controller, child) {
                    final anchor = _selectionAnchor(controller);
                    final cellValue = anchor != null
                        ? _gridKey.currentState?.getCellValue(anchor.row, anchor.column) ?? ''
                        : '';

                    return FormulaBar(
                      currentCellAddress: controller.selectedCellAddress ?? 'A1',
                      currentValue: cellValue,
                      onValueChanged: (val) {
                        final target = _selectionAnchor(controller);
                        if (target != null) {
                          _gridKey.currentState?.updateCellValue(target.row, target.column, val);
                        }
                      },
                      onSubmit: () {
                        final target = _selectionAnchor(controller);
                        if (target != null && controller.editingCell != null) {
                          _gridKey.currentState?.updateCellValue(
                            target.row,
                            target.column,
                            controller.editingCell!.value ?? '',
                          );
                        }
                      },
                    );
                  },
                ),

                // Grid Area with Floating Top Drawer Overlay
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        children: [
                      // Column headers (Fixed - doesn't scroll vertically)
                      Consumer<EditorController>(
                        builder: (context, controller, child) {
                          final colCount = controller.currentSheet?.metadata?.columnCount ?? 26;
                          return ColumnHeaders(
                            columnCount: colCount,
                            getColumnWidth: controller.getColumnWidth,
                            getColumnName: controller.getColumnName,
                            gridScrollController: _horizontalController,
                            getCellValue: (row, col) => _gridKey.currentState?.getCellValue(row, col) ?? '',
                            onColumnTap: controller.selectFullColumn,
                            onColumnLongPress: controller.requestEditColumn,
                            onColumnDoubleTap: controller.requestEditColumn,
                            onAddColumn: () => controller.addColumn(),
                            themeConfig: controller.themeConfig,
                            onSwipeLeft: (colIndex) => _showColumnSwipeMenu(colIndex, SwipeActionType.left),
                            onSwipeRight: (colIndex) => _showColumnSwipeMenu(colIndex, SwipeActionType.right),
                            onReorder: (oldIndex, newIndex) {
                              controller.reorderColumn(oldIndex, newIndex);
                              _gridKey.currentState?.reorderColumnData(oldIndex, newIndex);
                            },
                            frozenColumns: controller.frozenColumns,
                          );
                        },
                      ),

                      // Grid with row headers
                      Expanded(
                        child: Row(
                          children: [
                            // Row headers (Fixed - doesn't scroll horizontally)
                            Consumer<EditorController>(
                              builder: (context, controller, child) {
                                final rowCount = controller.currentSheet?.metadata?.rowCount ?? 1000;
                                return RowHeaders(
                                  rowCount: rowCount,
                                  rowHeight: controller.defaultRowHeight,
                                  getRowHeight: controller.getRowHeight,
                                  gridScrollController: _verticalController,
                                  onRowTap: controller.selectRow,
                                  onRowLongPress: (row) => _showRowProperties(context, controller, row),
                                  onAddRow: () => controller.addRow(),
                                  visibleRows: _visibleRows,
                                  themeConfig: controller.themeConfig,
                                  frozenRows: controller.frozenRows,
                                );
                              },
                            ),

                            // Main grid
                            Expanded(
                              child: Consumer<EditorController>(
                                builder: (context, controller, child) {
                                  final rowCount = controller.currentSheet?.metadata?.rowCount ?? 1000;
                                  final colCount = controller.currentSheet?.metadata?.columnCount ?? 26;
                                  return GridWidget(
                                    key: _gridKey,
                                    rowCount: rowCount,
                                    columnCount: colCount,
                                    sheetId: controller.currentSheet?.sheetId,
                                    getColumnWidth: controller.getColumnWidth,
                                    getColumnType: controller.getColumnType,
                                    getRowHeight: controller.getRowHeight,
                                    onRowCountRequired: controller.setRowCount,
                                    onColumnCountRequired: controller.setColumnCount,
                                    selectedFullRow: controller.selectedFullRow,
                                    selectedFullColumn: controller.selectedFullColumn,
                                    horizontalController: _horizontalController,
                                    verticalController: _verticalController,
                                    onCellTap: controller.selectCell,
                                    onCellDoubleTap: (row, col) {
                                      controller.editCell(row, col);
                                      _openEditorBottomSheet(context, controller);
                                    },
                                    onSearchMatchChanged: (current, total) {
                                      setState(() {
                                        _searchMatchCurrent = current;
                                        _searchMatchTotal = total;
                                      });
                                    },
                                    onVisibleRowsChanged: (rows) {
                                      setState(() {
                                        _visibleRows = rows;
                                      });
                                    },
                                    initialCellData: _cellData,
                                    onCellDataChanged: (data) {
                                       setState(() {
                                         _cellData = Map<String, String>.from(data);
                                       });
                                       SheetDataStorage.saveCellData(controller.currentSheet?.sheetId ?? widget.spreadsheet.spreadsheetId, _cellData);
                                     },
                                    themeConfig: controller.themeConfig,
                                    frozenRows: controller.frozenRows,
                                    frozenColumns: controller.frozenColumns,
                                    formatMap: _formatMap,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Floating Top Tool Drawer Overlay (Slides down over top of grid)
                  if (_isTopDrawerOpen)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: EditorTopDrawer(
                        onClose: () => setState(() => _isTopDrawerOpen = false),
                        onSaveToDevice: () => _saveToDevice(format: 'csv'),
                        onExportCsv: () => _saveToDevice(format: 'csv'),
                        onExportExcel: () => _saveToDevice(format: 'excel'),
                        onExportXlsx: () => _saveToDevice(format: 'xlsx'),
                        onExportPdf: () {
                          final anchor = _selectionAnchor(controller);
                          _showReceiptPdfForRow(context, anchor?.row ?? 0);
                        },
                        onRename: () {
                          setState(() => _isTopDrawerOpen = false);
                        },
                        onQuickShare: () {
                          final anchor = _selectionAnchor(controller);
                          _showQuickShareForRow(context, anchor?.row ?? 0);
                        },
                        onFindReplace: () {
                          setState(() {
                            _isTopDrawerOpen = false;
                            _isSearching = true;
                          });
                        },
                        onSmartTextParser: () {
                          setState(() => _isTopDrawerOpen = false);
                          SmartTextParserDialog.show(context, (parsedData) {});
                        },
                        onReceiptPdf: () {
                          setState(() => _isTopDrawerOpen = false);
                          final anchor = _selectionAnchor(controller);
                          _showReceiptPdfForRow(context, anchor?.row ?? 0);
                        },
                        onAudioRecorder: () {
                          setState(() => _isTopDrawerOpen = false);
                          showDialog(
                            context: context,
                            builder: (ctx) => const AudioRecorderDialog(),
                          );
                        },
                        onThemeCustomizer: () {
                          setState(() => _isTopDrawerOpen = false);
                          SpreadsheetThemeSheet.show(
                            context,
                            initialConfig: controller.themeConfig,
                            onApply: (config) => controller.updateThemeConfig(config),
                          );
                        },
                        onConditionalFormatting: () {
                          setState(() => _isTopDrawerOpen = false);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => cf_widgets.CFManagerSheet(
                              sheetId: controller.currentSheet?.sheetId ?? 'Sheet1',
                            ),
                          );
                        },
                        onFreezePanes: () {
                          setState(() => _isTopDrawerOpen = false);
                          controller.toggleFreezeTopRow();
                        },
                        onFooterSettings: () {
                          setState(() => _isTopDrawerOpen = false);
                        },
                        onSortAsc: () {
                          setState(() => _isTopDrawerOpen = false);
                        },
                        onSortDesc: () {
                          setState(() => _isTopDrawerOpen = false);
                        },
                        onFormulaHelper: () {
                          setState(() => _isTopDrawerOpen = false);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => FormulaHelperSheet(
                              onFormulaSelected: (formula) {},
                            ),
                          );
                        },
                        onAutoFill: () {
                          setState(() => _isTopDrawerOpen = false);
                          _autoFillSelection(controller);
                        },
                        onTextToColumns: () async {
                          setState(() => _isTopDrawerOpen = false);
                          
                          String initialVal = '';
                          int row = 0;
                          int col = 0;
                          if (controller.selectedCells.isNotEmpty) {
                            final pos = controller.selectedCells.first;
                            row = pos.row;
                            col = pos.column;
                            initialVal = _gridKey.currentState?.getCellValue(row, col) ?? _cellData['$row:$col'] ?? '';
                          }
                          
                          final resultData = await Navigator.of(context).push<Map<String, String>>(
                            MaterialPageRoute(
                              builder: (_) => TextToColumnsScreen(
                                controller: controller,
                                initialData: initialVal,
                                startRow: row,
                                startCol: col,
                                spreadsheetId: widget.spreadsheet.spreadsheetId,
                                existingCellData: _cellData,
                              ),
                            ),
                          );
                          
                          if (resultData != null && mounted) {
                            setState(() {
                              _cellData = Map<String, String>.from(resultData);
                            });
                            await SheetDataStorage.saveCellData(widget.spreadsheet.spreadsheetId, _cellData);
                          }
                        },
                        onPivotDesigner: () => _showPivotDesigner(context),
                        onPipelineApplied: (pipeline) async {
                          _gridKey.currentState?.syncFromNative();
                          final currentSheetId = widget.spreadsheet.spreadsheetId;
                          final savedFormats = await NumberFormatService.instance.loadFormats(currentSheetId);
                          final sheet1Formats = await NumberFormatService.instance.loadFormats('Sheet1');
                          final mergedFormats = Map<String, CellFormat>.from(savedFormats)..addAll(sheet1Formats);
                          if (mounted) {
                            setState(() {
                              _formatMap = mergedFormats;
                            });
                          }
                          await ConditionalFormattingService.restoreRules(currentSheetId);
                          await ConditionalFormattingService.restoreRules('Sheet1');
                          _gridKey.currentState?.syncFromNative();
                        },
                        onOpenPowerScriptStudio: _openPowerScriptStudio,
                        spreadsheetId: widget.spreadsheet.spreadsheetId,
                        cellData: _cellData,
                        formatMap: _formatMap,
                        onFormatMapChanged: (newMap) async {
                          setState(() => _formatMap = newMap);
                          final sheetId = widget.spreadsheet.spreadsheetId;
                          for (final entry in newMap.entries) {
                            final parts = entry.key.split(':');
                            if (parts.length == 2) {
                              final r = int.tryParse(parts[0]);
                              final c = int.tryParse(parts[1]);
                              if (r != null && c != null) {
                                await NumberFormatService.instance
                                    .saveFormat(sheetId, r, c, entry.value);
                              }
                            }
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),

                // Sheet Tabs
                Consumer<EditorController>(
                  builder: (context, controller, child) {
                    final sheets = controller.spreadsheet?.sheets ?? [];
                    final currentIndex = sheets.indexWhere((s) => s.sheetId == controller.currentSheet?.sheetId);
                    
                    return SheetTabsBar(
                      sheets: sheets,
                      selectedIndex: currentIndex >= 0 ? currentIndex : 0,
                      onSheetSelected: (index) async {
                        if (index >= 0 && index < sheets.length) {
                          final currentSheet = controller.currentSheet;
                          if (currentSheet != null) {
                            await SheetDataStorage.saveCellData(currentSheet.sheetId, _cellData);
                          }
                          controller.switchSheet(sheets[index]);
                          final fallbackId = index == 0 ? widget.spreadsheet.spreadsheetId : null;
                          final newData = await SheetDataStorage.loadCellData(sheets[index].sheetId, fallbackSpreadsheetId: fallbackId) ?? {};
                          // Only clear memory if agent is NOT running — let it finish in background
                          if (!CopilotService.isAgentRunning) {
                            LocalAgentService.clearMemory();
                            NativeEngine.clearGrid();
                          }
                          if (mounted) {
                            setState(() {
                              _cellData = newData;
                            });
                            _gridKey.currentState?.loadNewData(newData);
                          }
                          _syncCopilotWorkbookContext();
                        }
                      },
                      onAddSheet: () async {
                        final currentSheet = controller.currentSheet;
                        if (currentSheet != null) {
                          await SheetDataStorage.saveCellData(currentSheet.sheetId, _cellData);
                        }
                        controller.addSheet('Sheet ${sheets.length + 1}');
                        // Only clear memory if agent is NOT running — let it finish in background
                        if (!CopilotService.isAgentRunning) {
                          LocalAgentService.clearMemory();
                          NativeEngine.clearGrid();
                        }
                        if (mounted) {
                          setState(() {
                            _cellData = {};
                          });
                          _gridKey.currentState?.loadNewData({});
                        }
                        _syncCopilotWorkbookContext();
                      },
                      onRenameSheet: (index, newName) {
                        controller.renameSheet(index, newName);
                      },
                    );
                  },
                ),


                // Bottom toolbar
                if (_isSearching)
                  SearchToolbar(
                    onSearch: (query) => _gridKey.currentState?.search(query),
                    onNext: () => _gridKey.currentState?.nextMatch(),
                    onPrevious: () => _gridKey.currentState?.previousMatch(),
                    onReplace: (newText) => _gridKey.currentState?.replaceCurrent(newText),
                    onReplaceAll: (newText) => _gridKey.currentState?.replaceAll(newText),
                    currentMatch: _searchMatchCurrent,
                    totalMatches: _searchMatchTotal,
                    onClose: () {
                      setState(() {
                        _isSearching = false;
                        _searchMatchCurrent = 0;
                        _searchMatchTotal = 0;
                      });
                      _gridKey.currentState?.search('');
                    },
                  )
                else
                  Consumer<EditorController>(
                    builder: (context, controller, child) {
                      return GestureDetector(
                        onTap: () => _openEditorBottomSheet(context, controller),
                        onVerticalDragUpdate: (details) {
                          if (details.primaryDelta! < -5) {
                            _openEditorBottomSheet(context, controller);
                          }
                        },
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.menu, color: Colors.grey),
                                onPressed: () {
                                  _showMoreOptionsMenu(context, controller);
                                },
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  controller.currentSheet?.name ?? 'Sheet1',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF107C41)),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.keyboard_arrow_up, color: Colors.grey),
                                onPressed: () => _openEditorBottomSheet(context, controller),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            if (_showFloatingAiBot)
              SheetproAiFloatingBot(
                sheetId: controller.currentSheet?.sheetId ?? widget.spreadsheet.spreadsheetId,
                onPipelineApplied: _handlePipelineApplied,
                onDismiss: () {
                  setState(() {
                    _showFloatingAiBot = false;
                  });
                },
              ),
          ],
        );
        },
      ),
    ),
  );
  }

  void _openEditorBottomSheet(BuildContext context, EditorController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChangeNotifierProvider.value(
        value: controller,
        child: EditorBottomSheet(
          onClose: () => Navigator.pop(ctx),
          currentSheetName: controller.currentSheet?.name ?? 'Sheet1',
        ),
      ),
    );
  }

  void _showSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _showRowProperties(BuildContext context, EditorController controller, int row) {
    double currentHeight = controller.getRowHeight(row);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Row ${row + 1} Properties',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Row Height:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Text('${currentHeight.round()} px', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          setSheetState(() {
                            currentHeight = (currentHeight - 5).clamp(15.0, 150.0);
                          });
                          controller.updateRowHeight(row, currentHeight);
                        },
                      ),
                      Expanded(
                        child: Slider(
                          value: currentHeight,
                          min: 15.0,
                          max: 150.0,
                          divisions: 27,
                          label: '${currentHeight.round()}px',
                          onChanged: (val) {
                            setSheetState(() {
                              currentHeight = val;
                            });
                            controller.updateRowHeight(row, val);
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          setSheetState(() {
                            currentHeight = (currentHeight + 5).clamp(15.0, 150.0);
                          });
                          controller.updateRowHeight(row, currentHeight);
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.restore, size: 18),
                        label: const Text('Reset (40px)'),
                        onPressed: () {
                          setSheetState(() {
                            currentHeight = 40.0;
                          });
                          controller.updateRowHeight(row, 40.0);
                        },
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.format_line_spacing, size: 18),
                        label: const Text('Apply to All Rows'),
                        onPressed: () {
                          controller.updateAllRowHeights(currentHeight);
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  ListTile(
                    leading: const Icon(Icons.copy, color: Color(0xFF2879FF)),
                    title: const Text('Copy Row', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Copy the full row to clipboard'),
                    onTap: () async {
                      Navigator.pop(context);
                      await _copySelection(controller);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.auto_fix_high, color: Color(0xFF28C76F)),
                    title: const Text('AutoFill Row Down', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Duplicate this row to the next row'),
                    onTap: () async {
                      Navigator.pop(context);
                      await _autoFillSelection(controller);
                    },
                  ),
                  const Divider(height: 12),
                  ListTile(
                    leading: const Icon(Icons.add, color: Colors.green),
                    title: const Text('Insert Row Above'),
                    onTap: () {
                      Navigator.pop(context);
                      controller.addRow();
                      _gridKey.currentState?.insertRow(row);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.add, color: Colors.blue),
                    title: const Text('Insert Row Below'),
                    onTap: () {
                      Navigator.pop(context);
                      controller.addRow();
                      _gridKey.currentState?.insertRow(row + 1);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.picture_as_pdf, color: Color(0xFF2879FF)),
                    title: const Text('Generate Receipt PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Share invoice/voucher PDF for this row'),
                    onTap: () {
                      Navigator.pop(context);
                      _showReceiptPdfForRow(context, row);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.share, color: Color(0xFF28C76F)),
                    title: const Text('Quick Share Row Data', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Direct share to WhatsApp, Custom PDF & Gmail'),
                    onTap: () {
                      Navigator.pop(context);
                      _showQuickShareForRow(context, row);
                    },
                  ),
                  const Divider(height: 12),
                  ListTile(
                    leading: const Icon(Icons.delete_sweep, color: Colors.red),
                    title: const Text('Clear All Data in Row', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    subtitle: const Text('Clear all cell values in Row'),
                    onTap: () {
                      Navigator.pop(context);
                      _gridKey.currentState?.clearRowData(row);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Cleared all data in Row ${row + 1}'),
                          backgroundColor: Colors.red.shade700,
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showFormatOptions() {
    final controller = context.read<EditorController>();
    final cell = _selectionAnchor(controller);
    if (cell == null) return;
    
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Format Cell', style: TextStyle(fontWeight: FontWeight.bold)),
              ListTile(
                leading: const Icon(Icons.format_bold),
                title: const Text('Bold'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSortOptions() {
    final controller = context.read<EditorController>();
    final cell = _selectionAnchor(controller);
    if (cell == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a cell/column first to sort')),
      );
      return;
    }
    final colIndex = cell.column;
    final colLetter = String.fromCharCode(65 + (colIndex % 26));

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Sort Column $colLetter', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha, color: Colors.blue),
                title: const Text('Sort A to Z (Ascending)'),
                onTap: () {
                  Navigator.pop(context);
                  _gridKey.currentState?.sortColumn(colIndex, true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha, color: Colors.orange),
                title: const Text('Sort Z to A (Descending)'),
                onTap: () {
                  Navigator.pop(context);
                  _gridKey.currentState?.sortColumn(colIndex, false);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFilterOptions() {
    final controller = context.read<EditorController>();
    final cell = _selectionAnchor(controller);
    if (cell == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a cell/column first to filter')),
      );
      return;
    }
    final colIndex = cell.column;
    final colLetter = String.fromCharCode(65 + (colIndex % 26));
    final filterTextController = TextEditingController();

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Filter Column $colLetter', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(
                controller: filterTextController,
                decoration: const InputDecoration(
                  labelText: 'Filter text or pattern',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.filter_alt),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _gridKey.currentState?.clearFilters();
                    },
                    child: const Text('Clear Filter'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _gridKey.currentState?.filterColumn(colIndex, filterTextController.text);
                    },
                    child: const Text('Apply Filter'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMoreOptionsMenu(BuildContext context, EditorController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isRowFrozen = controller.frozenRows > 0;
            final isColFrozen = controller.frozenColumns > 0;

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Sheet Options & Tools',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          if (isRowFrozen || isColFrozen)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(Icons.ac_unit, size: 14, color: Colors.red),
                              label: const Text('Unfreeze All', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                controller.setFreezeState(rows: 0, columns: 0);
                                setModalState(() {});
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // ── FREEZE PANES COMPACT CONTAINER ──
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.ac_unit_rounded, size: 16, color: Color(0xFF2563EB)),
                                SizedBox(width: 6),
                                Text(
                                  'Freeze Panes (Lock Scrolling)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1E293B)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            SwitchListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Freeze Top Row (Row 1)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              subtitle: const Text('Header row stays visible when scrolling down', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                              value: isRowFrozen,
                              activeColor: const Color(0xFF2563EB),
                              onChanged: (val) {
                                controller.toggleFreezeTopRow();
                                setModalState(() {});
                              },
                            ),
                            const Divider(height: 2),
                            SwitchListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Freeze First Column (Column A)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              subtitle: const Text('First column stays visible when scrolling right', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                              value: isColFrozen,
                              activeColor: const Color(0xFF2563EB),
                              onChanged: (val) {
                                controller.toggleFreezeFirstColumn();
                                setModalState(() {});
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: const Icon(Icons.palette_outlined, size: 20, color: Color(0xFF2848D3)),
                        title: const Text('Spreadsheet Theme & Colors', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.pop(context);
                          _showThemeOptions(context, controller);
                        },
                      ),
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: const Icon(Icons.format_paint_outlined, size: 20, color: Color(0xFFE65100)),
                        title: const Text('Conditional Formatting', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.pop(context);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => cf_widgets.CFManagerSheet(sheetId: controller.currentSheet?.sheetId ?? 'Sheet1'),
                          );
                        },
                      ),
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: const Icon(Icons.functions_outlined, size: 20, color: Color(0xFF28C76F)),
                        title: const Text('Summary Footer Bar', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.pop(context);
                          _showFooterOptions(context, controller);
                        },
                      ),
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF7367F0)),
                        title: const Text('Search & Replace Data', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.pop(context);
                          _showSearch();
                        },
                      ),
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: const Icon(Icons.sort_by_alpha_rounded, size: 20, color: Color(0xFFFF9F43)),
                        title: const Text('Sort Column Data', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.pop(context);
                          _showSortOptions();
                        },
                      ),
                      const Divider(height: 12),
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: const Icon(Icons.psychology, size: 20, color: Color(0xFF28C76F)),
                        title: const Text('WhatsApp Smart Text Parser', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Auto-extract entry from copied WhatsApp text', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        onTap: () {
                          Navigator.pop(context);
                          _showSmartTextParser(context, controller);
                        },
                      ),
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: const Icon(Icons.picture_as_pdf_outlined, size: 20, color: Color(0xFF2879FF)),
                        title: const Text('Generate Receipt PDF from Selected Row', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Share PDF voucher for selected row', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        onTap: () {
                          Navigator.pop(context);
                          final selectedRow = controller.selectedFullRow ??
                              controller.selectedCells.firstOrNull?.row ??
                              0;
                          _showReceiptPdfForRow(context, selectedRow);
                        },
                      ),
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: const Icon(Icons.tune, size: 20, color: Color(0xFF2879FF)),
                        title: const Text('Customize Invoice & PDF Layout', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Set business name, logo, tax % & terms once', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const InvoiceCustomizerScreen()),
                          );
                        },
                      ),
                      const Divider(height: 12),
                      SwitchListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        secondary: const Icon(Icons.smart_toy_rounded, size: 20, color: Color(0xFF06B6D4)),
                        title: const Text('Sheetpro AI Floating Bot', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Animated Lottie bot on sheet for instant AI Copilot', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        value: _showFloatingAiBot,
                        activeColor: const Color(0xFF06B6D4),
                        onChanged: (val) {
                          setState(() {
                            _showFloatingAiBot = val;
                          });
                          setModalState(() {});
                        },
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPivotDesigner(BuildContext context) {
    setState(() => _isTopDrawerOpen = false);

    final Map<String, String> data = _cellData;
    List<String> availableColumns = [];
    for (int c = 0; c < 26; c++) {
      String cellRef = '0:$c';
      if (data.containsKey(cellRef) && data[cellRef]!.isNotEmpty) {
        availableColumns.add(data[cellRef]!);
      }
    }
    if (availableColumns.isEmpty) {
      availableColumns = ['Region', 'Category', 'Product', 'Sales', 'Quantity'];
    }

    setState(() {
      _pivotAvailableColumns = availableColumns;
    });

    // Use Future.delayed or addPostFrameCallback to ensure the state updates the drawer before opening
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldKey.currentState?.openEndDrawer();
    });
  }

  void _onCopilotPipelineTriggered() async {
    final pipeline = CopilotService.pipelineNotifier.value;
    if (pipeline == null) return;
    
    // Reset value so we don't trigger recursively or re-run same pipeline
    CopilotService.pipelineNotifier.value = null;

    final steps = pipeline['steps'] as List?;
    if (steps != null) {
      for (var step in steps) {
        if (step is Map && step['type'] == 'create_pivot_table') {
          final rowFields = List<String>.from(step['rowFields'] ?? []);
          final colFields = List<String>.from(step['colFields'] ?? []);
          final dataFields = List<String>.from(step['dataFields'] ?? []);
          final slicerFields = List<String>.from(step['slicerFields'] ?? []);
          final aggTypeStr = step['aggType']?.toString() ?? 'SUM';
          final themeStr = step['theme']?.toString() ?? 'professionalBlue';

          final aggType = AggregationTypeExtension.fromString(aggTypeStr);
          PivotThemeMode themeMode = PivotThemeMode.professionalBlue;
          try {
            themeMode = PivotThemeMode.values.firstWhere(
              (e) => e.toString().split('.').last == themeStr,
              orElse: () => PivotThemeMode.professionalBlue,
            );
          } catch (_) {}

          // Extract headers from _cellData
          final availableCols = <String>[];
          for (int c = 0; c < 26; c++) {
            final header = _cellData['0:$c'];
            if (header != null && header.isNotEmpty) {
              availableCols.add(header.trim());
            }
          }
          if (availableCols.isEmpty) {
            availableCols.addAll(['Region', 'Category', 'Product', 'Sales', 'Quantity']);
          }

          await _applyPivotToSheet(
            context,
            availableCols,
            rowFields,
            colFields,
            dataFields,
            slicerFields,
            aggType,
            themeMode,
          );
        }
      }
    }

    // Always sync Dart-side grid from C++ engine to catch updates from any run_script steps
    _gridKey.currentState?.syncFromNative();
  }

  Future<void> _applyPivotToSheet(
    BuildContext context,
    List<String> availableColumns,
    List<String> rowFields,
    List<String> colFields,
    List<String> dataFields,
    List<String> slicerFields,
    AggregationType aggType,
    PivotThemeMode themeMode,
  ) async {
    final controller = Provider.of<EditorController>(context, listen: false);
    final currentSheetId = controller.currentSheet?.sheetId ?? widget.spreadsheet.spreadsheetId;

    final Map<String, String> updatedCellData = Map<String, String>.from(_cellData);
    final Map<String, CellFormat> updatedFormatMap = Map<String, CellFormat>.from(_formatMap);

    final actualRowFields = rowFields.isNotEmpty
        ? rowFields
        : (availableColumns.isNotEmpty ? [availableColumns.first] : ['Region']);
    final actualDataFields = dataFields.isNotEmpty
        ? dataFields
        : (availableColumns.length > 1 ? [availableColumns.last] : ['Sales']);

    bool needsSampleData = updatedCellData.isEmpty;
    bool hasHeaders = false;
    for (int c = 0; c < 26; c++) {
      if (updatedCellData.containsKey('0:$c') && updatedCellData['0:$c']!.isNotEmpty) {
        hasHeaders = true;
        break;
      }
    }
    if (!hasHeaders) {
      needsSampleData = true;
    }

    if (needsSampleData) {
      final sampleHeaders = ['Region', 'Category', 'Product', 'Sales', 'Quantity'];
      for (int c = 0; c < sampleHeaders.length; c++) {
        updatedCellData['0:$c'] = sampleHeaders[c];
      }

      final sampleRows = [
        ['North', 'Electronics', 'Phone', '1500', '10'],
        ['North', 'Electronics', 'Laptop', '3200', '5'],
        ['South', 'Clothing', 'Shirt', '800', '20'],
        ['South', 'Electronics', 'Tablet', '2100', '7'],
        ['East', 'Furniture', 'Chair', '1200', '15'],
        ['West', 'Clothing', 'Jacket', '950', '12'],
      ];

      for (int r = 0; r < sampleRows.length; r++) {
        for (int c = 0; c < sampleRows[r].length; c++) {
          final cellRef = '${r + 1}:$c';
          updatedCellData[cellRef] = sampleRows[r][c];
        }
      }
      availableColumns = sampleHeaders;
    }

    _cellData = Map<String, String>.from(updatedCellData);
    final List<Map<String, dynamic>> rawData = _buildRawDataFromSpreadsheet(updatedCellData, availableColumns);

    final pivotEngine = PivotEngine();
    final pivotResult = await pivotEngine.pivot(
      sheetId: currentSheetId,
      rowFields: actualRowFields,
      colFields: colFields,
      dataFields: actualDataFields,
      aggType: aggType,
      themeMode: themeMode,
      slicerFields: slicerFields,
      rawData: rawData,
    );

    int maxCol = -1;
    for (String key in updatedCellData.keys) {
      if (updatedCellData[key]?.isNotEmpty ?? false) {
        final parts = key.split(':');
        if (parts.length == 2) {
          int c = int.tryParse(parts[1]) ?? 0;
          if (c > maxCol) maxCol = c;
        }
      }
    }

    int startCol = maxCol >= 0 ? maxCol + 2 : 5; // e.g., Column F (index 5) or 2 columns after last column

    final theme = pivotResult.theme;
    String colorToHex(Color color) {
      final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
      final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
      final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
      return '#$r$g$b';
    }

    final headerBgHex = colorToHex(theme.headerBgColor);
    final headerTextHex = colorToHex(theme.headerTextColor);
    final accentHex = colorToHex(theme.accentColor);
    final rowBgHex = colorToHex(theme.rowBgColor);

    // 1. Write Header Row 0
    int headerColIdx = startCol;
    for (final rf in actualRowFields) {
      updatedCellData['0:$headerColIdx'] = rf;
      updatedFormatMap['0:$headerColIdx'] = CellFormat.general;
      headerColIdx++;
    }
    for (final colHeader in pivotResult.colHeaderGrid) {
      updatedCellData['0:$headerColIdx'] = colHeader.join(" - ");
      updatedFormatMap['0:$headerColIdx'] = CellFormat.general;
      headerColIdx++;
    }
    for (final df in actualDataFields) {
      updatedCellData['0:$headerColIdx'] = 'Grand Total - $df';
      updatedFormatMap['0:$headerColIdx'] = CellFormat.general;
      headerColIdx++;
    }

    // Common row styling formats
    final rowBgAltHex = colorToHex(theme.alternateRowBgColor);
    final textColorHex = colorToHex(theme.textColor);

    // 2. Populate Pivot Rows
    int rIdx = 1;
    for (int i = 0; i < pivotResult.rowHeaderGrid.length; i++) {
      int colIdx = startCol;

      // Row Header values
      for (final val in pivotResult.rowHeaderGrid[i]) {
        updatedCellData['$rIdx:$colIdx'] = val;
        updatedFormatMap['$rIdx:$colIdx'] = CellFormat.general;
        colIdx++;
      }

      // Matrix Data cells
      for (int c = 0; c < pivotResult.colHeaderGrid.length; c++) {
        final cellVal = i < pivotResult.dataGrid.length && c < pivotResult.dataGrid[i].length ? pivotResult.dataGrid[i][c] : 0.0;
        final valStr = cellVal is double ? (cellVal % 1 == 0 ? cellVal.toInt().toString() : cellVal.toStringAsFixed(2)) : cellVal.toString();
        updatedCellData['$rIdx:$colIdx'] = valStr;
        updatedFormatMap['$rIdx:$colIdx'] = CellFormat.number;
        colIdx++;
      }

      // Row Subtotals / Grand Totals
      final dfCount = pivotResult.dataFields.length;
      for (int dfIdx = 0; dfIdx < dfCount; dfIdx++) {
        final subtotalIdx = i * dfCount + dfIdx;
        final subtotalVal = subtotalIdx < pivotResult.rowSubtotals.length ? pivotResult.rowSubtotals[subtotalIdx] : 0.0;
        final subtotalStr = subtotalVal.toStringAsFixed(2);
        updatedCellData['$rIdx:$colIdx'] = subtotalStr;
        updatedFormatMap['$rIdx:$colIdx'] = CellFormat.number;
        colIdx++;
      }

      rIdx++;
    }

    // 3. Grand Total Row (Bottom)
    int colIdx = startCol;

    // Grand Total labels
    updatedCellData['$rIdx:$colIdx'] = 'Grand Total';
    updatedFormatMap['$rIdx:$colIdx'] = CellFormat.general;
    colIdx++;
    for (int j = 1; j < actualRowFields.length; j++) {
      updatedCellData['$rIdx:$colIdx'] = '';
      updatedFormatMap['$rIdx:$colIdx'] = CellFormat.general;
      colIdx++;
    }

    // Column subtotals
    for (int c = 0; c < pivotResult.colSubtotals.length; c++) {
      final subtotalVal = pivotResult.colSubtotals[c];
      final subtotalStr = subtotalVal.toStringAsFixed(2);
      updatedCellData['$rIdx:$colIdx'] = subtotalStr;
      updatedFormatMap['$rIdx:$colIdx'] = CellFormat.number;
      colIdx++;
    }

    // Overall grand totals (for each value field)
    final dfCount = pivotResult.dataFields.length;
    for (int dfIdx = 0; dfIdx < dfCount; dfIdx++) {
      double sumOfSubtotals = 0.0;
      for (int c = dfIdx; c < pivotResult.colSubtotals.length; c += dfCount) {
        sumOfSubtotals += pivotResult.colSubtotals[c];
      }
      final gtVal = dfIdx == 0 ? pivotResult.grandTotal : sumOfSubtotals;
      updatedCellData['$rIdx:$colIdx'] = gtVal.toStringAsFixed(2);
      updatedFormatMap['$rIdx:$colIdx'] = CellFormat.number;
      colIdx++;
    }

    // Add Native Conditional Formatting Rules for Pivot Table styling
    final startColLetter = EditorController.getColumnLetter(startCol);
    final endColLetter = EditorController.getColumnLetter(colIdx - 1);

    try {
      // 1. Header formatting rule (Row 1)
      final headerRule = {
        "id": "pivot_hdr_${DateTime.now().millisecondsSinceEpoch}",
        "ranges": ["${startColLetter}1:${endColLetter}1"],
        "type": "Static",
        "op": "None",
        "style": {
          "bgColor": headerBgHex,
          "textColor": headerTextHex,
          "fontColor": headerTextHex,
          "bold": true,
        }
      };
      NativeEngine.cfAddRule(currentSheetId, jsonEncode(headerRule));
      if (currentSheetId != 'Sheet1') {
        NativeEngine.cfAddRule('Sheet1', jsonEncode(headerRule));
      }

      // 2. Data rows formatting rule
      if (pivotResult.rowHeaderGrid.isNotEmpty) {
        final totalRows = pivotResult.rowHeaderGrid.length;
        final dataRule = {
          "id": "pivot_data_${DateTime.now().millisecondsSinceEpoch}",
          "ranges": ["${startColLetter}2:${endColLetter}${totalRows + 1}"],
          "type": "Static",
          "op": "None",
          "style": {
            "bgColor": rowBgHex,
            "textColor": colorToHex(theme.textColor),
            "fontColor": colorToHex(theme.textColor),
          }
        };
        NativeEngine.cfAddRule(currentSheetId, jsonEncode(dataRule));
        if (currentSheetId != 'Sheet1') {
          NativeEngine.cfAddRule('Sheet1', jsonEncode(dataRule));
        }
      }

      // 3. Grand total row formatting rule
      final totalRowIdx = pivotResult.rowHeaderGrid.length + 2;
      final totalRule = {
        "id": "pivot_tot_${DateTime.now().millisecondsSinceEpoch}",
        "ranges": ["${startColLetter}$totalRowIdx:${endColLetter}$totalRowIdx"],
        "type": "Static",
        "op": "None",
        "style": {
          "bgColor": headerBgHex,
          "textColor": accentHex,
          "fontColor": accentHex,
          "bold": true,
        }
      };
      NativeEngine.cfAddRule(currentSheetId, jsonEncode(totalRule));
      if (currentSheetId != 'Sheet1') {
        NativeEngine.cfAddRule('Sheet1', jsonEncode(totalRule));
      }
    } catch (e) {
      debugPrint('[PivotTable] Error applying CF rules: $e');
    }

    setState(() {
      _cellData = Map<String, String>.from(updatedCellData);
      _formatMap = Map<String, CellFormat>.from(updatedFormatMap);
    });

    _gridKey.currentState?.loadNewData(_cellData);

    await SheetDataStorage.saveCellData(currentSheetId, _cellData);
    await ConditionalFormattingService.saveRules(currentSheetId);
    if (currentSheetId != 'Sheet1') {
      await ConditionalFormattingService.saveRules('Sheet1');
    }
    if (currentSheetId != widget.spreadsheet.spreadsheetId) {
      await SheetDataStorage.saveCellData(widget.spreadsheet.spreadsheetId, _cellData);
      await ConditionalFormattingService.saveRules(widget.spreadsheet.spreadsheetId);
    }

    final colCount = controller.currentSheet?.metadata?.columnCount ?? 26;
    if (colIdx > colCount) {
      controller.setColumnCount(colIdx);
    }

    // Auto-scroll grid to Pivot Table position so user sees it immediately
    if (_horizontalController.hasClients) {
      final targetOffset = (startCol - 1) * 90.0;
      _horizontalController.animateTo(
        targetOffset.clamp(0.0, _horizontalController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }

    debugPrint('PIVOT TABLE SUCCESSFULLY BLENDED AT COLUMN $startCol');

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.table_chart, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Pivot Table blended into Sheet at Column ${EditorController.getColumnLetter(startCol)}!'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1B5E20),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _buildRawDataFromSpreadsheet(Map<String, String> cellData, List<String> columns) {
    List<Map<String, dynamic>> rows = [];
    
    // Find column indices based on header names in row 0
    Map<String, int> colIndices = {};
    for (int c = 0; c < 50; c++) {
      String cellRef = '0:$c';
      if (cellData.containsKey(cellRef) && cellData[cellRef]!.trim().isNotEmpty) {
        final headerText = cellData[cellRef]!.trim();
        colIndices[headerText] = c;
        colIndices[headerText.toLowerCase()] = c;
        colIndices[headerText.toUpperCase()] = c;
      }
      // Also map Column letters A, B, C, D...
      String colLetter = EditorController.getColumnLetter(c);
      colIndices[colLetter] = c;
      colIndices[colLetter.toLowerCase()] = c;
    }

    int maxRow = 100;
    for (var k in cellData.keys) {
      final parts = k.split(':');
      if (parts.length == 2) {
        final r = int.tryParse(parts[0]) ?? 0;
        if (r > maxRow) maxRow = r;
      }
    }

    for (int r = 1; r <= maxRow; r++) {
      bool hasData = false;
      Map<String, dynamic> rowMap = {};
      for (String colName in columns) {
        int c = colIndices[colName] ?? colIndices[colName.toLowerCase()] ?? colIndices[colName.toUpperCase()] ?? -1;
        if (c >= 0) {
          String ref = '$r:$c';
          String val = cellData[ref] ?? '';
          if (val.trim().isNotEmpty) hasData = true;
          
          double? numVal = double.tryParse(val.replaceAll(RegExp(r'[₹$€£¥¢,]'), '').trim());
          rowMap[colName] = numVal ?? val.trim();
        } else {
          rowMap[colName] = '';
        }
      }
      if (hasData) {
        rows.add(rowMap);
      }
    }

    if (rows.isEmpty) {
      return [
        {'Region': 'North', 'Category': 'Electronics', 'Product': 'Phone', 'Sales': 1500.0, 'Quantity': 10},
        {'Region': 'North', 'Category': 'Electronics', 'Product': 'Laptop', 'Sales': 3200.0, 'Quantity': 5},
        {'Region': 'South', 'Category': 'Clothing', 'Product': 'Shirt', 'Sales': 800.0, 'Quantity': 20},
        {'Region': 'South', 'Category': 'Electronics', 'Product': 'Tablet', 'Sales': 2100.0, 'Quantity': 7},
        {'Region': 'East', 'Category': 'Furniture', 'Product': 'Chair', 'Sales': 1200.0, 'Quantity': 15},
        {'Region': 'West', 'Category': 'Clothing', 'Product': 'Jacket', 'Sales': 950.0, 'Quantity': 12},
      ];
    }
    return rows;
  }
}
