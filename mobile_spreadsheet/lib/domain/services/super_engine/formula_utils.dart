import 'dart:math' as math;
import 'formula_rewrite_engine.dart';

class FormulaUtils {
  static final RegExp _colOnlyRegExp = RegExp(r'^[A-Z]+$');
  static final RegExp _rowOnlyRegExp = RegExp(r'^[0-9]+$');
  static final RegExp _cellRegExp = RegExp(r'^([A-Z]+)([0-9]+)$');

  static String cellRefFromCoords(int row, int col) {
    return '${_colStrFromIndex(col)}${row + 1}';
  }

  static String _colStrFromIndex(int index) {
    String res = '';
    int i = index;
    while (i >= 0) {
      res = String.fromCharCode((i % 26) + 65) + res;
      i = (i ~/ 26) - 1;
    }
    return res;
  }

  static (int row, int col)? parseCellRef(String cellRef) {
    final match = _cellRegExp.firstMatch(cellRef.toUpperCase());
    if (match == null) return null;

    final colStr = match.group(1)!;
    final rowStr = match.group(2)!;

    int col = colIndexFromStr(colStr);
    final row = (int.tryParse(rowStr) ?? 1) - 1; // 0-indexed
    return (row, col);
  }

  static int colIndexFromStr(String colStr) {
    int col = 0;
    for (int i = 0; i < colStr.length; i++) {
      col = col * 26 + (colStr.codeUnitAt(i) - 64);
    }
    return col - 1; // Convert to 0-indexed
  }

  static String formatNumber(double val) {
    if (val.isNaN) return '#VALUE!';
    if (val.isInfinite) return '#DIV/0!';

    if (val == val.truncateToDouble()) {
      if (val.abs() < 9007199254740992) {
        return val.toInt().toString();
      }
      return val.toStringAsFixed(0);
    }

    if (val.abs() < 1e-10 && val != 0) {
      return val.toString();
    }

    final formatted = val.toStringAsFixed(10);
    return formatted.replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  /// Shifts formula references when rows or columns are inserted using AST Rewrite Engine
  static String shiftFormulaReferences(
    String formula, {
    int insertedRow = -1,
    int insertedCol = -1,
  }) {
    return FormulaRewriteEngine.rewrite(
      formula,
      insertedRow: insertedRow,
      insertedCol: insertedCol,
    );
  }
}

class FooterEvaluator {
  static String evaluate({
    required Map<String, String> cellData,
    required List<int> visibleRows,
    required int columnIndex,
    required String calculationType,
  }) {
    if (visibleRows.isEmpty) return '0';
    
    // Convert calculationType to Excel function
    String funcName = calculationType.toUpperCase();
    if (funcName == 'AVG') funcName = 'AVERAGE';
    
    // Construct the formula, e.g., =SUM(A1,A2,A5)
    String colStr = FormulaUtils._colStrFromIndex(columnIndex);
    List<String> cells = [];
    for (int row in visibleRows) {
      cells.add('$colStr${row + 1}');
    }
    
    String formula = '=$funcName(${cells.join(',')})';
    
    // In our current FFI implementation, NativeEngine evaluates based on memory state, 
    // but the Dart cellData map isn't automatically fed to C++ yet for dynamically constructed formulas
    // that rely on getCellValue. For now, we manually evaluate the sum/avg from cellData.
    
    double sum = 0;
    int count = 0;
    double min = double.infinity;
    double max = double.negativeInfinity;
    
    for (int row in visibleRows) {
      final raw = cellData['$row:$columnIndex'];
      if (raw != null && raw.isNotEmpty && !raw.startsWith('=')) {
        double? val = double.tryParse(raw);
        if (val != null) {
          sum += val;
          count++;
          if (val < min) min = val;
          if (val > max) max = val;
        }
      }
    }
    
    if (count == 0 && calculationType != 'count') return '0';
    
    double result = 0;
    switch (calculationType.toLowerCase()) {
      case 'sum': result = sum; break;
      case 'avg': result = sum / count; break;
      case 'count': return count.toString();
      case 'min': result = min == double.infinity ? 0 : min; break;
      case 'max': result = max == double.negativeInfinity ? 0 : max; break;
    }
    
    return FormulaUtils.formatNumber(result);
  }
}
