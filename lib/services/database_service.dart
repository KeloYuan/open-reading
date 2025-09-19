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
  static const int _dbVersion = 6; // <-- Version incremented for cover image path

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath;
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
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
      await db.execute('ALTER TABLE books ADD COLUMN totalPages INTEGER DEFAULT 1');
    }
    if (oldVersion < 4) {
      // Check if notes table exists before creating
      final notesTableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='notes'"
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
        "SELECT name FROM sqlite_master WHERE type='table' AND name='highlights'"
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
      await db.execute('ALTER TABLE books ADD COLUMN file_modified_time INTEGER');
      await db.execute('ALTER TABLE books ADD COLUMN content_hash TEXT');
      await db.execute('ALTER TABLE books ADD COLUMN table_of_contents TEXT');
    }
    if (oldVersion < 6) {
      // Add cover image path field to books table
      await db.execute('ALTER TABLE books ADD COLUMN cover_image_path TEXT');
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