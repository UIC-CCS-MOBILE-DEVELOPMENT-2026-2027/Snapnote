import 'package:flutter_test/flutter_test.dart';
import 'package:subject_notes_app/utils/search_utils.dart';

void main() {
  group('parseSearchTerms', () {
    test('splits on whitespace and drops blanks/duplicates', () {
      expect(parseSearchTerms('  newton   Law newton '), ['newton', 'Law']);
      expect(parseSearchTerms('   '), isEmpty);
    });
  });

  group('escapeLike', () {
    test('escapes LIKE wildcards and backslashes', () {
      expect(escapeLike('50%_off'), r'50\%\_off');
      expect(escapeLike(r'a\b'), r'a\\b');
    });
  });

  group('buildSnippet', () {
    test('centers on the first match with ellipses', () {
      final content = '${'x' * 200} needle ${'y' * 200}';
      final s = buildSnippet(content, ['needle']);
      expect(s, contains('needle'));
      expect(s.startsWith('…'), isTrue);
      expect(s.endsWith('…'), isTrue);
    });

    test('is case-insensitive and collapses whitespace', () {
      expect(
          buildSnippet('Line one\n\nLine   TWO', ['two']), 'Line one Line TWO');
    });

    test('falls back to the start when nothing matches', () {
      expect(buildSnippet('hello world', ['zzz']), 'hello world');
    });

    test('handles LaTeX and regex metacharacters in terms', () {
      expect(buildSnippet(r'energy is $E=mc^2$ here', [r'$E=mc^2$']),
          contains(r'$E=mc^2$'));
    });
  });

  group('buildHighlightPattern', () {
    test('returns null for no terms and prefers longer terms', () {
      expect(buildHighlightPattern([]), isNull);
      final p = buildHighlightPattern(['phys', 'physics'])!;
      expect(p.firstMatch('Physics')!.group(0), 'Physics');
    });
  });
}
