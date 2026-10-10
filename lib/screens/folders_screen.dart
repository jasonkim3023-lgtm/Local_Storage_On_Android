// Folders tab: every folder with its ID and card count.
// Tap a folder to see its cards. No SQL here: only repository calls.

import 'package:flutter/material.dart';

import '../data/card_repository.dart';
import '../models/folder.dart';
import '../widgets/folder_name_dialog.dart';
import 'cards_screen.dart';

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key, required this.repository});

  final CardRepository repository;

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  List<Folder> _folders = const [];
  bool _loading = true;
  String? _loadError;

  /// True while a delete is running, so a second tap cannot start another.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Reads the list from the database. A failure here is a read failure only:
  /// it never repeats a write.
  Future<void> _load() async {
    try {
      final folders = await widget.repository.getFoldersWithCounts();
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load folders: $e';
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addFolder() async {
    int? newId;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => FolderNameDialog(
        heading: 'New folder',
        onSave: (name) async {
          newId = await widget.repository.insertFolder(name);
        },
      ),
    );
    if (!mounted || saved != true) return;
    _showMessage('Folder added (ID $newId).');
    await _load();
  }

  Future<void> _renameFolder(Folder folder) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => FolderNameDialog(
        heading: 'Rename folder',
        initialName: folder.name,
        onSave: (name) async {
          final changed = await widget.repository.renameFolder(folder.id, name);
          if (changed == 0) {
            throw const RepositoryException(
              'This folder no longer exists, so nothing was changed.',
            );
          }
        },
      ),
    );
    if (!mounted || saved != true) return;
    _showMessage('Folder ID ${folder.id} renamed.');
    await _load();
  }

  Future<void> _deleteFolder(Folder folder) async {
    if (_busy) return;

    final cards = folder.cardCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${folder.name}"?'),
        content: Text(
          cards == 0
              ? 'This folder (ID ${folder.id}) is empty.'
              : 'This also deletes the $cards ${cards == 1 ? 'card' : 'cards'} '
                  'inside folder ID ${folder.id}. This cannot be undone.',
        ),
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
    // Cancel (or tapping outside) returns here without touching the database.
    if (!mounted || confirmed != true) return;

    setState(() => _busy = true);
    try {
      final deleted = await widget.repository.deleteFolder(folder.id);
      if (!mounted) return;
      _showMessage(
        deleted == 0
            ? 'Folder ID ${folder.id} was not found. Nothing was deleted.'
            : 'Deleted "${folder.name}" and its cards.',
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('Could not delete "${folder.name}": $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _load();
  }

  Future<void> _openFolder(Folder folder) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => CardsScreen(
          repository: widget.repository,
          folder: folder,
        ),
      ),
    );
    if (!mounted) return;
    await _load(); // card counts may have changed
  }

  @override
  Widget build(BuildContext context) {
    final totalCards =
        _folders.fold<int>(0, (sum, folder) => sum + folder.cardCount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Folders'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _loading
                  ? 'Loading…'
                  : '${_folders.length} folders · $totalCards cards in total',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _addFolder,
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('New folder'),
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

    if (_folders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No folders yet. Tap "New folder" to add one.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: _folders.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final folder = _folders[index];
          final count = folder.cardCount;
          return ListTile(
            leading: const Icon(Icons.folder),
            title: Text(folder.name),
            subtitle: Text(
              'ID ${folder.id} · $count ${count == 1 ? 'card' : 'cards'}',
            ),
            onTap: _busy ? null : () => _openFolder(folder),
            trailing: PopupMenuButton<String>(
              enabled: !_busy,
              onSelected: (action) {
                if (action == 'rename') {
                  _renameFolder(folder);
                } else if (action == 'delete') {
                  _deleteFolder(folder);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          );
        },
      ),
    );
  }
}
