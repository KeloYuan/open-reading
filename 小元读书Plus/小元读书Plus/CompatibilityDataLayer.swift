import Foundation
import SQLite3
import CryptoKit

struct BookRecord: Identifiable, Hashable, Codable {
    let id: Int64
    var title: String
    var author: String
    var filePath: String
    var format: String
    var currentPage: Int
    var totalPages: Int
    var cachedContent: String
    var cachedPages: String
    var contentHash: String?
    var coverImagePath: String?
    var textEncoding: String?
    var lastReadTime: Int64
}

struct BookmarkRecord: Identifiable, Hashable, Codable {
    let id: Int64
    let bookID: Int64
    let pageIndex: Int
    let chapterTitle: String?
    let createdAt: Int64
}

struct NoteRecord: Identifiable, Hashable, Codable {
    let id: Int64
    let bookID: Int64
    let pageIndex: Int
    let content: String
    let noteType: String
    let color: String?
    let createdAt: Int64
}

struct ReadingStatRecord: Identifiable, Hashable, Codable {
    let id: Int64
    let bookID: Int64
    let date: String
    let durationSeconds: Int
    let pagesRead: Int
}

struct BookSourceRecord: Identifiable, Hashable, Codable {
    let id: Int64
    let sourceName: String
    let sourceURL: String
    let enabled: Bool
    let createdAt: Int64
}

enum DatabaseError: LocalizedError {
    case openFailed
    case executeFailed(String)
    case prepareFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed:
            return "数据库打开失败"
        case let .executeFailed(message):
            return "数据库执行失败: \(message)"
        case let .prepareFailed(message):
            return "数据库预编译失败: \(message)"
        }
    }
}

final class LegacyDatabaseService {
    static let shared = LegacyDatabaseService()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.xiaoyuan.plus.sqlite")
    private var isReady = false

    private init() {}

    func initializeIfNeeded() throws {
        try queue.sync {
            try ensureReadyLocked()
        }
    }

    func sync<T>(_ block: (OpaquePointer) throws -> T) throws -> T {
        try queue.sync {
            try ensureReadyLocked()
            guard let db else { throw DatabaseError.openFailed }
            return try block(db)
        }
    }

    private func ensureReadyLocked() throws {
        if isReady { return }
        try openDatabase()
        try createSchemaIfNeeded()
        isReady = true
    }

    private func openDatabase() throws {
        let url = try databaseURL()
        if sqlite3_open(url.path, &db) != SQLITE_OK {
            throw DatabaseError.openFailed
        }
        sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA foreign_keys=ON;", nil, nil, nil)
    }

    private func databaseURL() throws -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("xxread_v2.db")
    }

    private func createSchemaIfNeeded() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS books (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            author TEXT,
            file_path TEXT UNIQUE,
            format TEXT,
            current_page INTEGER DEFAULT 0,
            total_pages INTEGER DEFAULT 0,
            cached_content TEXT,
            cached_pages TEXT,
            content_hash TEXT,
            cover_image_path TEXT,
            text_encoding TEXT,
            last_read_time INTEGER DEFAULT 0,
            created_at INTEGER DEFAULT (strftime('%s','now')),
            updated_at INTEGER DEFAULT (strftime('%s','now'))
        );

        CREATE TABLE IF NOT EXISTS bookmarks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book_id INTEGER NOT NULL,
            page_index INTEGER NOT NULL,
            chapter_title TEXT,
            created_at INTEGER DEFAULT (strftime('%s','now'))
        );

        CREATE TABLE IF NOT EXISTS book_notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book_id INTEGER NOT NULL,
            page_index INTEGER NOT NULL,
            content TEXT NOT NULL,
            note_type TEXT DEFAULT 'note',
            color TEXT,
            created_at INTEGER DEFAULT (strftime('%s','now'))
        );

        CREATE TABLE IF NOT EXISTS reading_stats (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            duration_seconds INTEGER DEFAULT 0,
            pages_read INTEGER DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS book_sources (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            source_name TEXT NOT NULL,
            source_url TEXT NOT NULL,
            enabled INTEGER DEFAULT 1,
            created_at INTEGER DEFAULT (strftime('%s','now'))
        );

        CREATE INDEX IF NOT EXISTS idx_books_file_path ON books(file_path);
        CREATE INDEX IF NOT EXISTS idx_bookmarks_book_id ON bookmarks(book_id);
        CREATE INDEX IF NOT EXISTS idx_notes_book_id ON book_notes(book_id);
        CREATE INDEX IF NOT EXISTS idx_stats_book_id ON reading_stats(book_id);
        CREATE INDEX IF NOT EXISTS idx_sources_enabled ON book_sources(enabled);
        """
        try executeBatch(sql)
    }

    func executeBatch(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.executeFailed(msg)
        }
    }
}

final class BookSourceRepository {
    private let database: LegacyDatabaseService

    init(database: LegacyDatabaseService = .shared) {
        self.database = database
    }

    func fetchAll() throws -> [BookSourceRecord] {
        try database.sync { db in
            let sql = "SELECT id, source_name, source_url, enabled, created_at FROM book_sources ORDER BY id DESC;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }

            var items: [BookSourceRecord] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                items.append(
                    BookSourceRecord(
                        id: sqlite3_column_int64(stmt, 0),
                        sourceName: sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? "",
                        sourceURL: sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? "",
                        enabled: sqlite3_column_int64(stmt, 3) == 1,
                        createdAt: sqlite3_column_int64(stmt, 4)
                    )
                )
            }
            return items
        }
    }

    func add(name: String, url: String) throws {
        _ = try database.sync { db in
            let sql = "INSERT INTO book_sources (source_name, source_url, enabled, created_at) VALUES (?, ?, 1, strftime('%s','now'));"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, (name as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (url as NSString).utf8String, -1, nil)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
            }
            return 0
        }
    }

    func setEnabled(id: Int64, enabled: Bool) throws {
        _ = try database.sync { db in
            let sql = "UPDATE book_sources SET enabled = ? WHERE id = ?;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, enabled ? 1 : 0)
            sqlite3_bind_int64(stmt, 2, id)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
            }
            return 0
        }
    }

    func delete(id: Int64) throws {
        _ = try database.sync { db in
            let sql = "DELETE FROM book_sources WHERE id = ?;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, id)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
            }
            return 0
        }
    }

    func merge(_ records: [BookSourceRecord]) throws {
        for item in records {
            _ = try database.sync { db in
                let sql = """
                INSERT INTO book_sources (source_name, source_url, enabled, created_at)
                SELECT ?, ?, ?, ?
                WHERE NOT EXISTS (
                    SELECT 1 FROM book_sources
                    WHERE source_name = ? AND source_url = ?
                );
                """
                var stmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                    throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
                }
                defer { sqlite3_finalize(stmt) }
                sqlite3_bind_text(stmt, 1, (item.sourceName as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (item.sourceURL as NSString).utf8String, -1, nil)
                sqlite3_bind_int64(stmt, 3, item.enabled ? 1 : 0)
                sqlite3_bind_int64(stmt, 4, item.createdAt)
                sqlite3_bind_text(stmt, 5, (item.sourceName as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 6, (item.sourceURL as NSString).utf8String, -1, nil)
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
                }
                return 0
            }
        }
    }
}

final class BookRepository {
    private let database: LegacyDatabaseService

    init(database: LegacyDatabaseService = .shared) {
        self.database = database
    }

    func fetchAllBooks() throws -> [BookRecord] {
        try database.sync { db in
            let sql = """
            SELECT id, title, author, file_path, format, current_page, total_pages,
                     IFNULL(cached_content, ''), IFNULL(cached_pages, ''), content_hash, cover_image_path,
                     text_encoding, IFNULL(last_read_time, 0)
            FROM books
            ORDER BY created_at DESC;
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }

            var items: [BookRecord] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                items.append(
                    BookRecord(
                        id: sqlite3_column_int64(stmt, 0),
                        title: String(cString: sqlite3_column_text(stmt, 1)),
                        author: sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? "未知作者",
                        filePath: sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? "",
                        format: sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? "txt",
                        currentPage: Int(sqlite3_column_int64(stmt, 5)),
                        totalPages: Int(sqlite3_column_int64(stmt, 6)),
                        cachedContent: sqlite3_column_text(stmt, 7).map { String(cString: $0) } ?? "",
                        cachedPages: sqlite3_column_text(stmt, 8).map { String(cString: $0) } ?? "",
                        contentHash: sqlite3_column_text(stmt, 9).map { String(cString: $0) },
                        coverImagePath: sqlite3_column_text(stmt, 10).map { String(cString: $0) },
                        textEncoding: sqlite3_column_text(stmt, 11).map { String(cString: $0) },
                        lastReadTime: sqlite3_column_int64(stmt, 12)
                    )
                )
            }
            return items
        }
    }

    func insertImportedBook(payload: ImportedBookPayload, storedPath: String) throws -> Int64 {
        try database.sync { db in
            let sql = """
            INSERT INTO books (title, author, file_path, format, current_page, total_pages, cached_content, cached_pages, content_hash, text_encoding, created_at, updated_at)
            VALUES (?, ?, ?, ?, 0, ?, ?, ?, ?, ?, strftime('%s','now'), strftime('%s','now'));
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, (payload.title as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (payload.author as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (storedPath as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (payload.format.rawValue as NSString).utf8String, -1, nil)
            sqlite3_bind_int64(stmt, 5, Int64(payload.estimatedPages))
            sqlite3_bind_text(stmt, 6, (payload.plainText as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 7, ("" as NSString).utf8String, -1, nil)
            let hash = payload.plainText.sha256()
            sqlite3_bind_text(stmt, 8, (hash as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 9, ("utf8" as NSString).utf8String, -1, nil)

            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
            }
            return sqlite3_last_insert_rowid(db)
        }
    }

    func findBookID(byContentHash hash: String) throws -> Int64? {
        try database.sync { db in
            let sql = "SELECT id FROM books WHERE content_hash = ? LIMIT 1;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, (hash as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                return sqlite3_column_int64(stmt, 0)
            }
            return nil
        }
    }

    func updateProgress(bookID: Int64, page: Int, totalPages: Int) throws {
        _ = try database.sync { db in
            let sql = """
            UPDATE books
            SET current_page = ?, total_pages = ?, last_read_time = strftime('%s','now'), updated_at = strftime('%s','now')
            WHERE id = ?;
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, Int64(page))
            sqlite3_bind_int64(stmt, 2, Int64(totalPages))
            sqlite3_bind_int64(stmt, 3, bookID)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
            }
            return 0
        }
    }

    func updatePaginationCache(bookID: Int64, cachedPages: String) throws {
        _ = try database.sync { db in
            let sql = """
            UPDATE books
            SET cached_pages = ?, updated_at = strftime('%s','now')
            WHERE id = ?;
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, (cachedPages as NSString).utf8String, -1, nil)
            sqlite3_bind_int64(stmt, 2, bookID)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
            }
            return 0
        }
    }

    func upsertSyncedBook(_ record: BookRecord) throws {
        _ = try database.sync { db in
            let sql = """
            INSERT INTO books (id, title, author, file_path, format, current_page, total_pages, cached_content, cached_pages, content_hash, cover_image_path, text_encoding, last_read_time, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, strftime('%s','now'), strftime('%s','now'))
            ON CONFLICT(file_path) DO UPDATE SET
                title = excluded.title,
                author = excluded.author,
                format = excluded.format,
                current_page = CASE WHEN excluded.current_page > books.current_page THEN excluded.current_page ELSE books.current_page END,
                total_pages = CASE WHEN excluded.total_pages > books.total_pages THEN excluded.total_pages ELSE books.total_pages END,
                cached_content = CASE WHEN length(excluded.cached_content) > length(books.cached_content) THEN excluded.cached_content ELSE books.cached_content END,
                cached_pages = CASE WHEN length(excluded.cached_pages) > length(books.cached_pages) THEN excluded.cached_pages ELSE books.cached_pages END,
                content_hash = COALESCE(excluded.content_hash, books.content_hash),
                cover_image_path = COALESCE(excluded.cover_image_path, books.cover_image_path),
                text_encoding = COALESCE(excluded.text_encoding, books.text_encoding),
                last_read_time = CASE WHEN excluded.last_read_time > books.last_read_time THEN excluded.last_read_time ELSE books.last_read_time END,
                updated_at = strftime('%s','now');
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_int64(stmt, 1, record.id)
            sqlite3_bind_text(stmt, 2, (record.title as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (record.author as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (record.filePath as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 5, (record.format as NSString).utf8String, -1, nil)
            sqlite3_bind_int64(stmt, 6, Int64(record.currentPage))
            sqlite3_bind_int64(stmt, 7, Int64(record.totalPages))
            sqlite3_bind_text(stmt, 8, (record.cachedContent as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 9, (record.cachedPages as NSString).utf8String, -1, nil)
            if let contentHash = record.contentHash {
                sqlite3_bind_text(stmt, 10, (contentHash as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 10)
            }
            if let cover = record.coverImagePath {
                sqlite3_bind_text(stmt, 11, (cover as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 11)
            }
            if let encoding = record.textEncoding {
                sqlite3_bind_text(stmt, 12, (encoding as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 12)
            }
            sqlite3_bind_int64(stmt, 13, record.lastReadTime)

            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
            }
            return 0
        }
    }

    func deleteBookAndRelated(bookID: Int64) throws {
        _ = try database.sync { db in
            let sql = """
            DELETE FROM bookmarks WHERE book_id = ?;
            DELETE FROM book_notes WHERE book_id = ?;
            DELETE FROM reading_stats WHERE book_id = ?;
            DELETE FROM books WHERE id = ?;
            """
            var error: UnsafeMutablePointer<Int8>?
            let replaced = sql
                .replacingOccurrences(of: "?", with: "\(bookID)")
            guard sqlite3_exec(db, replaced, nil, nil, &error) == SQLITE_OK else {
                let msg = error.map { String(cString: $0) } ?? "unknown"
                sqlite3_free(error)
                throw DatabaseError.executeFailed(msg)
            }
            return 0
        }
    }
}

final class BookmarkRepository {
    private let database: LegacyDatabaseService

    init(database: LegacyDatabaseService = .shared) {
        self.database = database
    }

    func fetchBookmarks(bookID: Int64) throws -> [BookmarkRecord] {
        try database.sync { db in
            let sql = "SELECT id, book_id, page_index, chapter_title, created_at FROM bookmarks WHERE book_id = ? ORDER BY created_at DESC;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, bookID)

            var items: [BookmarkRecord] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                items.append(
                    BookmarkRecord(
                        id: sqlite3_column_int64(stmt, 0),
                        bookID: sqlite3_column_int64(stmt, 1),
                        pageIndex: Int(sqlite3_column_int64(stmt, 2)),
                        chapterTitle: sqlite3_column_text(stmt, 3).map { String(cString: $0) },
                        createdAt: sqlite3_column_int64(stmt, 4)
                    )
                )
            }
            return items
        }
    }

    func addBookmark(bookID: Int64, pageIndex: Int, chapterTitle: String? = nil) throws {
        _ = try database.sync { db in
            let sql = "INSERT INTO bookmarks (book_id, page_index, chapter_title, created_at) VALUES (?, ?, ?, strftime('%s','now'));"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, bookID)
            sqlite3_bind_int64(stmt, 2, Int64(pageIndex))
            if let chapterTitle {
                sqlite3_bind_text(stmt, 3, (chapterTitle as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 3)
            }
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
            }
            return 0
        }
    }

    func deleteBookmark(id: Int64) throws {
        _ = try database.sync { db in
            let sql = "DELETE FROM bookmarks WHERE id = ?;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, id)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
            }
            return 0
        }
    }

    func merge(_ records: [BookmarkRecord]) throws {
        for item in records {
            _ = try database.sync { db in
                let sql = """
                INSERT INTO bookmarks (book_id, page_index, chapter_title, created_at)
                SELECT ?, ?, ?, ?
                WHERE NOT EXISTS (
                    SELECT 1 FROM bookmarks
                    WHERE book_id = ? AND page_index = ? AND IFNULL(chapter_title,'') = IFNULL(?, '')
                );
                """
                var stmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                    throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
                }
                defer { sqlite3_finalize(stmt) }
                sqlite3_bind_int64(stmt, 1, item.bookID)
                sqlite3_bind_int64(stmt, 2, Int64(item.pageIndex))
                if let chapter = item.chapterTitle {
                    sqlite3_bind_text(stmt, 3, (chapter as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 3)
                }
                sqlite3_bind_int64(stmt, 4, item.createdAt)
                sqlite3_bind_int64(stmt, 5, item.bookID)
                sqlite3_bind_int64(stmt, 6, Int64(item.pageIndex))
                if let chapter = item.chapterTitle {
                    sqlite3_bind_text(stmt, 7, (chapter as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 7)
                }
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
                }
                return 0
            }
        }
    }
}

final class NoteRepository {
    private let database: LegacyDatabaseService

    init(database: LegacyDatabaseService = .shared) {
        self.database = database
    }

    func fetchNotes(bookID: Int64) throws -> [NoteRecord] {
        try database.sync { db in
            let sql = "SELECT id, book_id, page_index, content, note_type, color, created_at FROM book_notes WHERE book_id = ? ORDER BY created_at DESC;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, bookID)

            var items: [NoteRecord] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                items.append(
                    NoteRecord(
                        id: sqlite3_column_int64(stmt, 0),
                        bookID: sqlite3_column_int64(stmt, 1),
                        pageIndex: Int(sqlite3_column_int64(stmt, 2)),
                        content: sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? "",
                        noteType: sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? "note",
                        color: sqlite3_column_text(stmt, 5).map { String(cString: $0) },
                        createdAt: sqlite3_column_int64(stmt, 6)
                    )
                )
            }
            return items
        }
    }

    func addNote(bookID: Int64, pageIndex: Int, content: String) throws {
        _ = try database.sync { db in
            let sql = "INSERT INTO book_notes (book_id, page_index, content, note_type, created_at) VALUES (?, ?, ?, 'note', strftime('%s','now'));"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, bookID)
            sqlite3_bind_int64(stmt, 2, Int64(pageIndex))
            sqlite3_bind_text(stmt, 3, (content as NSString).utf8String, -1, nil)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
            }
            return 0
        }
    }

    func deleteNote(id: Int64) throws {
        _ = try database.sync { db in
            let sql = "DELETE FROM book_notes WHERE id = ?;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, id)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
            }
            return 0
        }
    }

    func merge(_ records: [NoteRecord]) throws {
        for item in records {
            _ = try database.sync { db in
                let sql = """
                INSERT INTO book_notes (book_id, page_index, content, note_type, color, created_at)
                SELECT ?, ?, ?, ?, ?, ?
                WHERE NOT EXISTS (
                    SELECT 1 FROM book_notes
                    WHERE book_id = ? AND page_index = ? AND content = ? AND note_type = ?
                );
                """
                var stmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                    throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
                }
                defer { sqlite3_finalize(stmt) }
                sqlite3_bind_int64(stmt, 1, item.bookID)
                sqlite3_bind_int64(stmt, 2, Int64(item.pageIndex))
                sqlite3_bind_text(stmt, 3, (item.content as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 4, (item.noteType as NSString).utf8String, -1, nil)
                if let color = item.color {
                    sqlite3_bind_text(stmt, 5, (color as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 5)
                }
                sqlite3_bind_int64(stmt, 6, item.createdAt)
                sqlite3_bind_int64(stmt, 7, item.bookID)
                sqlite3_bind_int64(stmt, 8, Int64(item.pageIndex))
                sqlite3_bind_text(stmt, 9, (item.content as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 10, (item.noteType as NSString).utf8String, -1, nil)
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
                }
                return 0
            }
        }
    }
}

final class ReadingStatsRepository {
    private let database: LegacyDatabaseService

    init(database: LegacyDatabaseService = .shared) {
        self.database = database
    }

    func fetchStats() throws -> [ReadingStatRecord] {
        try database.sync { db in
            let sql = "SELECT id, book_id, date, duration_seconds, pages_read FROM reading_stats ORDER BY id DESC LIMIT 1000;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }

            var items: [ReadingStatRecord] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                items.append(
                    ReadingStatRecord(
                        id: sqlite3_column_int64(stmt, 0),
                        bookID: sqlite3_column_int64(stmt, 1),
                        date: sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? "",
                        durationSeconds: Int(sqlite3_column_int64(stmt, 3)),
                        pagesRead: Int(sqlite3_column_int64(stmt, 4))
                    )
                )
            }
            return items
        }
    }

    func record(bookID: Int64, durationSeconds: Int, pagesRead: Int) throws {
        _ = try database.sync { db in
            let sql = "INSERT INTO reading_stats (book_id, date, duration_seconds, pages_read) VALUES (?, date('now'), ?, ?);"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, bookID)
            sqlite3_bind_int64(stmt, 2, Int64(durationSeconds))
            sqlite3_bind_int64(stmt, 3, Int64(pagesRead))
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
            }
            return 0
        }
    }

    func merge(_ records: [ReadingStatRecord]) throws {
        for item in records {
            _ = try database.sync { db in
                let sql = """
                INSERT INTO reading_stats (book_id, date, duration_seconds, pages_read)
                SELECT ?, ?, ?, ?
                WHERE NOT EXISTS (
                    SELECT 1 FROM reading_stats
                    WHERE book_id = ? AND date = ? AND duration_seconds = ? AND pages_read = ?
                );
                """
                var stmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                    throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
                }
                defer { sqlite3_finalize(stmt) }
                sqlite3_bind_int64(stmt, 1, item.bookID)
                sqlite3_bind_text(stmt, 2, (item.date as NSString).utf8String, -1, nil)
                sqlite3_bind_int64(stmt, 3, Int64(item.durationSeconds))
                sqlite3_bind_int64(stmt, 4, Int64(item.pagesRead))
                sqlite3_bind_int64(stmt, 5, item.bookID)
                sqlite3_bind_text(stmt, 6, (item.date as NSString).utf8String, -1, nil)
                sqlite3_bind_int64(stmt, 7, Int64(item.durationSeconds))
                sqlite3_bind_int64(stmt, 8, Int64(item.pagesRead))
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
                }
                return 0
            }
        }
    }
}

extension String {
    func sha256() -> String {
        guard let data = self.data(using: .utf8) else { return "" }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
