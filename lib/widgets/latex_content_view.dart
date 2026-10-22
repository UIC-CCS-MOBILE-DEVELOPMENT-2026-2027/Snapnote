import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Renders [content] as plain text, except that math segments delimited by
/// `$$...$$` (block) or `$...$` (inline) are rendered with flutter_math_fork.
///
/// This is intentionally a small hand-rolled parser rather than a full
/// Markdown pipeline, since the only special syntax this app needs is LaTeX
/// math delimiters.
class LatexContentView extends StatelessWidget {
  const LatexContentView({
    super.key,
    required this.content,
    this.style,
  });

  final String content;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final segments = _parseSegments(content);

    // Block math can't live inside the Wrap below: Wrap hands its children
    // unbounded constraints along the main axis, and a SizedBox(width:
    // infinity) — or anything else that asks to fill available width —
    // throws under that combination. So instead we walk the segments and
    // build a Column: consecutive text/inline-math segments are batched
    // into one Wrap each (which *is* safe, since none of those children
    // demand infinite width), and every block-math segment flushes the
    // current run and becomes its own full-width Column child.
    final children = <Widget>[];
    final currentRun = <Widget>[];

    void flushRun() {
      if (currentRun.isEmpty) return;
      children.add(Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: List.of(currentRun),
      ));
      currentRun.clear();
    }

    for (final segment in segments) {
      if (segment.type == _SegmentType.blockMath) {
        flushRun();
        children.add(_buildBlockMath(segment, baseStyle));
      } else {
        currentRun.add(_buildInlineSegment(segment, baseStyle));
      }
    }
    flushRun();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildInlineSegment(_ContentSegment segment, TextStyle baseStyle) {
    switch (segment.type) {
      case _SegmentType.text:
        return Text(segment.text, style: baseStyle);
      case _SegmentType.inlineMath:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Math.tex(
            segment.text,
            textStyle: baseStyle,
            onErrorFallback: (err) => Text(
              '\$${segment.text}\$',
              style: baseStyle.copyWith(color: Colors.red),
            ),
          ),
        );
      case _SegmentType.blockMath:
        // Never reached: build() intercepts blockMath before calling this.
        throw StateError('blockMath must not reach _buildInlineSegment');
    }
  }

 Widget _buildBlockMath(_ContentSegment segment, TextStyle baseStyle) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Math.tex(
        segment.text,
        textStyle: baseStyle,
        onErrorFallback: (err) => Text(
          '\$\$${segment.text}\$\$',
          style: baseStyle.copyWith(color: Colors.red),
        ),
      ),
    ),
  );
}

  List<_ContentSegment> _parseSegments(String input) {
    final segments = <_ContentSegment>[];
    final pattern = RegExp(r'\$\$(.+?)\$\$|\$(.+?)\$', dotAll: true);

    int lastEnd = 0;
    for (final match in pattern.allMatches(input)) {
      if (match.start > lastEnd) {
        segments.add(_ContentSegment(
          _SegmentType.text,
          input.substring(lastEnd, match.start),
        ));
      }

      final blockMatch = match.group(1);
      final inlineMatch = match.group(2);
      if (blockMatch != null) {
        segments
            .add(_ContentSegment(_SegmentType.blockMath, blockMatch.trim()));
      } else if (inlineMatch != null) {
        segments
            .add(_ContentSegment(_SegmentType.inlineMath, inlineMatch.trim()));
      }

      lastEnd = match.end;
    }

    if (lastEnd < input.length) {
      segments
          .add(_ContentSegment(_SegmentType.text, input.substring(lastEnd)));
    }

    return segments;
  }
}

enum _SegmentType { text, inlineMath, blockMath }

class _ContentSegment {
  const _ContentSegment(this.type, this.text);
  final _SegmentType type;
  final String text;
}
