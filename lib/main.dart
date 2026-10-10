// Activity 09 - Local Storage, Part II
// App entry point. No SQL lives here: this file only starts the app, opens the
// database once (which triggers onCreate / onUpgrade), and routes to screens.

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'data/card_repository.dart';
import 'data/database_helper.dart';
import 'data/guest_repository.dart';
import 'data/part_one_repository.dart';
import 'screens/folders_screen.dart';
import 'screens/part_one_screen.dart';
import 'screens/roster_screen.dart';

void main() {
  // Required before any plugin (sqflite, path) is used.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CardCatalogueApp());
}

class CardCatalogueApp extends StatelessWidget {
  const CardCatalogueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Card Catalogue',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const StartupGate(),
    );
  }
}

/// Opens the database before any screen queries it.
///
/// The version 1 -> 2 migration runs inside this open call. If it fails, the
/// error is shown here instead of crashing or being hidden, and the user can
/// retry. Nothing in this widget deletes, clears, or recreates data.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late Future<Database> _opening;

  @override
  void initState() {
    super.initState();
    _opening = DatabaseHelper.instance.database;
  }

  void _retry() {
    setState(() {
      _opening = DatabaseHelper.instance.database;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Database>(
      future: _opening,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Database error')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'The database could not be opened or upgraded. '
                    'Your saved data has not been changed.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _retry,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }

        return const HomeShell();
      },
    );
  }
}

/// Three tabs: the new folder/card catalogue, the original Part I roster
/// screen (still working on the same rows), and a read-only database check
/// that shows the version, tables and Part I row count (evidence for T1).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // One repository for the whole app; screens call its methods, never SQL.
  late final CardRepository _repository =
      CardRepository(DatabaseHelper.instance);
  late final GuestRepository _guestRepository =
      GuestRepository(DatabaseHelper.instance);
  late final PartOneRepository _partOneRepository =
      PartOneRepository(DatabaseHelper.instance);

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          FoldersScreen(repository: _repository),
          RosterScreen(helper: _guestRepository),
          PartOneScreen(repository: _partOneRepository),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Folders',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Roster',
          ),
          NavigationDestination(
            icon: Icon(Icons.table_rows_outlined),
            selectedIcon: Icon(Icons.table_rows),
            label: 'Database',
          ),
        ],
      ),
    );
  }
}
