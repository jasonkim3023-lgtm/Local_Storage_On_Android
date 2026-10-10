// Read-only access to the Part I table, used to show that its rows survived
// the version 2 upgrade. Nothing in this file writes to the database.

import 'database_helper.dart';

/// What the Part I tab displays: the schema version, the tables that exist,
/// and every row of the Part I table.
class PartOneSnapshot {
  const PartOneSnapshot({
    required this.schemaVersion,
    required this.tableName,
    required this.tableExists,
    required this.allTables,
    required this.rows,
  });

  final int schemaVersion;
  final String tableName;
  final bool tableExists;
  final List<String> allTables;
  final List<Map<String, Object?>> rows;
}

class PartOneRepository {
  PartOneRepository(this._helper);

  final DatabaseHelper _helper;

  Future<PartOneSnapshot> load() async {
    final db = await _helper.database;
    const table = DatabaseHelper.partOneTable;

    // PRAGMA user_version is where SQLite stores the schema version number.
    final versionRows = await db.rawQuery('PRAGMA user_version');
    final version = versionRows.isEmpty
        ? 0
        : (versionRows.first['user_version'] as int?) ?? 0;

    final tableRows = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: 'type = ? AND name NOT LIKE ? AND name != ?',
      whereArgs: ['table', 'sqlite_%', 'android_metadata'],
      orderBy: 'name ASC',
    );
    final allTables = tableRows.map((row) => row['name'] as String).toList();

    final exists = allTables.contains(table);
    final rows = exists ? await db.query(table) : <Map<String, Object?>>[];

    return PartOneSnapshot(
      schemaVersion: version,
      tableName: table,
      tableExists: exists,
      allTables: allTables,
      rows: rows,
    );
  }
}
