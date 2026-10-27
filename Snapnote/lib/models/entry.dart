/// A single note/entry belonging to a [Subject].
///
/// [content] is stored as plain text/Markdown-like text where math is
/// preserved using LaTeX delimiters: `$...$` for inline math and
/// `$$...$$` for block/display math. Rendering is handled by
/// flutter_math_fork wherever this content is displayed.
class Entry {
  final int? id;
  final int subjectId;
  final String content;

  /// Path to the source photo on device storage, if this entry originated
  /// from a transcribed image. Null for manually typed entries.
  final String? sourceImagePath;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Entry({
    this.id,
    required this.subjectId,
    required this.content,
    this.sourceImagePath,
    required this.createdAt,
    required this.updatedAt,
  });

  Entry copyWith({
    int? id,
    int? subjectId,
    String? content,
    String? sourceImagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Entry(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      content: content ?? this.content,
      sourceImagePath: sourceImagePath ?? this.sourceImagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectId': subjectId,
      'content': content,
      'sourceImagePath': sourceImagePath,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Entry.fromMap(Map<String, dynamic> map) {
    return Entry(
      id: map['id'] as int?,
      subjectId: map['subjectId'] as int,
      content: map['content'] as String,
      sourceImagePath: map['sourceImagePath'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  @override
  String toString() =>
      'Entry(id: $id, subjectId: $subjectId, updatedAt: $updatedAt)';
}
