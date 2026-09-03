import '../entities/cell_entity.dart';

/// Abstract repository interface for cell operations
abstract class CellRepository {
  /// Get cell by address
  Future<CellEntity?> getCellByAddress(String sheetId, String rowId, String columnId);
  
  /// Get cells in range
  Future<List<CellEntity>> getCellRange(String sheetId, int startRow, int endRow, int startCol, int endCol);
  
  /// Get all cells in sheet
  Future<List<CellEntity>> getCellsBySheet(String sheetId);
  
  /// Insert or update cell
  Future<void> saveCell(CellEntity cell);
  
  /// Batch save cells
  Future<void> saveCells(List<CellEntity> cells);
  
  /// Delete cell
  Future<void> deleteCell(String cellId);
  
  /// Clear cache
  void clearCache();
}