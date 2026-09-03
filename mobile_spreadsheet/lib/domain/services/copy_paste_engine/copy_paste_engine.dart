import 'package:flutter/foundation.dart';
import '../autofill/autofill_engine.dart';

class PastePayload {
  final String text;
  final int startRow;
  final int startColumn;
  final int maxRows;
  final int maxColumns;

  PastePayload(this.text, this.startRow, this.startColumn, this.maxRows, this.maxColumns);
}

class AutoFillPayload {
  final int startRow;
  final int endRow;
  final int col;
  final List<String> sourceValues;

  AutoFillPayload(this.startRow, this.endRow, this.col, this.sourceValues);
}

class CopyPayload {
  final int startRow;
  final int startCol;
  final int endRow;
  final int endCol;
  final Map<String, String> cellData;

  CopyPayload(this.startRow, this.startCol, this.endRow, this.endCol, this.cellData);
}

class CopyPasteEngine {
  /// Background processor for parsing pasted CSV/TSV text
  static Future<Map<String, String>> processPasteAsync(
      String text, int startRow, int startColumn, int maxRows, int maxColumns) async {
    return compute(_parsePasteData, PastePayload(text, startRow, startColumn, maxRows, maxColumns));
  }

  static Map<String, String> _parsePasteData(PastePayload payload) {
    final Map<String, String> updates = {};
    if (payload.text.trim().isEmpty) return updates;
    
    final lines = payload.text.split(RegExp(r'\r?\n'));
    for (int rIdx = 0; rIdx < lines.length; rIdx++) {
      final line = lines[rIdx];
      if (line.isEmpty && rIdx == lines.length - 1) continue;
      
      final targetRow = payload.startRow + rIdx;
      if (targetRow >= payload.maxRows) break;
      
      final cells = line.contains('\t') ? line.split('\t') : [line];
      for (int cIdx = 0; cIdx < cells.length; cIdx++) {
        final targetCol = payload.startColumn + cIdx;
        if (targetCol >= payload.maxColumns) break;
        
        final val = cells[cIdx].trim();
        final key = '${targetRow}:${targetCol}';
        updates[key] = val;
      }
    }
    return updates;
  }

  /// Background processor for generating auto-filled series
  static Future<Map<String, String>> processAutoFillAsync(
      int startRow, int endRow, int col, List<String> sourceValues) async {
    return compute(_generateAutoFillData, AutoFillPayload(startRow, endRow, col, sourceValues));
  }

  static Map<String, String> _generateAutoFillData(AutoFillPayload payload) {
    final Map<String, String> generatedCells = {};
    if (payload.sourceValues.isEmpty) return generatedCells;

    final fillStartRow = payload.startRow + payload.sourceValues.length;
    if (fillStartRow > payload.endRow) return generatedCells;

    for (int targetRow = fillStartRow; targetRow <= payload.endRow; targetRow++) {
      final targetIndex = targetRow - payload.startRow;
      final rowDelta = targetRow - payload.startRow;

      final generatedVal = AutoFillEngine.calculateNextValue(
        sourceValues: payload.sourceValues,
        targetIndex: targetIndex,
        rowDelta: rowDelta,
      );

      final key = '${targetRow}:${payload.col}';
      generatedCells[key] = generatedVal;
    }
    return generatedCells;
  }

  /// Background processor for copying selection to clipboard text
  static Future<String> processCopyAsync(
      Map<String, String> cellData, int startRow, int startCol, int endRow, int endCol) async {
    return compute(_generateCopyData, CopyPayload(startRow, startCol, endRow, endCol, cellData));
  }

  static String _generateCopyData(CopyPayload payload) {
    final buffer = StringBuffer();
    for (int r = payload.startRow; r <= payload.endRow; r++) {
      for (int c = payload.startCol; c <= payload.endCol; c++) {
        final key = '${r}:${c}';
        final val = payload.cellData[key] ?? '';
        buffer.write(val);
        if (c < payload.endCol) buffer.write('\t');
      }
      if (r < payload.endRow) buffer.write('\n');
    }
    return buffer.toString();
  }
}
