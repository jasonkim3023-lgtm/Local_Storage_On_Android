// All folder and card SQL lives here. Screens call these methods and get
// model objects back; they never see a SQL string.
//
// Every value that comes from the user is bound with whereArgs / a values map,
// never joined into a SQL string.

import 'package:sqflite/sqflite.dart';

import '../models/folder.dart';
import '../models/playing_card.dart';
import 'database_helper.dart';

/// A problem the user can understand and fix (bad input, duplicate name,
/// missing row). Screens show [message] as-is.
class RepositoryException implements Exception {
  const RepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CardRepository {
  CardRepository(this._helper);

  final DatabaseHelper _helper;

  static const String _folders = DatabaseHelper.tableFolders;
  static const String _cards = DatabaseHelper.tableCards;

  // ---------------------------------------------------------------- folders

  /// Every folder with the number of cards inside it, in one query.
  /// LEFT JOIN keeps folders that have zero cards.
  Future<List<Folder>> getFoldersWithCounts() async {
    final db = await _helper.database;
    final rows = await db.rawQuery('''
      SELECT f.id, f.name, f.created_at, COUNT(c.id) AS card_count
      FROM $_folders f
      LEFT JOIN $_cards c ON c.folder_id = f.id
      GROUP BY f.id
      ORDER BY f.name COLLATE NOCASE ASC
    ''');
    return rows.map(Folder.fromMap).toList();
  }

  /// Returns the new folder's ID.
  Future<int> insertFolder(String name) async {
    final cleanName = _cleanFolderName(name);
    final db = await _helper.database;
    try {
      return await db.insert(_folders, {
        'name': cleanName,
        'created_at': DateTime.now().toIso8601String(),
      });
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw RepositoryException('A folder named "$cleanName" already exists.');
      }
      rethrow;
    }
  }

  /// Returns the number of rows changed. 0 means no folder has that ID.
  Future<int> renameFolder(int id, String name) async {
    final cleanName = _cleanFolderName(name);
    final db = await _helper.database;
    try {
      return await db.update(
        _folders,
        {'name': cleanName},
        where: 'id = ?',
        whereArgs: [id],
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw RepositoryException('A folder named "$cleanName" already exists.');
      }
      rethrow;
    }
  }

  /// Deletes one folder by ID. Its cards are removed by the schema's
  /// ON DELETE CASCADE rule (foreign keys are switched on in onConfigure).
  /// Returns the number of folders deleted. 0 means no folder has that ID.
  Future<int> deleteFolder(int id) async {
    final db = await _helper.database;
    return db.delete(_folders, where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------------ cards

  /// Only the cards whose folder_id matches [folderId].
  Future<List<PlayingCard>> getCards(int folderId) async {
    final db = await _helper.database;
    final rows = await db.query(
      _cards,
      where: 'folder_id = ?',
      whereArgs: [folderId],
      orderBy: 'title COLLATE NOCASE ASC',
    );
    return rows.map(PlayingCard.fromMap).toList();
  }

  /// Returns the new card's ID.
  Future<int> insertCard(PlayingCard card) async {
    final clean = _validated(card);
    final db = await _helper.database;
    await _requireFolder(db, clean.folderId);
    try {
      return await db.insert(_cards, clean.toMap());
    } on DatabaseException catch (e) {
      throw RepositoryException('The card could not be saved: $e');
    }
  }

  /// Updates the card whose ID is [card.id]. Returns the number of rows
  /// changed. 0 means no card has that ID.
  Future<int> updateCard(PlayingCard card) async {
    final id = card.id;
    if (id == null) {
      throw const RepositoryException('This card has no ID, so it cannot be updated.');
    }
    final clean = _validated(card);
    final db = await _helper.database;
    await _requireFolder(db, clean.folderId);
    try {
      return await db.update(
        _cards,
        clean.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
    } on DatabaseException catch (e) {
      throw RepositoryException('The card could not be saved: $e');
    }
  }

  /// Returns the number of cards deleted. 0 means no card has that ID.
  Future<int> deleteCard(int id) async {
    final db = await _helper.database;
    return db.delete(_cards, where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------- helpers

  String _cleanFolderName(String name) {
    final clean = name.trim();
    if (clean.isEmpty) {
      throw const RepositoryException('Enter a folder name.');
    }
    return clean;
  }

  /// Trims the input and rejects anything the form should not have let
  /// through. Nothing is written if this throws.
  PlayingCard _validated(PlayingCard card) {
    final title = card.title.trim();
    if (title.isEmpty) {
      throw const RepositoryException('Enter a title.');
    }
    if (!Suits.isSupported(card.suit)) {
      throw RepositoryException('"${card.suit}" is not a supported suit.');
    }
    final imageRef = card.imageRef?.trim() ?? '';

    return PlayingCard(
      id: card.id,
      title: title,
      suit: card.suit,
      notes: card.notes.trim(),
      imageRef: imageRef.isEmpty ? null : imageRef,
      folderId: card.folderId,
    );
  }

  Future<void> _requireFolder(Database db, int folderId) async {
    final rows = await db.query(
      _folders,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [folderId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const RepositoryException('That folder no longer exists. Choose another folder.');
    }
  }
}
