// A child row from the cards table.
//
// The assignment calls this model "Card". It is named PlayingCard here because
// Flutter's material library already has a widget called Card, and two classes
// with the same name in one file will not compile.

/// The suit values the app accepts.
class Suits {
  const Suits._();

  static const List<String> values = ['Spades', 'Hearts', 'Diamonds', 'Clubs'];

  static bool isSupported(String suit) => values.contains(suit);

  static String symbol(String suit) {
    switch (suit) {
      case 'Spades':
        return '♠';
      case 'Hearts':
        return '♥';
      case 'Diamonds':
        return '♦';
      case 'Clubs':
        return '♣';
      default:
        return '?';
    }
  }

  static bool isRed(String suit) => suit == 'Hearts' || suit == 'Diamonds';
}

class PlayingCard {
  const PlayingCard({
    this.id,
    required this.title,
    required this.suit,
    this.notes = '',
    this.imageRef,
    required this.folderId,
  });

  /// Primary key. Null only for a card that has not been inserted yet.
  final int? id;
  final String title;
  final String suit;
  final String notes;

  /// Where the picture lives (asset path or URL), not the picture itself.
  /// Null means "no image": the UI shows the suit placeholder.
  final String? imageRef;

  /// Foreign key: the ID of the folder this card belongs to.
  final int folderId;

  factory PlayingCard.fromMap(Map<String, Object?> map) {
    return PlayingCard(
      id: map['id'] as int?,
      title: map['title'] as String,
      suit: map['suit'] as String,
      notes: (map['notes'] as String?) ?? '',
      imageRef: map['image_ref'] as String?,
      folderId: map['folder_id'] as int,
    );
  }

  /// The ID is left out so SQLite assigns it on insert, and so an update can
  /// never change a row's primary key.
  Map<String, Object?> toMap() {
    return {
      'title': title,
      'suit': suit,
      'notes': notes,
      'image_ref': imageRef,
      'folder_id': folderId,
    };
  }
}
