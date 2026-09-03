import 'package:sqflite/sqflite.dart';
import 'database/database_helper.dart';
import 'database/database_schema.dart';
import '../models/cell_model.dart';
import '../models/sheet_model.dart';
import '../models/spreadsheet_model.dart';
import '../models/row_model.dart';
import '../models/column_model.dart';

/// Local data source for SQLite database operations
class LocalDataSource {
  final DatabaseHelper _databaseHelper;

  LocalDataSource(this._databaseHelper);

  // Cell operations
  
  /// Query single cell by address
  Future<CellModel?> queryCellByAddress(
    String sheetId,
    String rowId,
    String columnId,
  ) async {
    final db = await _databaseHelper.database;
    
    final results = await db.query(
      DatabaseSchema.tableCells,
      where: '${DatabaseSchema.cellSheetId} = ? AND ${DatabaseSchema.cellRowId} = ? AND ${DatabaseSchema.cellColumnId} = ?',
      whereArgs: [sheetId, rowId, columnId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return CellModel.fromMap(results.first);
  }

  /// Batch update cells in a transaction
  Future<void> batchUpdateCells(List<CellModel> cells) async {
    final db = await _databaseHelper.database;
    
    await db.transaction((txn) async {
      final batch = txn.batch();
      
      for (final cell in cells) {
        batch.insert(
          DatabaseSchema.tableCells,
          cell.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      await batch.commit(noResult: true);
    });
  }

  /// Query cell range
  Future<List<CellModel>> queryCellRange(
    String sheetId,
    int startRow,
    int endRow,
    int startCol,
    int endCol,
  ) async {
    final db = await _databaseHelper.database;
    
    final results = await db.rawQuery('''
      SELECT c.* FROM ${DatabaseSchema.tableCells} c
      INNER JOIN ${DatabaseSchema.tableRows} r ON c.${DatabaseSchema.cellRowId} = r.${DatabaseSchema.rowId}
      INNER JOIN ${DatabaseSchema.tableColumns} col ON c.${DatabaseSchema.cellColumnId} = col.${DatabaseSchema.columnId}
      WHERE c.${DatabaseSchema.cellSheetId} = ? 
      AND r.${DatabaseSchema.rowDisplayPosition} >= ? 
      AND r.${DatabaseSchema.rowDisplayPosition} <= ?
      AND col.${DatabaseSchema.columnDisplayPosition} >= ?
      AND col.${DatabaseSchema.columnDisplayPosition} <= ?
      ORDER BY r.${DatabaseSchema.rowDisplayPosition}, col.${DatabaseSchema.columnDisplayPosition}
    ''', [sheetId, startRow, endRow, startCol, endCol]);

    return results.map((map) => CellModel.fromMap(map)).toList();
  }

  /// Insert or update single cell
  Future<void> insertOrUpdateCell(CellModel cell) async {
    final db = await _databaseHelper.database;
    
    await db.insert(
      DatabaseSchema.tableCells,
      cell.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Delete cell
  Future<void> deleteCell(String cellId) async {
    final db = await _databaseHelper.database;
    
    await db.delete(
      DatabaseSchema.tableCells,
      where: '${DatabaseSchema.cellId} = ?',
      whereArgs: [cellId],
    );
  }

  /// Get all cells in sheet
  Future<List<CellModel>> getCellsBySheet(String sheetId) async {
    final db = await _databaseHelper.database;
    
    final results = await db.query(
      DatabaseSchema.tableCells,
      where: '${DatabaseSchema.cellSheetId} = ?',
      whereArgs: [sheetId],
    );

    return results.map((map) => CellModel.fromMap(map)).toList();
  }

  // Sheet operations

  /// Create new sheet
  Future<void> createSheet(SheetModel sheet) async {
    final db = await _databaseHelper.database;
    
    await db.insert(
      DatabaseSchema.tableSheets,
      sheet.toMap(),
    );
  }

  /// Delete sheet
  Future<void> deleteSheet(String sheetId) async {
    final db = await _databaseHelper.database;
    
    await db.delete(
      DatabaseSchema.tableSheets,
      where: '${DatabaseSchema.sheetId} = ?',
      whereArgs: [sheetId],
    );
  }

  /// Update sheet
  Future<void> updateSheet(SheetModel sheet) async {
    final db = await _databaseHelper.database;
    
    await db.update(
      DatabaseSchema.tableSheets,
      sheet.toMap(),
      where: '${DatabaseSchema.sheetId} = ?',
      whereArgs: [sheet.id],
    );
  }

  /// Get sheets by spreadsheet
  Future<List<SheetModel>> getSheetsBySpreadsheet(String spreadsheetId) async {
    final db = await _databaseHelper.database;
    
    final results = await db.query(
      DatabaseSchema.tableSheets,
      where: '${DatabaseSchema.sheetSpreadsheetId} = ?',
      whereArgs: [spreadsheetId],
      orderBy: DatabaseSchema.sheetPosition,
    );

    return results.map((map) => SheetModel.fromMap(map)).toList();
  }

  // Spreadsheet operations

  /// Get all spreadsheets
  Future<List<SpreadsheetModel>> getAllSpreadsheets() async {
    final db = await _databaseHelper.database;
    
    final results = await db.query(
      DatabaseSchema.tableSpreadsheets,
      orderBy: '${DatabaseSchema.spreadsheetUpdatedAt} DESC',
    );

    return results.map((map) => SpreadsheetModel.fromMap(map)).toList();
  }

  /// Create spreadsheet
  Future<void> createSpreadsheet(SpreadsheetModel spreadsheet) async {
    final db = await _databaseHelper.database;
    
    await db.insert(
      DatabaseSchema.tableSpreadsheets,
      spreadsheet.toMap(),
    );
  }

  /// Update spreadsheet
  Future<void> updateSpreadsheet(SpreadsheetModel spreadsheet) async {
    final db = await _databaseHelper.database;
    
    await db.update(
      DatabaseSchema.tableSpreadsheets,
      spreadsheet.toMap(),
      where: '${DatabaseSchema.spreadsheetId} = ?',
      whereArgs: [spreadsheet.id],
    );
  }

  /// Delete spreadsheet
  Future<void> deleteSpreadsheet(String spreadsheetId) async {
    final db = await _databaseHelper.database;
    
    await db.transaction((txn) async {
      // Find all sheet IDs for this spreadsheet
      final sheets = await txn.query(
        DatabaseSchema.tableSheets,
        columns: [DatabaseSchema.sheetId],
        where: '${DatabaseSchema.sheetSpreadsheetId} = ?',
        whereArgs: [spreadsheetId],
      );

      for (var sheet in sheets) {
        final sheetId = sheet[DatabaseSchema.sheetId];
        // Delete cells
        await txn.delete(
          DatabaseSchema.tableCells,
          where: '${DatabaseSchema.cellSheetId} = ?',
          whereArgs: [sheetId],
        );
        // Delete columns
        await txn.delete(
          DatabaseSchema.tableColumns,
          where: '${DatabaseSchema.columnSheetId} = ?',
          whereArgs: [sheetId],
        );
        // Delete rows
        await txn.delete(
          DatabaseSchema.tableRows,
          where: '${DatabaseSchema.rowSheetId} = ?',
          whereArgs: [sheetId],
        );
      }

      // Delete sheets
      await txn.delete(
        DatabaseSchema.tableSheets,
        where: '${DatabaseSchema.sheetSpreadsheetId} = ?',
        whereArgs: [spreadsheetId],
      );

      // Delete spreadsheet
      await txn.delete(
        DatabaseSchema.tableSpreadsheets,
        where: '${DatabaseSchema.spreadsheetId} = ?',
        whereArgs: [spreadsheetId],
      );
    });
  }

  /// Get spreadsheet by ID
  Future<SpreadsheetModel?> getSpreadsheetById(String id) async {
    final db = await _databaseHelper.database;
    
    final results = await db.query(
      DatabaseSchema.tableSpreadsheets,
      where: '${DatabaseSchema.spreadsheetId} = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return SpreadsheetModel.fromMap(results.first);
  }

  // Row operations

  /// Create row
  Future<void> createRow(RowModel row) async {
    final db = await _databaseHelper.database;
    
    await db.insert(
      DatabaseSchema.tableRows,
      row.toMap(),
    );
  }

  /// Update row
  Future<void> updateRow(RowModel row) async {
    final db = await _databaseHelper.database;
    
    await db.update(
      DatabaseSchema.tableRows,
      row.toMap(),
      where: '${DatabaseSchema.rowId} = ?',
      whereArgs: [row.id],
    );
  }

  /// Delete row
  Future<void> deleteRow(String rowId) async {
    final db = await _databaseHelper.database;
    
    await db.delete(
      DatabaseSchema.tableRows,
      where: '${DatabaseSchema.rowId} = ?',
      whereArgs: [rowId],
    );
  }

  /// Get rows by sheet
  Future<List<RowModel>> getRowsBySheet(String sheetId) async {
    final db = await _databaseHelper.database;
    
    final results = await db.query(
      DatabaseSchema.tableRows,
      where: '${DatabaseSchema.rowSheetId} = ?',
      whereArgs: [sheetId],
      orderBy: DatabaseSchema.rowDisplayPosition,
    );

    return results.map((map) => RowModel.fromMap(map)).toList();
  }

  // Column operations

  /// Create column
  Future<void> createColumn(ColumnModel column) async {
    final db = await _databaseHelper.database;
    
    await db.insert(
      DatabaseSchema.tableColumns,
      column.toMap(),
    );
  }

  /// Update column
  Future<void> updateColumn(ColumnModel column) async {
    final db = await _databaseHelper.database;
    
    await db.update(
      DatabaseSchema.tableColumns,
      column.toMap(),
      where: '${DatabaseSchema.columnId} = ?',
      whereArgs: [column.id],
    );
  }

  /// Delete column
  Future<void> deleteColumn(String columnId) async {
    final db = await _databaseHelper.database;
    
    await db.delete(
      DatabaseSchema.tableColumns,
      where: '${DatabaseSchema.columnId} = ?',
      whereArgs: [columnId],
    );
  }

  /// Get columns by sheet
  Future<List<ColumnModel>> getColumnsBySheet(String sheetId) async {
    final db = await _databaseHelper.database;
    
    final results = await db.query(
      DatabaseSchema.tableColumns,
      where: '${DatabaseSchema.columnSheetId} = ?',
      whereArgs: [sheetId],
      orderBy: DatabaseSchema.columnDisplayPosition,
    );

    return results.map((map) => ColumnModel.fromMap(map)).toList();
  }
}