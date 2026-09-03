import 'package:mobile_spreadsheet/domain/services/super_engine/ffi_bridge.dart';

class FormattingActionService {
  /// Convert column index (0-indexed) to column letter (A, B, C...)
  static String _columnName(int index) {
    int quotient = index;
    String name = '';
    while (quotient >= 0) {
      name = String.fromCharCode((quotient % 26) + 65) + name;
      quotient = (quotient ~/ 26) - 1;
    }
    return name;
  }

  /// Execute formatting script
  static void applyFormat(
      int minRow, int minCol, int maxRow, int maxCol, String method, String arg) {
    final rangeStr =
        '${_columnName(minCol)}${minRow + 1}:${_columnName(maxCol)}${maxRow + 1}';
    final script = '''
      var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
      sheet.getRange("$rangeStr").$method("$arg");
    ''';
    NativeEngine.evalJsScript(script);
  }
  
  static void clearFormat(int minRow, int minCol, int maxRow, int maxCol) {
    final rangeStr =
        '${_columnName(minCol)}${minRow + 1}:${_columnName(maxCol)}${maxRow + 1}';
    final script = '''
      var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
      sheet.getRange("$rangeStr").clearFormat();
    ''';
    NativeEngine.evalJsScript(script);
  }

  /// Apply Table Style
  static void applyTableStyle(int minRow, int minCol, int maxRow, int maxCol,
      String headerBg, String headerText, String oddBg, String evenBg) {
    if (minRow > maxRow) return;

    final headerRange =
        '${_columnName(minCol)}${minRow + 1}:${_columnName(maxCol)}${minRow + 1}';
    
    String rowsScript = '';
    for (int r = minRow + 1; r <= maxRow; r++) {
      String bg = (r - minRow) % 2 != 0 ? oddBg : evenBg;
      String rowRange = '${_columnName(minCol)}${r + 1}:${_columnName(maxCol)}${r + 1}';
      rowsScript += 'sheet.getRange("$rowRange").setBackground("$bg");\\n';
    }

    final script = '''
      var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
      var header = sheet.getRange("$headerRange");
      header.setBackground("$headerBg");
      header.setFontColor("$headerText");
      header.setFontWeight("bold");
      $rowsScript
    ''';
    NativeEngine.evalJsScript(script);
  }
}
