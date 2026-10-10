// Database tab: a read-only check of the upgraded database.
//
// It shows the database version, the tables that exist, the Part I row count
// and every Part I row, which is the evidence T1 asks for. It never writes.

import 'package:flutter/material.dart';

import '../data/part_one_repository.dart';

class PartOneScreen extends StatefulWidget {
  const PartOneScreen({super.key, required this.repository});

  final PartOneRepository repository;

  @override
  State<PartOneScreen> createState() => _PartOneScreenState();
}

class _PartOneScreenState extends State<PartOneScreen> {
  PartOneSnapshot? _snapshot;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not read the Part I table: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database check'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = _loadError;
    final snapshot = _snapshot;
    if (error != null || snapshot == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error ?? 'No data loaded.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Database version: ${snapshot.schemaVersion}'),
                const SizedBox(height: 4),
                Text('Tables: ${snapshot.allTables.join(', ')}'),
                const SizedBox(height: 4),
                Text(
                  snapshot.tableExists
                      ? 'Rows in "${snapshot.tableName}": ${snapshot.rows.length}'
                      : 'Table "${snapshot.tableName}" was not found.',
                  style: textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (!snapshot.tableExists)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'The Part I table is missing from this database. '
              'Do not clear app data to fix this.',
            ),
          )
        else if (snapshot.rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('The Part I table exists and has no rows.'),
          )
        else
          for (final row in snapshot.rows)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in row.entries)
                      Text('${entry.key}: ${entry.value}'),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
