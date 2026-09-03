import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../domain/entities/column_types/base/column_type.dart';
import '../../../../domain/entities/theme/spreadsheet_theme_config.dart';
import '../../../../domain/entities/cell_range.dart';
import '../../../../application/autofill/autofill_engine.dart';
import '../../../../domain/services/super_engine/ffi_bridge.dart';
import '../../../../domain/services/super_engine/formula_utils.dart';
import '../../../../domain/services/super_engine/formula_rewrite_engine.dart';
import '../../../../domain/services/copy_paste_engine/copy_paste_engine.dart';
import 'formula_progress_dialog.dart';
import 'audio_recorder_dialog.dart';
import '../../../../domain/services/conditional_formatting_service.dart';
import '../modules/number_format/number_format_model.dart';

String _recalculateAllTask(Map<String, String> cellData) {
  NativeEngine.initialize();
  NativeEngine.clearGrid();

  cellData.forEach((key, val) {
    final parts = key.split(':');
    if (parts.length != 2) return;
    final r = int.tryParse(parts[0]);
    final c = int.tryParse(parts[1]);
    if (r == null || c == null) return;
    final cellRef = FormulaUtils.cellRefFromCoords(r, c);

    final trimmed = val.trim();

    if (trimmed.startsWith('=')) {
      NativeEngine.setCellFormula(cellRef, trimmed);
    } else {
      // Clean currency/thousands formatting if purely numeric
      final cleanNumStr = trimmed.replaceAll(RegExp(r'[^0-9.\-+eE]'), '');
      final isFormattedNum = cleanNumStr.isNotEmpty && !trimmed.contains(RegExp(r'[a-df-zA-DF-Z]'));
      final num = double.tryParse(isFormattedNum ? cleanNumStr : trimmed);
      if (num != null) {
        NativeEngine.setCellConstant(cellRef, num);
      } else {
        NativeEngine.setCellConstantString(cellRef, val);
      }
    }
  });

  return NativeEngine.calculateAll();
}

String _cfCurrentSheetId(String? sheetId, String? spreadsheetId) {
  return sheetId ?? 'Sheet1'; 
}

/// Check if formula needs progress indicator
bool _needsProgressDialog(String formula) {
  if (!formula.startsWith('=')) return false;
  
  final upperFormula = formula.toUpperCase();
  final largeArrayFunctions = ['MAKEARRAY', 'SEQUENCE', 'RANDARRAY', 'SORTBY'];
  
  for (final func in largeArrayFunctions) {
    if (upperFormula.contains(func)) {
      // Simple heuristic: check if numbers > 100
      final numRegex = RegExp(r'\d+');
      final matches = numRegex.allMatches(formula);
      for (final match in matches) {
        final num = int.tryParse(match.group(0) ?? '0') ?? 0;
        if (num >= 100) return true; // 100x100 or more
      }
    }
  }
  
  return false;
}

/// High-performance Grid widget â€” uses CustomPainter to draw cells on canvas
/// instead of building 26 widgets per row. Only ~20 CustomPaint widgets exist
/// at any time (one per visible row), giving buttery smooth scrolling.
class GridWidget extends StatefulWidget {
  final int rowCount;
  final int columnCount;
  final double Function(int) getColumnWidth;
  final ColumnType Function(int) getColumnType;
  final double Function(int)? getRowHeight;
  final int? selectedFullRow;
  final int? selectedFullColumn;
  final double rowHeight;
  final ScrollController? horizontalController;
  final ScrollController? verticalController;
  final Function(int row, int column)? onCellTap;
  final Function(int row, int column)? onCellDoubleTap;
  final Map<String, String>? initialCellData;
  final ValueChanged<Map<String, String>>? onCellDataChanged;
  final ValueChanged<int>? onRowCountRequired;
  final ValueChanged<int>? onColumnCountRequired;
  final Function(int current, int total)? onSearchMatchChanged;
  final ValueChanged<List<int>>? onVisibleRowsChanged;
  final SpreadsheetThemeConfig? themeConfig;
  final int frozenRows;
  final int frozenColumns;
  final String? sheetId;
  final Map<String, CellFormat> formatMap;

  const GridWidget({
    Key? key,
    this.rowCount = 1000,
    this.columnCount = 26,
    required this.getColumnWidth,
    required this.getColumnType,
    this.getRowHeight,
    this.selectedFullRow,
    this.selectedFullColumn,
    this.rowHeight = 40.0,
    this.horizontalController,
    this.verticalController,
    this.onCellTap,
    this.onCellDoubleTap,
    this.initialCellData,
    this.onCellDataChanged,
    this.onRowCountRequired,
    this.onColumnCountRequired,
    this.onSearchMatchChanged,
    this.onVisibleRowsChanged,
    this.themeConfig,
    this.frozenRows = 0,
    this.frozenColumns = 0,
    this.sheetId,
    this.formatMap = const {},
  }) : super(key: key);

  @override
  GridWidgetState createState() => GridWidgetState();
}

class GridWidgetState extends State<GridWidget> {
  late ScrollController _horizontalController;
  late ScrollController _verticalController;
  bool _internalHorizontalController = false;
  bool _internalVerticalController = false;

  CellRange? _currentSelection;
  CellRange? get currentSelection => _currentSelection;
  CellRange? _dragPreviewRange;
  int? get _selectedRow => _currentSelection?.startRow;
  int? get _selectedColumn => _currentSelection?.startCol;
  
  int? _editingRow;
  int? _editingColumn;
  String? _initialEditText;
  bool _snapshotSavedThisEdit = false;
  int _dataVersion = 0;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // AutoFill State
  bool _showFillHandle = false;   // Handle visible after double-tap / long-press
  bool _isDragFilling = false;    // Currently dragging the handle
  bool _handleTouched = false;    // Raw pointer is on the handle
  int? _fillTargetRow;
  int? _fillTargetCol;

  // Selection Handle Drag State (blue circles at corners of multi-cell selection)
  bool _isDraggingSelectionHandle = false;
  bool _isTopLeftHandle = false;  // true = dragging top-left, false = bottom-right

  // Double-tap detection
  DateTime? _lastTapTime;
  int? _lastTapRow;
  int? _lastTapCol;

  // Store cell data
  late Map<String, String> _cellData;
  Map<String, String> _evaluatedData = {};
  Map<String, String> _spillData = {};
  Map<String, dynamic> _cfStyles = {};
  
  // Sorting & Filtering
  late List<int> _visibleRows;
  
  // Undo / Redo Stacks
  final List<Map<String, String>> _undoStack = [];
  final List<Map<String, String>> _redoStack = [];

  // Search state
  String? _searchQuery;
  List<String> _searchMatches = [];
  int _currentMatchIndex = -1;
  Map<int, double> _autoRowHeights = {};
  int _recalcGeneration = 0;

  double _getH(int row) {
    final baseHeight = widget.getRowHeight?.call(row) ?? widget.rowHeight;
    final autoHeight = _autoRowHeights[row] ?? 0.0;
    return math.max(baseHeight, autoHeight);
  }
  Map<String, String> get cellData => _cellData;

  String getCellValue(int row, int col) {
    return _cellData['$row:$col'] ?? '';
  }


  // --- Data Shifting for Column Operations ---
  void deleteColumnData(int colIndex) {
    final newData = Map<String, String>.from(_cellData);
    final toRemove = <String>[];
    
    _cellData.forEach((key, value) {
      final parts = key.split(':');
      if (parts.length != 2) return;
      final row = int.tryParse(parts[0]);
      final col = int.tryParse(parts[1]);
      if (row == null || col == null) return;

      if (col == colIndex) {
        toRemove.add(key);
      } else if (col > colIndex) {
        toRemove.add(key);
        newData['$row:${col - 1}'] = value;
      }
    });

    for (final key in toRemove) {
      newData.remove(key);
    }
    setState(() {
      _saveSnapshot();
      _cellData = newData;
      _dataVersion++;
      _recalculateAll();
      widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
    });
  }

  void duplicateColumnData(int colIndex) {
    insertColumnData(colIndex + 1); // shift everything right
    final newData = Map<String, String>.from(_cellData);
    _cellData.forEach((key, value) {
      final parts = key.split(':');
      if (parts.length == 2) {
        final row = int.tryParse(parts[0]);
        final col = int.tryParse(parts[1]);
        if (row != null && col == colIndex) {
          newData['$row:${colIndex + 1}'] = value;
        }
      }
    });
    setState(() {
      _saveSnapshot();
      _cellData = newData;
      _dataVersion++;
      _recalculateAll();
      widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
    });
  }

  void insertColumnData(int colIndex) {
    final newData = Map<String, String>.from(_cellData);
    final keysToShift = _cellData.keys.where((k) {
      final parts = k.split(':');
      return parts.length == 2 && (int.tryParse(parts[1]) ?? -1) >= colIndex;
    }).toList();
    
    keysToShift.sort((a, b) {
      final colA = int.parse(a.split(':')[1]);
      final colB = int.parse(b.split(':')[1]);
      return colB.compareTo(colA);
    });

    for (final key in keysToShift) {
      final parts = key.split(':');
      final row = parts[0];
      final col = int.parse(parts[1]);
      newData['$row:${col + 1}'] = newData[key]!;
      newData.remove(key);
    }
    setState(() {
      _saveSnapshot();
      _cellData = newData;
      _dataVersion++;
      _recalculateAll();
      widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
    });
  }

  /// Clear all cell values in a single row
  void clearRowData(int rowIndex) {
    final newData = Map<String, String>.from(_cellData);
    final toRemove = <String>[];
    newData.forEach((key, value) {
      final parts = key.split(':');
      if (parts.length == 2 && int.tryParse(parts[0]) == rowIndex) {
        toRemove.add(key);
      }
    });
    for (final k in toRemove) {
      newData.remove(k);
    }
    setState(() {
      _saveSnapshot();
      _cellData = newData;
      _dataVersion++;
      _recalculateAll();
      widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
    });
  }

  /// Clear all cell values in a single column
  void clearColumnData(int colIndex) {
    final newData = Map<String, String>.from(_cellData);
    final toRemove = <String>[];
    newData.forEach((key, value) {
      final parts = key.split(':');
      if (parts.length == 2 && int.tryParse(parts[1]) == colIndex) {
        toRemove.add(key);
      }
    });
    for (final k in toRemove) {
      newData.remove(k);
    }
    setState(() {
      _saveSnapshot();
      _cellData = newData;
      _dataVersion++;
      _recalculateAll();
      widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
    });
  }

  /// Load entirely new data into the grid (e.g., when switching sheets)
  void loadNewData(Map<String, String> newData) {
    setState(() {
      _cellData = Map.from(newData);
      _dataVersion++;
      _recalculateAll();
    });
  }

  /// Clear all cell values in the entire grid
  void clearAllGridData() {
    setState(() {
      _saveSnapshot();
      _cellData.clear();
      _evaluatedData.clear();
      _spillData.clear();
      _dataVersion++;
      NativeEngine.clearGrid();
      widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
    });
  }

  /// Clear all cell values in multiple selected rows
  void clearMultipleRowsData(List<int> rowIndices) {
    final rowSet = rowIndices.toSet();
    final newData = Map<String, String>.from(_cellData);
    final toRemove = <String>[];
    newData.forEach((key, value) {
      final parts = key.split(':');
      if (parts.length == 2) {
        final r = int.tryParse(parts[0]);
        if (r != null && rowSet.contains(r)) {
          toRemove.add(key);
        }
      }
    });
    for (final k in toRemove) {
      newData.remove(k);
    }
    setState(() {
      _saveSnapshot();
      _cellData = newData;
      _dataVersion++;
      _recalculateAll();
      widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
    });
  }

  void reorderColumnData(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final newData = Map<String, String>.from(_cellData);
    
    final colDataToMove = <int, String>{};
    _cellData.forEach((key, value) {
      final parts = key.split(':');
      if (parts.length == 2) {
        final row = int.tryParse(parts[0]);
        final col = int.tryParse(parts[1]);
        if (row != null && col == oldIndex) {
          colDataToMove[row] = value;
        }
      }
    });

    final shiftStart = math.min(oldIndex, newIndex);
    final shiftEnd = math.max(oldIndex, newIndex);
    final shiftAmount = oldIndex < newIndex ? -1 : 1;

    final keysToShift = _cellData.keys.where((k) {
      final parts = k.split(':');
      if (parts.length != 2) return false;
      final col = int.tryParse(parts[1]);
      if (col == null || col == oldIndex) return false;
      return col >= shiftStart && col <= shiftEnd;
    }).toList();

    keysToShift.sort((a, b) {
      final colA = int.parse(a.split(':')[1]);
      final colB = int.parse(b.split(':')[1]);
      return shiftAmount > 0 ? colB.compareTo(colA) : colA.compareTo(colB);
    });

    for (final key in keysToShift) {
      final parts = key.split(':');
      final row = parts[0];
      final col = int.parse(parts[1]);
      newData['$row:${col + shiftAmount}'] = newData[key]!;
      newData.remove(key);
    }

    colDataToMove.keys.forEach((row) {
      newData.remove('$row:$oldIndex');
    });

    colDataToMove.forEach((row, value) {
      newData['$row:$newIndex'] = value;
    });

    setState(() {
      _saveSnapshot();
      _cellData = newData;
      _dataVersion++;
      _recalculateAll();
      widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
    });
  }
  // --- End Data Shifting ---

  void updateCellValue(int row, int col, String val) {
    setState(() {
      _saveSnapshot();
      final key = '$row:$col';
      if (val.isNotEmpty) {
        _cellData[key] = val;
      } else {
        _cellData.remove(key);
      }
      _dataVersion++;
      _recalculateAll();
      widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
    });
  }

  void _saveSnapshot() {
    _undoStack.add(Map.from(_cellData));
    if (_undoStack.length > 50) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isNotEmpty) {
      setState(() {
        _redoStack.add(Map.from(_cellData));
        _cellData = _undoStack.removeLast();
        _dataVersion++;
        _recalculateAll();
      widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
      });
    }
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(Map.from(_cellData));
      _cellData = _redoStack.removeLast();
      _dataVersion++;
      _recalculateAll();
      widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
    });
  }

  // Sorting and Filtering Methods
  void sortColumn(int columnIndex, bool ascending) {
    setState(() {
      final bool hasHeader = _visibleRows.contains(0);
      final dataRows = hasHeader 
          ? _visibleRows.where((r) => r != 0).toList() 
          : List<int>.from(_visibleRows);

      dataRows.sort((a, b) {
        final valA = _cellData['$a:$columnIndex'] ?? '';
        final valB = _cellData['$b:$columnIndex'] ?? '';
        final numA = double.tryParse(valA);
        final numB = double.tryParse(valB);
        if (numA != null && numB != null) {
          return ascending ? numA.compareTo(numB) : numB.compareTo(numA);
        }
        return ascending ? valA.compareTo(valB) : valB.compareTo(valA);
      });

      _visibleRows = hasHeader ? [0, ...dataRows] : dataRows;
      _dataVersion++;
      widget.onVisibleRowsChanged?.call(List.unmodifiable(_visibleRows));
    });
  }

  void filterColumn(int columnIndex, String query) {
    setState(() {
      if (query.isEmpty) {
        _visibleRows = List.generate(widget.rowCount, (index) => index);
      } else {
        final q = query.trim().toLowerCase();
        _visibleRows = List.generate(widget.rowCount, (index) => index).where((row) {
          final val = (_cellData['$row:$columnIndex'] ?? '').trim().toLowerCase();
          return val.contains(q);
        }).toList();
      }
      _dataVersion++;
      widget.onVisibleRowsChanged?.call(List.unmodifiable(_visibleRows));
    });
  }
  
  void clearFilters() {
    setState(() {
      _visibleRows = List.generate(widget.rowCount, (index) => index);
      _dataVersion++;
      widget.onVisibleRowsChanged?.call(List.unmodifiable(_visibleRows));
    });
  }

  void refreshGrid() {
    setState(() {
      _dataVersion++;
      _recalculateAll();
    });
  }

  void syncFromNative() {
    final rawJson = NativeEngine.getRawGrid();
    if (rawJson == null || rawJson.isEmpty) return;
    try {
      Map<String, dynamic> gridMap;
      try {
        gridMap = jsonDecode(rawJson);
      } catch (_) {
        // Fallback: sanitize unescaped backslashes in raw JSON string
        final sanitized = rawJson.replaceAllMapped(
          RegExp(r'\\([^"\\/bfnrtu])'),
          (match) => '\\\\${match.group(1)}',
        );
        gridMap = jsonDecode(sanitized);
      }

      final newCellData = <String, String>{};
      gridMap.forEach((cellRef, value) {
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
          newCellData['$r:$c'] = value.toString();
        }
      });


      setState(() {
        _cellData = Map<String, String>.from(newCellData);
        _dataVersion++;
        _recalculateAll();
      });
      widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
    } catch (e) {
      debugPrint("syncFromNative error: $e");
    }
  }


  // --- Search Logic ---
  void search(String query) {
    setState(() {
      _searchQuery = query;
      _searchMatches.clear();
      _currentMatchIndex = -1;
      if (query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final isNumeric = double.tryParse(q) != null;
        _cellData.forEach((key, value) {
          final valTrimmed = value.trim().toLowerCase();
          if (valTrimmed.isEmpty) return;
          bool isMatch = false;
          if (isNumeric) {
            isMatch = valTrimmed == q;
          } else {
            if (q.length <= 3) {
              isMatch = valTrimmed.split(RegExp(r'\s+')).contains(q);
            } else {
              isMatch = valTrimmed.contains(q);
            }
          }
          if (isMatch) {
            final rowStr = key.split(':')[0];
            final rowInt = int.tryParse(rowStr) ?? -1;
            if (_visibleRows.contains(rowInt)) {
              _searchMatches.add(key);
            }
          }
        });
        _searchMatches.sort((a, b) {
          final pa = a.split(':');
          final pb = b.split(':');
          final r1 = int.tryParse(pa[0]) ?? 0;
          final c1 = int.tryParse(pa[1]) ?? 0;
          final r2 = int.tryParse(pb[0]) ?? 0;
          final c2 = int.tryParse(pb[1]) ?? 0;
          if (r1 != r2) return r1.compareTo(r2);
          return c1.compareTo(c2);
        });
        if (_searchMatches.isNotEmpty) {
          _currentMatchIndex = 0;
          _scrollToMatch();
          widget.onSearchMatchChanged?.call(_currentMatchIndex + 1, _searchMatches.length);
        } else {
          widget.onSearchMatchChanged?.call(0, 0);
        }
      } else {
        widget.onSearchMatchChanged?.call(0, 0);
      }
      _dataVersion++;
    });
  }

  void nextMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _searchMatches.length;
      _scrollToMatch();
      widget.onSearchMatchChanged?.call(_currentMatchIndex + 1, _searchMatches.length);
      _dataVersion++;
    });
  }

  void previousMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1 + _searchMatches.length) % _searchMatches.length;
      _scrollToMatch();
      widget.onSearchMatchChanged?.call(_currentMatchIndex + 1, _searchMatches.length);
      _dataVersion++;
    });
  }

  void replaceCurrent(String newText) {
    if (_searchMatches.isEmpty || _currentMatchIndex < 0) return;
    setState(() {
      _saveSnapshot();
      final key = _searchMatches[_currentMatchIndex];
      _cellData[key] = newText;
      search(_searchQuery ?? '');
      _recalculateAll();
      widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
    });
  }

  void replaceAll(String newText) {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _saveSnapshot();
      for (final key in _searchMatches) {
        _cellData[key] = newText;
      }
      search(_searchQuery ?? '');
      _recalculateAll();
      widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
    });
  }

  void _scrollToMatch() {
    if (_currentMatchIndex < 0 || _currentMatchIndex >= _searchMatches.length) return;
    final key = _searchMatches[_currentMatchIndex];
    final parts = key.split(':');
    final row = int.tryParse(parts[0]) ?? 0;
    final col = int.tryParse(parts[1]) ?? 0;
    final visualRowIndex = _visibleRows.indexOf(row);
    if (visualRowIndex == -1) return;
    double targetY = 0;
    for (int i = 0; i < visualRowIndex; i++) {
      targetY += _getH(_visibleRows[i]);
    }
    double targetX = 0;
    for (int i = 0; i < col; i++) {
      targetX += widget.getColumnWidth(i);
    }
    _verticalController.animateTo(
      targetY.clamp(0.0, _verticalController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _horizontalController.animateTo(
      targetX.clamp(0.0, _horizontalController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Inserts a row and rebases formula cell references
  void insertRow(int rowIndex) {
    setState(() {
      _saveSnapshot();
      final Map<String, String> newData = {};
      _cellData.forEach((key, value) {
        final parts = key.split(':');
        final r = int.tryParse(parts[0]) ?? 0;
        final c = int.tryParse(parts[1]) ?? 0;
        final updatedValue = value.startsWith('=')
            ? FormulaUtils.shiftFormulaReferences(value, insertedRow: rowIndex)
            : value;
        if (r >= rowIndex) {
          newData['${r + 1}:$c'] = updatedValue;
        } else {
          newData[key] = updatedValue;
        }
      });
      _cellData = newData;
      _visibleRows = List.generate(widget.rowCount + 1, (index) => index);
      _dataVersion++;
      _recalculateAll();
      widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
    });
    widget.onVisibleRowsChanged?.call(_visibleRows);
  }

  /// Inserts a column and rebases formula cell references
  void insertColumn(int colIndex) {
    setState(() {
      _saveSnapshot();
      final Map<String, String> newData = {};
      _cellData.forEach((key, value) {
        final parts = key.split(':');
        final r = int.tryParse(parts[0]) ?? 0;
        final c = int.tryParse(parts[1]) ?? 0;
        final updatedValue = value.startsWith('=')
            ? FormulaRewriteEngine.rewrite(value, insertedCol: colIndex)
            : value;
        if (c >= colIndex) {
          newData['$r:${c + 1}'] = updatedValue;
        } else {
          newData[key] = updatedValue;
        }
      });
      _cellData = newData;
      _dataVersion++;
      _recalculateAll();
      widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
    });
  }

  /// Deletes a row and updates formula references to #REF! or shifted index
  void deleteRow(int rowIndex) {
    setState(() {
      _saveSnapshot();
      final Map<String, String> newData = {};
      _cellData.forEach((key, value) {
        final parts = key.split(':');
        final r = int.tryParse(parts[0]) ?? 0;
        final c = int.tryParse(parts[1]) ?? 0;

        if (r == rowIndex) {
          // Row is deleted, drop cells in deleted row
          return;
        }

        final updatedValue = value.startsWith('=')
            ? FormulaRewriteEngine.rewrite(value, deletedRow: rowIndex)
            : value;

        if (r > rowIndex) {
          newData['${r - 1}:$c'] = updatedValue;
        } else {
          newData[key] = updatedValue;
        }
      });
      _cellData = newData;
      if (_visibleRows.length > 1) {
        _visibleRows = List.generate(_visibleRows.length - 1, (index) => index);
      }
      _dataVersion++;
      _recalculateAll();
      widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
    });
    widget.onVisibleRowsChanged?.call(_visibleRows);
  }

  /// Deletes a column and updates formula references to #REF! or shifted index
  void deleteColumn(int colIndex) {
    setState(() {
      _saveSnapshot();
      final Map<String, String> newData = {};
      _cellData.forEach((key, value) {
        final parts = key.split(':');
        final r = int.tryParse(parts[0]) ?? 0;
        final c = int.tryParse(parts[1]) ?? 0;

        if (c == colIndex) {
          // Column is deleted, drop cells in deleted column
          return;
        }

        final updatedValue = value.startsWith('=')
            ? FormulaRewriteEngine.rewrite(value, deletedCol: colIndex)
            : value;

        if (c > colIndex) {
          newData['$r:${c - 1}'] = updatedValue;
        } else {
          newData[key] = updatedValue;
        }
      });
      _cellData = newData;
      _dataVersion++;
      _recalculateAll();
      widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
    });
  }

  // Fast Vertical Scroll Slider State
  final ValueNotifier<bool> _showFastScrollerNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> _currentScrolledRowNotifier = ValueNotifier<int>(1);
  bool _isDraggingScroller = false;
  Timer? _scrollerHideTimer;
  DateTime? _scrollStartTime;
  double _dragStartScrollOffset = 0.0;
  double _dragStartGlobalY = 0.0;

  int _getRowIndexAtOffset(double offset) {
    if (_visibleRows.isEmpty) return 1;
    double currentY = 0.0;
    for (int i = 0; i < _visibleRows.length; i++) {
      final actualRowIndex = _visibleRows[i];
      final h = _getH(actualRowIndex);
      if (offset >= currentY && offset < currentY + h) {
        return actualRowIndex + 1; // 1-based index
      }
      currentY += h;
    }
    return _visibleRows.last + 1;
  }

  void _onVerticalScroll() {
    // Hide bottom sheet if scrolling significantly
  }

  void _onHorizontalScroll() {
    // Intentionally empty. Columns should not auto-expand just by scrolling right.
    // They expand via automation, formulas, or explicit user action.
  }
  
  bool _isEvaluating = false;

  Future<void> _recalculateAll() async {
    final generation = ++_recalcGeneration;
    final snapshot = Map<String, String>.from(_cellData);

    if (!mounted) return;
    setState(() {
      _isEvaluating = true;
    });

    String resultJson = '{}';
    try {
      NativeEngine.initialize();
      resultJson = _recalculateAllTask(snapshot);
    } catch (e) {
      debugPrint('Engine recalculation failed: $e');
    }

    if (!mounted || generation != _recalcGeneration) return;
    setState(() {
      _isEvaluating = false;
      _spillData.clear();
      _evaluatedData.clear(); // Clear before parsing new results
      
      int maxRequiredRow = 0;
      int maxRequiredCol = 0;

      if (resultJson.isNotEmpty && resultJson != "{}") {
        try {
          final Map<String, dynamic> parsed = jsonDecode(resultJson);
          parsed.forEach((cellRef, value) {
            final coords = FormulaUtils.parseCellRef(cellRef);
            if (coords != null) {
              final key = '${coords.$1}:${coords.$2}';
              
              if (value is Map && value['type'] == 'spill') {
                 final List<dynamic> data = value['data'];
                 maxRequiredRow = math.max(maxRequiredRow, coords.$1 + data.length);
                 int maxColInSpill = 0;
                 for (int r = 0; r < data.length; r++) {
                   final rowList = data[r] as List;
                   maxColInSpill = math.max(maxColInSpill, coords.$2 + rowList.length);
                 }
                 maxRequiredCol = math.max(maxRequiredCol, maxColInSpill);
                 
                 bool blocked = false;
                 for (int r = 0; r < data.length; r++) {
                   final rowList = data[r] as List;
                   for (int c = 0; c < rowList.length; c++) {
                     if (r == 0 && c == 0) continue;
                     final targetKey = '${coords.$1 + r}:${coords.$2 + c}';
                     final existingContent = _cellData[targetKey];
                     if (existingContent != null && existingContent.isNotEmpty) {
                       blocked = true;
                       break;
                     }
                   }
                   if (blocked) break;
                 }
                 
                 if (blocked) {
                   _evaluatedData[key] = '#SPILL!';
                 } else {
                   _evaluatedData[key] = data[0][0].toString();
                   for (int r = 0; r < data.length; r++) {
                     final rowList = data[r] as List;
                     for (int c = 0; c < rowList.length; c++) {
                       if (r == 0 && c == 0) continue;
                       final targetKey = '${coords.$1 + r}:${coords.$2 + c}';
                       _spillData[targetKey] = rowList[c].toString();
                     }
                   }
                 }
              } else {
                _evaluatedData[key] = value.toString();
              }
            }
          });
        } catch (e) {
          debugPrint('Error parsing calculate result: $e');
        }
      }

      _cellData.forEach((k, v) {
        if (v.trim().startsWith('=')) {
          final parts = k.split(':');
          if (parts.length == 2) {
            final cellRef = FormulaUtils.cellRefFromCoords(int.parse(parts[0]), int.parse(parts[1]));
            final evalVal = _evaluatedData[k];
            debugPrint('[GridWidget] Formula Cell $cellRef ($k): raw="$v" => evaluated="$evalVal"');
          }
        }
      });

      // Update Conditional Formatting Styles
      final Set<String> activeCellRefsSet = {};
      _cellData.forEach((k, v) {
        final parts = k.split(':');
        activeCellRefsSet.add(FormulaUtils.cellRefFromCoords(int.parse(parts[0]), int.parse(parts[1])));
      });
      
      // Ensure CF evaluates on empty cells in the immediate viewport/buffer
      // Without this, rules like IsBlank or =ROW()=3 won't highlight empty cells
      for (int r = 0; r < 200; r++) {
        for (int c = 0; c < 26; c++) {
          activeCellRefsSet.add(FormulaUtils.cellRefFromCoords(r, c));
        }
      }
      final activeCellRefs = activeCellRefsSet.toList();
      _spillData.forEach((k, v) {
        final parts = k.split(':');
        activeCellRefs.add(FormulaUtils.cellRefFromCoords(int.parse(parts[0]), int.parse(parts[1])));
      });
      
      final currentSheetId = _cfCurrentSheetId(widget.sheetId, null);
      final rawStyles = ConditionalFormattingService.evaluateVisibleCells(
        currentSheetId,
        activeCellRefs,
      );
      if (currentSheetId != 'Sheet1') {
        final fallbackStyles = ConditionalFormattingService.evaluateVisibleCells(
          'Sheet1',
          activeCellRefs,
        );
        fallbackStyles.forEach((k, v) {
          if (!rawStyles.containsKey(k)) rawStyles[k] = v;
        });
      }
      final mappedStyles = <String, dynamic>{};
      rawStyles.forEach((key, value) {
        final coords = FormulaUtils.parseCellRef(key);
        if (coords != null) {
          mappedStyles['${coords.$1}:${coords.$2}'] = value;
        }
      });
      _cfStyles = mappedStyles;

      if (maxRequiredRow > widget.rowCount || maxRequiredCol > widget.columnCount) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (maxRequiredRow > widget.rowCount) {
            widget.onRowCountRequired?.call(maxRequiredRow + 20);
          }
          if (maxRequiredCol > widget.columnCount) {
            widget.onColumnCountRequired?.call(maxRequiredCol + 5);
          }
        });
      }
    });
  }

  void _hideBottomSheet() {
    if (_visibleRows.length < 25) return;

    if (_verticalController.hasClients && _verticalController.position.maxScrollExtent > 600) {
      final offset = _verticalController.offset;
      final exactRow = _getRowIndexAtOffset(offset);
      _currentScrolledRowNotifier.value = exactRow;

      _scrollStartTime ??= DateTime.now();
      final scrollDurationMs = DateTime.now().difference(_scrollStartTime!).inMilliseconds;

      // Require continuous scrolling for at least 1.2s (or active dragging) before popping up the handle
      if (scrollDurationMs > 1200 || _isDraggingScroller) {
        if (!_showFastScrollerNotifier.value) {
          _showFastScrollerNotifier.value = true;
        }
      }

      _scrollerHideTimer?.cancel();
      if (!_isDraggingScroller) {
        _scrollerHideTimer = Timer(const Duration(milliseconds: 1000), () {
          if (mounted && !_isDraggingScroller) {
            _showFastScrollerNotifier.value = false;
            _scrollStartTime = null;
          }
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _cellData = widget.initialCellData != null ? Map.from(widget.initialCellData!) : {};
    _recalculateAll();
    _visibleRows = List.generate(widget.rowCount, (index) => index);
    if (widget.horizontalController != null) {
      _horizontalController = widget.horizontalController!;
    } else {
      _horizontalController = ScrollController();
      _internalHorizontalController = true;
    }
    if (widget.verticalController != null) {
      _verticalController = widget.verticalController!;
    } else {
      _verticalController = ScrollController();
      _internalVerticalController = true;
    }
    _verticalController.addListener(_onVerticalScroll);
    _horizontalController.addListener(_onHorizontalScroll);
  }

  @override
  void didUpdateWidget(GridWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCellData != null && !mapEquals(oldWidget.initialCellData, widget.initialCellData)) {
      _cellData = Map.from(widget.initialCellData!);
      _dataVersion++;
      _recalculateAll();
    }
    
    if (oldWidget.selectedFullRow != widget.selectedFullRow || oldWidget.selectedFullColumn != widget.selectedFullColumn) {
      if (widget.selectedFullRow != null || widget.selectedFullColumn != null) {
        _currentSelection = null;
      }
    }
    if (oldWidget.rowCount != widget.rowCount) {
      setState(() {
        _visibleRows = List.generate(widget.rowCount, (index) => index);
      });
    }
    if (oldWidget.verticalController != widget.verticalController) {
      oldWidget.verticalController?.removeListener(_onVerticalScroll);
      _verticalController.addListener(_onVerticalScroll);
    }
    if (oldWidget.horizontalController != widget.horizontalController) {
      oldWidget.horizontalController?.removeListener(_onHorizontalScroll);
      _horizontalController.addListener(_onHorizontalScroll);
    }
  }

  @override
  void dispose() {
    _scrollerHideTimer?.cancel();
    _verticalController.removeListener(_onVerticalScroll);
    _horizontalController.removeListener(_onHorizontalScroll);
    if (_internalHorizontalController) _horizontalController.dispose();
    if (_internalVerticalController) _verticalController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _getCellKey(int row, int column) => '$row:$column';

  // ═══════════════════════════════════════════════════════════════════════════
  // CELL TAP, DOUBLE-TAP & LONG-PRESS HANDLING
  // ═══════════════════════════════════════════════════════════════════════════

  void _handleCellTap(int row, int column) {
    final now = DateTime.now();

    // Detect double-tap: same cell tapped twice within 400ms
    final isDoubleTap = _lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 400) &&
        _lastTapRow == row &&
        _lastTapCol == column;

    _lastTapTime = now;
    _lastTapRow = row;
    _lastTapCol = column;

    if (isDoubleTap && _selectedRow == row && _selectedColumn == column) {
      // ── DOUBLE-TAP on already-selected cell → show fill handle ──
      setState(() {
        _showFillHandle = true;
      });
      return;
    }

    // ── SINGLE TAP → select cell + start editing ──
    if (_editingRow != null && _editingColumn != null &&
        (_editingRow != row || _editingColumn != column)) {
      _stopEditing();
    }

    setState(() {
      _currentSelection = CellRange(row, column, row, column);
      _showFillHandle = false; // Reset handle on new cell selection
    });

    widget.onCellTap?.call(row, column);
    _startEditing(row, column);
  }

  void _handleCellLongPress(int row, int column) {
    // Long-press on an already-selected cell → show fill handle
    if (_selectedRow == row && _selectedColumn == column) {
      setState(() {
        _showFillHandle = true;
      });
    }
  }

  Future<void> _startEditing(int row, int column) async {
    final type = widget.getColumnType(column);
    final String key = _getCellKey(row, column);
    final currentValue = _cellData[key] ?? '';

    if (type.id == 'date') {
      DateTime initialDate = DateTime.now();
      if (currentValue.isNotEmpty) {
        try { initialDate = DateTime.parse(currentValue); } catch (_) {}
      }
      final picked = await showDatePicker(
        context: context, initialDate: initialDate,
        firstDate: DateTime(1900), lastDate: DateTime(2100),
      );
      if (picked != null) {
        if (!mounted) return;
        setState(() {
          _saveSnapshot();
          _cellData[key] = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
          _dataVersion++;
          _recalculateAll();
      widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
        });
      }
      return;
    } else if (type.id == 'time') {
      TimeOfDay initialTime = TimeOfDay.now();
      if (currentValue.isNotEmpty && currentValue.contains(':')) {
        final parts = currentValue.split(':');
        if (parts.length >= 2) {
          initialTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? initialTime.hour,
            minute: int.tryParse(parts[1]) ?? initialTime.minute,
          );
        }
      }
      final picked = await showTimePicker(context: context, initialTime: initialTime);
      if (picked != null) {
        if (!mounted) return;
        setState(() {
          _saveSnapshot();
          _cellData[key] = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
          _dataVersion++;
          _recalculateAll();
      widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
        });
      }
      return;
    } else if (type.id == 'selectable') {
      List<String> options = [];
      try { options = (type as dynamic).options; } catch (_) {}
      if (options.isEmpty) return;
      final picked = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Select Option'),
          children: options.map((option) => SimpleDialogOption(
            onPressed: () => Navigator.pop(context, option),
            child: Text(option),
          )).toList(),
        ),
      );
      if (picked != null) {
        if (!mounted) return;
        setState(() {
          _saveSnapshot();
          _cellData[key] = picked;
          _dataVersion++;
          _recalculateAll();
      widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
        });
      }
      return;
    } else if (type.id == 'audio') {
      final picked = await showDialog<String?>(
        context: context,
        builder: (context) => AudioRecorderDialog(existingAudioPath: currentValue),
      );
      if (picked != null) {
        if (!mounted) return;
        setState(() {
          _saveSnapshot();
          _cellData[key] = picked;
          _dataVersion++;
          _recalculateAll();
      widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
        });
      }
      return;
    } else if (type.id == 'pdf') {
      try {
        final result = await FilePicker.pickFiles(
          type: FileType.custom, allowedExtensions: ['pdf'],
        );
        if (result != null && result.files.isNotEmpty) {
          final filePath = result.files.single.path ?? result.files.single.name;
          if (!mounted) return;
          setState(() {
            _saveSnapshot();
            _cellData[key] = filePath;
            _dataVersion++;
            _recalculateAll();
      widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
          });
        }
      } catch (e) {
        debugPrint('PDF file pick error: $e');
      }
      return;
    }

    if (!mounted) return;
    _initialEditText = currentValue;
    _snapshotSavedThisEdit = false;
    setState(() {
      _editingRow = row;
      _editingColumn = column;
      _textController.text = currentValue;
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _stopEditing() {
    if (_editingRow != null && _editingColumn != null) {
      final key = _getCellKey(_editingRow!, _editingColumn!);
      if (!_snapshotSavedThisEdit && _textController.text != (_initialEditText ?? '')) {
        _saveSnapshot();
      }
      if (_textController.text.isNotEmpty) {
        _cellData[key] = _textController.text;
      } else {
        _cellData.remove(key);
      }
      if (!mounted) return;
      setState(() {
        _editingRow = null;
        _editingColumn = null;
        _dataVersion++;
        _recalculateAll();
      widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
      });
    }
  }

  /// Multi-Row and Multi-Column (2D Matrix / Tab-separated TSV / CSV) Paste Engine
  Future<void> pasteData(int startRow, int startColumn, String text) async {
    if (text.trim().isEmpty) return;
    
    setState(() { _isEvaluating = true; });
    _saveSnapshot();

    try {
      // Process paste in C++ (extremely fast background thread)
      final jsonResult = await NativeEngine.pasteDataBlockAsync(startRow, startColumn, text);
      
      if (!mounted) return;
      setState(() {
        try {
          final Map<String, dynamic> updates = jsonDecode(jsonResult);
          updates.forEach((key, val) {
            if (val.toString().isNotEmpty) {
              _cellData[key] = val.toString();
            } else {
              _cellData.remove(key);
            }
          });
        } catch (e) {
          debugPrint("Paste C++ JSON parse error: $e");
        }
        
        _dataVersion++;
        _recalculateAll();
        widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
      });
    } catch (e) {
      debugPrint("Paste failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Paste failed: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isEvaluating = false; });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTOFILL HANDLE & DRAG-TO-SELECT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Convert absolute Y (viewport Y + scrollY) to row index
  int _rowFromAbsoluteY(double absY) {
    double currentY = 0;
    for (int i = 0; i < _visibleRows.length; i++) {
      final h = _getH(_visibleRows[i]);
      if (absY >= currentY && absY < currentY + h) {
        return _visibleRows[i];
      }
      currentY += h;
    }
    // If beyond all rows, return last visible row
    return _visibleRows.isNotEmpty ? _visibleRows.last : 0;
  }

  /// Convert absolute X (viewport X + scrollX) to column index
  int _colFromAbsoluteX(double absX) {
    double currentX = 0;
    for (int i = 0; i < widget.columnCount; i++) {
      final w = widget.getColumnWidth(i);
      if (absX >= currentX && absX < currentX + w) {
        return i;
      }
      currentX += w;
    }
    return widget.columnCount - 1;
  }

  /// Returns true if [localPos] is within 30px of the fill handle center
  bool _isNearFillHandle(Offset localPos) {
    if (_currentSelection == null || !_showFillHandle) {
      return false;
    }

    double cellRightX = 0;
    for (int c = 0; c <= _currentSelection!.maxCol; c++) {
      cellRightX += widget.getColumnWidth(c);
    }
    double cellBottomY = 0;
    final visualIndex = _visibleRows.indexOf(_currentSelection!.maxRow);
    if (visualIndex == -1) return false;
    for (int r = 0; r <= visualIndex; r++) {
      cellBottomY += _getH(_visibleRows[r]);
    }

    final scrollX = _horizontalController.hasClients ? _horizontalController.offset : 0.0;
    final scrollY = _verticalController.hasClients ? _verticalController.offset : 0.0;

    final handleVX = cellRightX - scrollX;
    final handleVY = cellBottomY - scrollY;

    final dx = localPos.dx - handleVX;
    final dy = localPos.dy - handleVY;
    return (dx * dx + dy * dy) <= 30 * 30; // 30px touch radius
  }

  /// Check if pointer is near a selection handle (blue circle at corners)
  /// Returns: 0 = not near, 1 = near top-left handle, 2 = near bottom-right handle
  int _nearSelectionHandle(Offset localPos) {
    if (_currentSelection == null) return 0;

    final scrollX = _horizontalController.hasClients ? _horizontalController.offset : 0.0;
    final scrollY = _verticalController.hasClients ? _verticalController.offset : 0.0;

    // Top-left handle position
    double tlX = 0;
    for (int c = 0; c < _currentSelection!.minCol; c++) {
      tlX += widget.getColumnWidth(c);
    }
    double tlY = 0;
    for (int i = 0; i < _visibleRows.length; i++) {
      if (_visibleRows[i] == _currentSelection!.minRow) break;
      tlY += _getH(_visibleRows[i]);
    }
    final tlVX = tlX - scrollX;
    final tlVY = tlY - scrollY;
    final dtl = (localPos.dx - tlVX) * (localPos.dx - tlVX) + (localPos.dy - tlVY) * (localPos.dy - tlVY);
    if (dtl <= 40 * 40) return 1;

    // Bottom-right handle position
    double brX = 0;
    for (int c = 0; c <= _currentSelection!.maxCol; c++) {
      brX += widget.getColumnWidth(c);
    }
    double brY = 0;
    final brVisIdx = _visibleRows.indexOf(_currentSelection!.maxRow);
    if (brVisIdx != -1) {
      for (int i = 0; i <= brVisIdx; i++) {
        brY += _getH(_visibleRows[i]);
      }
    }
    final brVX = brX - scrollX;
    final brVY = brY - scrollY;
    final dbr = (localPos.dx - brVX) * (localPos.dx - brVX) + (localPos.dy - brVY) * (localPos.dy - brVY);
    if (dbr <= 40 * 40) return 2;

    return 0;
  }

  /// Called by Listener — raw pointer events that do NOT compete with gesture arena
  void _onPointerDown(PointerDownEvent event) {
    // Priority 1: Fill handle drag
    if (_showFillHandle && _isNearFillHandle(event.localPosition)) {
      setState(() {
        _handleTouched = true;
        _isDragFilling = true;
        _dragPreviewRange = _currentSelection;
      });
      return;
    }

    // Priority 2: Selection handle drag
    final handleHit = _nearSelectionHandle(event.localPosition);
    if (handleHit > 0) {
      setState(() {
        _isDraggingSelectionHandle = true;
        _isTopLeftHandle = (handleHit == 1);
      });
      return;
    }
  }

  void _autoScrollEdges(PointerEvent event) {
    if (_verticalController.hasClients) {
      final viewportH = _verticalController.position.viewportDimension;
      final currentScroll = _verticalController.offset;
      if (event.localPosition.dy > viewportH - 60) {
        _verticalController.jumpTo(
          (currentScroll + 6).clamp(0.0, _verticalController.position.maxScrollExtent),
        );
      } else if (event.localPosition.dy < 60) {
        _verticalController.jumpTo(
          (currentScroll - 6).clamp(0.0, _verticalController.position.maxScrollExtent),
        );
      }
    }
    if (_horizontalController.hasClients) {
      final viewportW = _horizontalController.position.viewportDimension;
      final currentScroll = _horizontalController.offset;
      if (event.localPosition.dx > viewportW - 60) {
        _horizontalController.jumpTo(
          (currentScroll + 6).clamp(0.0, _horizontalController.position.maxScrollExtent),
        );
      } else if (event.localPosition.dx < 60) {
        _horizontalController.jumpTo(
          (currentScroll - 6).clamp(0.0, _horizontalController.position.maxScrollExtent),
        );
      }
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    // === FILL HANDLE DRAG ===
    if (_handleTouched && _isDragFilling && _currentSelection != null) {
      _autoScrollEdges(event);

      final scrollY = _verticalController.hasClients ? _verticalController.offset : 0.0;
      final touchY = event.localPosition.dy + scrollY;
      final scrollX = _horizontalController.hasClients ? _horizontalController.offset : 0.0;
      final touchX = event.localPosition.dx + scrollX;

      final matchedRow = _rowFromAbsoluteY(touchY);
      final matchedCol = _colFromAbsoluteX(touchX);

      final newPreview = _currentSelection!.expandToLockedAxis(matchedRow, matchedCol);
      if (_dragPreviewRange != newPreview) {
        setState(() {
          _dragPreviewRange = newPreview;
        });
      }
      return;
    }

    // === SELECTION HANDLE DRAG (expand/contract multi-cell selection) ===
    if (_isDraggingSelectionHandle && _currentSelection != null) {
      _autoScrollEdges(event);

      final scrollY = _verticalController.hasClients ? _verticalController.offset : 0.0;
      final scrollX = _horizontalController.hasClients ? _horizontalController.offset : 0.0;
      final touchRow = _rowFromAbsoluteY(event.localPosition.dy + scrollY);
      final touchCol = _colFromAbsoluteX(event.localPosition.dx + scrollX);

      CellRange newSel;
      if (_isTopLeftHandle) {
        newSel = CellRange(touchRow, touchCol, _currentSelection!.endRow, _currentSelection!.endCol);
      } else {
        newSel = CellRange(_currentSelection!.startRow, _currentSelection!.startCol, touchRow, touchCol);
      }
      if (newSel != _currentSelection) {
        setState(() {
          _currentSelection = newSel;
        });
      }
      return;
    }

  }

  void _onPointerUp(PointerUpEvent event) {
    // === FILL HANDLE DRAG END ===
    if (_handleTouched && _isDragFilling) {
      if (_currentSelection != null && _dragPreviewRange != null) {
        final source = _currentSelection!;
        final target = _dragPreviewRange!;
        if (source != target) {
          _commitAutoFill(source, target);
        }
        setState(() {
          _currentSelection = target;
        });
      }
      setState(() {
        _handleTouched = false;
        _isDragFilling = false;
        _dragPreviewRange = null;
      });
      return;
    }

    // === SELECTION HANDLE DRAG END ===
    if (_isDraggingSelectionHandle) {
      setState(() {
        _isDraggingSelectionHandle = false;
      });
      return;
    }

  }

  void _commitAutoFill(CellRange source, CellRange target) {
    // 1. Snapshot for Undo
    _saveSnapshot();

    // 2. Generate new data
    final newData = AutoFillEngine.generateFillData(source, target, _cellData);

    // 3. Batch apply
    _cellData.addAll(newData);

    // 4. Trigger logic recalculation
    _dataVersion++;
    _recalculateAll();

    if (widget.onCellDataChanged != null) {
      widget.onCellDataChanged!(Map.from(_cellData));
    }
  }


  TextInputType _getKeyboardType(dynamic type) {
    if (type.id == 'number' || type.id == 'amount') {
      return const TextInputType.numberWithOptions(decimal: true, signed: true);
    } else if (type.id == 'phone') {
      return TextInputType.phone;
    }
    return TextInputType.text;
  }

  int _colFromLocalX(double localX) {
    double currentX = 0;
    for (int i = 0; i < widget.columnCount; i++) {
      final width = widget.getColumnWidth(i);
      if (localX >= currentX && localX < currentX + width) return i;
      currentX += width;
    }
    return -1;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final cfg = widget.themeConfig ?? SpreadsheetThemeConfig.defaultTheme;
    final gridBg = cfg.isHeaderOnly ? const Color(0xFFFFFFFF) : cfg.gridBgColor;

    double totalWidth = 0;
    for (int i = 0; i < widget.columnCount; i++) {
      totalWidth += widget.getColumnWidth(i);
    }
    final fullWidth = totalWidth + 44.0; // 44px matching _AddColumnButton width

    return Container(
      decoration: BoxDecoration(
        color: gridBg,
        border: Border(
          bottom: BorderSide(color: cfg.borderColor),
          right: BorderSide(color: cfg.borderColor),
        ),
      ),
      child: Stack(
        children: [
          // ── Listener: raw pointer events for fill-handle drag only ──
          Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              physics: _isDragFilling
                  ? const NeverScrollableScrollPhysics()
                  : const ClampingScrollPhysics(),
              child: SizedBox(
                width: fullWidth,
                child: ListView.builder(
                  controller: _verticalController,
                  physics: _isDragFilling
                      ? const NeverScrollableScrollPhysics()
                      : const ClampingScrollPhysics(),
                  itemCount: _visibleRows.length + 1, // +1 for trailing row space
                  addAutomaticKeepAlives: false,
                  itemExtentBuilder: (int index, SliverLayoutDimensions dimensions) {
                    if (index == _visibleRows.length) return 40.0;
                    return _getH(_visibleRows[index]);
                  },
                  itemBuilder: (context, rowIndex) {
                    if (rowIndex == _visibleRows.length) {
                      return const SizedBox(height: 40.0); // 40px matching _AddRowButton height
                    }
                    final actualRowIndex = _visibleRows[rowIndex];
                    return _buildSingleRowWidget(actualRowIndex, totalWidth, cfg);
                  },
                ),
              ),
            ),
          ),

          // ── Sticky Frozen Row 0 Overlay (Top Row Lock) ──
          if (widget.frozenRows > 0 && _visibleRows.isNotEmpty)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: _getH(_visibleRows[0]),
              child: AnimatedBuilder(
                animation: _horizontalController,
                builder: (context, child) {
                  final scrollX = _horizontalController.hasClients
                      ? _horizontalController.offset
                      : 0.0;
                  return ClipRect(
                    child: Container(
                      color: cfg.gridBgColor,
                      child: Transform.translate(
                        offset: Offset(-scrollX, 0),
                        child: OverflowBox(
                          minWidth: totalWidth,
                          maxWidth: totalWidth,
                          minHeight: _getH(_visibleRows[0]),
                          maxHeight: _getH(_visibleRows[0]),
                          alignment: Alignment.topLeft,
                          child: SizedBox(
                            width: totalWidth,
                            height: _getH(_visibleRows[0]),
                            child: _buildSingleRowWidget(_visibleRows[0], totalWidth, cfg),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // ── Fast Vertical Scroll Slider Overlay ──
          ValueListenableBuilder<bool>(
            valueListenable: _showFastScrollerNotifier,
            builder: (context, showScroller, child) {
              if (!showScroller && !_isDraggingScroller) return const SizedBox.shrink();
              return Positioned(
                right: 6,
                top: 0,
                bottom: 0,
                child: _buildFastScrollerOverlay(cfg),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFastScrollerOverlay(SpreadsheetThemeConfig cfg) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackHeight = constraints.maxHeight;
        if (trackHeight <= 0 || !_verticalController.hasClients) {
          return const SizedBox.shrink();
        }

        final maxExtent = _verticalController.position.maxScrollExtent;
        if (maxExtent <= 0) return const SizedBox.shrink();

        const thumbHeight = 44.0;
        final maxThumbY = math.max(0.0, trackHeight - thumbHeight);
        final fraction = (_verticalController.offset / maxExtent).clamp(0.0, 1.0);
        final thumbY = fraction * maxThumbY;

        return Positioned(
          top: thumbY,
          right: 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Floating Row Badge Indicator
              ValueListenableBuilder<int>(
                valueListenable: _currentScrolledRowNotifier,
                builder: (context, currentRow, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'Row $currentRow',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),

              // Fast Scroll Slider Thumb Handle (Strictly 32px width â€” zero touch interference on sheet cells)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (details) {
                  _isDraggingScroller = true;
                  _showFastScrollerNotifier.value = true;
                  _dragStartScrollOffset = _verticalController.hasClients ? _verticalController.offset : 0.0;
                  _dragStartGlobalY = details.globalPosition.dy;
                },
                onVerticalDragUpdate: (details) {
                  _updateFastScrollFromDeltaY(details.globalPosition.dy, maxThumbY, maxExtent);
                },
                onVerticalDragEnd: (details) {
                  _isDraggingScroller = false;
                  _scrollerHideTimer?.cancel();
                  _scrollerHideTimer = Timer(const Duration(milliseconds: 1000), () {
                    if (mounted && !_isDraggingScroller) {
                      _showFastScrollerNotifier.value = false;
                      _scrollStartTime = null;
                    }
                  });
                },
                child: Container(
                  width: 32,
                  height: thumbHeight,
                  decoration: BoxDecoration(
                    color: cfg.accentColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: cfg.accentColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.unfold_more_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _updateFastScrollFromDeltaY(double currentGlobalY, double maxThumbY, double maxExtent) {
    if (maxThumbY <= 0 || !_verticalController.hasClients) return;
    final deltaY = currentGlobalY - _dragStartGlobalY;
    final scrollDelta = (deltaY / maxThumbY) * maxExtent;
    final targetScrollOffset = (_dragStartScrollOffset + scrollDelta).clamp(0.0, maxExtent);
    
    _verticalController.jumpTo(targetScrollOffset);
    _currentScrolledRowNotifier.value = _getRowIndexAtOffset(targetScrollOffset);
  }

  Widget _buildSingleRowWidget(int actualRowIndex, double totalWidth, SpreadsheetThemeConfig cfg) {
    final rowH = _getH(actualRowIndex);
    final isEditingThisRow = _editingRow == actualRowIndex && _editingColumn != null;

    return SizedBox(
      height: rowH,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          final col = _colFromLocalX(details.localPosition.dx);
          if (col != -1) {
            _handleCellTap(actualRowIndex, col);
          }
        },
        onLongPressStart: (details) {
          final col = _colFromLocalX(details.localPosition.dx);
          if (col != -1) {
            _handleCellLongPress(actualRowIndex, col);
          }
        },
        child: isEditingThisRow
            ? _buildEditingRow(actualRowIndex, totalWidth, rowH, cfg)
            : CustomPaint(
                painter: _RowPainter(
                  rowIndex: actualRowIndex,
                  columnCount: widget.columnCount,
                  getColumnWidth: widget.getColumnWidth,
                  getColumnType: widget.getColumnType,
                  rowHeight: rowH,
                  cellData: _cellData,
                  evaluatedData: _evaluatedData,
                  spillData: _spillData,
                  onCellDataChanged: widget.onCellDataChanged,
                  currentSelection: _currentSelection,
                  dragPreviewRange: _dragPreviewRange,
                  selectedFullRow: widget.selectedFullRow,
                  selectedFullColumn: widget.selectedFullColumn ?? (_selectedRow == null ? _selectedColumn : null),
                  dataVersion: _dataVersion,
                  searchMatches: _searchMatches,
                  currentMatchIndex: _currentMatchIndex,
                  themeConfig: cfg,
                  showFillHandle: _showFillHandle,
                  isDragFilling: _isDragFilling,
                  frozenRows: widget.frozenRows,
                  frozenColumns: widget.frozenColumns,
                  horizontalController: _horizontalController,
                  cfStyles: _cfStyles,
                  formatMap: widget.formatMap,
                ),
                size: Size(totalWidth, rowH),
              ),
      ),
    );
  }

  Widget _buildEditingRow(int rowIndex, double totalWidth, double rowH, SpreadsheetThemeConfig cfg) {
    double editColX = 0;
    for (int i = 0; i < _editingColumn!; i++) {
      editColX += widget.getColumnWidth(i);
    }
    final editColWidth = widget.getColumnWidth(_editingColumn!);

    return Stack(
      children: [
        CustomPaint(
          painter: _RowPainter(
            rowIndex: rowIndex,
            columnCount: widget.columnCount,
            getColumnWidth: widget.getColumnWidth,
            getColumnType: widget.getColumnType,
            rowHeight: rowH,
            cellData: _cellData,
            evaluatedData: _evaluatedData,
            spillData: _spillData,
            onCellDataChanged: widget.onCellDataChanged,
            currentSelection: _currentSelection,
            dragPreviewRange: _dragPreviewRange,
            selectedFullRow: widget.selectedFullRow,
            selectedFullColumn: widget.selectedFullColumn ?? (_selectedRow == null ? _selectedColumn : null),
            dataVersion: _dataVersion,
            searchMatches: _searchMatches,
            currentMatchIndex: _currentMatchIndex,
            themeConfig: cfg,
            showFillHandle: _showFillHandle,
            isDragFilling: _isDragFilling,
            frozenRows: widget.frozenRows,
            frozenColumns: widget.frozenColumns,
            horizontalController: _horizontalController,
            cfStyles: _cfStyles,
            formatMap: widget.formatMap,
          ),
          size: Size(totalWidth, rowH),
        ),
        Positioned(
          left: editColX,
          top: 0,
          width: editColWidth,
          height: rowH,
          child: Container(
            decoration: BoxDecoration(
              color: cfg.gridBgColor,
              border: Border.all(color: cfg.accentColor, width: 2),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              keyboardType: _getKeyboardType(widget.getColumnType(_editingColumn!)),
              style: TextStyle(
                fontSize: 14,
                color: cfg.gridBgColor.computeLuminance() < 0.4 ? Colors.white : Colors.black87,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) {
                if (_editingRow != null && _editingColumn != null) {
                  final key = _getCellKey(_editingRow!, _editingColumn!);
                  if (!_snapshotSavedThisEdit && val != (_initialEditText ?? '')) {
                    _saveSnapshot();
                    _snapshotSavedThisEdit = true;
                  }
                  if (val.isNotEmpty) {
                    _cellData[key] = val;
                  } else {
                    _cellData.remove(key);
                  }
                  widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
                  _recalculateAll();
                }
              },
              onSubmitted: (_) => _stopEditing(),
              onTapOutside: (_) => _stopEditing(),
            ),
          ),
        ),
      ],
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// ROW PAINTER â€” Draws cells, selection, fill handle, and fill target overlay
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _RowPainter extends CustomPainter {
  final int rowIndex;
  final int columnCount;
  final double Function(int) getColumnWidth;
  final dynamic Function(int)? getColumnType;
  final double rowHeight;
  final Map<String, String> cellData;
  final Map<String, String> evaluatedData;
  final Map<String, String> spillData;
  final Map<String, dynamic> cfStyles;
  final ValueChanged<Map<String, String>>? onCellDataChanged;
  final CellRange? currentSelection;
  final CellRange? dragPreviewRange;
  final int? selectedFullRow;
  final int? selectedFullColumn;
  final int dataVersion;
  final List<String> searchMatches;
  final int currentMatchIndex;
  final SpreadsheetThemeConfig themeConfig;
  final bool showFillHandle;
  final bool isDragFilling;
  final int frozenRows;
  final int frozenColumns;
  final ScrollController? horizontalController;
  final Map<String, CellFormat> formatMap;

  static final Paint _bgSearchMatch = Paint()..color = Colors.yellow[200]!;
  static final Paint _bgSearchActive = Paint()..color = Colors.orange[300]!;
  static final TextPainter _tp = TextPainter(
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  );

  _RowPainter({
    required this.rowIndex,
    required this.columnCount,
    required this.getColumnWidth,
    this.getColumnType,
    required this.rowHeight,
    required this.cellData,
    required this.evaluatedData,
    required this.spillData,
    this.cfStyles = const {},
    this.onCellDataChanged,
    this.currentSelection,
    this.dragPreviewRange,
    this.selectedFullRow,
    this.selectedFullColumn,
    required this.dataVersion,
    required this.searchMatches,
    required this.currentMatchIndex,
    required this.themeConfig,
    this.showFillHandle = false,
    this.isDragFilling = false,
    this.frozenRows = 0,
    this.frozenColumns = 0,
    this.horizontalController,
    this.formatMap = const {},
  }) : super(repaint: horizontalController);

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = themeConfig.borderColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final selectedBorderPaint = Paint()
      ..color = themeConfig.accentColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Large prominent fill handle paints
    final handleFillPaint = Paint()
      ..color = themeConfig.accentColor
      ..style = PaintingStyle.fill;
    final handleBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final fillTargetBgPaint = Paint()
      ..color = themeConfig.accentColor.withOpacity(0.15);
    final fillTargetBorderPaint = Paint()
      ..color = themeConfig.accentColor
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final gridBg = themeConfig.isHeaderOnly ? const Color(0xFFFFFFFF) : themeConfig.gridBgColor;
    final selBg = themeConfig.isHeaderOnly ? const Color(0xFFE3F2FD) : themeConfig.selectionColor;
    final bgGridPaint = Paint()..color = gridBg;
    final bgSelectedPaint = Paint()..color = selBg;

    final isGridDark = gridBg.computeLuminance() < 0.4;
    final defaultCellTextColor = isGridDark ? Colors.white : Colors.black87;
    final iconTextColor = isGridDark ? Colors.white70 : Colors.black54;

    final defaultCellStyle = TextStyle(fontSize: 14, color: defaultCellTextColor);
    final iconStyle = TextStyle(fontSize: 12, color: iconTextColor);

    // Horizontal scroll offset for frozen column pinning
    final double scrollX = (frozenColumns > 0 && horizontalController != null && horizontalController!.hasClients)
        ? horizontalController!.offset
        : 0.0;

    // Helper to draw a single cell at a given X position
    void _drawCell(int col, double drawX, double colWidth) {
      final rect = Rect.fromLTWH(drawX, 0, colWidth, rowHeight);
      final isSelected = (currentSelection?.contains(rowIndex, col) ?? false) ||
          (selectedFullRow == rowIndex) ||
          (selectedFullColumn == col);
      final isTargetFillRow = isDragFilling &&
          dragPreviewRange != null && dragPreviewRange!.contains(rowIndex, col) &&
          !(currentSelection?.contains(rowIndex, col) ?? false);

      final cellKey = '$rowIndex:$col';
      final isSearchMatch = searchMatches.contains(cellKey);
      final isSearchActive = isSearchMatch &&
          searchMatches.isNotEmpty &&
          currentMatchIndex >= 0 &&
          currentMatchIndex < searchMatches.length &&
          searchMatches[currentMatchIndex] == cellKey;

      Paint bgPaint = bgGridPaint;
      final cfStyle = cfStyles[cellKey];
      if (cfStyle != null && cfStyle['bgColor'] != null) {
        try {
          String bgHex = cfStyle['bgColor'].toString().replaceAll('#', '');
          if (bgHex.length == 6) bgHex = 'FF$bgHex';
          bgPaint = Paint()..color = Color(int.parse(bgHex, radix: 16));
        } catch (_) {}
      }

      // Draw base cell background (includes CF background color if set)
      canvas.drawRect(rect, bgPaint);

      // Layer selection/search highlights over the base CF background
      if (isSearchActive) {
        canvas.drawRect(rect, _bgSearchActive);
      } else if (isSearchMatch) {
        canvas.drawRect(rect, _bgSearchMatch);
      } else if (isTargetFillRow) {
        canvas.drawRect(rect, fillTargetBgPaint);
      } else if (isSelected) {
        canvas.drawRect(rect, bgSelectedPaint);
      }
      
      // Conditional Formatting Data Bar
      if (cfStyle != null && cfStyle['dataBarPercent'] != null) {
        try {
          final double percent = (cfStyle['dataBarPercent'] as num).toDouble().clamp(0.0, 1.0);
          final String barFill = cfStyle['dataBarFill']?.toString() ?? 'FF4285F4';
          String barHex = barFill.replaceAll('#', '');
          if (barHex.length == 6) barHex = 'FF$barHex';
          
          final dataBarPaint = Paint()..color = Color(int.parse(barHex, radix: 16));
          final dataBarRect = Rect.fromLTWH(drawX, 0, colWidth * percent, rowHeight);
          canvas.drawRect(dataBarRect, dataBarPaint);
        } catch (_) {}
      }

      // ALWAYS draw the base grid lines first so they don't disappear inside selections
      canvas.drawRect(rect, borderPaint);
      
      // Custom Cell Borders from Conditional Formatting / AI Styling
      if (cfStyle != null && cfStyle['border'] != null && cfStyle['border'] is Map) {
        final borderMap = cfStyle['border'] as Map<String, dynamic>;
        
        Color _parseBorderColor(dynamic sideObj) {
          if (sideObj is Map && sideObj['color'] != null) {
            String hex = sideObj['color'].toString().replaceAll('#', '');
            if (hex.length == 6) hex = 'FF$hex';
            try { return Color(int.parse(hex, radix: 16)); } catch (_) {}
          }
          return isGridDark ? Colors.white : Colors.black;
        }

        if (borderMap['top'] != null && borderMap['top'] is Map && (borderMap['top']['show'] == true || borderMap['top']['color'] != null)) {
          final topPaint = Paint()
            ..color = _parseBorderColor(borderMap['top'])
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke;
          canvas.drawLine(rect.topLeft, rect.topRight, topPaint);
        }
        if (borderMap['bottom'] != null && borderMap['bottom'] is Map && (borderMap['bottom']['show'] == true || borderMap['bottom']['color'] != null)) {
          final botPaint = Paint()
            ..color = _parseBorderColor(borderMap['bottom'])
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke;
          canvas.drawLine(rect.bottomLeft, rect.bottomRight, botPaint);
        }
        if (borderMap['left'] != null && borderMap['left'] is Map && (borderMap['left']['show'] == true || borderMap['left']['color'] != null)) {
          final leftPaint = Paint()
            ..color = _parseBorderColor(borderMap['left'])
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke;
          canvas.drawLine(rect.topLeft, rect.bottomLeft, leftPaint);
        }
        if (borderMap['right'] != null && borderMap['right'] is Map && (borderMap['right']['show'] == true || borderMap['right']['color'] != null)) {
          final rightPaint = Paint()
            ..color = _parseBorderColor(borderMap['right'])
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke;
          canvas.drawLine(rect.topRight, rect.bottomRight, rightPaint);
        }
      }
      
      if (isTargetFillRow && !isSelected) {
        canvas.drawRect(rect, fillTargetBorderPaint);
      }
      
      if (isSelected) {
        // Draw selection outer borders only
        bool drawTop = true;
        bool drawBottom = true;
        bool drawLeft = true;
        bool drawRight = true;

        if (selectedFullColumn == col) {
           drawTop = (rowIndex == 0); // Only draw top if first row
           drawBottom = false; 
        } else if (selectedFullRow == rowIndex) {
           drawLeft = (col == 0);
           drawRight = false;
        } else if (currentSelection != null) {
           drawTop = (rowIndex == currentSelection!.minRow);
           drawBottom = (rowIndex == currentSelection!.maxRow);
           drawLeft = (col == currentSelection!.minCol);
           drawRight = (col == currentSelection!.maxCol);
        }

        // To prevent clipping at the very top edge of the grid, shift the top line down by 1px
        final topY = (rowIndex == 0 && drawTop) ? 1.0 : rect.top;

        if (drawTop) canvas.drawLine(Offset(rect.left, topY), Offset(rect.right, topY), selectedBorderPaint);
        if (drawBottom) canvas.drawLine(rect.bottomLeft, rect.bottomRight, selectedBorderPaint);
        if (drawLeft) canvas.drawLine(rect.topLeft, rect.bottomLeft, selectedBorderPaint);
        if (drawRight) canvas.drawLine(rect.topRight, rect.bottomRight, selectedBorderPaint);
      }

      // ── Draw Freeze Line Indicator ──
      if (frozenRows > 0 && rowIndex == frozenRows - 1) {
        final freezeLinePaint = Paint()
          ..color = themeConfig.accentColor
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(rect.left, rect.bottom),
          Offset(rect.right, rect.bottom),
          freezeLinePaint,
        );
      }

      if (frozenColumns > 0 && col == frozenColumns - 1) {
        final freezeColLinePaint = Paint()
          ..color = themeConfig.accentColor
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(rect.right, rect.top),
          Offset(rect.right, rect.bottom),
          freezeColLinePaint,
        );
      }

      // ── Draw "+" Fill Handle (only when showFillHandle == true) ──
      if (isSelected && currentSelection?.maxRow == rowIndex && currentSelection?.maxCol == col && showFillHandle) {
        final handleCenter = Offset(drawX + colWidth - 2, rowHeight - 2);
        final handleSize = 22.0;

        final handleRect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: handleCenter, width: handleSize, height: handleSize),
          const Radius.circular(6),
        );
        canvas.drawRRect(handleRect, handleFillPaint);
        canvas.drawRRect(handleRect, handleBorderPaint);

        final plusPaint = Paint()
          ..color = Colors.white
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        final armLen = 6.0;
        canvas.drawLine(
          Offset(handleCenter.dx - armLen, handleCenter.dy),
          Offset(handleCenter.dx + armLen, handleCenter.dy),
          plusPaint,
        );
        canvas.drawLine(
          Offset(handleCenter.dx, handleCenter.dy - armLen),
          Offset(handleCenter.dx, handleCenter.dy + armLen),
          plusPaint,
        );
      }

      // ── Draw Selection Drag Handles (blue circles) for selection ──
      if (!showFillHandle && !isDragFilling && currentSelection != null) {
        if (rowIndex == currentSelection!.minRow && col == currentSelection!.minCol) {
          // Top-Left handle
          final handleCenter = Offset(drawX, 0);
          canvas.drawCircle(handleCenter, 8.0, handleFillPaint);
          canvas.drawCircle(handleCenter, 8.0, handleBorderPaint);
        }
        if (rowIndex == currentSelection!.maxRow && col == currentSelection!.maxCol) {
          // Bottom-Right handle
          final handleCenter = Offset(drawX + colWidth, rowHeight);
          canvas.drawCircle(handleCenter, 8.0, handleFillPaint);
          canvas.drawCircle(handleCenter, 8.0, handleBorderPaint);
        }
      }

      // Column type icons
      final type = getColumnType?.call(col);
      double textPaddingRight = 16.0;
      if (type != null) {
        String? iconChar;
        if (type.id == 'selectable') iconChar = '▼';
        else if (type.id == 'date') iconChar = '📅';
        else if (type.id == 'time') iconChar = 'â°';
        if (iconChar != null) {
          textPaddingRight = 30.0;
          _tp.text = TextSpan(text: iconChar, style: iconStyle);
          _tp.layout(maxWidth: 20);
          _tp.paint(canvas, Offset(drawX + colWidth - _tp.width - 8,
              (rowHeight - _tp.height) / 2));
        }
      }

      final content = cellData['$rowIndex:$col'] ?? '';
      // Apply number format if present
      String _applyFmt(String raw) {
        final fmt = formatMap['$rowIndex:$col'] ?? CellFormat.general;
        if (fmt == CellFormat.general) return raw;
        return formatCellValue(raw, fmt);
      }

      if (type?.id == 'audio') {
        final icon = content.isNotEmpty ? Icons.play_circle : Icons.mic;
        final color = content.isNotEmpty ? Colors.green : Colors.grey;
        final iconPainter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(fontSize: 20, fontFamily: icon.fontFamily, color: color),
          ),
          textDirection: TextDirection.ltr,
        );
        iconPainter.layout();
        iconPainter.paint(canvas, Offset(drawX + 8, (rowHeight - iconPainter.height) / 2));
      } else if (type?.id == 'pdf') {
        final icon = Icons.picture_as_pdf;
        final color = content.isNotEmpty ? Colors.red : Colors.grey[400]!;
        final iconPainter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(fontSize: 20, fontFamily: icon.fontFamily, color: color),
          ),
          textDirection: TextDirection.ltr,
        );
        iconPainter.layout();
        iconPainter.paint(canvas, Offset(drawX + 8, (rowHeight - iconPainter.height) / 2));
        final fileName = content.isNotEmpty
            ? (content.contains('/') || content.contains('\\')
                ? content.split(RegExp(r'[/\\]')).last : content)
            : 'Attach PDF';
        _tp.text = TextSpan(
          text: fileName,
          style: TextStyle(
            fontSize: 13,
            color: content.isNotEmpty ? defaultCellTextColor : Colors.grey[500]!,
            fontStyle: content.isEmpty ? FontStyle.italic : FontStyle.normal,
          ),
        );
        _tp.layout(maxWidth: math.max(0.0, colWidth - 36));
        _tp.paint(canvas, Offset(drawX + 32, (rowHeight - _tp.height) / 2));
      } else {
        String? displayContent;
        bool isSpilled = false;
        
        if (content.isNotEmpty) {
          if (content.startsWith('=')) {
            displayContent = _applyFmt(evaluatedData['$rowIndex:$col'] ?? content);
          } else {
            displayContent = _applyFmt(content);
          }
        } else {
          final spilledValue = spillData['$rowIndex:$col'];
          if (spilledValue != null) {
            displayContent = spilledValue;
            isSpilled = true;
          }
        }

        if (displayContent != null && displayContent.isNotEmpty) {
          TextStyle style = isSpilled ? defaultCellStyle.copyWith(color: defaultCellStyle.color?.withOpacity(0.7) ?? Colors.grey) : defaultCellStyle;
          
          if (cfStyle != null) {
            Color? cfColor;
            if (cfStyle['textColor'] != null) {
              try {
                String tcHex = cfStyle['textColor'].toString().replaceAll('#', '');
                if (tcHex.length == 6) tcHex = 'FF$tcHex';
                cfColor = Color(int.parse(tcHex, radix: 16));
              } catch (_) {}
            }
            
            TextDecoration? dec = style.decoration;
            if (cfStyle['underline'] == true && cfStyle['strike'] == true) {
              dec = TextDecoration.combine([TextDecoration.underline, TextDecoration.lineThrough]);
            } else if (cfStyle['underline'] == true) {
              dec = TextDecoration.underline;
            } else if (cfStyle['strike'] == true) {
              dec = TextDecoration.lineThrough;
            }

            style = style.copyWith(
              color: cfColor ?? style.color,
              fontWeight: cfStyle['bold'] == true ? FontWeight.bold : style.fontWeight,
              fontStyle: cfStyle['italic'] == true ? FontStyle.italic : style.fontStyle,
              decoration: dec,
            );
          }

          _tp.text = TextSpan(text: displayContent, style: style);
          _tp.layout(maxWidth: colWidth - textPaddingRight);
          _tp.paint(canvas, Offset(drawX + 8, (rowHeight - _tp.height) / 2));
        }
      }
    }

    // ── PASS 1: Draw all NON-frozen columns at their natural positions ──
    double currentX = 0;
    for (int col = 0; col < columnCount; col++) {
      final width = getColumnWidth(col);
      if (currentX - scrollX > size.width + 300) break;

      if (col >= frozenColumns) {
        _drawCell(col, currentX, width);
      }
      currentX += width;
    }

    // ── PASS 2: Draw FROZEN columns on top, pinned at scrollX ──
    // When SingleChildScrollView translates canvas by -scrollX,
    // drawing at (scrollX + originalX) makes them appear at (originalX) on screen.
    if (frozenColumns > 0) {
      double frozenX = 0;
      for (int col = 0; col < frozenColumns && col < columnCount; col++) {
        final width = getColumnWidth(col);
        _drawCell(col, scrollX + frozenX, width);
        frozenX += width;
      }
    }
  }

  @override
  bool shouldRepaint(_RowPainter old) => true;
}

