import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import '../../entities/spreadsheet_entity.dart';

class CsvImportService {
  final _uuid = const Uuid();

  /// Decode bytes to string supporting UTF-8, UTF-16LE, UTF-16BE, and Latin-1 / Windows-1252.
  String _decodeCsvBytes(List<int> bytes) {
    if (bytes.isEmpty) return '';

    // 1. Check UTF-8 BOM: EF BB BF
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      try {
        return utf8.decode(bytes.sublist(3), allowMalformed: true).replaceAll('\uFEFF', '');
      } catch (_) {}
    }

    // 2. Check UTF-16 LE BOM: FF FE
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _decodeUtf16Le(bytes.sublist(2));
    }

    // 3. Check UTF-16 BE BOM: FE FF
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _decodeUtf16Be(bytes.sublist(2));
    }

    // 4. Check for UTF-16 LE without BOM (check for alternating null bytes)
    if (bytes.length >= 6 && bytes[1] == 0x00 && bytes[3] == 0x00 && bytes[5] == 0x00) {
      return _decodeUtf16Le(bytes);
    }

    // 5. Try strict UTF-8
    try {
      final decoded = utf8.decode(bytes, allowMalformed: false);
      return decoded.replaceAll('\uFEFF', '');
    } catch (_) {
      // 6. Strict UTF-8 failed, try Latin-1 / Windows-1252
      try {
        final latin1Decoded = latin1.decode(bytes, allowInvalid: true);
        return latin1Decoded.replaceAll('\uFEFF', '');
      } catch (_) {
        return utf8.decode(bytes, allowMalformed: true).replaceAll('\uFEFF', '');
      }
    }
  }

  String _decodeUtf16Le(List<int> bytes) {
    final buffer = StringBuffer();
    for (int i = 0; i < bytes.length - 1; i += 2) {
      final codeUnit = bytes[i] | (bytes[i + 1] << 8);
      if (codeUnit != 0 && codeUnit != 0xFEFF) {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }

  String _decodeUtf16Be(List<int> bytes) {
    final buffer = StringBuffer();
    for (int i = 0; i < bytes.length - 1; i += 2) {
      final codeUnit = (bytes[i] << 8) | bytes[i + 1];
      if (codeUnit != 0 && codeUnit != 0xFEFF) {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }

  String _detectDelimiter(String text) {
    final firstLine = text.split(RegExp(r'[\r\n]+')).firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    if (firstLine.isEmpty) return ',';
    final commas = ','.allMatches(firstLine).length;
    final semicolons = ';'.allMatches(firstLine).length;
    final tabs = '\t'.allMatches(firstLine).length;
    if (semicolons > commas && semicolons > tabs) return ';';
    if (tabs > commas && tabs > semicolons) return '\t';
    return ',';
  }

  String _normalizeCellText(String value) {
    var text = value.trim();
    while (text.startsWith('\uFEFF') || text.startsWith('\u200B')) {
      text = text.substring(1).trim();
    }
    while (text.endsWith('\uFEFF') || text.endsWith('\u200B')) {
      text = text.substring(0, text.length - 1).trim();
    }
    return text;
  }

  bool _looksLikeFormula(String value) {
    final text = value.trimLeft();
    return text.startsWith('=') && text.length > 1;
  }

  /// Picks a CSV file and parses it into a new Spreadsheet object.
  Future<SpreadsheetEntity?> pickAndImportCsv() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'tsv', 'txt'],
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = File(result.files.single.path!);
      final csvBytes = await file.readAsBytes();
      final csvString = _decodeCsvBytes(csvBytes);

      final delimiter = _detectDelimiter(csvString);
      final List<List<dynamic>> rows = CsvToListConverter(
        fieldDelimiter: delimiter,
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(csvString);

      if (rows.isEmpty) {
        return null;
      }

      final Map<String, String> cellData = {};
      for (int r = 0; r < rows.length; r++) {
        final row = rows[r];
        for (int c = 0; c < row.length; c++) {
          final value = _normalizeCellText(row[c].toString());
          if (value.isNotEmpty) {
            cellData['$r:$c'] = value;
          }
        }
      }

      final rawName = result.files.single.name;
      final name = rawName.contains('.') ? rawName.substring(0, rawName.lastIndexOf('.')) : rawName;

      return SpreadsheetEntity(
        spreadsheetId: _uuid.v4(),
        name: name.isEmpty ? 'Imported CSV' : name,
        transientCellData: cellData,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      print('Error importing CSV: $e');
      return null;
    }
  }

  /// Imports a CSV directly from a file path
  Future<SpreadsheetEntity?> importCsvFromFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;

      final csvBytes = await file.readAsBytes();
      final csvString = _decodeCsvBytes(csvBytes);

      final delimiter = _detectDelimiter(csvString);
      final List<List<dynamic>> rows = CsvToListConverter(
        fieldDelimiter: delimiter,
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(csvString);

      if (rows.isEmpty) return null;

      final Map<String, String> cellData = {};
      for (int r = 0; r < rows.length; r++) {
        final row = rows[r];
        for (int c = 0; c < row.length; c++) {
          final value = _normalizeCellText(row[c].toString());
          if (value.isNotEmpty) {
            cellData['$r:$c'] = value;
          }
        }
      }

      final rawName = file.uri.pathSegments.last;
      final name = rawName.contains('.') ? rawName.substring(0, rawName.lastIndexOf('.')) : rawName;

      return SpreadsheetEntity(
        spreadsheetId: _uuid.v4(),
        name: name.isEmpty ? 'Imported CSV' : name,
        transientCellData: cellData,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      print('Error importing CSV from file: $e');
      return null;
    }
  }
}
