import '../entities/sheet_entity.dart';

/// Abstract repository interface for sheet operations
abstract class SheetRepository {
  /// Get all sheets in spreadsheet
  Future<List<SheetEntity>> getSheetsBySpreadsheet(String spreadsheetId);
  
  /// Get sheet by ID
  Future<SheetEntity?> getSheetById(String sheetId);
  
  /// Create new sheet
  Future<void> createSheet(SheetEntity sheet);
  
  /// Update sheet
  Future<void> updateSheet(SheetEntity sheet);
  
  /// Delete sheet
  Future<void> deleteSheet(String sheetId);
}