import 'dart:async';

import 'package:flutter/material.dart';

import '../data/entry_repository.dart';
import '../models/entry_search_result.dart';
import '../utils/search_utils.dart';
import 'entry_editor_screen.dart';

/// Searches every entry across all subjects. Matches against entry content
/// and subject names; tapping a result opens it in the editor.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _repo = EntryRepository();
  final _controller = TextEditingController();

  Timer? _debounce;
  int _requestId = 0; // Lets us ignore out-of-order (stale) results.

  String _activeQuery = '';
  List<EntrySearchResult> _results = const [];
  bool _isSearching = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(value));
    setState(() {}); // Refresh the clear button's visibility.
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    final requestId = ++_requestId;

    if (trimmed.isEmpty) {
      setState(() {
        _activeQuery = '';
        _results = const [];
        _isSearching = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final results = await _repo.search(trimmed);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _activeQuery = trimmed;
        _results = results;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _isSearching = false;
        _error = "Couldn't search — try again";
      });
    }
  }

  Future<void> _openResult(EntrySearchResult result) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EntryEditorScreen(
          subjectId: result.entry.subjectId,
          existingEntry: result.entry,
        ),
      ),
    );
    // The entry may have been edited, so re-run the current query.
    if (mounted) _search(_controller.text);
  }

  void _clear() {
    _controller.clear();
    _debounce?.cancel();
    _search('');
  }

  /// "Sep 6, 2026" — avoids pulling in intl for one string.
  String _formatDate(DateTime dt) {
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
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  /// Renders [text] with every match of [pattern] bolded and tinted.
  Widget _highlighted(BuildContext context, String text, RegExp? pattern) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyMedium;
    if (pattern == null) {
      return Text(text,
          style: base, maxLines: 3, overflow: TextOverflow.ellipsis);
    }

    final spans = <TextSpan>[];
    var cursor = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.end == m.start) continue;
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start)));
      }
      spans.add(TextSpan(
        text: text.substring(m.start, m.end),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          backgroundColor: theme.colorScheme.primaryContainer,
        ),
      ));
      cursor = m.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));

    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_activeQuery.isEmpty) {
      return Center(
        child: Text(
          _isSearching ? '' : 'Search your notes by text or subject name',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: _isSearching
            ? const SizedBox.shrink()
            : Text('No notes match "$_activeQuery"'),
      );
    }

    final terms = parseSearchTerms(_activeQuery);
    final pattern = buildHighlightPattern(terms);

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = _results[index];
        final snippet = buildSnippet(result.entry.content, terms);
        return ListTile(
          isThreeLine: true,
          title: Text(
            result.subjectName,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _highlighted(
              context,
              snippet.isEmpty ? '(empty entry)' : snippet,
              pattern,
            ),
          ),
          trailing: Text(
            _formatDate(result.entry.updatedAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          onTap: () => _openResult(result),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search notes',
            border: InputBorder.none,
          ),
          onChanged: _onQueryChanged,
          onSubmitted: (value) {
            _debounce?.cancel();
            _search(value);
          },
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Clear',
              onPressed: _clear,
            ),
        ],
        bottom: _isSearching
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: _buildBody(context),
    );
  }
}
