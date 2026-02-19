import Foundation
import Observation

@MainActor
@Observable
final class ReaderAppStore {
    var books: [BookRecord] = []
    var stats: [ReadingStatRecord] = []
    var sources: [BookSourceRecord] = []
    var isLoading = false
    var errorMessage: String?
    var syncStatusMessage: String?
    var isSyncing = false

    private let bookRepository = BookRepository()
    private let statsRepository = ReadingStatsRepository()
    private let bookmarkRepository = BookmarkRepository()
    private let noteRepository = NoteRepository()
    private let sourceRepository = BookSourceRepository()

    init() {}

    func bootstrap() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try LegacyDatabaseService.shared.initializeIfNeeded()
            try reloadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reloadAll() throws {
        books = try bookRepository.fetchAllBooks()
        stats = try statsRepository.fetchStats()
        sources = try sourceRepository.fetchAll()
    }

    func importBook(from url: URL) async {
        do {
            let payload = try await BookImportService.shared.importBook(from: url)
            let hash = payload.plainText.sha256()
            if let _ = try bookRepository.findBookID(byContentHash: hash) {
                errorMessage = "该书已存在，已跳过导入"
                return
            }
            let storedPath = try copyBookToSandbox(from: url)
            _ = try bookRepository.insertImportedBook(payload: payload, storedPath: storedPath)
            try reloadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteBook(book: BookRecord) {
        do {
            try bookRepository.deleteBookAndRelated(bookID: book.id)
            if FileManager.default.fileExists(atPath: book.filePath) {
                try? FileManager.default.removeItem(atPath: book.filePath)
            }
            try reloadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateReadingProgress(bookID: Int64, currentPage: Int, totalPages: Int, pagesRead: Int, durationSeconds: Int) {
        do {
            try bookRepository.updateProgress(bookID: bookID, page: currentPage, totalPages: totalPages)
            try statsRepository.record(bookID: bookID, durationSeconds: durationSeconds, pagesRead: pagesRead)
            try reloadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateReadingPosition(bookID: Int64, currentPage: Int, totalPages: Int) {
        do {
            try bookRepository.updateProgress(bookID: bookID, page: currentPage, totalPages: totalPages)
            try reloadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updatePaginationCache(bookID: Int64, pages: [String], chapters: [ReaderChapter]) {
        do {
            guard let payload = ReaderCacheCodec.encode(pages: pages, chapters: chapters) else { return }
            try bookRepository.updatePaginationCache(bookID: bookID, cachedPages: payload)
            try reloadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchBookmarks(bookID: Int64) -> [BookmarkRecord] {
        (try? bookmarkRepository.fetchBookmarks(bookID: bookID)) ?? []
    }

    func addBookmark(bookID: Int64, pageIndex: Int, chapterTitle: String? = nil) {
        do {
            try bookmarkRepository.addBookmark(bookID: bookID, pageIndex: pageIndex, chapterTitle: chapterTitle)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteBookmark(id: Int64) {
        do {
            try bookmarkRepository.deleteBookmark(id: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchNotes(bookID: Int64) -> [NoteRecord] {
        (try? noteRepository.fetchNotes(bookID: bookID)) ?? []
    }

    func addNote(bookID: Int64, pageIndex: Int, content: String) {
        do {
            try noteRepository.addNote(bookID: bookID, pageIndex: pageIndex, content: content)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteNote(id: Int64) {
        do {
            try noteRepository.deleteNote(id: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addSource(name: String, url: String) {
        do {
            try sourceRepository.add(name: name, url: url)
            try reloadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleSource(id: Int64, enabled: Bool) {
        do {
            try sourceRepository.setEnabled(id: id, enabled: enabled)
            try reloadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSource(id: Int64) {
        do {
            try sourceRepository.delete(id: id)
            try reloadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func runWebDavSync(config: WebDavConfig) async {
        isSyncing = true
        defer { isSyncing = false }

        var bookmarksByBook: [Int64: [BookmarkRecord]] = [:]
        var notesByBook: [Int64: [NoteRecord]] = [:]
        for book in books {
            bookmarksByBook[book.id] = fetchBookmarks(bookID: book.id)
            notesByBook[book.id] = fetchNotes(bookID: book.id)
        }

        let result = await WebDavSyncService.shared.syncAll(
            config: config,
            books: books,
            bookmarksByBook: bookmarksByBook,
            notesByBook: notesByBook,
            stats: stats,
            sources: sources
        )

        switch result {
        case .success:
            let pull = await WebDavSyncService.shared.fetchRemotePayload(config: config)
            switch pull {
            case let .success(payload):
                mergeRemotePayload(payload)
                syncStatusMessage = "同步完成：上传 + 拉取 + 合并已完成"
            case let .failure(.message(message)):
                syncStatusMessage = "上传成功，但拉取失败：\(message)"
            }
        case let .failure(message):
            syncStatusMessage = message
        }
    }

    private func mergeRemotePayload(_ payload: SyncPayload) {
        do {
            for book in payload.books {
                try bookRepository.upsertSyncedBook(book)
            }

            let allBookmarks = payload.bookmarks.values.flatMap { $0 }
            let allNotes = payload.notes.values.flatMap { $0 }

            try bookmarkRepository.merge(allBookmarks)
            try noteRepository.merge(allNotes)
            try statsRepository.merge(payload.stats)
            try sourceRepository.merge(payload.sources)
            try reloadAll()
        } catch {
            errorMessage = "合并远端数据失败：\(error.localizedDescription)"
        }
    }

    private func copyBookToSandbox(from sourceURL: URL) throws -> String {
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let booksDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("books", isDirectory: true)

        if !FileManager.default.fileExists(atPath: booksDir.path) {
            try FileManager.default.createDirectory(at: booksDir, withIntermediateDirectories: true)
        }

        let filename = sourceURL.lastPathComponent
        let targetURL = booksDir.appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: targetURL.path) {
            try FileManager.default.removeItem(at: targetURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: targetURL)
        return targetURL.path
    }
}
