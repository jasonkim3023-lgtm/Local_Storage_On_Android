// A parent row from the folders table.

class Folder {
  const Folder({
    required this.id,
    required this.name,
    required this.createdAt,
    this.cardCount = 0,
  });

  /// Primary key. Folders are always read back from the database, so this is
  /// never null.
  final int id;
  final String name;
  final DateTime createdAt;

  /// Not a column: filled in by the "folders with counts" query.
  final int cardCount;

  factory Folder.fromMap(Map<String, Object?> map) {
    return Folder(
      id: map['id'] as int,
      name: map['name'] as String,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      cardCount: (map['card_count'] as int?) ?? 0,
    );
  }

  /// Only real columns go back to the database (card_count is derived).
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
