import 'entry.dart';

/// An [Entry] that matched a search, paired with the name of the Subject
/// it belongs to so results can be shown without a second lookup.
class EntrySearchResult {
  const EntrySearchResult({
    required this.entry,
    required this.subjectName,
    this.topicName,
  });

  final Entry entry;
  final String subjectName;

  /// Null when the entry has no topic.
  final String? topicName;
}
