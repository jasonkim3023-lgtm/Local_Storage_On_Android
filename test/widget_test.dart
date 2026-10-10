// Unit tests for the model classes. These check the row <-> object conversion
// and need no database or emulator, so they run with: flutter test

import 'package:flutter_test/flutter_test.dart';
import 'package:inclass09/models/folder.dart';
import 'package:inclass09/models/playing_card.dart';

void main() {
  test('PlayingCard is built from a database row', () {
    final card = PlayingCard.fromMap({
      'id': 5,
      'title': 'Two of Hearts',
      'suit': 'Hearts',
      'notes': 'test note',
      'image_ref': null,
      'folder_id': 3,
    });

    expect(card.id, 5);
    expect(card.title, 'Two of Hearts');
    expect(card.suit, 'Hearts');
    expect(card.notes, 'test note');
    expect(card.imageRef, isNull);
    expect(card.folderId, 3);
  });

  test('PlayingCard.toMap leaves out the id and keeps the foreign key', () {
    const card = PlayingCard(
      id: 9,
      title: 'King of Clubs',
      suit: 'Clubs',
      folderId: 4,
    );

    final map = card.toMap();

    expect(map.containsKey('id'), isFalse);
    expect(map['title'], 'King of Clubs');
    expect(map['suit'], 'Clubs');
    expect(map['notes'], '');
    expect(map['image_ref'], isNull);
    expect(map['folder_id'], 4);
  });

  test('Folder reads the card count from the joined query', () {
    final folder = Folder.fromMap({
      'id': 1,
      'name': 'Spades',
      'created_at': '2026-10-09T22:00:00.000',
      'card_count': 2,
    });

    expect(folder.id, 1);
    expect(folder.name, 'Spades');
    expect(folder.cardCount, 2);
    expect(folder.toMap().containsKey('card_count'), isFalse);
  });

  test('Only the four suits are supported', () {
    expect(Suits.values, ['Spades', 'Hearts', 'Diamonds', 'Clubs']);
    expect(Suits.isSupported('Hearts'), isTrue);
    expect(Suits.isSupported('Stars'), isFalse);
    expect(Suits.symbol('Stars'), '?');
  });
}
