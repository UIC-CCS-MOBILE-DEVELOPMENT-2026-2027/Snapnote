import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../data/entry_repository.dart';
import '../data/topic_repository.dart';
import '../models/entry.dart';
import '../models/subject.dart';
import '../models/topic.dart';
import '../widgets/latex_content_view.dart';
import '../widgets/topic_name_dialog.dart';
import 'capture_screen.dart';
import 'entry_editor_screen.dart';

/// Lists Entries within a single Subject, optionally filtered by Topic
/// (lesson). Supports create (via photo transcription), edit, and delete of
/// entries, plus create / rename / delete of topics.
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

/// Topics and entries are loaded together so the chips and the list always
/// describe the same moment in time.
class _DetailData {
  const _DetailData(this.topics, this.entries);

  final List<Topic> topics;
  final List<Entry> entries;
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  // Filter values: real topic ids are always > 0 (AUTOINCREMENT), so negative
  // numbers are safe sentinels.
  static const _filterAll = -1;
  static const _filterNone = -2;

  final _db = DatabaseHelper.instance;
  final _repo = EntryRepository();
  final _topicRepo = TopicRepository();

  late Future<Subject?> _subjectFuture;
  late Future<_DetailData> _dataFuture;
  _DetailData? _latest;
  int _filter = _filterAll;

  @override
  void initState() {
    super.initState();
    _subjectFuture = _db.getSubject(widget.subjectId);
    _dataFuture = _load();
  }

  Future<_DetailData> _load() async {
    final topics = await _topicRepo.getForSubject(widget.subjectId);
    final entries = await _repo.getForSubject(widget.subjectId);
    final data = _DetailData(topics, entries);
    _latest = data;
    return data;
  }

  void _refresh() {
    setState(() {
      _dataFuture = _load();
    });
  }

  /// The currently selected real topic, or null for All / No topic.
  Topic? _selectedTopic(List<Topic> topics) {
    for (final t in topics) {
      if (t.id == _filter) return t;
    }
    return null;
  }

  List<Entry> _visibleEntries(_DetailData data) {
    if (_filter == _filterAll) return data.entries;
    if (_filter == _filterNone) {
      return data.entries.where((e) => e.topicId == null).toList();
    }
    return data.entries.where((e) => e.topicId == _filter).toList();
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
    // New notes start in the topic currently being viewed.
    final topic = _selectedTopic(_latest?.topics ?? const []);

    // CaptureScreen pushReplacement's into EntryEditorScreen once the user
    // confirms a photo, so awaiting this single push covers both legs of
    // the capture -> transcribe -> edit flow.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CaptureScreen(
          subjectId: widget.subjectId,
          initialTopicId: topic?.id,
        ),
      ),
    );
    _refresh();
  }

  // -- Topics -----------------------------------------------------------

  Future<void> _createTopic() async {
    final existing = (_latest?.topics ?? const <Topic>[])
        .map((t) => t.name)
        .toList();
    final name = await showTopicNameDialog(context, existingNames: existing);
    if (name == null) return;

    try {
      final topic = await _topicRepo.create(widget.subjectId, name);
      if (!mounted) return;
      _filter = topic.id!; // Jump straight into the new topic.
      _refresh();
    } catch (_) {
      _showError("Couldn't create topic — try again");
    }
  }

  Future<void> _renameTopic(Topic topic) async {
    final others = (_latest?.topics ?? const <Topic>[])
        .where((t) => t.id != topic.id)
        .map((t) => t.name)
        .toList();
    final name = await showTopicNameDialog(
      context,
      initialName: topic.name,
      existingNames: others,
    );
    if (name == null || name == topic.name) return;

    try {
      await _topicRepo.rename(topic, name);
      _refresh();
    } catch (_) {
      _showError("Couldn't rename topic — try again");
    }
  }

  Future<void> _deleteTopic(Topic topic) async {
    final count =
        _latest?.entries.where((e) => e.topicId == topic.id).length ?? 0;
    final noteWord = count == 1 ? 'note' : 'notes';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${topic.name}"?'),
        content: Text(
          count == 0
              ? 'This topic is empty.'
              : 'Its $count $noteWord will be kept and moved to "No topic".',
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
    if (confirmed != true || topic.id == null) return;

    try {
      await _topicRepo.delete(topic.id!);
      if (!mounted) return;
      _filter = _filterAll;
      _refresh();
    } catch (_) {
      _showError("Couldn't delete topic — try again");
    }
  }

  // -- Entries ----------------------------------------------------------

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

  // -- UI ---------------------------------------------------------------

  Widget _filterChip(String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  Widget _buildTopicBar(_DetailData data) {
    final hasUngrouped = data.entries.any((e) => e.topicId == null);

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          if (data.topics.isNotEmpty) _filterChip('All', _filterAll),
          for (final t in data.topics) _filterChip(t.name, t.id!),
          if (data.topics.isNotEmpty && hasUngrouped)
            _filterChip('No topic', _filterNone),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: Text(
              data.topics.isEmpty
                  ? 'Organize by topic (e.g. Quadratic Equations)'
                  : 'New topic',
            ),
            onPressed: _createTopic,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DetailData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final selected = data == null ? null : _selectedTopic(data.topics);

        return Scaffold(
          appBar: AppBar(
            title: FutureBuilder<Subject?>(
              future: _subjectFuture,
              builder: (context, subjectSnapshot) {
                return Text(subjectSnapshot.data?.name ?? '');
              },
            ),
            actions: [
              if (selected != null)
                PopupMenuButton<String>(
                  tooltip: 'Topic options',
                  onSelected: (value) {
                    if (value == 'rename') _renameTopic(selected);
                    if (value == 'delete') _deleteTopic(selected);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename topic')),
                    PopupMenuItem(value: 'delete', child: Text('Delete topic')),
                  ],
                ),
            ],
          ),
          body: _buildBody(context, snapshot, data),
          floatingActionButton: FloatingActionButton(
            onPressed: _openCapture,
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncSnapshot<_DetailData> snapshot,
    _DetailData? data,
  ) {
    if (snapshot.connectionState != ConnectionState.done || data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // If the selected topic vanished (e.g. deleted elsewhere), fall back.
    if (_filter > 0 && _selectedTopic(data.topics) == null) {
      _filter = _filterAll;
    }

    final entries = _visibleEntries(data);
    final topicNames = {for (final t in data.topics) t.id: t.name};

    return Column(
      children: [
        _buildTopicBar(data),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    _filter == _filterAll
                        ? 'No entries yet. Tap + to add one.'
                        : 'No notes here yet. Tap + to add one.',
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final topicName = topicNames[entry.topicId];
                    return Card(
                      child: ListTile(
                        title: LatexContentView(
                          content: _preview(entry.content),
                        ),
                        subtitle: Text(
                          // The topic label is redundant once you're already
                          // filtered to that topic.
                          '${topicName != null && _filter == _filterAll ? '$topicName · ' : ''}'
                          'Updated ${_formatDateTime(entry.updatedAt)}',
                        ),
                        onTap: () => _openEditor(entry: entry),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteEntry(entry),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
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
