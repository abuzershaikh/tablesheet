import '../entities/spreadsheet_entity.dart';

/// Abstract repository interface for spreadsheet operations
abstract class SpreadsheetRepository {
  /// Get all spreadsheets
  Future<List<SpreadsheetEntity>> getAllSpreadsheets();
  
  /// Get spreadsheet by ID
  Future<SpreadsheetEntity?> getSpreadsheetById(String id);
  
  /// Create new spreadsheet
  Future<void> createSpreadsheet(SpreadsheetEntity spreadsheet);
  
  /// Update spreadsheet
  Future<void> updateSpreadsheet(SpreadsheetEntity spreadsheet);
  
  /// Delete spreadsheet
  Future<void> deleteSpreadsheet(String id);
}