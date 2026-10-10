// One form for both adding and editing a card.
//
// - Add:  card is null. Saving inserts a new row.
// - Edit: card is set. Saving updates the row with that card's ID.
// - Back / Cancel: leaves without calling the repository, so nothing is written.
// - Failed save: the form stays open with everything the user typed.

import 'package:flutter/material.dart';

import '../data/card_repository.dart';
import '../models/folder.dart';
import '../models/playing_card.dart';

class CardFormScreen extends StatefulWidget {
  const CardFormScreen({
    super.key,
    required this.repository,
    required this.initialFolderId,
    this.card,
  });

  final CardRepository repository;

  /// The folder the user came from; preselected when adding.
  final int initialFolderId;

  /// The card being edited, or null to add a new one.
  final PlayingCard? card;

  @override
  State<CardFormScreen> createState() => _CardFormScreenState();
}

class _CardFormScreenState extends State<CardFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title =
      TextEditingController(text: widget.card?.title ?? '');
  late final TextEditingController _notes =
      TextEditingController(text: widget.card?.notes ?? '');
  late final TextEditingController _imageRef =
      TextEditingController(text: widget.card?.imageRef ?? '');

  late String? _suit = widget.card?.suit;
  late int? _folderId = widget.card?.folderId ?? widget.initialFolderId;

  List<Folder> _folders = const [];
  bool _loadingFolders = true;

  /// One busy flag: while true, Save is disabled so a double tap cannot
  /// insert the same card twice.
  bool _busy = false;

  String? _suitError;
  String? _folderError;
  String? _saveError;

  bool get _isEdit => widget.card?.id != null;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _imageRef.dispose();
    super.dispose();
  }

  Future<void> _loadFolders() async {
    try {
      final folders = await widget.repository.getFoldersWithCounts();
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _loadingFolders = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingFolders = false;
        _saveError = 'Could not load folders: $e';
      });
    }
  }

  Future<void> _save() async {
    if (_busy) return;

    final fieldsValid = _formKey.currentState?.validate() ?? false;
    final suit = _suit;
    final folderId = _folderId;
    final folderIsValid =
        folderId != null && _folders.any((folder) => folder.id == folderId);

    setState(() {
      _suitError = suit == null ? 'Choose a suit.' : null;
      _folderError = folderIsValid ? null : 'Choose a folder.';
      _saveError = null;
    });

    // Invalid input stops here: the repository is never called.
    if (!fieldsValid || suit == null || folderId == null || !folderIsValid) {
      return;
    }

    setState(() => _busy = true);

    try {
      final draft = PlayingCard(
        id: widget.card?.id,
        title: _title.text,
        suit: suit,
        notes: _notes.text,
        imageRef: _imageRef.text,
        folderId: folderId,
      );

      final String message;
      if (_isEdit) {
        final changed = await widget.repository.updateCard(draft);
        if (changed == 0) {
          throw const RepositoryException(
            'This card no longer exists, so nothing was updated.',
          );
        }
        message = 'Updated card ID ${draft.id}.';
      } else {
        final newId = await widget.repository.insertCard(draft);
        message = 'Added card ID $newId.';
      }

      if (!mounted) return;
      Navigator.of(context).pop(message);
    } on RepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _saveError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _saveError = 'Could not save: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final saveError = _saveError;

    // A dropdown's value must be one of its items, so fall back to "nothing
    // selected" if the stored value is not in the list.
    final suitValue = Suits.values.contains(_suit) ? _suit : null;
    final folderValue =
        _folders.any((folder) => folder.id == _folderId) ? _folderId : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit card ID ${widget.card?.id}' : 'Add card'),
      ),
      body: _loadingFolders
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _title,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter a title.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Suit',
                      border: const OutlineInputBorder(),
                      errorText: _suitError,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: suitValue,
                        isExpanded: true,
                        isDense: true,
                        hint: const Text('Choose a suit'),
                        items: [
                          for (final suit in Suits.values)
                            DropdownMenuItem(
                              value: suit,
                              child: Text('${Suits.symbol(suit)}  $suit'),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(() {
                                  _suit = value;
                                  _suitError = null;
                                }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Folder',
                      border: const OutlineInputBorder(),
                      errorText: _folderError,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: folderValue,
                        isExpanded: true,
                        isDense: true,
                        hint: const Text('Choose a folder'),
                        items: [
                          for (final folder in _folders)
                            DropdownMenuItem(
                              value: folder.id,
                              child: Text('${folder.name} (ID ${folder.id})'),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(() {
                                  _folderId = value;
                                  _folderError = null;
                                }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notes,
                    enabled: !_busy,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _imageRef,
                    enabled: !_busy,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Image reference (optional)',
                      helperText:
                          'An assets/... path or an https:// URL. Leave blank '
                          'to show the suit symbol.',
                      helperMaxLines: 2,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (saveError != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      saveError,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          // Pops with no result: the list screen treats that
                          // as "nothing changed".
                          onPressed:
                              _busy ? null : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _busy ? null : _save,
                          child: Text(_busy ? 'Saving…' : 'Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
