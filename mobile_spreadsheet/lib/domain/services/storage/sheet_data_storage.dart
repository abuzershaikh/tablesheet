import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../entities/theme/spreadsheet_theme_config.dart';

class SheetDataStorage {
  /// Returns or creates target subfolder inside `Documents/Spreadsheet pro/` ('csv', 'excel', 'xlsx')
  static Future<Directory> getSpreadsheetProDir(String type) async {
    Directory baseDocs;
    if (Platform.isAndroid) {
      final publicDocs = Directory('/storage/emulated/0/Documents');
      if (await publicDocs.exists()) {
        baseDocs = publicDocs;
      } else {
        final externalStorage = await getExternalStorageDirectory();
        baseDocs = externalStorage ?? await getApplicationDocumentsDirectory();
      }
    } else {
      baseDocs = await getApplicationDocumentsDirectory();
    }

    final targetFolder = Directory('${baseDocs.path}/Spreadsheet pro/$type');
    if (!await targetFolder.exists()) {
      await targetFolder.create(recursive: true);
    }
    return targetFolder;
  }

  static Future<File> _getFile(String sheetId) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/${sheetId}_cells.json');
  }

  static Future<File> _getThemeFile(String spreadsheetId) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/${spreadsheetId}_theme.json');
  }

  static Future<void> saveCellData(String sheetId, Map<String, String> data) async {
    try {
      final file = await _getFile(sheetId);
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print('Error saving cell data: $e');
    }
  }

  static Future<Map<String, String>?> loadCellData(String sheetId, {String? fallbackSpreadsheetId}) async {
    try {
      var file = await _getFile(sheetId);
      if (!(await file.exists()) && fallbackSpreadsheetId != null) {
        final directory = await getApplicationDocumentsDirectory();
        file = File('${directory.path}/${fallbackSpreadsheetId}_cells.json');
      }
      if (await file.exists()) {
        final content = await file.readAsString();
        final decoded = jsonDecode(content) as Map<String, dynamic>;
        return decoded.map((key, value) => MapEntry(key, value.toString()));
      }
    } catch (e) {
      print('Error loading cell data: $e');
    }
    return null;
  }

  static Future<void> saveThemeConfig(String spreadsheetId, SpreadsheetThemeConfig config) async {
    try {
      final file = await _getThemeFile(spreadsheetId);
      await file.writeAsString(jsonEncode(config.toJson()));
    } catch (e) {
      print('Error saving theme config: $e');
    }
  }

  static Future<SpreadsheetThemeConfig?> loadThemeConfig(String spreadsheetId) async {
    try {
      final file = await _getThemeFile(spreadsheetId);
      if (await file.exists()) {
        final content = await file.readAsString();
        final decoded = jsonDecode(content) as Map<String, dynamic>;
        return SpreadsheetThemeConfig.fromJson(decoded);
      }
    } catch (e) {
      print('Error loading theme config: $e');
    }
    return null;
  }
  
  static Future<File> _getFooterFile(String spreadsheetId) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/${spreadsheetId}_footer.json');
  }

  static Future<void> saveFooterConfig(String spreadsheetId, Map<String, dynamic> configJson) async {
    try {
      final file = await _getFooterFile(spreadsheetId);
      await file.writeAsString(jsonEncode(configJson));
    } catch (e) {
      print('Error saving footer config: $e');
    }
  }

  static Future<Map<String, dynamic>?> loadFooterConfig(String spreadsheetId) async {
    try {
      final file = await _getFooterFile(spreadsheetId);
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error loading footer config: $e');
    }
    return null;
  }
  
  static Future<File> _getFreezeFile(String spreadsheetId) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/${spreadsheetId}_freeze.json');
  }

  static Future<void> saveFreezeConfig(String spreadsheetId, int rows, int cols) async {
    try {
      final file = await _getFreezeFile(spreadsheetId);
      await file.writeAsString(jsonEncode({'frozenRows': rows, 'frozenColumns': cols}));
    } catch (e) {
      print('Error saving freeze config: $e');
    }
  }

  static Future<Map<String, int>?> loadFreezeConfig(String spreadsheetId) async {
    try {
      final file = await _getFreezeFile(spreadsheetId);
      if (await file.exists()) {
        final content = await file.readAsString();
        final decoded = jsonDecode(content) as Map<String, dynamic>;
        return {
          'frozenRows': decoded['frozenRows'] as int? ?? 0,
          'frozenColumns': decoded['frozenColumns'] as int? ?? 0,
        };
      }
    } catch (e) {
      print('Error loading freeze config: $e');
    }
    return null;
  }

  static Future<void> deleteCellData(String sheetId) async {
    try {
      final file = await _getFile(sheetId);
      if (await file.exists()) {
        await file.delete();
      }
      final themeFile = await _getThemeFile(sheetId);
      if (await themeFile.exists()) {
        await themeFile.delete();
      }
    } catch (e) {
      print('Error deleting cell data: $e');
    }
  }
}
