import 'dart:math' as math;

/// Pure helpers for the search feature (no Flutter or DB dependencies, so
/// they can be unit-tested directly).

/// Splits a raw query into lowercase-insensitive search terms.
///
/// Whitespace separates terms; duplicates are dropped. Every term must match
/// for an entry to be returned (AND semantics).
List<String> parseSearchTerms(String query) {
  final seen = <String>{};
  final terms = <String>[];
  for (final raw in query.trim().split(RegExp(r'\s+'))) {
    if (raw.isEmpty) continue;
    if (seen.add(raw.toLowerCase())) terms.add(raw);
  }
  return terms;
}

/// Escapes `\`, `%` and `_` so user input is matched literally inside a SQL
/// `LIKE ... ESCAPE '\'` pattern (searching for "50%" or "a_b" must not act
/// as wildcards).
String escapeLike(String input) {
  return input
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}

/// Builds a single-line excerpt of [content] around the first match of any
/// term in [terms]. Falls back to the start of the content when nothing in
/// the content matches (e.g. the entry matched via its subject name).
String buildSnippet(
  String content,
  List<String> terms, {
  int before = 40,
  int after = 110,
}) {
  final flat = content.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.isEmpty) return '';

  int? firstMatch;
  for (final term in terms) {
    final m = RegExp(RegExp.escape(term), caseSensitive: false)
        .firstMatch(flat);
    if (m != null && (firstMatch == null || m.start < firstMatch)) {
      firstMatch = m.start;
    }
  }

  final start = firstMatch == null ? 0 : math.max(0, firstMatch - before);
  final end = math.min(flat.length, start + before + after);
  final prefix = start > 0 ? '…' : '';
  final suffix = end < flat.length ? '…' : '';
  return '$prefix${flat.substring(start, end)}$suffix';
}

/// A regex matching any of [terms] (case-insensitive), for highlighting.
/// Longer terms come first so "physics" wins over "phys" in the alternation.
/// Returns null when there are no terms.
RegExp? buildHighlightPattern(List<String> terms) {
  if (terms.isEmpty) return null;
  final sorted = [...terms]..sort((a, b) => b.length.compareTo(a.length));
  return RegExp(
    sorted.map(RegExp.escape).join('|'),
    caseSensitive: false,
  );
}
