import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/entry.dart';
import '../models/entry_search_result.dart';
import '../models/subject.dart';
import '../models/topic.dart';
import '../utils/search_utils.dart';

/// Singleton wrapper around a local sqflite database.
///
/// Everything lives on-device only — there is no network sync and no
/// user account. Deleting the app deletes the data.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const _dbName = 'subject_notes.db';
  static const _dbVersion = 2;

  static const tableSubjects = 'subjects';
  static const tableTopics = 'topics';
  static const tableEntries = 'entries';

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final dbPath = p.join(directory.path, _dbName);

    return openDatabase(
      dbPath,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableSubjects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            createdAt TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE $tableTopics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subjectId INTEGER NOT NULL,
            name TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            FOREIGN KEY (subjectId) REFERENCES $tableSubjects (id)
              ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE $tableEntries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subjectId INTEGER NOT NULL,
            topicId INTEGER,
            content TEXT NOT NULL,
            sourceImagePath TEXT,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            FOREIGN KEY (subjectId) REFERENCES $tableSubjects (id)
              ON DELETE CASCADE,
            FOREIGN KEY (topicId) REFERENCES $tableTopics (id)
              ON DELETE SET NULL
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_entries_subjectId ON $tableEntries (subjectId)',
        );
        await db.execute(
          'CREATE INDEX idx_entries_topicId ON $tableEntries (topicId)',
        );
        await db.execute(
          'CREATE INDEX idx_topics_subjectId ON $tableTopics (subjectId)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v1 -> v2: add topics. Existing entries keep working with a NULL
        // topicId ("No topic"); no data is rewritten.
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE $tableTopics (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              subjectId INTEGER NOT NULL,
              name TEXT NOT NULL,
              createdAt TEXT NOT NULL,
              FOREIGN KEY (subjectId) REFERENCES $tableSubjects (id)
                ON DELETE CASCADE
            )
          ''');
          await db.execute(
            'ALTER TABLE $tableEntries ADD COLUMN topicId INTEGER '
            'REFERENCES $tableTopics (id) ON DELETE SET NULL',
          );
          await db.execute(
            'CREATE INDEX idx_entries_topicId ON $tableEntries (topicId)',
          );
          await db.execute(
            'CREATE INDEX idx_topics_subjectId ON $tableTopics (subjectId)',
          );
        }
      },
    );
  }

  // ---------------------------------------------------------------------
  // Subject CRUD
  // ---------------------------------------------------------------------

  Future<Subject> createSubject(Subject subject) async {
    final db = await database;
    final id = await db.insert(tableSubjects, subject.toMap()..remove('id'));
    return subject.copyWith(id: id);
  }

  Future<List<Subject>> getAllSubjects() async {
    final db = await database;
    final rows = await db.query(tableSubjects, orderBy: 'createdAt DESC');
    return rows.map(Subject.fromMap).toList();
  }

  Future<Subject?> getSubject(int id) async {
    final db = await database;
    final rows = await db.query(
      tableSubjects,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Subject.fromMap(rows.first);
  }

  Future<int> updateSubject(Subject subject) async {
    if (subject.id == null) {
      throw ArgumentError('Cannot update a Subject without an id');
    }
    final db = await database;
    return db.update(
      tableSubjects,
      subject.toMap(),
      where: 'id = ?',
      whereArgs: [subject.id],
    );
  }

  /// Deletes the subject and, via ON DELETE CASCADE, all of its entries.
  Future<int> deleteSubject(int id) async {
    final db = await database;
    return db.delete(tableSubjects, where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------
  // Topic CRUD
  // ---------------------------------------------------------------------

  Future<Topic> createTopic(Topic topic) async {
    final db = await database;
    final id = await db.insert(tableTopics, topic.toMap()..remove('id'));
    return topic.copyWith(id: id);
  }

  Future<List<Topic>> getTopicsForSubject(int subjectId) async {
    final db = await database;
    final rows = await db.query(
      tableTopics,
      where: 'subjectId = ?',
      whereArgs: [subjectId],
      orderBy: 'createdAt ASC',
    );
    return rows.map(Topic.fromMap).toList();
  }

  Future<int> updateTopic(Topic topic) async {
    if (topic.id == null) {
      throw ArgumentError('Cannot update a Topic without an id');
    }
    final db = await database;
    return db.update(
      tableTopics,
      topic.toMap(),
      where: 'id = ?',
      whereArgs: [topic.id],
    );
  }

  /// Deletes the topic; its entries survive with topicId set to NULL.
  Future<int> deleteTopic(int id) async {
    final db = await database;
    return db.delete(tableTopics, where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------
  // Entry CRUD
  // ---------------------------------------------------------------------

  Future<Entry> createEntry(Entry entry) async {
    final db = await database;
    final id = await db.insert(tableEntries, entry.toMap()..remove('id'));
    return entry.copyWith(id: id);
  }

  Future<List<Entry>> getEntriesForSubject(int subjectId) async {
    final db = await database;
    final rows = await db.query(
      tableEntries,
      where: 'subjectId = ?',
      whereArgs: [subjectId],
      orderBy: 'createdAt ASC',
    );
    return rows.map(Entry.fromMap).toList();
  }

  Future<Entry?> getEntry(int id) async {
    final db = await database;
    final rows = await db.query(
      tableEntries,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Entry.fromMap(rows.first);
  }

  Future<int> updateEntry(Entry entry) async {
    if (entry.id == null) {
      throw ArgumentError('Cannot update an Entry without an id');
    }
    final db = await database;
    return db.update(
      tableEntries,
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> deleteEntry(int id) async {
    final db = await database;
    return db.delete(tableEntries, where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------

  /// Finds entries across all subjects. Every term must match the entry's
  /// content, its subject's name, or its topic's name (AND across terms), so
  /// typing a subject or topic name lists its entries. Newest-updated first.
  ///
  /// Note: SQLite's LIKE is case-insensitive for ASCII only; accented or
  /// non-Latin letters match case-sensitively.
  Future<List<EntrySearchResult>> searchEntries(
    List<String> terms, {
    int limit = 100,
  }) async {
    if (terms.isEmpty) return const [];
    final db = await database;

    final clauses = <String>[];
    final args = <Object?>[];
    for (final term in terms) {
      clauses.add(
        r"(e.content LIKE ? ESCAPE '\' OR s.name LIKE ? ESCAPE '\' "
        r"OR t.name LIKE ? ESCAPE '\')",
      );
      final pattern = '%${escapeLike(term)}%';
      args..add(pattern)..add(pattern)..add(pattern);
    }

    final rows = await db.rawQuery(
      '''
      SELECT e.*, s.name AS subjectName, t.name AS topicName
      FROM $tableEntries e
      INNER JOIN $tableSubjects s ON s.id = e.subjectId
      LEFT JOIN $tableTopics t ON t.id = e.topicId
      WHERE ${clauses.join(' AND ')}
      ORDER BY e.updatedAt DESC
      LIMIT $limit
      ''',
      args,
    );

    return rows
        .map((row) => EntrySearchResult(
              entry: Entry.fromMap(row),
              subjectName: row['subjectName'] as String,
              topicName: row['topicName'] as String?,
            ))
        .toList();
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
