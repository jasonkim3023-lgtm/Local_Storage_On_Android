// One dialog for both "new folder" and "rename folder".
//
// The dialog runs the save itself and stays open if it fails, so the user's
// typed name is kept and the error is shown next to the field.

import 'package:flutter/material.dart';

import '../data/card_repository.dart';

class FolderNameDialog extends StatefulWidget {
  const FolderNameDialog({
    super.key,
    required this.heading,
    required this.onSave,
    this.initialName = '',
  });

  final String heading;
  final String initialName;

  /// Performs the write. Throw a [RepositoryException] to show a message.
  final Future<void> Function(String name) onSave;

  @override
  State<FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<FolderNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return; // blocks a double tap from writing twice

    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a folder name.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.onSave(name);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on RepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not save: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.heading),
      content: TextField(
        controller: _controller,
        autofocus: true,
        enabled: !_busy,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Folder name',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          // Cancel closes the dialog without calling onSave: nothing is written.
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
