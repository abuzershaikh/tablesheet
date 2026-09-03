import 'package:uuid/uuid.dart';
import '../entities/sheet_entity.dart';
import '../repositories/sheet_repository.dart';

/// Use case for sheet management operations
class SheetManagementUseCase {
  final SheetRepository _sheetRepository;
  final Uuid _uuid = const Uuid();

  SheetManagementUseCase(this._sheetRepository);

  /// Create new sheet
  Future<SheetOperationResult<SheetEntity>> createSheet(
    String spreadsheetId,
    String name,
  ) async {
    try {
      if (name.trim().isEmpty) {
        return SheetOperationResult.failure(
          SheetOperationError.invalidName,
          'Sheet name cannot be empty',
        );
      }

      // Get existing sheets to determine position
      final existingSheets = await _sheetRepository.getSheetsBySpreadsheet(spreadsheetId);
      final position = existingSheets.length;

      // Create new sheet
      final sheet = SheetEntity(
        sheetId: _uuid.v4(),
        spreadsheetId: spreadsheetId,
        name: name,
        position: position,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _sheetRepository.createSheet(sheet);
      return SheetOperationResult.success(sheet);
      
    } catch (e) {
      return SheetOperationResult.failure(
        SheetOperationError.unknownError,
        'Failed to create sheet: $e',
      );
    }
  }

  /// Delete sheet
  Future<SheetOperationResult<void>> deleteSheet(String sheetId) async {
    try {
      // Check if sheet exists
      final sheet = await _sheetRepository.getSheetById(sheetId);
      if (sheet == null) {
        return SheetOperationResult.failure(
          SheetOperationError.sheetNotFound,
          'Sheet not found',
        );
      }

      // Get all sheets in the spreadsheet
      final allSheets = await _sheetRepository.getSheetsBySpreadsheet(sheet.spreadsheetId);
      
      // Don't allow deletion if it's the last sheet
      if (allSheets.length <= 1) {
        return SheetOperationResult.failure(
          SheetOperationError.cannotDeleteLastSheet,
          'Cannot delete the last sheet',
        );
      }

      await _sheetRepository.deleteSheet(sheetId);

      // Reorder remaining sheets
      await _reorderSheetsAfterDeletion(sheet.spreadsheetId, sheet.position);

      return SheetOperationResult.success(null);
      
    } catch (e) {
      return SheetOperationResult.failure(
        SheetOperationError.unknownError,
        'Failed to delete sheet: $e',
      );
    }
  }

  /// Rename sheet
  Future<SheetOperationResult<SheetEntity>> renameSheet(
    String sheetId,
    String newName,
  ) async {
    try {
      if (newName.trim().isEmpty) {
        return SheetOperationResult.failure(
          SheetOperationError.invalidName,
          'Sheet name cannot be empty',
        );
      }

      final sheet = await _sheetRepository.getSheetById(sheetId);
      if (sheet == null) {
        return SheetOperationResult.failure(
          SheetOperationError.sheetNotFound,
          'Sheet not found',
        );
      }

      // Check for duplicate names in the same spreadsheet
      final existingSheets = await _sheetRepository.getSheetsBySpreadsheet(sheet.spreadsheetId);
      final nameExists = existingSheets.any(
        (s) => s.sheetId != sheetId && s.name.toLowerCase() == newName.toLowerCase(),
      );

      if (nameExists) {
        return SheetOperationResult.failure(
          SheetOperationError.duplicateName,
          'Sheet name already exists',
        );
      }

      final updatedSheet = sheet.copyWith(
        name: newName,
        updatedAt: DateTime.now(),
      );

      await _sheetRepository.updateSheet(updatedSheet);
      return SheetOperationResult.success(updatedSheet);
      
    } catch (e) {
      return SheetOperationResult.failure(
        SheetOperationError.unknownError,
        'Failed to rename sheet: $e',
      );
    }
  }

  /// Duplicate sheet
  Future<SheetOperationResult<SheetEntity>> duplicateSheet(String sheetId) async {
    try {
      final originalSheet = await _sheetRepository.getSheetById(sheetId);
      if (originalSheet == null) {
        return SheetOperationResult.failure(
          SheetOperationError.sheetNotFound,
          'Sheet not found',
        );
      }

      // Get existing sheets to determine position
      final existingSheets = await _sheetRepository.getSheetsBySpreadsheet(originalSheet.spreadsheetId);
      final position = existingSheets.length;

      // Generate unique name
      String newName = '${originalSheet.name} (Copy)';
      int counter = 1;
      while (existingSheets.any((s) => s.name == newName)) {
        counter++;
        newName = '${originalSheet.name} (Copy $counter)';
      }

      // Create duplicate sheet
      final duplicateSheet = SheetEntity(
        sheetId: _uuid.v4(),
        spreadsheetId: originalSheet.spreadsheetId,
        name: newName,
        position: position,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _sheetRepository.createSheet(duplicateSheet);
      
      // TODO: Copy cells from original sheet (will be implemented later)
      
      return SheetOperationResult.success(duplicateSheet);
      
    } catch (e) {
      return SheetOperationResult.failure(
        SheetOperationError.unknownError,
        'Failed to duplicate sheet: $e',
      );
    }
  }

  /// Reorder sheets
  Future<SheetOperationResult<List<SheetEntity>>> reorderSheets(
    String spreadsheetId,
    int oldIndex,
    int newIndex,
  ) async {
    try {
      final sheets = await _sheetRepository.getSheetsBySpreadsheet(spreadsheetId);
      
      if (oldIndex < 0 || oldIndex >= sheets.length || newIndex < 0 || newIndex >= sheets.length) {
        return SheetOperationResult.failure(
          SheetOperationError.invalidPosition,
          'Invalid sheet position',
        );
      }

      // Reorder the sheets list
      final reorderedSheets = List<SheetEntity>.from(sheets);
      final movedSheet = reorderedSheets.removeAt(oldIndex);
      reorderedSheets.insert(newIndex, movedSheet);

      // Update positions
      for (int i = 0; i < reorderedSheets.length; i++) {
        final updatedSheet = reorderedSheets[i].copyWith(
          position: i,
          updatedAt: DateTime.now(),
        );
        reorderedSheets[i] = updatedSheet;
        await _sheetRepository.updateSheet(updatedSheet);
      }

      return SheetOperationResult.success(reorderedSheets);
      
    } catch (e) {
      return SheetOperationResult.failure(
        SheetOperationError.unknownError,
        'Failed to reorder sheets: $e',
      );
    }
  }

  /// Get sheet list for spreadsheet
  Future<SheetOperationResult<List<SheetEntity>>> getSheetList(String spreadsheetId) async {
    try {
      final sheets = await _sheetRepository.getSheetsBySpreadsheet(spreadsheetId);
      return SheetOperationResult.success(sheets);
      
    } catch (e) {
      return SheetOperationResult.failure(
        SheetOperationError.unknownError,
        'Failed to get sheet list: $e',
      );
    }
  }

  /// Reorder sheets after deletion (fix gaps in position)
  Future<void> _reorderSheetsAfterDeletion(String spreadsheetId, int deletedPosition) async {
    final remainingSheets = await _sheetRepository.getSheetsBySpreadsheet(spreadsheetId);
    
    // Update positions for sheets after the deleted one
    for (final sheet in remainingSheets) {
      if (sheet.position > deletedPosition) {
        final updatedSheet = sheet.copyWith(
          position: sheet.position - 1,
          updatedAt: DateTime.now(),
        );
        await _sheetRepository.updateSheet(updatedSheet);
      }
    }
  }
}

/// Result wrapper for sheet operations
class SheetOperationResult<T> {
  final bool isSuccess;
  final T? data;
  final SheetOperationError? error;
  final String? errorMessage;

  const SheetOperationResult.success(this.data)
      : isSuccess = true,
        error = null,
        errorMessage = null;

  const SheetOperationResult.failure(this.error, this.errorMessage)
      : isSuccess = false,
        data = null;
}

/// Sheet operation error types
enum SheetOperationError {
  sheetNotFound,
  invalidName,
  duplicateName,
  cannotDeleteLastSheet,
  invalidPosition,
  unknownError,
}