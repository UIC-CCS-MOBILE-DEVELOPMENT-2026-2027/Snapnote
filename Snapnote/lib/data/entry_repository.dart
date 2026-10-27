import '../models/entry.dart';
import '../services/image_storage_service.dart';
import 'database_helper.dart';

/// Thin repository around [DatabaseHelper] for [Entry] CRUD.
class EntryRepository {
  EntryRepository({DatabaseHelper? db, ImageStorageService? imageService})
      : _db = db ?? DatabaseHelper.instance,
        _imageService = imageService ?? ImageStorageService();

  final DatabaseHelper _db;
  final ImageStorageService _imageService;

  Future<Entry> create({
    required int subjectId,
    required String content,
    String? sourceImagePath,
  }) {
    final now = DateTime.now();
    return _db.createEntry(
      Entry(
        subjectId: subjectId,
        content: content,
        sourceImagePath: sourceImagePath,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<List<Entry>> getForSubject(int subjectId) {
    return _db.getEntriesForSubject(subjectId);
  }

  Future<Entry?> getById(int id) => _db.getEntry(id);

  Future<void> update(
    Entry entry, {
    required String newContent,
    String? newSourceImagePath,
  }) {
    // copyWith's own `?? this.x` fallback means omitting
    // newSourceImagePath (leaving it null) keeps the entry's existing
    // image path — callers don't need to pass it just to leave it alone.
    return _db
        .updateEntry(entry.copyWith(
          content: newContent,
          sourceImagePath: newSourceImagePath,
          updatedAt: DateTime.now(),
        ))
        .then((_) {});
  }

  Future<void> delete(int id) async {
    final entry = await _db.getEntry(id);
    await _db.deleteEntry(id);
    if (entry?.sourceImagePath != null) {
      await _imageService.deleteImage(entry!.sourceImagePath);
    }
  }
}
