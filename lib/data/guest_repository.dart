// Part I guest (roster) queries, moved here from the Part I DatabaseHelper.
// The SQL is the same as in Activity 08; only where it lives has changed, so
// the roster screen keeps working on the same my_table rows after the upgrade.

import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

class GuestRepository {
  GuestRepository(this._helper);

  final DatabaseHelper _helper;

  static const table = DatabaseHelper.partOneTable;
  static const columnId = DatabaseHelper.partOneColumnId;
  static const columnName = DatabaseHelper.partOneColumnName;
  static const columnAge = DatabaseHelper.partOneColumnAge;

  /// Inserts a row and returns the ID that SQLite generated for it.
  Future<int> insert(Map<String, dynamic> row) async {
    final db = await _helper.database;
    return db.insert(table, row);
  }

  /// Returns every row as a map, in ascending ID order.
  Future<List<Map<String, dynamic>>> queryAllRows() async {
    final db = await _helper.database;
    return db.query(table, orderBy: '$columnId ASC');
  }

  /// Returns the number of rows in the table.
  Future<int> queryRowCount() async {
    final db = await _helper.database;
    final results = await db.rawQuery('SELECT COUNT(*) FROM $table');
    return Sqflite.firstIntValue(results) ?? 0;
  }

  /// Updates the row whose _id matches the one in [row].
  /// Returns the number of rows affected.
  Future<int> update(Map<String, dynamic> row) async {
    final db = await _helper.database;
    final id = row[columnId] as int;
    return db.update(table, row, where: '$columnId = ?', whereArgs: [id]);
  }

  /// Deletes the row with the given ID. Returns the number of rows affected.
  Future<int> delete(int id) async {
    final db = await _helper.database;
    return db.delete(table, where: '$columnId = ?', whereArgs: [id]);
  }
}
