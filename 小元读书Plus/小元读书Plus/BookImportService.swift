import Foundation
import PDFKit

enum BookFormat: String {
    case txt
    case pdf
    case epub
    case unknown
}

struct ImportedBookPayload {
    let title: String
    let author: String
    let fileName: String
    let format: BookFormat
    let plainText: String
    let estimatedPages: Int
    let bookmarkData: Data?
}

enum BookImportError: LocalizedError {
    case unsupportedFormat
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "暂不支持该文件格式"
        case .emptyContent:
            return "内容为空或无法解析"
        }
    }
}

final class BookImportService {
    static let shared = BookImportService()

    private init() {}

    func importBook(from url: URL) async throws -> ImportedBookPayload {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let ext = url.pathExtension.lowercased()
        let format = BookFormat(rawValue: ext) ?? .unknown

        let bookmarkData = try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        switch format {
        case .txt:
            let text = try readTextFile(from: url)
            let title = url.deletingPathExtension().lastPathComponent
            return ImportedBookPayload(
                title: title,
                author: "未知作者",
                fileName: url.lastPathComponent,
                format: .txt,
                plainText: text,
                estimatedPages: max(text.count / 1600, 1),
                bookmarkData: bookmarkData
            )

        case .pdf:
            let text = try readPDFText(from: url)
            let title = url.deletingPathExtension().lastPathComponent
            return ImportedBookPayload(
                title: title,
                author: "未知作者",
                fileName: url.lastPathComponent,
                format: .pdf,
                plainText: text,
                estimatedPages: max(text.count / 1700, 1),
                bookmarkData: bookmarkData
            )

        case .epub:
            let title = url.deletingPathExtension().lastPathComponent
            return ImportedBookPayload(
                title: title,
                author: "未知作者",
                fileName: url.lastPathComponent,
                format: .epub,
                plainText: "EPUB 已导入，阅读时将使用系统预览引擎。",
                estimatedPages: 1,
                bookmarkData: bookmarkData
            )

        default:
            throw BookImportError.unsupportedFormat
        }
    }

    private func readTextFile(from url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let gb18030Encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        let encodings: [String.Encoding] = [
            .utf8,
            .utf16,
            .unicode,
            gb18030Encoding,
        ]

        for encoding in encodings {
            if let text = String(data: data, encoding: encoding), !text.isEmpty {
                return text
            }
        }

        throw BookImportError.emptyContent
    }

    private func readPDFText(from url: URL) throws -> String {
        guard let pdf = PDFDocument(url: url) else {
            throw BookImportError.emptyContent
        }

        var allText = ""
        for index in 0..<pdf.pageCount {
            guard let page = pdf.page(at: index), let pageText = page.string else { continue }
            allText += pageText + "\n\n"
        }

        let result = allText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else {
            throw BookImportError.emptyContent
        }
        return result
    }
}
