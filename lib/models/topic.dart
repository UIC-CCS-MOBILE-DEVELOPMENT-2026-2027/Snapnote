/// A topic/lesson inside a [Subject], e.g. "Quadratic Equations" under
/// "Math". Entries can optionally belong to one topic.
class Topic {
  final int? id;
  final int subjectId;
  final String name;
  final DateTime createdAt;

  const Topic({
    this.id,
    required this.subjectId,
    required this.name,
    required this.createdAt,
  });

  Topic copyWith({int? id, int? subjectId, String? name, DateTime? createdAt}) {
    return Topic(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'subjectId': subjectId,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Topic.fromMap(Map<String, dynamic> map) {
    return Topic(
      id: map['id'] as int?,
      subjectId: map['subjectId'] as int,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  @override
  String toString() => 'Topic(id: $id, subjectId: $subjectId, name: $name)';
}
