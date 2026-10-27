import '../models/subject.dart';
import 'database_helper.dart';

/// Thin repository around [DatabaseHelper] for [Subject] CRUD.
/// Screens/widgets should depend on this, not on the DB helper directly.
class SubjectRepository {
  SubjectRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  Future<Subject> create(String name) {
    return _db.createSubject(
      Subject(name: name, createdAt: DateTime.now()),
    );
  }

  Future<List<Subject>> getAll() => _db.getAllSubjects();

  Future<Subject?> getById(int id) => _db.getSubject(id);

  Future<void> rename(Subject subject, String newName) {
    return _db.updateSubject(subject.copyWith(name: newName)).then((_) {});
  }

  Future<void> delete(int id) => _db.deleteSubject(id).then((_) {});
}
