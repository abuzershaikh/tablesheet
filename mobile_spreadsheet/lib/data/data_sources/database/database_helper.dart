import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'database_schema.dart';

/// DatabaseHelper - Singleton class for managing SQLite database operations
/// This class handles database creation, version management, and provides
/// a database instance for all data operations.
class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;

  // Private constructor for singleton pattern
  DatabaseHelper._internal();

  /// Get singleton instance of DatabaseHelper
  factory DatabaseHelper() {
    _instance ??= DatabaseHelper._internal();
    return _instance!;
  }

  /// Get database instance, create if not exists
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    // Get the database path
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, DatabaseSchema.databaseName);

    // Open/create the database
    return await openDatabase(
      path,
      version: DatabaseSchema.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  /// Configure database settings (called before onCreate/onUpgrade)
  Future<void> _onConfigure(Database db) async {
    // Enable foreign key constraints
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  /// Create database tables and indexes
  Future<void> _onCreate(Database db, int version) async {
    // Execute all table creation statements
    for (final statement in DatabaseSchema.createTableStatements) {
      await db.execute(statement);
    }

    // Execute all index creation statements
    for (final statement in DatabaseSchema.createIndexStatements) {
      await db.execute(statement);
    }

    print('Database created successfully with version $version');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Upgrading database from version $oldVersion to $newVersion');

    // Drop all existing tables
    for (final statement in DatabaseSchema.dropTableStatements) {
      await db.execute(statement);
    }

    // Recreate all tables and indexes
    await _onCreate(db, newVersion);
  }

  /// Close the database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Delete the database (useful for testing)
  Future<void> deleteDb() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, DatabaseSchema.databaseName);
    await deleteDatabase(path);
    _database = null;
  }

  /// Execute raw query (for testing and debugging)
  Future<List<Map<String, dynamic>>> rawQuery(String query,
      [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawQuery(query, arguments);
  }

  /// Execute raw insert/update/delete (for testing and debugging)
  Future<int> rawExecute(String query, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawUpdate(query, arguments);
  }

  /// Get database path (useful for debugging)
  Future<String> getDatabasePath() async {
    final databasesPath = await getDatabasesPath();
    return join(databasesPath, DatabaseSchema.databaseName);
  }

  /// Check if database exists
  Future<bool> databaseExists() async {
    final path = await getDatabasePath();
    return await databaseFactory.databaseExists(path);
  }

  /// Execute a batch of operations in a transaction
  Future<List<Object?>> executeBatch(
    Future<void> Function(Batch batch) operations,
  ) async {
    final db = await database;
    final batch = db.batch();
    await operations(batch);
    return await batch.commit(noResult: false);
  }

  /// Execute operations in a transaction
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action,
  ) async {
    final db = await database;
    return await db.transaction(action);
  }

  /// Get database version
  Future<int> getVersion() async {
    final db = await database;
    return await db.getVersion();
  }

  /// Vacuum database (optimize storage)
  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM;');
  }

  /// Get database size in bytes
  Future<int> getDatabaseSize() async {
    final path = await getDatabasePath();
    final file = await databaseFactory.databaseExists(path);
    if (!file) return 0;
    // Note: Getting actual file size requires dart:io which may not be available
    // This is a placeholder - actual implementation should use File class
    return 0;
  }
}
