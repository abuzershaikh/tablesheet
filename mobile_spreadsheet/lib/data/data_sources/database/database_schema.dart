/// Database schema constants for the mobile spreadsheet application.
/// This file contains all table names, column definitions, and SQL statements
/// for creating and managing the SQLite database.

class DatabaseSchema {
  // Database configuration
  static const String databaseName = 'spreadsheet.db';
  static const int databaseVersion = 1;

  // Table names
  static const String tableSpreadsheets = 'spreadsheets';
  static const String tableSheets = 'sheets';
  static const String tableRows = 'rows';
  static const String tableColumns = 'columns';
  static const String tableCells = 'cells';

  // Spreadsheets table columns
  static const String spreadsheetId = 'id';
  static const String spreadsheetName = 'name';
  static const String spreadsheetCreatedAt = 'created_at';
  static const String spreadsheetUpdatedAt = 'updated_at';
  static const String spreadsheetThumbnail = 'thumbnail';

  // Sheets table columns
  static const String sheetId = 'id';
  static const String sheetSpreadsheetId = 'spreadsheet_id';
  static const String sheetName = 'name';
  static const String sheetPosition = 'position';
  static const String sheetCreatedAt = 'created_at';
  static const String sheetUpdatedAt = 'updated_at';

  // Rows table columns
  static const String rowId = 'id';
  static const String rowSheetId = 'sheet_id';
  static const String rowDisplayPosition = 'display_position';
  static const String rowHeight = 'height';
  static const String rowIsHidden = 'is_hidden';

  // Columns table columns
  static const String columnId = 'id';
  static const String columnSheetId = 'sheet_id';
  static const String columnDisplayPosition = 'display_position';
  static const String columnName = 'name';
  static const String columnWidth = 'width';
  static const String columnType = 'type';
  static const String columnIsHidden = 'is_hidden';

  // Cells table columns
  static const String cellId = 'id';
  static const String cellSheetId = 'sheet_id';
  static const String cellRowId = 'row_id';
  static const String cellColumnId = 'column_id';
  static const String cellValue = 'value';
  static const String cellFormula = 'formula';
  static const String cellType = 'type';
  static const String cellFormatBold = 'format_bold';
  static const String cellFormatItalic = 'format_italic';
  static const String cellFormatUnderline = 'format_underline';
  static const String cellFormatTextColor = 'format_text_color';
  static const String cellFormatBackgroundColor = 'format_background_color';
  static const String cellFormatAlignment = 'format_alignment';
  static const String cellFormatFontSize = 'format_font_size';
  static const String cellUpdatedAt = 'updated_at';

  /// SQL statement to create the spreadsheets table
  static const String createTableSpreadsheets = '''
    CREATE TABLE $tableSpreadsheets (
      $spreadsheetId TEXT PRIMARY KEY,
      $spreadsheetName TEXT NOT NULL,
      $spreadsheetCreatedAt INTEGER NOT NULL,
      $spreadsheetUpdatedAt INTEGER NOT NULL,
      $spreadsheetThumbnail TEXT
    );
  ''';

  /// SQL statement to create the sheets table
  static const String createTableSheets = '''
    CREATE TABLE $tableSheets (
      $sheetId TEXT PRIMARY KEY,
      $sheetSpreadsheetId TEXT NOT NULL,
      $sheetName TEXT NOT NULL,
      $sheetPosition INTEGER NOT NULL DEFAULT 0,
      $sheetCreatedAt INTEGER NOT NULL,
      $sheetUpdatedAt INTEGER NOT NULL,
      FOREIGN KEY ($sheetSpreadsheetId) REFERENCES $tableSpreadsheets($spreadsheetId) ON DELETE CASCADE
    );
  ''';

  /// SQL statement to create the rows table
  static const String createTableRows = '''
    CREATE TABLE $tableRows (
      $rowId TEXT PRIMARY KEY,
      $rowSheetId TEXT NOT NULL,
      $rowDisplayPosition INTEGER NOT NULL,
      $rowHeight REAL NOT NULL DEFAULT 40.0,
      $rowIsHidden INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY ($rowSheetId) REFERENCES $tableSheets($sheetId) ON DELETE CASCADE
    );
  ''';

  /// SQL statement to create the columns table
  static const String createTableColumns = '''
    CREATE TABLE $tableColumns (
      $columnId TEXT PRIMARY KEY,
      $columnSheetId TEXT NOT NULL,
      $columnDisplayPosition INTEGER NOT NULL,
      $columnName TEXT NOT NULL,
      $columnWidth REAL NOT NULL DEFAULT 120.0,
      $columnType TEXT NOT NULL DEFAULT 'text',
      $columnIsHidden INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY ($columnSheetId) REFERENCES $tableSheets($sheetId) ON DELETE CASCADE
    );
  ''';

  /// SQL statement to create the cells table
  static const String createTableCells = '''
    CREATE TABLE $tableCells (
      $cellId TEXT PRIMARY KEY,
      $cellSheetId TEXT NOT NULL,
      $cellRowId TEXT NOT NULL,
      $cellColumnId TEXT NOT NULL,
      $cellValue TEXT,
      $cellFormula TEXT,
      $cellType TEXT NOT NULL DEFAULT 'text',
      $cellFormatBold INTEGER NOT NULL DEFAULT 0,
      $cellFormatItalic INTEGER NOT NULL DEFAULT 0,
      $cellFormatUnderline INTEGER NOT NULL DEFAULT 0,
      $cellFormatTextColor TEXT,
      $cellFormatBackgroundColor TEXT,
      $cellFormatAlignment TEXT DEFAULT 'left',
      $cellFormatFontSize REAL DEFAULT 14.0,
      $cellUpdatedAt INTEGER NOT NULL,
      FOREIGN KEY ($cellSheetId) REFERENCES $tableSheets($sheetId) ON DELETE CASCADE,
      FOREIGN KEY ($cellRowId) REFERENCES $tableRows($rowId) ON DELETE CASCADE,
      FOREIGN KEY ($cellColumnId) REFERENCES $tableColumns($columnId) ON DELETE CASCADE
    );
  ''';

  // Index creation statements for optimized queries
  
  /// Index for quick cell lookup by sheet and position
  static const String indexCellsBySheetRowCol = '''
    CREATE INDEX idx_cells_sheet_row_col 
    ON $tableCells($cellSheetId, $cellRowId, $cellColumnId);
  ''';

  /// Index for quick cell lookup by sheet
  static const String indexCellsBySheet = '''
    CREATE INDEX idx_cells_sheet 
    ON $tableCells($cellSheetId);
  ''';

  /// Index for sheets by spreadsheet
  static const String indexSheetsBySpreadsheet = '''
    CREATE INDEX idx_sheets_spreadsheet 
    ON $tableSheets($sheetSpreadsheetId);
  ''';

  /// Index for rows by sheet
  static const String indexRowsBySheet = '''
    CREATE INDEX idx_rows_sheet 
    ON $tableRows($rowSheetId, $rowDisplayPosition);
  ''';

  /// Index for columns by sheet
  static const String indexColumnsBySheet = '''
    CREATE INDEX idx_columns_sheet 
    ON $tableColumns($columnSheetId, $columnDisplayPosition);
  ''';

  /// Get all create table statements
  static List<String> get createTableStatements => [
        createTableSpreadsheets,
        createTableSheets,
        createTableRows,
        createTableColumns,
        createTableCells,
      ];

  /// Get all index creation statements
  static List<String> get createIndexStatements => [
        indexCellsBySheetRowCol,
        indexCellsBySheet,
        indexSheetsBySpreadsheet,
        indexRowsBySheet,
        indexColumnsBySheet,
      ];

  /// Get all drop table statements (for migration)
  static List<String> get dropTableStatements => [
        'DROP TABLE IF EXISTS $tableCells;',
        'DROP TABLE IF EXISTS $tableColumns;',
        'DROP TABLE IF EXISTS $tableRows;',
        'DROP TABLE IF EXISTS $tableSheets;',
        'DROP TABLE IF EXISTS $tableSpreadsheets;',
      ];
}
