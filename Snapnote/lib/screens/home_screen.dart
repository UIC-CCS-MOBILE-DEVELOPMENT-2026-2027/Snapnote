import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../data/entry_repository.dart';
import '../models/subject.dart';
import 'subject_detail_screen.dart';

/// Home screen: lists all Subjects, with entry counts, create/delete, and
/// navigation into each Subject's entries.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// A Subject paired with how many Entries it has, for display purposes.
class _SubjectWithCount {
  const _SubjectWithCount(this.subject, this.entryCount);
  final Subject subject;
  final int entryCount;
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseHelper.instance;
  final _entryRepo = EntryRepository();

  late Future<List<_SubjectWithCount>> _subjectsFuture;

  @override
  void initState() {
    super.initState();
    _subjectsFuture = _loadSubjects();
  }

  void _refresh() {
    setState(() {
      _subjectsFuture = _loadSubjects();
    });
  }

  Future<List<_SubjectWithCount>> _loadSubjects() async {
    final subjects = await _db.getAllSubjects();

    // Entry counts aren't stored on Subject, so derive them by asking the
    // entry repository per subject. Fine at this scale (local, small lists);
    // if this ever needs to handle hundreds of subjects, add a single
    // GROUP BY query to DatabaseHelper instead.
    final withCounts = await Future.wait(subjects.map((subject) async {
      final entries = await _entryRepo.getForSubject(subject.id!);
      return _SubjectWithCount(subject, entries.length);
    }));

    return withCounts;
  }

  Future<void> _createSubject() async {
    final name = await _promptForName(context, title: 'New Subject');
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return;

    try {
      await _db
          .createSubject(Subject(name: trimmed, createdAt: DateTime.now()));
      _refresh();
    } catch (_) {
      _showError("Couldn't save subject — try again");
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<String?> _promptForName(
    BuildContext context, {
    required String title,
  }) {
    final controller = TextEditingController();
    String? errorText;

    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Subject name',
                  errorText: errorText,
                ),
                onChanged: (_) {
                  if (errorText != null) {
                    setDialogState(() => errorText = null);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (controller.text.trim().isEmpty) {
                      setDialogState(() => errorText = 'Name can\'t be empty');
                      return;
                    }
                    Navigator.pop(context, controller.text.trim());
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmDelete(Subject subject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete subject?'),
        content: Text(
          'This deletes "${subject.name}" and all of its entries '
          '(cascade delete). This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _deleteSubject(Subject subject) async {
    try {
      await _db.deleteSubject(subject.id!);
    } catch (_) {
      _showError("Couldn't delete subject — try again");
    } finally {
      // Refresh either way: on success this reflects the deletion; on
      // failure it re-syncs the list with what's actually in the DB, which
      // matters for the swipe-to-dismiss path since Dismissible has
      // already removed the row from view by the time onDismissed fires.
      _refresh();
    }
  }

  void _openSubject(Subject subject) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubjectDetailScreen(subjectId: subject.id!),
      ),
    ).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SnapNote')),
      body: FutureBuilder<List<_SubjectWithCount>>(
        future: _subjectsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Center(
              child: Text('No subjects yet — tap + to add one'),
            );
          }

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final subject = item.subject;

              return Dismissible(
                key: ValueKey(subject.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete_outline),
                ),
                confirmDismiss: (_) => _confirmDelete(subject),
                onDismissed: (_) => _deleteSubject(subject),
                child: ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(subject.name),
                  subtitle: Text(
                    '${item.entryCount} ${item.entryCount == 1 ? 'entry' : 'entries'}',
                  ),
                  onTap: () => _openSubject(subject),
                  onLongPress: () async {
                    final confirmed = await _confirmDelete(subject);
                    if (confirmed) await _deleteSubject(subject);
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createSubject,
        tooltip: 'New Subject',
        child: const Icon(Icons.add),
      ),
    );
  }
}
