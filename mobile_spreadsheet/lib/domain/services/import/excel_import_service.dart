import 'dart:io';
import 'package:excel_plus/excel_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import '../../entities/spreadsheet_entity.dart';
import '../../entities/sheet_entity.dart';
import '../storage/sheet_data_storage.dart';
import 'excel_image_extractor.dart';

class ExcelImportService {
  final _uuid = const Uuid();

  Future<SpreadsheetEntity?> pickAndImportExcel() async {
    try {
      print('DEBUG [ExcelImport]: Starting FilePicker...');
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null) {
        print('DEBUG [ExcelImport]: FilePicker result is null (User cancelled)');
        return null;
      }
      if (result.files.isEmpty) {
        print('DEBUG [ExcelImport]: FilePicker returned empty files list');
        return null;
      }
      
      final file = result.files.single;
      if (file.bytes != null) {
        print('DEBUG [ExcelImport]: File picked successfully with bytes. Size: ${file.bytes!.length}');
        return importExcelFromBytes(file.bytes!, file.name);
      } else if (file.path != null) {
        print('DEBUG [ExcelImport]: File picked successfully with path. Path: ${file.path}');
        return importExcelFromFile(file.path!);
      } else {
        print('DEBUG [ExcelImport]: FilePicker returned no bytes and no path.');
        return null;
      }
    } catch (e, stack) {
      print('DEBUG [ExcelImport]: Error picking Excel: $e\n$stack');
      return null;
    }
  }

  Future<SpreadsheetEntity?> importExcelFromBytes(List<int> bytes, String fileName) async {
    try {
      print('DEBUG [ExcelImport]: Importing from bytes. Size: ${bytes.length}');
      final excel = Excel.decodeBytes(bytes);
      return _processExcelArchive(excel, bytes, fileName);
    } catch (e, stack) {
      print('DEBUG [ExcelImport]: Error importing Excel from bytes: $e\n$stack');
      return null;
    }
  }

  Future<SpreadsheetEntity?> importExcelFromFile(String path) async {
    try {
      print('DEBUG [ExcelImport]: Importing from path: $path');
      final file = File(path);
      if (!file.existsSync()) {
        print('DEBUG [ExcelImport]: File does NOT exist at path: $path');
        return null;
      }
      
      print('DEBUG [ExcelImport]: File exists. Reading bytes...');
      final bytes = file.readAsBytesSync();
      print('DEBUG [ExcelImport]: Read ${bytes.length} bytes. Decoding Excel...');
      
      final excel = Excel.decodeBytes(bytes);
      final fileName = file.uri.pathSegments.last;
      return _processExcelArchive(excel, bytes, fileName);
    } catch (e, stack) {
      print('DEBUG [ExcelImport]: Error importing Excel from file: $e\n$stack');
      return null;
    }
  }

  Future<SpreadsheetEntity?> _processExcelArchive(Excel excel, List<int> bytes, String fileName) async {
    try {
      print('DEBUG [ExcelImport]: Excel decoded. Found ${excel.tables.length} tables/sheets.');
      
      // Extract images
      final imageExtractor = ExcelImageExtractor();
      final sheetImages = await imageExtractor.extractImages(bytes);
      print('DEBUG [ExcelImport]: Extracted images for ${sheetImages.length} sheets.');

      final spreadsheetId = _uuid.v4();
      final name = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;
      final now = DateTime.now();

      List<SheetEntity> sheets = [];
      int position = 0;

      for (var table in excel.tables.keys) {
        print('DEBUG [ExcelImport]: Parsing sheet: $table');
        final sheet = excel.tables[table];
        if (sheet == null) continue;
        
        final Map<String, String> cellData = {};
        int maxRow = 1000;
        int maxCol = 26;

        final allRows = sheet.rows;
        for (int r = 0; r < allRows.length; r++) {
          final row = allRows[r];
          for (int c = 0; c < row.length; c++) {
            final cell = row[c];
            if (cell != null && cell.value != null) {
              final valStr = cell.value.toString().trim();
              if (valStr.isNotEmpty) {
                cellData['$r:$c'] = valStr;
                if (r >= maxRow) maxRow = r + 50;
                if (c >= maxCol) maxCol = c + 5;
              }
            }
          }
        }
        
        print('DEBUG [ExcelImport]: Sheet $table parsed. Found ${cellData.length} cells. Saving to storage...');
        final sheetId = _uuid.v4();
        await SheetDataStorage.saveCellData(sheetId, cellData);
        if (sheets.isEmpty) {
          await SheetDataStorage.saveCellData(spreadsheetId, cellData);
        }

        sheets.add(SheetEntity(
          sheetId: sheetId,
          spreadsheetId: spreadsheetId,
          name: table,
          position: position++,
          createdAt: now,
          updatedAt: now,
          metadata: SheetMetadata(
            rowCount: maxRow,
            columnCount: maxCol,
          ),
          images: sheetImages[table] ?? [],
        ));
      }

      print('DEBUG [ExcelImport]: Import completed successfully. Returning SpreadsheetEntity.');
      return SpreadsheetEntity(
        spreadsheetId: spreadsheetId,
        name: name.isEmpty ? 'Imported Excel' : name,
        sheets: sheets,
        createdAt: now,
        updatedAt: now,
      );
    } catch (e, stack) {
      print('DEBUG [ExcelImport]: Error processing Excel archive: $e\n$stack');
      return null;
    }
  }
}
