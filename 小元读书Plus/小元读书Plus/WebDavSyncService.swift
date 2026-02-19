import Foundation

struct WebDavConfig: Codable {
    var endpoint: String
    var username: String
    var password: String
    var remotePath: String

    static let empty = WebDavConfig(endpoint: "", username: "", password: "", remotePath: "xxread")

    var isValid: Bool {
        !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum SyncResult {
    case success(String)
    case failure(String)
}

enum SyncFetchError: Error {
    case message(String)
}

final class WebDavSyncService {
    static let shared = WebDavSyncService()

    private init() {}

    func syncAll(
        config: WebDavConfig,
        books: [BookRecord],
        bookmarksByBook: [Int64: [BookmarkRecord]],
        notesByBook: [Int64: [NoteRecord]],
        stats: [ReadingStatRecord],
        sources: [BookSourceRecord]
    ) async -> SyncResult {
        guard config.isValid else {
            return .failure("请先填写完整 WebDAV 配置")
        }

        guard let baseURL = URL(string: config.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return .failure("WebDAV 地址无效")
        }

        do {
            let root = baseURL.appending(path: config.remotePath)
            try await ensureCollection(root, config: config)

            let payload = SyncPayload(
                exportedAt: Date().timeIntervalSince1970,
                books: books,
                bookmarks: bookmarksByBook,
                notes: notesByBook,
                stats: stats,
                sources: sources
            )
            let data = try JSONEncoder().encode(payload)
            let fileURL = root.appending(path: "sync_payload.json")
            try await put(data: data, to: fileURL, config: config)
            return .success("同步完成：已上传 \(books.count) 本书的数据")
        } catch {
            return .failure("同步失败：\(error.localizedDescription)")
        }
    }

    func fetchRemotePayload(config: WebDavConfig) async -> Result<SyncPayload, SyncFetchError> {
        guard config.isValid else {
            return .failure(.message("请先填写完整 WebDAV 配置"))
        }
        guard let baseURL = URL(string: config.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return .failure(.message("WebDAV 地址无效"))
        }
        let fileURL = baseURL.appending(path: config.remotePath).appending(path: "sync_payload.json")

        do {
            var request = URLRequest(url: fileURL)
            request.httpMethod = "GET"
            request.setValue(authHeader(config: config), forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return .failure(.message("远端数据拉取失败"))
            }
            let payload = try JSONDecoder().decode(SyncPayload.self, from: data)
            return .success(payload)
        } catch {
            return .failure(.message("远端数据解析失败：\(error.localizedDescription)"))
        }
    }

    private func ensureCollection(_ url: URL, config: WebDavConfig) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "MKCOL"
        request.setValue(authHeader(config: config), forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return }
        if !(http.statusCode == 201 || http.statusCode == 405 || http.statusCode == 301 || http.statusCode == 200) {
            throw NSError(domain: "WebDAV", code: http.statusCode)
        }
    }

    private func put(data: Data, to url: URL, config: WebDavConfig) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authHeader(config: config), forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw NSError(domain: "WebDAV", code: -1)
        }
    }

    private func authHeader(config: WebDavConfig) -> String {
        let raw = "\(config.username):\(config.password)"
        let base64 = Data(raw.utf8).base64EncodedString()
        return "Basic \(base64)"
    }
}

struct SyncPayload: Codable {
    let exportedAt: TimeInterval
    let books: [BookRecord]
    let bookmarks: [Int64: [BookmarkRecord]]
    let notes: [Int64: [NoteRecord]]
    let stats: [ReadingStatRecord]
    let sources: [BookSourceRecord]
}
