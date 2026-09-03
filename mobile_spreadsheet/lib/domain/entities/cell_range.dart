import 'dart:math' as math;

/// Represents a rectangular range of cells in a spreadsheet.
class CellRange {
  final int startRow;
  final int startCol;
  final int endRow;
  final int endCol;

  const CellRange(this.startRow, this.startCol, this.endRow, this.endCol);

  int get minRow => math.min(startRow, endRow);
  int get maxRow => math.max(startRow, endRow);
  int get minCol => math.min(startCol, endCol);
  int get maxCol => math.max(startCol, endCol);

  int get rowCount => (maxRow - minRow) + 1;
  int get colCount => (maxCol - minCol) + 1;
  int get cellCount => rowCount * colCount;

  bool contains(int row, int col) {
    return row >= minRow && row <= maxRow && col >= minCol && col <= maxCol;
  }

  /// Returns true if this range is a single cell.
  bool get isSingleCell => startRow == endRow && startCol == endCol;

  /// Returns the direction of the drag based on the major axis.
  /// Used for calculating target range when dragging the fill handle.
  /// 0 = Up, 1 = Down, 2 = Left, 3 = Right, -1 = No drag
  int getDragDirection(CellRange targetPreview) {
    final dr = targetPreview.endRow - endRow;
    final dc = targetPreview.endCol - endCol;

    if (dr == 0 && dc == 0) return -1;

    if (dr.abs() > dc.abs()) {
      return dr > 0 ? 1 : 0; // 1=Down, 0=Up
    } else {
      return dc > 0 ? 3 : 2; // 3=Right, 2=Left
    }
  }

  /// Expands the range along a single axis (locked).
  CellRange expandToLockedAxis(int targetRow, int targetCol) {
    final dr = targetRow - endRow;
    final dc = targetCol - endCol;

    if (dr.abs() > dc.abs()) {
      // Lock to Vertical
      return CellRange(startRow, startCol, targetRow, endCol);
    } else {
      // Lock to Horizontal
      return CellRange(startRow, startCol, endRow, targetCol);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellRange &&
          runtimeType == other.runtimeType &&
          startRow == other.startRow &&
          startCol == other.startCol &&
          endRow == other.endRow &&
          endCol == other.endCol;

  @override
  int get hashCode =>
      startRow.hashCode ^ startCol.hashCode ^ endRow.hashCode ^ endCol.hashCode;

  @override
  String toString() {
    return 'CellRange(R$startRow:C$startCol to R$endRow:C$endCol)';
  }
}
