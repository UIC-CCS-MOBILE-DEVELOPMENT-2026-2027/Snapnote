/// A top-level grouping for notes, e.g. "Calculus II" or "Organic Chemistry".
class Subject {
  final int? id;
  final String name;
  final DateTime createdAt;

  const Subject({
    this.id,
    required this.name,
    required this.createdAt,
  });

  Subject copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
  }) {
    return Subject(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  @override
  String toString() => 'Subject(id: $id, name: $name, createdAt: $createdAt)';
}
