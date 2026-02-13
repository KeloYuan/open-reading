import 'package:sqflite/sqflite.dart';

import '../data/reader_models.dart';
import '../paginator/page_plan.dart';
import '../../services/core/database_service.dart';

class ReaderStorage {
  ReaderStorage({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService();

  final DatabaseService _databaseService;
  bool _initialized = false;

  Future<Database> get _db async {
    final db = await _databaseService.database;
    if (!_initialized) {
      await _ensureTables(db);
      _initialized = true;
    }
    return db;
  }

  Future<void> _ensureTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reader_books(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        file_path TEXT NOT NULL,
        format TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS reader_chapters(
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        title TEXT NOT NULL,
        chapter_order INTEGER NOT NULL,
        content TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS reader_annotations(
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        chapter_id TEXT NOT NULL,
        start_offset INTEGER NOT NULL,
        end_offset INTEGER NOT NULL,
        color INTEGER NOT NULL,
        note_text TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS reader_positions(
        book_id TEXT PRIMARY KEY,
        chapter_id TEXT NOT NULL,
        anchor_offset INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS reader_pagination_cache(
        cache_key TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        chapter_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> saveBook(Book book) async {
    final db = await _db;
    await db.insert(
      'reader_books',
      {
        'id': book.id,
        'title': book.title,
        'author': book.author,
        'file_path': book.filePath,
        'format': book.format,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveChapters(List<Chapter> chapters) async {
    if (chapters.isEmpty) return;
    final db = await _db;
    await db.transaction((txn) async {
      for (final chapter in chapters) {
        await txn.insert(
          'reader_chapters',
          {
            'id': chapter.id,
            'book_id': chapter.bookId,
            'title': chapter.title,
            'chapter_order': chapter.order,
            'content': chapter.content,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> saveAnnotation(Annotation annotation) async {
    final db = await _db;
    await db.insert(
      'reader_annotations',
      annotation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Annotation>> listAnnotations({
    required String bookId,
    required String chapterId,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'reader_annotations',
      where: 'book_id = ? AND chapter_id = ?',
      whereArgs: [bookId, chapterId],
      orderBy: 'start_offset ASC',
    );

    return rows.map((e) => Annotation.fromMap(e)).toList();
  }

  Future<void> saveReadingPosition({
    required String bookId,
    required ReadingPosition position,
  }) async {
    final db = await _db;
    await db.insert(
      'reader_positions',
      position.toMap(bookId),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ReadingPosition?> getReadingPosition(String bookId) async {
    final db = await _db;
    final rows = await db.query(
      'reader_positions',
      where: 'book_id = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return ReadingPosition.fromMap(rows.first);
  }

  Future<void> savePaginationCache({
    required String cacheKey,
    required String bookId,
    required String chapterId,
    required PagePlan plan,
  }) async {
    final db = await _db;
    await db.insert(
      'reader_pagination_cache',
      {
        'cache_key': cacheKey,
        'book_id': bookId,
        'chapter_id': chapterId,
        'payload': plan.toJson(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<PagePlan?> getPaginationCache(String cacheKey) async {
    final db = await _db;
    final rows = await db.query(
      'reader_pagination_cache',
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }

    final payload = rows.first['payload'] as String;
    return PagePlan.fromJson(payload);
  }
}
