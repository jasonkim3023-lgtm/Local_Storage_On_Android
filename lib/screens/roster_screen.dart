// Part I roster screen (Activity 08), carried over unchanged except that it
// now talks to GuestRepository instead of the old Part I DatabaseHelper.
// It reads and writes the same my_table rows as before the upgrade.

import 'package:flutter/material.dart';

import '../data/guest_repository.dart';

class RosterScreen extends StatefulWidget {
  const RosterScreen({super.key, required this.helper});

  final GuestRepository helper;

  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<RosterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  /// Rows exactly as the last successful query returned them.
  List<Map<String, dynamic>> _rows = [];
  int _count = 0;

  /// True while any database action is pending. Starts true because the first
  /// load begins in initState. Every button and field is disabled while true.
  bool _busy = true;

  /// True once at least one query has succeeded, so "empty" is a real result.
  bool _hasLoaded = false;

  /// Set when the most recent read failed. Kept separate from write feedback.
  String? _readError;

  /// Text feedback from the most recent action (inserted ID, rows affected...).
  String? _message;

  /// ID of the row being edited, or null in Add mode.
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- reading

  Future<void> _initialLoad() async {
    try {
      await _reload();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// Queries the database and copies the result into screen state.
  /// Returns true if the read succeeded. Does not touch [_busy] or [_message];
  /// callers own those.
  Future<bool> _reload() async {
    try {
      final rows = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();
      if (!mounted) return false;
      setState(() {
        _rows = rows;
        _count = count;
        _readError = null;
        _hasLoaded = true;
      });
      return true;
    } catch (error, stackTrace) {
      debugPrint('Roster read failed: $error\n$stackTrace');
      if (!mounted) return false;
      setState(() {
        _readError = 'Could not read the roster from local storage. Press Refresh to retry.';
      });
      return false;
    }
  }

  /// Runs one database action at a time and always releases the busy flag.
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _refresh() {
    return _run(() async {
      final ok = await _reload();
      if (!mounted) return;
      setState(() {
        _message = ok ? 'Roster refreshed. Guest count: $_count.' : null;
      });
    });
  }

  // ------------------------------------------------------------- validation

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter a name. Spaces alone do not count.';
    }
    return null;
  }

  String? _validateAge(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Enter an age from 0 to 130.';
    }
    // radix: 10 keeps "0x1F"-style hex input from being accepted.
    final age = int.tryParse(text, radix: 10);
    if (age == null) {
      return 'Age must be a whole number such as 21. No decimals or letters.';
    }
    if (age < 0 || age > 130) {
      return 'Age must be from 0 to 130.';
    }
    return null;
  }

  // ---------------------------------------------------------------- writing

  /// Add/Save button handler. Validates first; invalid input writes nothing.
  Future<void> _submit() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _message =
            'Nothing was saved. Fix the field marked below and try again.';
      });
      return;
    }
    final name = _nameController.text.trim();
    final age = int.parse(_ageController.text.trim(), radix: 10);
    final editingId = _selectedId;
    if (editingId == null) {
      await _add(name, age);
    } else {
      await _saveEdit(editingId, name, age);
    }
  }

  Future<void> _add(String name, int age) {
    return _run(() async {
      final int id;
      try {
        // No _id in the map: SQLite assigns it.
        id = await widget.helper.insert({
          GuestRepository.columnName: name,
          GuestRepository.columnAge: age,
        });
      } catch (error, stackTrace) {
        debugPrint('Insert failed: $error\n$stackTrace');
        if (mounted) {
          setState(() {
            _message =
                'Could not add the guest. Nothing was saved and your '
                'input is still in the form. Try Add again.';
          });
        }
        return;
      }
      if (!mounted) return;

      // The write succeeded, so clear the form now. A later refresh failure
      // must not lead to the same guest being inserted twice.
      _resetForm();
      final ok = await _reload();
      if (!mounted) return;
      setState(() {
        _message = ok
            ? 'Added "$name" with ID $id. Guest count: $_count.'
            : 'Saved "$name" with ID $id, but refresh failed. Press Refresh. '
                  'Do not add this guest again.';
      });
    });
  }

  Future<void> _saveEdit(int id, String name, int age) {
    return _run(() async {
      final int updated;
      try {
        updated = await widget.helper.update({
          GuestRepository.columnId: id,
          GuestRepository.columnName: name,
          GuestRepository.columnAge: age,
        });
      } catch (error, stackTrace) {
        debugPrint('Update of ID $id failed: $error\n$stackTrace');
        if (mounted) {
          setState(() {
            _message =
                'Could not save changes to guest ID $id. Nothing was '
                'changed and your input is still in the form. Try Save again.';
          });
        }
        return;
      }
      if (!mounted) return;

      if (updated != 1) {
        // Zero rows affected: the row is gone. Not a success. Leave edit mode
        // (there is nothing left to edit) but keep what the user typed.
        setState(() => _selectedId = null);
        await _reload();
        if (!mounted) return;
        setState(() {
          _message = updated == 0
              ? 'Guest ID $id no longer exists, so nothing was updated '
                    '(rows affected: 0). Your input is still in the form.'
              : 'Unexpected result for guest ID $id: rows affected: $updated.';
        });
        return;
      }

      _resetForm();
      setState(() => _selectedId = null);
      final ok = await _reload();
      if (!mounted) return;
      setState(() {
        _message = ok
            ? 'Updated guest ID $id (rows affected: 1). Guest count: $_count.'
            : 'Saved guest ID $id (rows affected: 1), but refresh failed. '
                  'Press Refresh.';
      });
    });
  }

  Future<void> _confirmAndDelete(Map<String, dynamic> row) async {
    if (_busy) return;
    final id = row[GuestRepository.columnId] as int;
    final name = row[GuestRepository.columnName] as String;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this guest?'),
        content: Text('ID $id, "$name" will be removed from the roster.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Delete ID $id'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) {
      setState(() {
        _message = 'Deletion of guest ID $id cancelled. Nothing was written.';
      });
      return;
    }

    await _run(() async {
      final int deleted;
      try {
        deleted = await widget.helper.delete(id);
      } catch (error, stackTrace) {
        debugPrint('Delete of ID $id failed: $error\n$stackTrace');
        if (mounted) {
          setState(() {
            _message =
                'Could not delete guest ID $id. Nothing was removed. '
                'Try Delete again.';
          });
        }
        return;
      }
      if (!mounted) return;

      // If the deleted row was the one being edited, leave edit mode.
      if (deleted == 1 && _selectedId == id) {
        _resetForm();
        setState(() => _selectedId = null);
      }
      final ok = await _reload();
      if (!mounted) return;
      setState(() {
        if (deleted == 0) {
          _message =
              'Guest ID $id no longer exists, so nothing was deleted '
              '(rows affected: 0).';
        } else if (deleted != 1) {
          _message =
              'Unexpected result for guest ID $id: rows affected: $deleted.';
        } else if (ok) {
          _message =
              'Deleted guest ID $id (rows affected: 1). '
              'Guest count: $_count.';
        } else {
          _message =
              'Deleted guest ID $id (rows affected: 1), but refresh '
              'failed. Press Refresh.';
        }
      });
    });
  }

  // ------------------------------------------------------- form selection

  /// Clears both fields and any validation messages. Writes nothing.
  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _ageController.clear();
  }

  void _startEdit(Map<String, dynamic> row) {
    if (_busy) return;
    final id = row[GuestRepository.columnId] as int;
    _formKey.currentState?.reset();
    setState(() {
      _selectedId = id;
      _nameController.text = row[GuestRepository.columnName] as String;
      _ageController.text = '${row[GuestRepository.columnAge]}';
      _message =
          'Editing guest ID $id. Save changes only this ID. '
          'Cancel edit writes nothing.';
    });
  }

  void _cancelEdit() {
    if (_busy) return;
    final id = _selectedId;
    if (id == null) return;
    _resetForm();
    setState(() {
      _selectedId = null;
      _message = 'Edit of guest ID $id cancelled. Nothing was written.';
    });
  }

  // -------------------------------------------------------------- rendering

  String get _countLabel {
    if (_readError != null) return 'Guest count: unknown (last read failed)';
    if (!_hasLoaded) return 'Guest count: loading';
    return 'Guest count: $_count';
  }

  List<Widget> _buildRosterSection() {
    if (_readError != null) {
      return [Text(_readError!)];
    }
    if (!_hasLoaded) {
      return const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_rows.isEmpty) {
      // Only reached after a successful query that returned zero rows.
      return const [Text('No festival guests yet. The hay bales are waiting.')];
    }
    return [for (final row in _rows) _buildRow(row)];
  }

  Widget _buildRow(Map<String, dynamic> row) {
    final id = row[GuestRepository.columnId] as int;
    final name = row[GuestRepository.columnName] as String;
    final age = row[GuestRepository.columnAge] as int;
    final isBeingEdited = id == _selectedId;

    return Card(
      key: ValueKey<int>(id),
      child: ListTile(
        title: Text('ID $id: $name'),
        subtitle: Text(isBeingEdited ? 'Age $age (being edited)' : 'Age $age'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: _busy ? null : () => _startEdit(row),
              child: const Text('Edit'),
            ),
            TextButton(
              onPressed: _busy ? null : () => _confirmAndDelete(row),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editingId = _selectedId;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Fall Festival Roster')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              editingId == null ? 'Add a guest' : 'Edit guest ID $editingId',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Guest name',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: _validateName,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ageController,
                    enabled: !_busy,
                    // Default text keyboard on purpose: a number pad would
                    // hide letters and the minus sign, and the validator is
                    // what must reject "abc", "1.5" and "-1".
                    decoration: const InputDecoration(
                      labelText: 'Age (whole number, 0 to 130)',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    validator: _validateAge,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(
                    editingId == null
                        ? 'Add guest'
                        : 'Save changes to ID $editingId',
                  ),
                ),
                OutlinedButton(
                  onPressed: (_busy || editingId == null) ? null : _cancelEdit,
                  child: const Text('Cancel edit'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _refresh,
                  child: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_busy) ...const [
              LinearProgressIndicator(),
              SizedBox(height: 8),
            ],
            Text(_countLabel, style: textTheme.titleMedium),
            if (_message != null) ...[
              const SizedBox(height: 8),
              Semantics(liveRegion: true, child: Text(_message!)),
            ],
            const Divider(height: 32),
            ..._buildRosterSection(),
          ],
        ),
      ),
    );
  }
}
