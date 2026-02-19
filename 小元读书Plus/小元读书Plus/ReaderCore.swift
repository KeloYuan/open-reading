import Foundation

enum ReaderSettingsKey {
    static let fontSize = "reader.fontSize"
    static let lineSpacing = "reader.lineSpacing"
    static let horizontalPadding = "reader.horizontalPadding"
    static let readingMode = "reader.readingMode"
    static let readingTheme = "reader.readingTheme"
    static let ttsRate = "reader.ttsRate"
    static let ttsPitch = "reader.ttsPitch"
    static let ttsVolume = "reader.ttsVolume"
}

enum ReaderTheme: String, CaseIterable {
    case ocean
    case paper
    case dark
    case forest
    case sunset
    case violet
    case graphite
    case emerald

    var title: String {
        switch self {
        case .ocean: return "海蓝"
        case .paper: return "纸白"
        case .dark: return "深夜"
        case .forest: return "森林"
        case .sunset: return "晚霞"
        case .violet: return "紫雾"
        case .graphite: return "石墨"
        case .emerald: return "翡翠"
        }
    }
}

enum ReaderMode: String, CaseIterable {
    case scroll
    case slide
    case cover
    case simulation

    var title: String {
        switch self {
        case .scroll:
            return "滚动"
        case .slide:
            return "滑动"
        case .cover:
            return "覆盖"
        case .simulation:
            return "仿真"
        }
    }
}

struct ReaderChapter: Codable, Hashable, Identifiable {
    var id: String { "\(title)-\(startPage)" }
    let title: String
    let startPage: Int
}

struct ReaderCachePack: Codable {
    let pages: [String]
    let chapters: [ReaderChapter]
}

enum ReaderChapterExtractor {
    static func extract(from text: String, pages: [String]) -> [ReaderChapter] {
        guard !text.isEmpty else { return [] }
        let regexPatterns = [
            "(?m)^\\s*第[一二三四五六七八九十百千万0-9]+[章回卷节].*$",
            "(?m)^\\s*Chapter\\s+[0-9IVXLC]+.*$",
        ]

        var titles: [String] = []
        for pattern in regexPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let nsText = text as NSString
                let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
                for match in matches {
                    let title = nsText.substring(with: match.range).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !title.isEmpty {
                        titles.append(title)
                    }
                }
            }
        }

        if titles.isEmpty {
            return [ReaderChapter(title: "开始阅读", startPage: 0)]
        }

        var result: [ReaderChapter] = [ReaderChapter(title: "开始阅读", startPage: 0)]
        for title in titles.prefix(300) {
            if let page = pages.firstIndex(where: { $0.contains(title) }) {
                if !result.contains(where: { $0.startPage == page }) {
                    result.append(ReaderChapter(title: title, startPage: page))
                }
            }
        }
        return result.sorted { $0.startPage < $1.startPage }
    }
}

enum ReaderPaginator {
    static func paginate(
        text: String,
        fontSize: Double,
        lineSpacing: Double,
        horizontalPadding: Double
    ) -> [String] {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return [] }

        let sizeFactor = max(fontSize / 20.0, 0.7)
        let spacingFactor = max(lineSpacing / 8.0, 0.5)
        let paddingFactor = max(horizontalPadding / 20.0, 0.6)

        let charsPerPage = max(Int(1800 / (sizeFactor * spacingFactor * paddingFactor)), 700)
        var pages: [String] = []

        var start = cleanText.startIndex
        while start < cleanText.endIndex {
            let roughEnd = cleanText.index(start, offsetBy: charsPerPage, limitedBy: cleanText.endIndex) ?? cleanText.endIndex
            if roughEnd == cleanText.endIndex {
                pages.append(String(cleanText[start..<roughEnd]))
                break
            }

            let segment = cleanText[start..<roughEnd]
            if let naturalBreak = segment.lastIndex(where: { $0 == "\n" || $0 == "。" || $0 == "！" || $0 == "？" }) {
                let end = cleanText.index(after: naturalBreak)
                pages.append(String(cleanText[start..<end]))
                start = end
            } else {
                pages.append(String(cleanText[start..<roughEnd]))
                start = roughEnd
            }
        }

        return pages
    }
}

enum ReaderCacheCodec {
    static func encode(pages: [String], chapters: [ReaderChapter]) -> String? {
        let pack = ReaderCachePack(pages: pages, chapters: chapters)
        guard let data = try? JSONEncoder().encode(pack) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(_ text: String) -> ReaderCachePack? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ReaderCachePack.self, from: data)
    }
}
