# Activity 09: Local Storage, Part II (Card Catalogue)

**Student:** Jason Kim
**Pathway:** Undergraduate (Build & explain)
**Course:** Mobile Application Development, In-Class Activity 09

## Environment

| Item | Value |
|---|---|
| Flutter | 3.47.6 (stable) |
| Dart | 3.13.5 |
| Target | Android (tested on a Pixel 6 emulator) |
| Packages | `sqflite`, `path`, `path_provider` |

## Setup, run, build, test

```
flutter pub get
flutter run                    # choose the Android device
flutter analyze                # output saved in evidence/analysis_output.txt
flutter test                   # unit tests for the model classes
flutter build apk --release    # output: build/app/outputs/flutter-apk/app-release.apk
```

## Database

| Item | Part I (Activity 08) | Part II (this app) |
|---|---|---|
| File | `MyDatabase.db` in the app documents directory | same file, same location |
| Version | 1 | 2 |
| Tables | `my_table` | `my_table`, `folders`, `cards` |
| Index | none | `idx_cards_folder_id` on `cards(folder_id)` |

**Migration.** `lib/data/database_helper.dart` opens the same file with
`version: 2`.

- `onConfigure` runs `PRAGMA foreign_keys = ON` so the cascade rule is enforced.
- `onUpgrade` (existing Part I install) creates `folders`, `cards` and the
  index. It does not drop, rename or rewrite `my_table`.
- `onCreate` (fresh install) creates `my_table` with the original Part I
  statement, then the same Part II tables, so both paths end with the same
  schema.
- Four sample folders (one per suit) with one Ace each are seeded once, inside
  `onCreate` / `onUpgrade` only. Each card uses the ID returned by its folder
  insert.

**Delete rule.** `cards.folder_id` references `folders(id)` with
`ON DELETE CASCADE`: deleting a folder deletes its cards. The app asks for
confirmation first and names the folder and the number of cards affected.

**Application ID.** This project's Android `applicationId` is set to
`com.example.inclass08`, the same as my Part I app. Android stores each app's
database under its application ID, so this is what lets Part II install as an
update of the Part I app and upgrade its existing database, instead of starting
with an empty one.

## Code layout

| File | Purpose |
|---|---|
| `lib/main.dart` | App start, opens the database, three tabs. No SQL. |
| `lib/data/database_helper.dart` | Opens the database; schema, migration, seeding. |
| `lib/data/card_repository.dart` | Folder and card queries (`getFoldersWithCounts`, `getCards`, `insertCard`, `updateCard`, `deleteCard`, `deleteFolder`, ...). All values bound with `whereArgs`. |
| `lib/data/guest_repository.dart` | The Part I roster queries, moved out of the old helper. |
| `lib/data/part_one_repository.dart` | Read-only check: schema version, table list, Part I rows. |
| `lib/models/folder.dart`, `lib/models/playing_card.dart` | Models with `fromMap()` / `toMap()`. |
| `lib/screens/folders_screen.dart` | Folder list with IDs and card counts. |
| `lib/screens/cards_screen.dart` | Cards in one folder, queried by folder ID. |
| `lib/screens/card_form_screen.dart` | One form for add and edit. |
| `lib/screens/roster_screen.dart` | The Part I roster screen. |
| `lib/screens/part_one_screen.dart` | "Database" tab used for T1 evidence. |
| `lib/widgets/card_image.dart` | Image display with suit-symbol fallback. |

The card model is named `PlayingCard` rather than `Card` because Flutter's
material library already has a `Card` widget.

## Image reference choice

`cards.image_ref` is a nullable `TEXT` column that stores a reference, not the
image. The app accepts a bundled asset path (`assets/...`) or an `https://`
URL. When the value is null, malformed, or cannot be loaded, the card shows a
suit symbol placeholder instead, so every card is usable without an image. No
image assets are bundled with this submission, and no test depends on the
network.

## Test results (T1 to T6)

Run on 9 October 2026 on a Pixel 6 emulator, using fictional data, on the
install upgraded from Part I. The app was not uninstalled and its storage was
not cleared at any point.

| Test | Action | Expected | Observed | Result |
|---|---|---|---|---|
| T1 Upgrade preservation | Recorded Part I rows, installed Part II over it, opened the Database tab. | Version 2 tables exist; all Part I rows unchanged. | Before: `my_table` had 3 rows (ID 2 River 35, ID 3 Acorn 0, ID 4 Oak 130). After: version 2; tables `cards`, `folders`, `my_table`; `my_table` still 3 rows with the same IDs and values. | Pass |
| T2 Parent-child create | Created folder "Test Deck"; added two cards to it and one card to Spades. | Three distinct card IDs, each only under its folder; counts match. | Test Deck = folder ID 5 with card ID 5 (Two of Hearts) and card ID 6 (King of Clubs). Spades = folder ID 1 gained card ID 7 (Three of Spades). Test Deck count 2, Spades count 2. | Pass |
| T3 Edit identity | Edited card ID 5 title and notes and saved; started editing card ID 6 and cancelled. | One row updated; others unchanged; cancel writes nothing. | Card ID 5 became "Two of Hearts(edited)" with note "Changed for T3". Card ID 6 still "King of Clubs". Folder count still 2. | Pass |
| T4 Restart persistence | Swiped the app closed (data not cleared) and reopened it. | Same folders, IDs and counts; no duplicate seed rows. | 5 folders, 7 cards: Clubs ID 4 (1), Diamonds ID 3 (1), Hearts ID 2 (1), Spades ID 1 (2), Test Deck ID 5 (2). One sample Ace per suit folder, no duplicates. | Pass |
| T5 Delete behaviour | Cancelled deleting Test Deck, then confirmed it. | Cancel changes nothing; confirm removes the folder and its cards. | After cancel: 5 folders, 7 cards. After confirm: 4 folders, 5 cards; Test Deck (ID 5) and its cards (IDs 5, 6) gone; Spades still 2 cards. | Pass |
| T6 Failure and image fallback | Saved a card with a blank title | Blank title writes nothing and shows an error; missing image shows the fallback. | Blank title showed "Enter a title." and no card was added. "Broken Image Test" saved as card ID 8 and displayed the suit symbol placeholder. Existing records unchanged. | Pass |


**Fresh install path.** Before the application ID was matched to Part I, the
same code was installed as a separate app (`com.example.inclass09`) with no
existing database. It opened without error and the Roster tab showed
"Guest count: 0", so `onCreate` built the schema including `my_table`.

## Evidence

| File | Shows |
|---|---|
| `evidence/T1_before.png` | Part I app before the upgrade: 3 guests. |
| `evidence/T1_after_roster.png` | Roster tab in the Part II app with the same 3 guests. |
| `evidence/T2_cards.png` | Test Deck (folder ID 5) with card IDs 5 and 6. |
| `evidence/T4_after.png` | Folders list after restart: 5 folders, 7 cards. |
| `evidence/analysis_output.txt` | Output of `flutter analyze`. |

## Rubric map

| Criterion | Where to look |
|---|---|
| Schema & data preservation | `lib/data/database_helper.dart`; T1, T5; `T1_before.png`, `T1_after.png` |
| Models, repository & CRUD | `lib/models/`, `lib/data/card_repository.dart`, `lib/screens/card_form_screen.dart`; T2, T3 |
| Image handling & usability | `lib/widgets/card_image.dart`, `lib/screens/cards_screen.dart`; T6 |
| Testing & evidence | Test table above; `evidence/` |
| Critical thinking & AI Lab | `Kim_Jason_CriticalThinking.docx` (submitted separately) |
| README & delivery | This file; `pubspec.yaml`, `pubspec.lock` |

## Known limitations

- No image assets are bundled, so the `assets/...` path was only tested with a
  missing file (the fallback case).
- The Android manifest does not request the `INTERNET` permission, so a URL
  image reference will show the placeholder in the release build.
- Automated tests cover the model classes only. Database behaviour (T1 to T6)
  was tested by hand on the emulator.
- T5 and T6 have no screenshots.
- Folder names are unique but case-sensitive ("Spades" and "spades" are
  treated as different names).
- Release APK smoke test: TODO, fill in the result after installing the APK.

## Credits

- Starting point: my own Activity 08 (Part I) project.
- Packages: `sqflite`, `path`, `path_provider` (pub.dev).
