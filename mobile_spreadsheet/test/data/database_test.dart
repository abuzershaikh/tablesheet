import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile_spreadsheet/data/data_sources/database/database_helper.dart';
import 'package:mobile_spreadsheet/data/data_sources/database/database_schema.dart';

void main() {
  // Initialize FFI for testing
  setUpAll(() {
    // Initialize ffi implementation
    sqfliteFfiInit();
    // Set global factory to use FFI
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper databaseHelper;

  setUp(() async {
    databaseHelper = DatabaseHelper();
    // Delete database before each test
    await databaseHelper.deleteDb();
  });

  tearDown(() async {
    // Clean up after each test
    await databaseHelper.close();
  });

  group('DatabaseHelper Tests', () {
    test('should create database successfully', () async {
      final db = await databaseHelper.database;
      expect(db, isNotNull);
      expect(db.isOpen, isTrue);
    });

    test('should have correct database version', () async {
      final version = await databaseHelper.getVersion();
      expect(version, equals(DatabaseSchema.databaseVersion));
    });

    test('should create all tables', () async {
      final db = await databaseHelper.database;

      // Query sqlite_master to get all tables
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;",
      );

      final tableNames = tables.map((t) => t['name'] as String).toList();

      expect(tableNames, contains(DatabaseSchema.tableSpreadsheets));
      expect(tableNames, contains(DatabaseSchema.tableSheets));
      expect(tableNames, contains(DatabaseSchema.tableRows));
      expect(tableNames, contains(DatabaseSchema.tableColumns));
      expect(tableNames, contains(DatabaseSchema.tableCells));
    });

    test('should create all indexes', () async {
      final db = await databaseHelper.database;

      // Query sqlite_master to get all indexes
      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' ORDER BY name;",
      );

      final indexNames = indexes.map((i) => i['name'] as String).toList();

      expect(indexNames, contains('idx_cells_sheet_row_col'));
      expect(indexNames, contains('idx_cells_sheet'));
      expect(indexNames, contains('idx_sheets_spreadsheet'));
      expect(indexNames, contains('idx_rows_sheet'));
      expect(indexNames, contains('idx_columns_sheet'));
    });

    test('should enable foreign key constraints', () async {
      final db = await databaseHelper.database;

      final result = await db.rawQuery('PRAGMA foreign_keys;');
      expect(result.first['foreign_keys'], equals(1));
    });

    test('should insert and query spreadsheet', () async {
      final db = await databaseHelper.database;

      final spreadsheetId = 'test-spreadsheet-1';
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert(DatabaseSchema.tableSpreadsheets, {
        DatabaseSchema.spreadsheetId: spreadsheetId,
        DatabaseSchema.spreadsheetName: 'Test Spreadsheet',
        DatabaseSchema.spreadsheetCreatedAt: now,
        DatabaseSchema.spreadsheetUpdatedAt: now,
      });

      final result = await db.query(
        DatabaseSchema.tableSpreadsheets,
        where: '${DatabaseSchema.spreadsheetId} = ?',
        whereArgs: [spreadsheetId],
      );

      expect(result.length, equals(1));
      expect(result.first[DatabaseSchema.spreadsheetName],
          equals('Test Spreadsheet'));
    });

    test('should cascade delete sheets when spreadsheet is deleted', () async {
      final db = await databaseHelper.database;

      final spreadsheetId = 'test-spreadsheet-1';
      final sheetId = 'test-sheet-1';
      final now = DateTime.now().millisecondsSinceEpoch;

      // Insert spreadsheet
      await db.insert(DatabaseSchema.tableSpreadsheets, {
        DatabaseSchema.spreadsheetId: spreadsheetId,
        DatabaseSchema.spreadsheetName: 'Test Spreadsheet',
        DatabaseSchema.spreadsheetCreatedAt: now,
        DatabaseSchema.spreadsheetUpdatedAt: now,
      });

      // Insert sheet
      await db.insert(DatabaseSchema.tableSheets, {
        DatabaseSchema.sheetId: sheetId,
        DatabaseSchema.sheetSpreadsheetId: spreadsheetId,
        DatabaseSchema.sheetName: 'Sheet 1',
        DatabaseSchema.sheetPosition: 0,
        DatabaseSchema.sheetCreatedAt: now,
        DatabaseSchema.sheetUpdatedAt: now,
      });

      // Verify sheet exists
      var sheets = await db.query(DatabaseSchema.tableSheets);
      expect(sheets.length, equals(1));

      // Delete spreadsheet
      await db.delete(
        DatabaseSchema.tableSpreadsheets,
        where: '${DatabaseSchema.spreadsheetId} = ?',
        whereArgs: [spreadsheetId],
      );

      // Verify sheet was cascade deleted
      sheets = await db.query(DatabaseSchema.tableSheets);
      expect(sheets.length, equals(0));
    });

    test('should cascade delete cells when sheet is deleted', () async {
      final db = await databaseHelper.database;

      final spreadsheetId = 'test-spreadsheet-1';
      final sheetId = 'test-sheet-1';
      final rowId = 'test-row-1';
      final columnId = 'test-column-1';
      final cellId = 'test-cell-1';
      final now = DateTime.now().millisecondsSinceEpoch;

      // Insert spreadsheet
      await db.insert(DatabaseSchema.tableSpreadsheets, {
        DatabaseSchema.spreadsheetId: spreadsheetId,
        DatabaseSchema.spreadsheetName: 'Test Spreadsheet',
        DatabaseSchema.spreadsheetCreatedAt: now,
        DatabaseSchema.spreadsheetUpdatedAt: now,
      });

      // Insert sheet
      await db.insert(DatabaseSchema.tableSheets, {
        DatabaseSchema.sheetId: sheetId,
        DatabaseSchema.sheetSpreadsheetId: spreadsheetId,
        DatabaseSchema.sheetName: 'Sheet 1',
        DatabaseSchema.sheetPosition: 0,
        DatabaseSchema.sheetCreatedAt: now,
        DatabaseSchema.sheetUpdatedAt: now,
      });

      // Insert row
      await db.insert(DatabaseSchema.tableRows, {
        DatabaseSchema.rowId: rowId,
        DatabaseSchema.rowSheetId: sheetId,
        DatabaseSchema.rowDisplayPosition: 0,
        DatabaseSchema.rowHeight: 40.0,
        DatabaseSchema.rowIsHidden: 0,
      });

      // Insert column
      await db.insert(DatabaseSchema.tableColumns, {
        DatabaseSchema.columnId: columnId,
        DatabaseSchema.columnSheetId: sheetId,
        DatabaseSchema.columnDisplayPosition: 0,
        DatabaseSchema.columnName: 'A',
        DatabaseSchema.columnWidth: 120.0,
        DatabaseSchema.columnType: 'text',
        DatabaseSchema.columnIsHidden: 0,
      });

      // Insert cell
      await db.insert(DatabaseSchema.tableCells, {
        DatabaseSchema.cellId: cellId,
        DatabaseSchema.cellSheetId: sheetId,
        DatabaseSchema.cellRowId: rowId,
        DatabaseSchema.cellColumnId: columnId,
        DatabaseSchema.cellValue: 'Test Value',
        DatabaseSchema.cellType: 'text',
        DatabaseSchema.cellUpdatedAt: now,
      });

      // Verify cell exists
      var cells = await db.query(DatabaseSchema.tableCells);
      expect(cells.length, equals(1));

      // Delete sheet
      await db.delete(
        DatabaseSchema.tableSheets,
        where: '${DatabaseSchema.sheetId} = ?',
        whereArgs: [sheetId],
      );

      // Verify cell was cascade deleted
      cells = await db.query(DatabaseSchema.tableCells);
      expect(cells.length, equals(0));
    });

    test('should execute batch operations in transaction', () async {
      final spreadsheetId = 'test-spreadsheet-1';
      final now = DateTime.now().millisecondsSinceEpoch;

      await databaseHelper.executeBatch((batch) async {
        batch.insert(DatabaseSchema.tableSpreadsheets, {
          DatabaseSchema.spreadsheetId: spreadsheetId,
          DatabaseSchema.spreadsheetName: 'Test Spreadsheet',
          DatabaseSchema.spreadsheetCreatedAt: now,
          DatabaseSchema.spreadsheetUpdatedAt: now,
        });

        batch.insert(DatabaseSchema.tableSheets, {
          DatabaseSchema.sheetId: 'sheet-1',
          DatabaseSchema.sheetSpreadsheetId: spreadsheetId,
          DatabaseSchema.sheetName: 'Sheet 1',
          DatabaseSchema.sheetPosition: 0,
          DatabaseSchema.sheetCreatedAt: now,
          DatabaseSchema.sheetUpdatedAt: now,
        });

        batch.insert(DatabaseSchema.tableSheets, {
          DatabaseSchema.sheetId: 'sheet-2',
          DatabaseSchema.sheetSpreadsheetId: spreadsheetId,
          DatabaseSchema.sheetName: 'Sheet 2',
          DatabaseSchema.sheetPosition: 1,
          DatabaseSchema.sheetCreatedAt: now,
          DatabaseSchema.sheetUpdatedAt: now,
        });
      });

      final db = await databaseHelper.database;
      final sheets = await db.query(DatabaseSchema.tableSheets);
      expect(sheets.length, equals(2));
    });

    test('should perform complex query with joins', () async {
      final db = await databaseHelper.database;

      final spreadsheetId = 'test-spreadsheet-1';
      final sheetId = 'test-sheet-1';
      final rowId = 'test-row-1';
      final columnId = 'test-column-1';
      final cellId = 'test-cell-1';
      final now = DateTime.now().millisecondsSinceEpoch;

      // Insert test data
      await db.insert(DatabaseSchema.tableSpreadsheets, {
        DatabaseSchema.spreadsheetId: spreadsheetId,
        DatabaseSchema.spreadsheetName: 'Test Spreadsheet',
        DatabaseSchema.spreadsheetCreatedAt: now,
        DatabaseSchema.spreadsheetUpdatedAt: now,
      });

      await db.insert(DatabaseSchema.tableSheets, {
        DatabaseSchema.sheetId: sheetId,
        DatabaseSchema.sheetSpreadsheetId: spreadsheetId,
        DatabaseSchema.sheetName: 'Sheet 1',
        DatabaseSchema.sheetPosition: 0,
        DatabaseSchema.sheetCreatedAt: now,
        DatabaseSchema.sheetUpdatedAt: now,
      });

      await db.insert(DatabaseSchema.tableRows, {
        DatabaseSchema.rowId: rowId,
        DatabaseSchema.rowSheetId: sheetId,
        DatabaseSchema.rowDisplayPosition: 0,
      });

      await db.insert(DatabaseSchema.tableColumns, {
        DatabaseSchema.columnId: columnId,
        DatabaseSchema.columnSheetId: sheetId,
        DatabaseSchema.columnDisplayPosition: 0,
        DatabaseSchema.columnName: 'A',
      });

      await db.insert(DatabaseSchema.tableCells, {
        DatabaseSchema.cellId: cellId,
        DatabaseSchema.cellSheetId: sheetId,
        DatabaseSchema.cellRowId: rowId,
        DatabaseSchema.cellColumnId: columnId,
        DatabaseSchema.cellValue: 'Test Value',
        DatabaseSchema.cellType: 'text',
        DatabaseSchema.cellUpdatedAt: now,
      });

      // Perform join query
      final result = await db.rawQuery('''
        SELECT c.*, r.${DatabaseSchema.rowDisplayPosition}, col.${DatabaseSchema.columnDisplayPosition}
        FROM ${DatabaseSchema.tableCells} c
        INNER JOIN ${DatabaseSchema.tableRows} r ON c.${DatabaseSchema.cellRowId} = r.${DatabaseSchema.rowId}
        INNER JOIN ${DatabaseSchema.tableColumns} col ON c.${DatabaseSchema.cellColumnId} = col.${DatabaseSchema.columnId}
        WHERE c.${DatabaseSchema.cellSheetId} = ?
      ''', [sheetId]);

      expect(result.length, equals(1));
      expect(result.first[DatabaseSchema.cellValue], equals('Test Value'));
      expect(result.first[DatabaseSchema.rowDisplayPosition], equals(0));
    });
  });
}
