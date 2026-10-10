// The cards inside one folder, queried by that folder's ID.

import 'package:flutter/material.dart';

import '../data/card_repository.dart';
import '../models/folder.dart';
import '../models/playing_card.dart';
import '../widgets/card_image.dart';
import 'card_form_screen.dart';

class CardsScreen extends StatefulWidget {
  const CardsScreen({
    super.key,
    required this.repository,
    required this.folder,
  });

  final CardRepository repository;
  final Folder folder;

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  List<PlayingCard> _cards = const [];
  bool _loading = true;
  String? _loadError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cards = await widget.repository.getCards(widget.folder.id);
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load cards: $e';
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Opens the shared form. [card] is null for "add", set for "edit".
  /// The form returns a message only if it actually wrote something.
  Future<void> _openForm({PlayingCard? card}) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (context) => CardFormScreen(
          repository: widget.repository,
          card: card,
          initialFolderId: widget.folder.id,
        ),
      ),
    );
    if (!mounted || message == null) return; // cancelled: nothing changed
    _showMessage(message);
    await _load();
  }

  Future<void> _deleteCard(PlayingCard card) async {
    final id = card.id;
    if (_busy || id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${card.title}"?'),
        content: Text('Card ID $id will be removed. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _busy = true);
    try {
      final deleted = await widget.repository.deleteCard(id);
      if (!mounted) return;
      _showMessage(
        deleted == 0
            ? 'Card ID $id was not found. Nothing was deleted.'
            : 'Deleted "${card.title}".',
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('Could not delete "${card.title}": $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _loading
                  ? 'Loading…'
                  : 'Folder ID ${widget.folder.id} · ${_cards.length} '
                      '${_cards.length == 1 ? 'card' : 'cards'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add card'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = _loadError;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    if (_cards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.style_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                'No cards in "${widget.folder.name}" yet.\n'
                'Tap "Add card" to create one.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: _cards.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final card = _cards[index];
          final details = [
            'ID ${card.id}',
            card.suit,
            if (card.notes.isNotEmpty) card.notes,
          ].join(' · ');

          return ListTile(
            leading: CardImage(imageRef: card.imageRef, suit: card.suit),
            title: Text(card.title),
            subtitle: Text(
              details,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: _busy ? null : () => _openForm(card: card),
            trailing: IconButton(
              tooltip: 'Delete card',
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : () => _deleteCard(card),
            ),
          );
        },
      ),
    );
  }
}
