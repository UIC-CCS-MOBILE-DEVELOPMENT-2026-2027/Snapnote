import '../models/topic.dart';
import 'database_helper.dart';

/// Thin repository around [DatabaseHelper] for [Topic] CRUD.
class TopicRepository {
  TopicRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  Future<Topic> create(int subjectId, String name) {
    return _db.createTopic(
      Topic(subjectId: subjectId, name: name, createdAt: DateTime.now()),
    );
  }

  /// Oldest first, so topics read in the order the lessons were added.
  Future<List<Topic>> getForSubject(int subjectId) {
    return _db.getTopicsForSubject(subjectId);
  }

  Future<void> rename(Topic topic, String newName) {
    return _db.updateTopic(topic.copyWith(name: newName)).then((_) {});
  }

  /// Deletes only the topic. Its entries are kept and become "No topic"
  /// (ON DELETE SET NULL).
  Future<void> delete(int id) => _db.deleteTopic(id).then((_) {});
}
