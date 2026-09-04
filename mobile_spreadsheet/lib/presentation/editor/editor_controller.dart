import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/spreadsheet_entity.dart';
import '../../domain/entities/sheet_entity.dart';
import '../../domain/entities/cell_range.dart';
import '../../domain/entities/cell_entity.dart';
import '../../domain/entities/column_types/base/column_type.dart';
import '../../domain/entities/column_types/text/text_column_type.dart';
import '../../domain/entities/theme/spreadsheet_theme_config.dart';
import '../../domain/services/storage/sheet_data_storage.dart';
import '../../domain/entities/excel_image_entity.dart';

/// Cell position for grid coordinates
class CellPosition {
  final int row;
  final int column;

  const CellPosition(this.row, this.column);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellPosition && runtimeType == other.runtimeType &&
          row == other.row && column == other.column;

  @override
  int get hashCode => row.hashCode ^ column.hashCode;

  @override
  String toString() => 'CellPosition(row: $row, column: $column)';
}

/// Controller for editor screen state management
class EditorController extends ChangeNotifier {
  SpreadsheetEntity? _spreadsheet;
  SheetEntity? _currentSheet;
  
  // Selection state
  final List<CellPosition> _selectedCells = [];
  CellRange? _currentSelection;
  CellRange? _dragPreviewRange;
  int? _selectedFullRow;
  CellEntity? _editingCell;
  
  // Viewport state
  double _scrollX = 0.0;
  double _scrollY = 0.0;
  double _zoom = 1.0;
  
  // UI state
  bool _isFormulaBarVisible = true;
  bool _isLoading = false;
  String? _error;

  // Theme Configuration State
  SpreadsheetThemeConfig _themeConfig = SpreadsheetThemeConfig.defaultTheme;
  
  // Footer Configuration State
  SheetFooterConfig _footerConfig = const SheetFooterConfig();
  
  // Column properties
  final Map<int, double> _columnWidths = {};
  final Map<int, String> _columnNames = {};
  final Map<int, ColumnType> _columnTypes = {};

  // Row properties
  final Map<int, double> _rowHeights = {};
  double _defaultRowHeight = 40.0;

  int? _selectedFullColumn;
  
  // Undo/Redo stacks
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];

  // Freeze state
  int _frozenRows = 0; // 0 = none, 1 = Row 1 (Top row)
  int _frozenColumns = 0; // 0 = none, 1 = Column A (First col)

  // Getters
  SpreadsheetEntity? get spreadsheet => _spreadsheet;
  SheetEntity? get currentSheet => _currentSheet;
  List<CellPosition> get selectedCells => List.unmodifiable(_selectedCells);
  CellRange? get currentSelection => _currentSelection;
  CellRange? get dragPreviewRange => _dragPreviewRange;
  int? get selectedFullRow => _selectedFullRow;
  int? get selectedFullColumn => _selectedFullColumn;
  CellEntity? get editingCell => _editingCell;
  bool get isFormulaBarVisible => _isFormulaBarVisible;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get scrollX => _scrollX;
  double get scrollY => _scrollY;
  double get zoom => _zoom;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  double get defaultRowHeight => _defaultRowHeight;
  SpreadsheetThemeConfig get themeConfig => _themeConfig;
  SheetFooterConfig get footerConfig => _footerConfig;
  int get frozenRows => _frozenRows;
  int get frozenColumns => _frozenColumns;

  /// Toggle top row (Row 1) freeze state
  void toggleFreezeTopRow() {
    _frozenRows = _frozenRows > 0 ? 0 : 1;
    notifyListeners();
    _saveFreezeState();
  }

  /// Toggle first column (Column A) freeze state
  void toggleFreezeFirstColumn() {
    _frozenColumns = _frozenColumns > 0 ? 0 : 1;
    notifyListeners();
    _saveFreezeState();
  }

  /// Set explicit freeze state
  void setFreezeState({int? rows, int? columns}) {
    if (rows != null) _frozenRows = rows;
    if (columns != null) _frozenColumns = columns;
    notifyListeners();
    _saveFreezeState();
  }

  Future<void> _saveFreezeState() async {
    if (_spreadsheet == null) return;
    final sheetId = _spreadsheet!.spreadsheetId;
    SheetDataStorage.saveFreezeConfig(sheetId, _frozenRows, _frozenColumns);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('freeze_rows_$sheetId', _frozenRows);
      await prefs.setInt('freeze_cols_$sheetId', _frozenColumns);
    } catch (e) {
      print('Error saving freeze prefs: $e');
    }
  }

  /// Update and persist theme configuration
  void updateThemeConfig(SpreadsheetThemeConfig config) {
    _themeConfig = config;
    notifyListeners();
    if (_spreadsheet != null) {
      SheetDataStorage.saveThemeConfig(_spreadsheet!.spreadsheetId, config);
    }
  }

  void toggleFormulaBar() {
    _isFormulaBarVisible = !_isFormulaBarVisible;
    notifyListeners();
  }

  bool _isSheetTabsVisible = true;
  bool get isSheetTabsVisible => _isSheetTabsVisible;
  
  void toggleSheetTabs() {
    _isSheetTabsVisible = !_isSheetTabsVisible;
    notifyListeners();
  }

  /// Update and persist footer configuration
  void updateFooterConfig(SheetFooterConfig config) {
    _footerConfig = config;
    if (_currentSheet != null) {
      final newMetadata = (_currentSheet!.metadata ?? const SheetMetadata()).copyWith(
        footerConfig: config,
      );
      _currentSheet = _currentSheet!.copyWith(metadata: newMetadata);
    }
    notifyListeners();
    if (_spreadsheet != null) {
      SheetDataStorage.saveFooterConfig(_spreadsheet!.spreadsheetId, config.toJson());
    }
  }

  /// Add new row(s) to current sheet
  void addRow({int count = 1}) {
    if (_currentSheet == null) return;
    final currentCount = _currentSheet!.metadata?.rowCount ?? 1000;
    setRowCount(currentCount + count);
  }

  /// Set absolute row count for current sheet
  void setRowCount(int count) {
    if (_currentSheet == null) return;
    final currentCount = _currentSheet!.metadata?.rowCount ?? 1000;
    if (count <= currentCount) return; // Only increase
    final updatedMetadata = (_currentSheet!.metadata ?? const SheetMetadata()).copyWith(
      rowCount: count,
    );
    _currentSheet = _currentSheet!.copyWith(metadata: updatedMetadata);
    notifyListeners();
  }

  /// Set absolute column count for current sheet
  void setColumnCount(int count) {
    if (_currentSheet == null) return;
    final currentCount = _currentSheet!.metadata?.columnCount ?? 26;
    if (count <= currentCount) return; // Only increase
    final updatedMetadata = (_currentSheet!.metadata ?? const SheetMetadata()).copyWith(
      columnCount: count,
    );
    _currentSheet = _currentSheet!.copyWith(metadata: updatedMetadata);
    notifyListeners();
  }

  /// Add new column(s) to current sheet
  void addColumn({int count = 1}) {
    if (_currentSheet == null) return;
    final currentCount = _currentSheet!.metadata?.columnCount ?? 26;
    final newCount = currentCount + count;
    final updatedMetadata = (_currentSheet!.metadata ?? const SheetMetadata()).copyWith(
      columnCount: newCount,
    );
    _currentSheet = _currentSheet!.copyWith(metadata: updatedMetadata);
    notifyListeners();
  }

  /// Get row height for a specific row
  double getRowHeight(int row) => _rowHeights[row] ?? _defaultRowHeight;

  /// Update row height for a specific row
  void updateRowHeight(int row, double height) {
    _rowHeights[row] = height.clamp(15.0, 200.0);
    notifyListeners();
  }

  // --- Column Management for Swipe & Reorder ---
  
  /// Delete a column at the specified index
  void deleteColumn(int index) {
    if (_currentSheet == null) return;
    final currentCount = _currentSheet!.metadata?.columnCount ?? 26;
    if (currentCount <= 1) return; // Cannot delete last column

    final updatedMetadata = (_currentSheet!.metadata ?? const SheetMetadata()).copyWith(
      columnCount: currentCount - 1,
    );
    _currentSheet = _currentSheet!.copyWith(metadata: updatedMetadata);
    
    // Adjust selections if needed
    _selectedCells.clear();
    _editingCell = null;
    notifyListeners();
  }

  /// Duplicate a column at the specified index
  void duplicateColumn(int index) {
    insertColumnAt(index + 1); // Insert blank column to the right
  }

  /// Insert a blank column at the specified index
  void insertColumnAt(int index) {
    if (_currentSheet == null) return;
    final currentCount = _currentSheet!.metadata?.columnCount ?? 26;

    final updatedMetadata = (_currentSheet!.metadata ?? const SheetMetadata()).copyWith(
      columnCount: currentCount + 1,
    );
    _currentSheet = _currentSheet!.copyWith(metadata: updatedMetadata);
    notifyListeners();
  }

  /// Reorder a column from oldIndex to newIndex (metadata only, no data shift here)
  void reorderColumn(int oldIndex, int newIndex) {
    if (oldIndex == newIndex || _currentSheet == null) return;
    _selectedCells.clear();
    _editingCell = null;
    notifyListeners();
  }
  // --- End Column Management ---

  /// Update row height for all rows
  void updateAllRowHeights(double height) {
    _defaultRowHeight = height.clamp(15.0, 200.0);
    _rowHeights.clear();
    notifyListeners();
  }

  /// Reset row height to default (40px)
  void resetRowHeights() {
    _defaultRowHeight = 40.0;
    _rowHeights.clear();
    notifyListeners();
  }

  /// Rename the spreadsheet
  void renameSpreadsheet(String newName) {
    if (_spreadsheet == null || newName.trim().isEmpty) return;
    _spreadsheet = _spreadsheet!.copyWith(name: newName.trim(), updatedAt: DateTime.now());
    notifyListeners();
  }

  /// Get selected cell address (e.g., "A1")
  String? get selectedCellAddress {
    if (_selectedCells.isNotEmpty) {
      final cell = _selectedCells.first;
      return '${getColumnLetter(cell.column)}${cell.row + 1}';
    }
    if (_selectedFullColumn != null) {
      return '${getColumnLetter(_selectedFullColumn!)}1';
    }
    return null;
  }

  /// Get selected cell value
  String? get selectedCellValue {
    if (_editingCell != null) {
      return _editingCell!.value ?? '';
    }
    return '';
  }

  /// Load spreadsheet data & theme configuration
  Future<void> loadSpreadsheet(SpreadsheetEntity spreadsheet) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _spreadsheet = spreadsheet;
      if (spreadsheet.sheets.isNotEmpty) {
        _currentSheet = spreadsheet.sheets.first;
        
        int maxRow = _currentSheet!.metadata?.rowCount ?? 1000;
        int maxCol = _currentSheet!.metadata?.columnCount ?? 26;
        bool changed = false;

        if (spreadsheet.transientCellData != null) {
          for (final key in spreadsheet.transientCellData!.keys) {
            final parts = key.split(':');
            if (parts.length == 2) {
              final r = int.tryParse(parts[0]) ?? 0;
              final c = int.tryParse(parts[1]) ?? 0;
              if (r >= maxRow) {
                maxRow = r + 50;
                changed = true;
              }
              if (c >= maxCol) {
                maxCol = c + 5;
                changed = true;
              }
            }
          }
        }
        
        if (changed || _currentSheet!.metadata == null) {
          final newMetadata = (_currentSheet!.metadata ?? const SheetMetadata()).copyWith(
            rowCount: maxRow,
            columnCount: maxCol,
          );
          _currentSheet = _currentSheet!.copyWith(metadata: newMetadata);
        }
      }

      // Load saved theme config if available
      final savedTheme = await SheetDataStorage.loadThemeConfig(spreadsheet.spreadsheetId);
      if (savedTheme != null) {
        _themeConfig = savedTheme;
      }
      
      // Load saved footer config if available
      final savedFooter = await SheetDataStorage.loadFooterConfig(spreadsheet.spreadsheetId);
      if (savedFooter != null) {
        _footerConfig = SheetFooterConfig.fromJson(savedFooter);
      } else if (_currentSheet?.metadata?.footerConfig != null) {
        _footerConfig = _currentSheet!.metadata!.footerConfig!;
      } else {
        _footerConfig = const SheetFooterConfig();
      }

      // Load saved freeze config if available
      final savedFreeze = await SheetDataStorage.loadFreezeConfig(spreadsheet.spreadsheetId);
      if (savedFreeze != null) {
        _frozenRows = savedFreeze['frozenRows'] ?? 0;
        _frozenColumns = savedFreeze['frozenColumns'] ?? 0;
      } else {
        try {
          final prefs = await SharedPreferences.getInstance();
          _frozenRows = prefs.getInt('freeze_rows_${spreadsheet.spreadsheetId}') ?? 0;
          _frozenColumns = prefs.getInt('freeze_cols_${spreadsheet.spreadsheetId}') ?? 0;
        } catch (_) {
          _frozenRows = 0;
          _frozenColumns = 0;
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Select single cell
  void selectCell(int row, int column) {
    _selectedFullRow = null;
    _selectedFullColumn = null;
    _selectedCells.clear();
    _selectedCells.add(CellPosition(row, column));
    _currentSelection = CellRange(row, column, row, column);
    _editingCell = null;
    notifyListeners();
  }

  void selectFullColumn(int column) {
    _selectedFullRow = null;
    _selectedFullColumn = column;
    _selectedCells.clear();
    _currentSelection = null;
    _editingCell = null;
    notifyListeners();
  }

  void clearFullColumnSelection() {
    _selectedFullColumn = null;
    _selectedFullRow = null;
    notifyListeners();
  }

  /// Select cell range
  void selectRange(CellPosition start, CellPosition end) {
    _selectedFullRow = null;
    _selectedFullColumn = null;
    _selectedCells.clear();
    
    final startRow = start.row < end.row ? start.row : end.row;
    final endRow = start.row > end.row ? start.row : end.row;
    final startCol = start.column < end.column ? start.column : end.column;
    final endCol = start.column > end.column ? start.column : end.column;
    
    _currentSelection = CellRange(startRow, startCol, endRow, endCol);

    for (int row = startRow; row <= endRow; row++) {
      for (int col = startCol; col <= endCol; col++) {
        _selectedCells.add(CellPosition(row, col));
      }
    }
    
    _editingCell = null;
    _isFormulaBarVisible = false;
    notifyListeners();
  }

  /// Set the drag preview range during AutoFill drag
  void updateDragPreview(CellRange range) {
    _dragPreviewRange = range;
    notifyListeners();
  }

  /// Clear the drag preview range
  void clearDragPreview() {
    _dragPreviewRange = null;
    notifyListeners();
  }

  /// Edit cell (enter edit mode)
  void editCell(int row, int column) {
    selectCell(row, column);
    _editingCell = CellEntity(
      cellId: 'temp-${row}-${column}',
      sheetId: _currentSheet?.sheetId ?? '',
      rowId: 'row-$row',
      columnId: 'col-$column',
      value: '',
      dataType: CellDataType.text,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
    );
    _isFormulaBarVisible = true;
    notifyListeners();
  }

  /// Update cell value during editing
  void updateCellValue(String value) {
    if (_editingCell != null) {
      _editingCell = _editingCell!.copyWith(
        value: value,
        modifiedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  /// Commit cell edit
  void commitCellEdit() {
    if (_editingCell != null) {
      _editingCell = null;
      _isFormulaBarVisible = false;
      notifyListeners();
    }
  }

  /// Select entire column
  void selectColumn(int column) {
    _selectedFullRow = null;
    _selectedFullColumn = column;
    _selectedCells.clear();
    final rowCount = _currentSheet?.metadata?.rowCount ?? 1000;
    for (int row = 0; row < rowCount; row++) {
      _selectedCells.add(CellPosition(row, column));
    }
    _editingCell = null;
    _isFormulaBarVisible = false;
    notifyListeners();
  }
  
  int? _columnToEdit;
  int? get columnToEdit => _columnToEdit;
  
  void requestEditColumn(int column) {
    _columnToEdit = column;
    notifyListeners();
  }
  
  void clearEditColumnRequest() {
    _columnToEdit = null;
    notifyListeners();
  }

  double getColumnWidth(int col) => _columnWidths[col] ?? 120.0;
  String? getColumnName(int col) => _columnNames[col];
  ColumnType getColumnType(int col) => _columnTypes[col] ?? const TextColumnType();

  void updateColumnProperties(int col, String name, ColumnType type, double width) {
    _columnNames[col] = name;
    _columnTypes[col] = type;
    _columnWidths[col] = width;
    notifyListeners();
  }

  /// Select entire row
  void selectRow(int row) {
    _selectedFullRow = row;
    _selectedFullColumn = null;
    _selectedCells.clear();
    final colCount = _currentSheet?.metadata?.columnCount ?? 26;
    for (int col = 0; col < colCount; col++) {
      _selectedCells.add(CellPosition(row, col));
    }
    _editingCell = null;
    _isFormulaBarVisible = false;
    notifyListeners();
  }

  /// Switch to different sheet
  void switchSheet(SheetEntity sheet) {
    _currentSheet = sheet;
    _selectedCells.clear();
    _selectedFullRow = null;
    _selectedFullColumn = null;
    _editingCell = null;
    _isFormulaBarVisible = false;
    notifyListeners();
  }

  /// Add a new sheet
  void addSheet(String name) {
    if (_spreadsheet == null) return;
    
    final sheets = List<SheetEntity>.from(_spreadsheet!.sheets);
    final newSheet = SheetEntity(
      sheetId: DateTime.now().millisecondsSinceEpoch.toString(), // Simple UUID
      spreadsheetId: _spreadsheet!.spreadsheetId,
      name: name,
      position: sheets.length,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      metadata: const SheetMetadata(),
    );
    
    sheets.add(newSheet);
    _spreadsheet = _spreadsheet!.copyWith(sheets: sheets);
    switchSheet(newSheet);
  }

  /// Rename a sheet
  void renameSheet(int index, String newName) {
    if (_spreadsheet == null || index < 0 || index >= _spreadsheet!.sheets.length) return;
    
    final sheets = List<SheetEntity>.from(_spreadsheet!.sheets);
    final oldSheet = sheets[index];
    final updatedSheet = oldSheet.copyWith(name: newName, updatedAt: DateTime.now());
    
    sheets[index] = updatedSheet;
    _spreadsheet = _spreadsheet!.copyWith(sheets: sheets);
    
    if (_currentSheet?.sheetId == updatedSheet.sheetId) {
      _currentSheet = updatedSheet;
    }
    
    notifyListeners();
  }

  /// Delete a sheet
  void deleteSheet(int index) {
    if (_spreadsheet == null || index < 0 || index >= _spreadsheet!.sheets.length || _spreadsheet!.sheets.length <= 1) return;
    
    final sheets = List<SheetEntity>.from(_spreadsheet!.sheets);
    final targetSheet = sheets.removeAt(index);
    _spreadsheet = _spreadsheet!.copyWith(sheets: sheets);
    
    if (_currentSheet?.sheetId == targetSheet.sheetId) {
      switchSheet(sheets.first);
    } else {
      notifyListeners();
    }
  }

  /// Update viewport position
  void updateViewport(double x, double y, double zoom) {
    _scrollX = x;
    _scrollY = y;
    _zoom = zoom.clamp(0.5, 2.0);
    notifyListeners();
  }

  /// Undo last action
  void undo() {
    if (_undoStack.isNotEmpty) {
      final action = _undoStack.removeLast();
      _redoStack.add(action);
      notifyListeners();
    }
  }

  /// Redo last undone action
  void redo() {
    if (_redoStack.isNotEmpty) {
      final action = _redoStack.removeLast();
      _undoStack.add(action);
      notifyListeners();
    }
  }

  static String getColumnLetter(int index) {
    String letter = '';
    int position = index;
    
    while (position >= 0) {
      letter = String.fromCharCode(65 + (position % 26)) + letter;
      position = (position ~/ 26) - 1;
    }
    
    return letter;
  }

  void updateImage(ExcelImageEntity newImage) {
    if (_currentSheet == null) return;
    
    final images = List<ExcelImageEntity>.from(_currentSheet!.images);
    final index = images.indexWhere((img) => img.id == newImage.id);
    
    if (index >= 0) {
      images[index] = newImage;
      _currentSheet = _currentSheet!.copyWith(images: images);

      // Persist to global spreadsheet so switching tabs doesn't lose data
      if (_spreadsheet != null) {
        final sheets = List<SheetEntity>.from(_spreadsheet!.sheets);
        final sheetIdx = sheets.indexWhere((s) => s.sheetId == _currentSheet!.sheetId);
        if (sheetIdx >= 0) {
          sheets[sheetIdx] = _currentSheet!;
          _spreadsheet = _spreadsheet!.copyWith(sheets: sheets);
        }
      }

      notifyListeners();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
