import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../data/entry_repository.dart';
import '../models/entry.dart';
import '../models/subject.dart';
import '../widgets/latex_content_view.dart';
import 'capture_screen.dart';
import 'entry_editor_screen.dart';

/// Lists Entries within a single Subject. Supports create (typed or via
/// photo transcription), edit, and delete.
///
/// Takes only [subjectId] (not a Subject object) so callers don't need to
/// hold a possibly-stale Subject around — this screen loads the current
/// name itself, which also means a rename elsewhere is picked up correctly.
class SubjectDetailScreen extends StatefulWidget {
  const SubjectDetailScreen({super.key, required this.subjectId});

  final int subjectId;

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  final _db = DatabaseHelper.instance;
  final _repo = EntryRepository();

  late Future<Subject?> _subjectFuture;
  late Future<List<Entry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _subjectFuture = _db.getSubject(widget.subjectId);
    _refresh();
  }

  void _refresh() {
    setState(() {
      _entriesFuture = _repo.getForSubject(widget.subjectId);
    });
  }

  Future<void> _openEditor({Entry? entry}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EntryEditorScreen(
          subjectId: widget.subjectId,
          existingEntry: entry,
        ),
      ),
    );
    _refresh();
  }

  Future<void> _openCapture() async {
    // CaptureScreen pushReplacement's into EntryEditorScreen once the user
    // confirms a photo, so awaiting this single push covers both legs of
    // the capture -> transcribe -> edit flow.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CaptureScreen(subjectId: widget.subjectId),
      ),
    );
    _refresh();
  }

  Future<void> _deleteEntry(Entry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('This cannot be undone.'),
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
    if (confirmed == true && entry.id != null) {
      try {
        await _repo.delete(entry.id!);
        _refresh();
      } catch (_) {
        _showError("Couldn't delete entry — try again");
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<Subject?>(
          future: _subjectFuture,
          builder: (context, snapshot) {
            return Text(snapshot.data?.name ?? '');
          },
        ),
      ),
      body: FutureBuilder<List<Entry>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data ?? [];
          if (entries.isEmpty) {
            return const Center(
              child: Text('No entries yet. Tap + to add one.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Card(
                child: ListTile(
                  title: LatexContentView(
                    content: _preview(entry.content),
                  ),
                  subtitle: Text('Updated ${_formatDateTime(entry.updatedAt)}'),
                  onTap: () => _openEditor(entry: entry),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteEntry(entry),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCapture,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _preview(String content) {
    const maxLen = 140;
    return content.length > maxLen
        ? '${content.substring(0, maxLen)}…'
        : content;
  }

  /// Formats e.g. "2026-09-06 14:32:07.891023" as "Sep 6, 2026, 2:32 PM"
  /// without pulling in the intl package for one string.
  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour24 = dt.hour;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour24 < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}, $hour12:$minute $period';
  }
}
