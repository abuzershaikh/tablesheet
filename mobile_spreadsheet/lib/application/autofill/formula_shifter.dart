/// Utility to shift cell references in formulas during AutoFill.
class FormulaShifter {
  static final RegExp _cellRefRegex = RegExp(r'(?<![a-zA-Z])(\$?)([a-zA-Z]+)(\$?)([1-9][0-9]*)');

  /// Shifts a single formula string by the given offsets.
  static String shiftFormula(String formula, int rowOffset, int colOffset) {
    if (!formula.startsWith('=')) return formula;

    return formula.replaceAllMapped(_cellRefRegex, (match) {
      final colAbs = match.group(1) == '\$';
      final colStr = match.group(2)!.toUpperCase();
      final rowAbs = match.group(3) == '\$';
      final rowStr = match.group(4)!;

      int colIndex = _columnNameToNumber(colStr);
      int rowIndex = int.parse(rowStr);

      if (!colAbs) {
        colIndex += colOffset;
      }
      if (!rowAbs) {
        rowIndex += rowOffset;
      }

      // Ensure we don't drop below A1
      if (colIndex < 1) colIndex = 1;
      if (rowIndex < 1) rowIndex = 1;

      final newColStr = _numberToColumnName(colIndex);
      return '${colAbs ? '\$' : ''}$newColStr${rowAbs ? '\$' : ''}$rowIndex';
    });
  }

  /// Converts column name like 'A' to 1, 'Z' to 26, 'AA' to 27.
  static int _columnNameToNumber(String columnName) {
    int result = 0;
    for (int i = 0; i < columnName.length; i++) {
      result *= 26;
      result += columnName.codeUnitAt(i) - 64;
    }
    return result;
  }

  /// Converts column number like 1 to 'A', 26 to 'Z', 27 to 'AA'.
  static String _numberToColumnName(int columnNumber) {
    String columnName = '';
    while (columnNumber > 0) {
      int modulo = (columnNumber - 1) % 26;
      columnName = String.fromCharCode(65 + modulo) + columnName;
      columnNumber = (columnNumber - modulo) ~/ 26;
    }
    return columnName;
  }
}
