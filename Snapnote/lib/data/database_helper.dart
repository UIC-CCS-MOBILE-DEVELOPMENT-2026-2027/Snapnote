import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/entry.dart';
import '../models/subject.dart';

/// Singleton wrapper around a local sqflite database.
///
/// Everything lives on-device only — there is no network sync and no
/// user account. Deleting the app deletes the data.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const _dbName = 'subject_notes.db';
  static const _dbVersion = 1;

  static const tableSubjects = 'subjects';
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
          CREATE TABLE $tableEntries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subjectId INTEGER NOT NULL,
            content TEXT NOT NULL,
            sourceImagePath TEXT,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            FOREIGN KEY (subjectId) REFERENCES $tableSubjects (id)
              ON DELETE CASCADE
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_entries_subjectId ON $tableEntries (subjectId)',
        );
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

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
