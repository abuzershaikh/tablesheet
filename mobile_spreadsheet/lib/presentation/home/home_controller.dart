import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/spreadsheet_entity.dart';
import '../../domain/entities/sheet_entity.dart';
import '../../domain/repositories/spreadsheet_repository.dart';
import '../../domain/services/import/csv_import_service.dart';
import '../../domain/services/import/excel_import_service.dart';
import '../../domain/services/storage/sheet_data_storage.dart';

/// Controller for home screen state management
class HomeController extends ChangeNotifier {
  final SpreadsheetRepository _spreadsheetRepository;
  
  List<SpreadsheetEntity> _spreadsheets = [];
  List<SpreadsheetEntity> _filteredSpreadsheets = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String _sortBy = 'date'; // 'name' or 'date'

  HomeController(this._spreadsheetRepository);

  // Getters
  List<SpreadsheetEntity> get spreadsheets => _filteredSpreadsheets;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> updateSpreadsheet(SpreadsheetEntity spreadsheet) async {
    try {
      await _spreadsheetRepository.updateSpreadsheet(spreadsheet);
      await loadSpreadsheets();
    } catch (e) {
      _error = 'Failed to update spreadsheet: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Load all spreadsheets
  Future<void> loadSpreadsheets() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _spreadsheets = await _spreadsheetRepository.getAllSpreadsheets();
      _applyFiltersAndSort();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Search spreadsheets by query
  void searchSpreadsheets(String query) {
    _searchQuery = query.toLowerCase();
    _applyFiltersAndSort();
    notifyListeners();
  }

  /// Sort spreadsheets
  void sortSpreadsheets(String sortBy) {
    _sortBy = sortBy;
    _applyFiltersAndSort();
    notifyListeners();
  }

  /// Create blank spreadsheet
  Future<SpreadsheetEntity?> createBlankSpreadsheet() async {
    try {
      final uuid = const Uuid();
      final now = DateTime.now();
      
      final spreadsheetId = uuid.v4();
      final sheetId = uuid.v4();

      // Generate a unique name
      String baseName = 'Untitled Spreadsheet';
      String name = baseName;
      int counter = 1;
      
      while (_spreadsheets.any((s) => s.name == name)) {
        name = '$baseName $counter';
        counter++;
      }

      // Create default sheet
      final sheet = SheetEntity(
        sheetId: sheetId,
        spreadsheetId: spreadsheetId,
        name: 'Sheet 1',
        position: 0,
        createdAt: now,
        updatedAt: now,
      );

      // Create spreadsheet with one sheet
      final spreadsheet = SpreadsheetEntity(
        spreadsheetId: spreadsheetId,
        name: name,
        createdAt: now,
        updatedAt: now,
        sheets: [sheet],
      );

      await _spreadsheetRepository.createSpreadsheet(spreadsheet);
      await loadSpreadsheets();
      return spreadsheet;
    } catch (e) {
      _error = 'Failed to create spreadsheet: $e';
      notifyListeners();
      return null;
    }
  }

  /// Import from Excel
  Future<SpreadsheetEntity?> importExcel() async {
    _isLoading = true;
    notifyListeners();
    try {
      final excelService = ExcelImportService();
      final spreadsheet = await excelService.pickAndImportExcel();
      
      if (spreadsheet != null) {
        await _spreadsheetRepository.createSpreadsheet(spreadsheet);
        await loadSpreadsheets();
        _isLoading = false;
        notifyListeners();
        return spreadsheet;
      }
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'Failed to import Excel: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<SpreadsheetEntity?> importExcelFromFile(String path) async {
    _isLoading = true;
    notifyListeners();
    try {
      final excelService = ExcelImportService();
      final spreadsheet = await excelService.importExcelFromFile(path);
      
      if (spreadsheet != null) {
        await _spreadsheetRepository.createSpreadsheet(spreadsheet);
        await loadSpreadsheets();
        _isLoading = false;
        notifyListeners();
        return spreadsheet;
      }
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'Failed to import Excel from file: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Import from CSV
  Future<SpreadsheetEntity?> importCsv() async {
    _isLoading = true;
    notifyListeners();
    try {
      final csvService = CsvImportService();
      final spreadsheet = await csvService.pickAndImportCsv();
      
      if (spreadsheet != null) {
        final uuid = const Uuid();
        final now = DateTime.now();
        final sheetId = uuid.v4();
        
        int maxRow = 1000;
        int maxCol = 26;
        if (spreadsheet.transientCellData != null) {
          for (final key in spreadsheet.transientCellData!.keys) {
            final parts = key.split(':');
            if (parts.length == 2) {
              final r = int.tryParse(parts[0]) ?? 0;
              final c = int.tryParse(parts[1]) ?? 0;
              if (r >= maxRow) maxRow = r + 50;
              if (c >= maxCol) maxCol = c + 5;
            }
          }
        }
        
        final sheet = SheetEntity(
          sheetId: sheetId,
          spreadsheetId: spreadsheet.spreadsheetId,
          name: 'Sheet 1',
          position: 0,
          createdAt: now,
          updatedAt: now,
          metadata: SheetMetadata(
            rowCount: maxRow,
            columnCount: maxCol,
          ),
        );
        
        final newSpreadsheet = spreadsheet.copyWith(sheets: [sheet]);
        
        if (spreadsheet.transientCellData != null) {
          await SheetDataStorage.saveCellData(sheetId, spreadsheet.transientCellData!);
          await SheetDataStorage.saveCellData(newSpreadsheet.spreadsheetId, spreadsheet.transientCellData!);
        }

        await _spreadsheetRepository.createSpreadsheet(newSpreadsheet);
        await loadSpreadsheets();
        _isLoading = false;
        notifyListeners();
        return newSpreadsheet;
      }
      
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'Failed to import CSV: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<SpreadsheetEntity?> importCsvFromFile(String path) async {
    _isLoading = true;
    notifyListeners();
    try {
      final csvService = CsvImportService();
      final spreadsheet = await csvService.importCsvFromFile(path);
      
      if (spreadsheet != null) {
        final uuid = const Uuid();
        final now = DateTime.now();
        final sheetId = uuid.v4();
        
        int maxRow = 1000;
        int maxCol = 26;
        if (spreadsheet.transientCellData != null) {
          for (final key in spreadsheet.transientCellData!.keys) {
            final parts = key.split(':');
            if (parts.length == 2) {
              final r = int.tryParse(parts[0]) ?? 0;
              final c = int.tryParse(parts[1]) ?? 0;
              if (r >= maxRow) maxRow = r + 50; 
              if (c >= maxCol) maxCol = c + 5; 
            }
          }
        }
        
        final sheet = SheetEntity(
          sheetId: sheetId,
          spreadsheetId: spreadsheet.spreadsheetId,
          name: 'Sheet 1',
          position: 0,
          createdAt: now,
          updatedAt: now,
          metadata: SheetMetadata(
            rowCount: maxRow,
            columnCount: maxCol,
          ),
        );
        
        final newSpreadsheet = spreadsheet.copyWith(sheets: [sheet]);
        
        if (spreadsheet.transientCellData != null) {
          await SheetDataStorage.saveCellData(sheetId, spreadsheet.transientCellData!);
          await SheetDataStorage.saveCellData(newSpreadsheet.spreadsheetId, spreadsheet.transientCellData!);
        }

        await _spreadsheetRepository.createSpreadsheet(newSpreadsheet);
        await loadSpreadsheets();
        _isLoading = false;
        notifyListeners();
        return newSpreadsheet;
      }
      
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'Failed to import CSV from file: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Smart dispatcher that inspects file header magic bytes and extension,
  /// routing to Excel or CSV import accordingly with automatic fallbacks.
  Future<SpreadsheetEntity?> importAnyFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        _error = 'File not found: $path';
        notifyListeners();
        return null;
      }

      final lowerPath = path.toLowerCase();

      // Read initial bytes to check magic headers
      List<int> headerBytes = [];
      try {
        final opened = await file.open(mode: FileMode.read);
        headerBytes = await opened.read(16);
        await opened.close();
      } catch (_) {}

      final isZipOrXlsx = headerBytes.length >= 4 &&
          headerBytes[0] == 0x50 &&
          headerBytes[1] == 0x4B &&
          (headerBytes[2] == 0x03 || headerBytes[2] == 0x05 || headerBytes[2] == 0x07);

      final isOleXls = headerBytes.length >= 8 &&
          headerBytes[0] == 0xD0 &&
          headerBytes[1] == 0xCF &&
          headerBytes[2] == 0x11 &&
          headerBytes[3] == 0xE0;

      if (isZipOrXlsx || isOleXls || lowerPath.endsWith('.xlsx') || lowerPath.endsWith('.xls') || lowerPath.endsWith('.xlsm')) {
        final result = await importExcelFromFile(path);
        if (result != null) return result;
        // Fallback to CSV if Excel decoder could not parse it
        return await importCsvFromFile(path);
      } else {
        final result = await importCsvFromFile(path);
        if (result != null) return result;
        // Fallback to Excel
        return await importExcelFromFile(path);
      }
    } catch (e) {
      _error = 'Failed to import file: $e';
      notifyListeners();
      return null;
    }
  }

  /// Delete spreadsheet with undo option
  Future<void> deleteSpreadsheet(String id) async {
    try {
      // Store for undo
      final deletedSpreadsheet = _spreadsheets.firstWhere((s) => s.spreadsheetId == id);
      
      await _spreadsheetRepository.deleteSpreadsheet(id);
      await SheetDataStorage.deleteCellData(id);
      await loadSpreadsheets();
      
      // Return deleted spreadsheet for undo functionality
      return;
    } catch (e) {
      _error = 'Failed to delete spreadsheet: $e';
      notifyListeners();
    }
  }

  /// Duplicate spreadsheet
  Future<void> duplicateSpreadsheet(String id) async {
    try {
      final original = _spreadsheets.firstWhere((s) => s.spreadsheetId == id);
      final uuid = const Uuid();
      final now = DateTime.now();
      
      final newSpreadsheetId = uuid.v4();
      
      // Duplicate sheets
      final newSheets = original.sheets.map((sheet) {
        return sheet.copyWith(
          sheetId: uuid.v4(),
          spreadsheetId: newSpreadsheetId,
          createdAt: now,
          updatedAt: now,
        );
      }).toList();

      // Create duplicate
      final duplicate = SpreadsheetEntity(
        spreadsheetId: newSpreadsheetId,
        name: '${original.name} (Copy)',
        createdAt: now,
        updatedAt: now,
        sheets: newSheets,
      );

      await _spreadsheetRepository.createSpreadsheet(duplicate);
      await loadSpreadsheets();
    } catch (e) {
      _error = 'Failed to duplicate spreadsheet: $e';
      notifyListeners();
    }
  }

  /// Rename spreadsheet
  Future<void> renameSpreadsheet(String id, String newName) async {
    try {
      final spreadsheet = _spreadsheets.firstWhere((s) => s.spreadsheetId == id);
      final updated = spreadsheet.copyWith(
        name: newName,
        updatedAt: DateTime.now(),
      );
      
      await _spreadsheetRepository.updateSpreadsheet(updated);
      await loadSpreadsheets();
    } catch (e) {
      _error = 'Failed to rename spreadsheet: $e';
      notifyListeners();
    }
  }

  /// Apply filters and sorting
  void _applyFiltersAndSort() {
    // Filter by search query
    if (_searchQuery.isEmpty) {
      _filteredSpreadsheets = List.from(_spreadsheets);
    } else {
      _filteredSpreadsheets = _spreadsheets
          .where((s) => s.name.toLowerCase().contains(_searchQuery))
          .toList();
    }

    // Sort
    if (_sortBy == 'name') {
      _filteredSpreadsheets.sort((a, b) => a.name.compareTo(b.name));
    } else if (_sortBy == 'date') {
      _filteredSpreadsheets.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
  }
}