import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;
  static const String _dbName = 'xxread_v2.db';
  static const int _dbVersion = 8;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath;
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      // 桌面平台使用 path_provider
      final appDocDir = await getApplicationDocumentsDirectory();
      dbPath = appDocDir.path;
    } else {
      // 移动平台使用 sqflite 的默认路径
      dbPath = await getDatabasesPath();
    }

    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE reading_stats(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          durationInSeconds INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE books ADD COLUMN totalPages INTEGER DEFAULT 1',
      );
    }
    if (oldVersion < 4) {
      // Check if notes table exists before creating
      final notesTableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='notes'",
      );
      if (notesTableExists.isEmpty) {
        await db.execute('''
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bookId INTEGER NOT NULL,
            pageNumber INTEGER NOT NULL,
            selectedText TEXT NOT NULL,
            noteText TEXT NOT NULL,
            createDate INTEGER NOT NULL,
            updateDate INTEGER,
            FOREIGN KEY (bookId) REFERENCES books (id) ON DELETE CASCADE
          )
        ''');
      }

      // Check if highlights table exists before creating
      final highlightsTableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='highlights'",
      );
      if (highlightsTableExists.isEmpty) {
        await db.execute('''
          CREATE TABLE highlights(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bookId INTEGER NOT NULL,
            pageNumber INTEGER NOT NULL,
            selectedText TEXT NOT NULL,
            startOffset INTEGER NOT NULL,
            endOffset INTEGER NOT NULL,
            colorValue INTEGER NOT NULL,
            createDate INTEGER NOT NULL,
            FOREIGN KEY (bookId) REFERENCES books (id) ON DELETE CASCADE
          )
        ''');
      }
    }
    if (oldVersion < 5) {
      // Add content caching fields to books table
      await db.execute('ALTER TABLE books ADD COLUMN cached_content TEXT');
      await db.execute('ALTER TABLE books ADD COLUMN cached_pages TEXT');
      await db.execute(
        'ALTER TABLE books ADD COLUMN file_modified_time INTEGER',
      );
      await db.execute('ALTER TABLE books ADD COLUMN content_hash TEXT');
      await db.execute('ALTER TABLE books ADD COLUMN table_of_contents TEXT');
    }
    if (oldVersion < 6) {
      // Add cover image path field to books table
      await db.execute('ALTER TABLE books ADD COLUMN cover_image_path TEXT');
    }
    if (oldVersion < 7) {
      // Create unified book_notes table
      await db.execute('''
        CREATE TABLE book_notes(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          book_id INTEGER NOT NULL,
          content TEXT NOT NULL,
          cfi TEXT NOT NULL,
          chapter TEXT NOT NULL,
          type TEXT NOT NULL,
          color TEXT NOT NULL,
          reader_note TEXT,
          page_number INTEGER,
          start_offset INTEGER,
          end_offset INTEGER,
          create_time TEXT,
          update_time TEXT NOT NULL,
          FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
        )
      ''');

      // Migrate data from highlights table
      final highlightsData = await db.query('highlights');
      for (final highlight in highlightsData) {
        await db.insert('book_notes', {
          'book_id': highlight['bookId'],
          'content': highlight['selectedText'],
          'cfi':
              'offset-${highlight['startOffset']}-${highlight['endOffset']}', // Generate CFI
          'chapter': 'Unknown Chapter',
          'type': 'highlight',
          'color': _intToHexColor(highlight['colorValue'] as int),
          'reader_note': null,
          'page_number': highlight['pageNumber'],
          'start_offset': highlight['startOffset'],
          'end_offset': highlight['endOffset'],
          'create_time': DateTime.fromMillisecondsSinceEpoch(
            highlight['createDate'] as int,
          ).toIso8601String(),
          'update_time': DateTime.fromMillisecondsSinceEpoch(
            highlight['createDate'] as int,
          ).toIso8601String(),
        });
      }

      // Migrate data from notes table
      final notesData = await db.query('notes');
      for (final note in notesData) {
        await db.insert('book_notes', {
          'book_id': note['bookId'],
          'content': note['selectedText'],
          'cfi':
              'page-${note['pageNumber']}', // Generate CFI for page-based notes
          'chapter': 'Unknown Chapter',
          'type': 'note',
          'color': '66CCFF', // Default color
          'reader_note': note['noteText'],
          'page_number': note['pageNumber'],
          'start_offset': null,
          'end_offset': null,
          'create_time': DateTime.fromMillisecondsSinceEpoch(
            note['createDate'] as int,
          ).toIso8601String(),
          'update_time': note['updateDate'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  note['updateDate'] as int,
                ).toIso8601String()
              : DateTime.fromMillisecondsSinceEpoch(
                  note['createDate'] as int,
                ).toIso8601String(),
        });
      }

      // Drop old tables after migration
      await db.execute('DROP TABLE IF EXISTS highlights');
      await db.execute('DROP TABLE IF EXISTS notes');
    }

    // Version 8: Add book_sources table for advanced book source system
    if (oldVersion < 8) {
      await _createBookSourcesTable(db);
    }
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE books(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT,
        filePath TEXT NOT NULL,
        format TEXT NOT NULL,
        currentPage INTEGER DEFAULT 0,
        totalPages INTEGER DEFAULT 1,
        importDate INTEGER NOT NULL,
        cached_content TEXT,
        cached_pages TEXT,
        file_modified_time INTEGER,
        content_hash TEXT,
        table_of_contents TEXT,
        cover_image_path TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE bookmarks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookId INTEGER NOT NULL,
        pageNumber INTEGER NOT NULL,
        note TEXT,
        createDate INTEGER NOT NULL,
        FOREIGN KEY (bookId) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE reading_stats(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        durationInSeconds INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE book_notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        content TEXT NOT NULL,
        cfi TEXT NOT NULL,
        chapter TEXT NOT NULL,
        type TEXT NOT NULL,
        color TEXT NOT NULL,
        reader_note TEXT,
        page_number INTEGER,
        start_offset INTEGER,
        end_offset INTEGER,
        create_time TEXT,
        update_time TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');

    // Create book_sources table for advanced book source system
    await _createBookSourcesTable(db);
  }

  /// 创建书源表
  Future<void> _createBookSourcesTable(Database db) async {
    await db.execute('''
      CREATE TABLE book_sources (
        id TEXT PRIMARY KEY,
        book_source_name TEXT NOT NULL,
        book_source_group TEXT NOT NULL DEFAULT '',
        book_source_comment TEXT NOT NULL DEFAULT '',
        book_source_type INTEGER NOT NULL DEFAULT 0,
        book_source_url TEXT NOT NULL,
        book_source_version INTEGER NOT NULL DEFAULT 1,
        enabled INTEGER NOT NULL DEFAULT 1,
        enabled_explore INTEGER NOT NULL DEFAULT 1,
        last_update_time INTEGER NOT NULL,
        weight INTEGER NOT NULL DEFAULT 0,
        rule_search TEXT,
        rule_explore TEXT,
        rule_book_info TEXT,
        rule_toc TEXT,
        rule_content TEXT,
        variable_map TEXT,
        http_config TEXT,
        header TEXT,
        login_url TEXT,
        login_ui TEXT,
        respond_time INTEGER NOT NULL DEFAULT 180000,
        created_time INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
        updated_time INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
      )
    ''');

    // Create indexes for better performance
    await db.execute(
      'CREATE INDEX idx_book_source_name ON book_sources (book_source_name)',
    );
    await db.execute(
      'CREATE INDEX idx_book_source_group ON book_sources (book_source_group)',
    );
    await db.execute(
      'CREATE INDEX idx_book_source_enabled ON book_sources (enabled)',
    );
    await db.execute(
      'CREATE INDEX idx_book_source_type ON book_sources (book_source_type)',
    );
  }

  /// 将整数颜色值转换为十六进制字符串（不含#前缀）
  String _intToHexColor(int colorValue) {
    return colorValue
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2)
        .toUpperCase();
  }
}
