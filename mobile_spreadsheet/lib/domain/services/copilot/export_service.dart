import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mobile_spreadsheet/domain/services/super_engine/ffi_bridge.dart';
import 'package:mobile_spreadsheet/domain/services/super_engine/formula_utils.dart';

class ExportResult {
  final bool success;
  final String filePath;
  final String format;
  final int exportedRows;
  final String? error;

  ExportResult({
    required this.success,
    required this.filePath,
    required this.format,
    required this.exportedRows,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'success': success,
    'file_path': filePath,
    'format': format,
    'exported_rows': exportedRows,
    if (error != null) 'error': error,
  };
}

class ExportService {
  /// Exports sheet data (full sheet or filtered columns/rows) to CSV, VCF (vCard), or Excel/PDF.
  static Future<ExportResult> exportData({
    required String format, // 'csv', 'vcf', 'xlsx', 'pdf'
    List<String>? targetColumns, // e.g. ["A", "C"] or ["Name", "Phone"]
    int startRow = 2,
    int? endRow,
    String? fileName,
  }) async {
    try {
      final rawGridJson = NativeEngine.getRawGrid();
      if (rawGridJson == null || rawGridJson.isEmpty || rawGridJson == '{}') {
        return ExportResult(success: false, filePath: '', format: format, exportedRows: 0, error: 'Sheet is empty');
      }

      Map<String, dynamic> gridMap;
      try {
        gridMap = jsonDecode(rawGridJson);
      } catch (_) {
        final sanitized = rawGridJson.replaceAllMapped(
          RegExp(r'\\([^"\\/bfnrtu])'),
          (match) => '\\\\${match.group(1)}',
        );
        gridMap = jsonDecode(sanitized);
      }

      // Parse grid into row-col map
      int maxR = 0;
      int maxC = 0;
      final matrix = <int, Map<int, String>>{};

      gridMap.forEach((cellRef, value) {
        int r = -1, c = -1;
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
          matrix.putIfAbsent(r, () => {})[c] = value.toString();
          if (r > maxR) maxR = r;
          if (c > maxC) maxC = c;
        }
      });

      // Flexible Row Range Slicing (1-indexed input → 0-indexed matrix bounds)
      int rStart = startRow - 1;
      if (startRow < 0) {
        // Negative startRow = last N rows (e.g. -50 = last 50 rows)
        rStart = (maxR + 1) + startRow;
      }
      if (rStart < 1) rStart = 1; // Row 1 is header row (0-indexed 0)

      int rEnd = maxR;
      if (endRow != null) {
        if (endRow < 0) {
          rEnd = (maxR + 1) + endRow;
        } else {
          rEnd = endRow - 1;
        }
      }
      if (rEnd > maxR) rEnd = maxR;
      if (rStart > rEnd) rStart = rEnd;

      final effectiveStartRow = rStart;
      final effectiveEndRow = rEnd;


      // Filter target columns if specified
      List<int> selectedColIndexes = [];
      if (targetColumns != null && targetColumns.isNotEmpty) {
        for (var colStr in targetColumns) {
          final colClean = colStr.trim().toUpperCase();
          if (RegExp(r'^[A-Z]+$').hasMatch(colClean)) {
            final parsed = FormulaUtils.parseCellRef('${colClean}1');
            if (parsed != null) selectedColIndexes.add(parsed.$2);
          } else {
            final intCol = int.tryParse(colClean);
            if (intCol != null) selectedColIndexes.add(intCol);
          }
        }
      }

      if (selectedColIndexes.isEmpty) {
        selectedColIndexes = List.generate(maxC + 1, (i) => i);
      }

      final fmtLower = format.trim().toLowerCase();
      final docsDir = await getApplicationDocumentsDirectory();
      final timeStamp = DateTime.now().millisecondsSinceEpoch;
      final outFileName = fileName ?? 'export_$timeStamp.$fmtLower';
      final outPath = '${docsDir.path}/$outFileName';
      final outFile = File(outPath);

      int exportedRowsCount = 0;

      if (fmtLower == 'vcf' || fmtLower == 'vcard') {
        // Generate VCF (vCard 3.0) file
        final buffer = StringBuffer();
        int nameCol = selectedColIndexes.first;
        int phoneCol = selectedColIndexes.length > 1 ? selectedColIndexes[1] : -1;
        int emailCol = selectedColIndexes.length > 2 ? selectedColIndexes[2] : -1;

        // Auto-detect name, phone, email columns if not explicitly ordered
        for (int c in selectedColIndexes) {
          final val = (matrix[1]?[c] ?? matrix[0]?[c] ?? '').toLowerCase();
          if (val.contains('name') || val.contains('fn')) nameCol = c;
          else if (val.contains('phone') || val.contains('mobile') || val.contains('tel')) phoneCol = c;
          else if (val.contains('email') || val.contains('mail')) emailCol = c;
        }

        for (int r = effectiveStartRow; r <= effectiveEndRow; r++) {

          final rowMap = matrix[r];
          if (rowMap == null || rowMap.isEmpty) continue;

          String fn = rowMap[nameCol]?.trim() ?? '';
          String tel = phoneCol >= 0 ? (rowMap[phoneCol]?.trim() ?? '') : '';
          String email = emailCol >= 0 ? (rowMap[emailCol]?.trim() ?? '') : '';

          // If fn is missing, check all cols in row
          if (fn.isEmpty) {
            rowMap.forEach((_, v) {
              if (fn.isEmpty && v.trim().isNotEmpty && !v.contains('@') && !v.contains('+')) {
                fn = v.trim();
              }
            });
          }

          if (fn.isEmpty && tel.isEmpty && email.isEmpty) continue;
          if (fn.isEmpty) fn = 'Contact ${r + 1}';

          buffer.writeln('BEGIN:VCARD');
          buffer.writeln('VERSION:3.0');
          buffer.writeln('FN:$fn');
          buffer.writeln('N:;$fn;;;');
          if (tel.isNotEmpty) buffer.writeln('TEL;TYPE=CELL:$tel');
          if (email.isNotEmpty) buffer.writeln('EMAIL;TYPE=INTERNET:$email');
          buffer.writeln('END:VCARD');
          exportedRowsCount++;
        }

        await outFile.writeAsString(buffer.toString());
      } else {
        // Generate CSV file (compatible with Excel .xlsx opening)
        final csvLines = <String>[];
        // Include Header Row (Row 0)
        final headerVals = selectedColIndexes.map((c) {
          final h = matrix[0]?[c] ?? FormulaUtils.cellRefFromCoords(0, c).replaceAll(RegExp(r'[0-9]'), '');
          return '"${h.replaceAll('"', '""')}"';
        }).join(',');
        csvLines.add(headerVals);

        for (int r = effectiveStartRow; r <= effectiveEndRow; r++) {

          final rowMap = matrix[r];
          if (rowMap == null || rowMap.isEmpty) continue;
          final line = selectedColIndexes.map((c) {
            final val = rowMap[c] ?? '';
            return '"${val.replaceAll('"', '""')}"';
          }).join(',');
          csvLines.add(line);
          exportedRowsCount++;
        }

        await outFile.writeAsString(csvLines.join('\n'));
      }

      // Save via SAF FilePicker or fallback to System Share
      try {
        final savePath = await FilePicker.saveFile(
          dialogTitle: 'Save Exported $fmtLower File',
          fileName: outFileName,
          type: FileType.custom,
          allowedExtensions: [fmtLower],
        );
        if (savePath != null && savePath.isNotEmpty) {
          await File(savePath).writeAsBytes(await outFile.readAsBytes());
          debugPrint('[ExportService] File saved via SAF to: $savePath');
        } else {
          await Share.shareXFiles([XFile(outPath)], text: 'Exported $outFileName ($exportedRowsCount rows)');
        }
      } catch (e) {
        debugPrint('[ExportService] SAF save error, falling back to Share: $e');
        await Share.shareXFiles([XFile(outPath)], text: 'Exported $outFileName ($exportedRowsCount rows)');
      }

      return ExportResult(
        success: true,
        filePath: outPath,
        format: fmtLower,
        exportedRows: exportedRowsCount,
      );

    } catch (e) {
      debugPrint('[ExportService] Export error: $e');
      return ExportResult(
        success: false,
        filePath: '',
        format: format,
        exportedRows: 0,
        error: e.toString(),
      );
    }
  }
}
