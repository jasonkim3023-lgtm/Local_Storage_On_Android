// Activity 09 - Local Storage, Part II
// The single place that opens the database and owns the schema.
//
// Version history
//   v1  Part I (Activity 08): one table, my_table (_id, name, age).
//   v2  Part II: adds folders, cards and idx_cards_folder_id. my_table and its
//       rows are left exactly as they were.

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  // ------------------------------------------------- unchanged from Part I

  /// Same filename as Part I, so the same file is opened and upgraded.
  static const String databaseFileName = 'MyDatabase.db';

  /// The version the Part I app shipped with.
  static const int partOneVersion = 1;

  /// The Part I table and its columns.
  static const String partOneTable = 'my_table';
  static const String partOneColumnId = '_id';
  static const String partOneColumnName = 'name';
  static const String partOneColumnAge = 'age';

  /// The Part I CREATE TABLE statement, unchanged. Only used on a fresh
  /// install (onCreate). The upgrade path never touches this table.
  static const String partOneCreateSql = '''
    CREATE TABLE $partOneTable (
      $partOneColumnId INTEGER PRIMARY KEY,
      $partOneColumnName TEXT NOT NULL,
      $partOneColumnAge INTEGER NOT NULL
    )
  ''';

  // ------------------------------------------------------- new in Part II

  /// Part II raises the version by exactly one.
  static const int databaseVersion = partOneVersion + 1;

  static const String tableFolders = 'folders';
  static const String tableCards = 'cards';

  Database? _db;
  Future<Database>? _opening;

  /// Opens the database once and reuses the connection. If opening fails, the
  /// failure is not cached, so the caller can try again.
  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;

    final opening = _opening ??= _open();
    try {
      final db = await opening;
      _db = db;
      return db;
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<Database> _open() async {
    // Part I stored the file in the app's documents directory, so Part II
    // must look in the same place to find the existing database.
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = p.join(documentsDirectory.path, databaseFileName);

    return openDatabase(
      path,
      version: databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Runs on every open, before onCreate / onUpgrade. Without this pragma the
  /// ON DELETE CASCADE rule is declared but silently not enforced.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Fresh install: build the complete schema (Part I table + Part II tables).
  ///
  /// sqflite runs onCreate and onUpgrade inside one transaction, so if any
  /// statement below fails, nothing is kept and the version is not raised.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute(partOneCreateSql);
    await _createCatalogueSchema(db);
    await _seedCatalogue(db);
  }

  /// Existing Part I install: add only what is new. Nothing here drops,
  /// renames or rewrites my_table.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < databaseVersion) {
      await _createCatalogueSchema(db);
      await _seedCatalogue(db);
    }
    // A future version 3 gets its own "if (oldVersion < 3)" block here.
  }

  /// The version 2 additions. Used by both paths so they end up identical.
  Future<void> _createCatalogueSchema(Database db) async {
    await db.execute('''
      CREATE TABLE $tableFolders (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableCards (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        title     TEXT NOT NULL,
        suit      TEXT NOT NULL,
        notes     TEXT NOT NULL DEFAULT '',
        image_ref TEXT,
        folder_id INTEGER NOT NULL,
        FOREIGN KEY (folder_id) REFERENCES $tableFolders(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_cards_folder_id ON $tableCards(folder_id)',
    );
  }

  /// Sample data, inserted exactly once: only when the tables are created.
  /// Each card uses the ID returned by its folder insert, never a guessed 1-4.
  Future<void> _seedCatalogue(Database db) async {
    const suits = ['Spades', 'Hearts', 'Diamonds', 'Clubs'];
    final now = DateTime.now().toIso8601String();

    for (final suit in suits) {
      final folderId = await db.insert(tableFolders, {
        'name': suit,
        'created_at': now,
      });

      await db.insert(tableCards, {
        'title': 'Ace of $suit',
        'suit': suit,
        'notes': 'Sample card',
        'image_ref': null,
        'folder_id': folderId,
      });
    }
  }
}
