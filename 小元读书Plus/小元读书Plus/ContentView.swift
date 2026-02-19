import SwiftUI
import UniformTypeIdentifiers
import QuickLook
import PDFKit

struct ContentView: View {
    @Environment(ReaderAppStore.self) private var store
    @State private var selectedTab: AppTab = .library
    @AppStorage(ReaderSettingsKey.readingTheme) private var themeRaw = ReaderTheme.ocean.rawValue

    var body: some View {
        @Bindable var bindableStore = store
        let theme = ReaderTheme(rawValue: themeRaw) ?? .ocean

        TabView(selection: $selectedTab) {
            LibraryView()
                .tag(AppTab.library)
                .tabItem { Label("书库", systemImage: "books.vertical") }

            BookSourceView()
                .tag(AppTab.sources)
                .tabItem { Label("书源", systemImage: "network") }

            StatsView(stats: store.stats)
                .tag(AppTab.stats)
                .tabItem { Label("统计", systemImage: "chart.line.uptrend.xyaxis") }

            SettingsView()
                .tag(AppTab.settings)
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .tint(.cyan)
        .background(AppGlassTheme.gradient(for: theme).ignoresSafeArea())
        .alert("提示", isPresented: Binding(
            get: { bindableStore.errorMessage != nil },
            set: { if !$0 { bindableStore.errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(bindableStore.errorMessage ?? "")
        }
    }
}

enum AppTab {
    case library
    case sources
    case stats
    case settings
}

struct LibraryView: View {
    @Environment(ReaderAppStore.self) private var store
    @State private var showingImporter = false
    @State private var searchText = ""

    private var filteredBooks: [BookRecord] {
        guard !searchText.isEmpty else { return store.books }
        return store.books.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.author.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if store.isLoading {
                        ProgressView("加载中...")
                            .padding(20)
                            .glassCard()
                    } else if filteredBooks.isEmpty {
                        EmptyLibraryView(showingImporter: $showingImporter)
                    } else {
                        ForEach(filteredBooks) { book in
                            NavigationLink {
                                ReaderView(book: book)
                            } label: {
                                BookCard(book: book)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    store.deleteBook(book: book)
                                } label: {
                                    Label("删除书籍", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("小元读书 Plus")
            .searchable(text: $searchText, prompt: "搜索书名 / 作者")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingImporter = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.plainText, .pdf, .epub],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                Task { await store.importBook(from: url) }
            case let .failure(error):
                store.errorMessage = error.localizedDescription
            }
        }
    }
}

struct ReaderView: View {
    @Environment(ReaderAppStore.self) private var store
    let book: BookRecord

    @AppStorage(ReaderSettingsKey.fontSize) private var fontSize = 22.0
    @AppStorage(ReaderSettingsKey.lineSpacing) private var lineSpacing = 8.0
    @AppStorage(ReaderSettingsKey.horizontalPadding) private var horizontalPadding = 20.0
    @AppStorage(ReaderSettingsKey.readingMode) private var readingModeRaw = ReaderMode.slide.rawValue
    @AppStorage(ReaderSettingsKey.readingTheme) private var themeRaw = ReaderTheme.ocean.rawValue

    @State private var pages: [String] = []
    @State private var chapters: [ReaderChapter] = []
    @State private var currentPage = 0
    @State private var sessionStart = Date()
    @State private var showBookmarkSheet = false
    @State private var showNoteSheet = false
    @State private var showTocSheet = false
    @State private var showSearchSheet = false
    @State private var pdfPageCount = 1
    @State private var showControls = true
    @State private var lastPersistedPage = -1
    @StateObject private var speechService = ReaderSpeechService()

    private var isEpub: Bool { book.format.lowercased() == BookFormat.epub.rawValue }
    private var isPdf: Bool { book.format.lowercased() == BookFormat.pdf.rawValue }
    private var readingMode: ReaderMode { ReaderMode(rawValue: readingModeRaw) ?? .scroll }
    private var theme: ReaderTheme { ReaderTheme(rawValue: themeRaw) ?? .ocean }
    private var totalPageCount: Int { isPdf ? max(pdfPageCount, 1) : max(pages.count, 1) }
    private var isScrollMode: Bool { !isPdf && !isEpub && readingMode == .scroll }

    var body: some View {
        ZStack {
            AppGlassTheme.gradient(for: theme).ignoresSafeArea()

            if isEpub {
                EpubQuickLookView(url: URL(fileURLWithPath: book.filePath))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(14)
            } else if isPdf {
                VStack(spacing: 12) {
                    if showControls { header }
                    NativePDFReaderView(
                        url: URL(fileURLWithPath: book.filePath),
                        currentPage: $currentPage,
                        totalPages: $pdfPageCount
                    )
                    .glassCard(cornerRadius: 28)
                    .padding(.horizontal, 14)
                    .overlay {
                        ReaderTapZonesOverlay(
                            onPrev: { currentPage = max(currentPage - 1, 0) },
                            onToggleControls: { withAnimation(.easeInOut(duration: 0.2)) { showControls.toggle() } },
                            onNext: { currentPage = min(currentPage + 1, max(totalPageCount - 1, 0)) }
                        )
                    }
                    if showControls { pageControl }
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    if showControls { header }
                    if isScrollMode {
                        scrollContent
                    } else {
                        pagedContent
                    }
                    if showControls { pageControl }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            sessionStart = Date()
            speechService.reloadSettings()
            repaginate()
            currentPage = min(book.currentPage, max(pages.count - 1, 0))
            lastPersistedPage = currentPage
        }
        .onDisappear {
            speechService.stop()
            persistReadingSession()
        }
        .sheet(isPresented: $showBookmarkSheet) {
            BookmarkSheet(bookID: book.id, currentPage: $currentPage)
        }
        .sheet(isPresented: $showNoteSheet) {
            NoteSheet(bookID: book.id, currentPage: currentPage)
        }
        .sheet(isPresented: $showTocSheet) {
            TocSheet(chapters: chapters, currentPage: $currentPage)
        }
        .sheet(isPresented: $showSearchSheet) {
            SearchSheet(pages: pages, currentPage: $currentPage)
        }
        .onChange(of: currentPage) { _, newPage in
            guard newPage >= 0, newPage != lastPersistedPage else { return }
            lastPersistedPage = newPage
            store.updateReadingPosition(bookID: book.id, currentPage: newPage, totalPages: totalPageCount)
        }
        .onChange(of: fontSize) { _, _ in repaginate() }
        .onChange(of: lineSpacing) { _, _ in repaginate() }
        .onChange(of: horizontalPadding) { _, _ in repaginate() }
        .onChange(of: readingModeRaw) { _, _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                showControls = true
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("第 \(currentPage + 1) / \(totalPageCount) 页")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                Button { showSearchSheet = true } label: { Image(systemName: "magnifyingglass") }
                Button { showTocSheet = true } label: { Image(systemName: "list.bullet") }
                Button { showBookmarkSheet = true } label: { Image(systemName: "bookmark") }
                Button { showNoteSheet = true } label: { Image(systemName: "note.text") }
                Button { toggleSpeech() } label: { Image(systemName: speechService.isSpeaking ? "speaker.slash.fill" : "speaker.wave.2.fill") }
            }
            .font(.title3)
        }
        .padding(14)
        .glassCard()
        .padding(.horizontal, 14)
    }

    private var scrollContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, text in
                        Text(text)
                            .font(.system(size: fontSize, weight: .regular, design: .rounded))
                            .lineSpacing(lineSpacing)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, horizontalPadding)
                            .padding(.vertical, 18)
                            .textSelection(.enabled)
                            .id(index)
                            .onAppear {
                                if index != currentPage {
                                    currentPage = index
                                }
                            }
                    }
                }
            }
            .onChange(of: currentPage) { _, page in
                guard page >= 0, page < pages.count else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(page, anchor: .top)
                }
            }
        }
        .glassCard(cornerRadius: 28)
        .padding(.horizontal, 14)
        .overlay {
            ReaderTapZonesOverlay(
                onPrev: { currentPage = max(currentPage - 1, 0) },
                onToggleControls: { withAnimation(.easeInOut(duration: 0.2)) { showControls.toggle() } },
                onNext: { currentPage = min(currentPage + 1, max(totalPageCount - 1, 0)) }
            )
        }
    }

    private var pagedContent: some View {
        TabView(selection: $currentPage) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, text in
                ScrollView {
                    Text(text)
                        .font(.system(size: fontSize, weight: .regular, design: .rounded))
                        .lineSpacing(lineSpacing)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, 26)
                        .textSelection(.enabled)
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(readingMode == .simulation ? .easeInOut(duration: 0.45) : .default, value: currentPage)
        .glassCard(cornerRadius: 28)
        .padding(.horizontal, 14)
        .overlay {
            ReaderTapZonesOverlay(
                onPrev: { currentPage = max(currentPage - 1, 0) },
                onToggleControls: { withAnimation(.easeInOut(duration: 0.2)) { showControls.toggle() } },
                onNext: { currentPage = min(currentPage + 1, max(totalPageCount - 1, 0)) }
            )
        }
    }

    private var pageControl: some View {
        VStack(spacing: 10) {
            Picker("模式", selection: $readingModeRaw) {
                ForEach(ReaderMode.allCases, id: \.rawValue) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)

            if !isScrollMode {
                Slider(value: Binding(
                    get: { Double(currentPage) },
                    set: { currentPage = Int($0.rounded()) }
                ), in: 0...Double(max(totalPageCount - 1, 0)), step: 1)
            }

            HStack {
                Button("上一页") { currentPage = max(currentPage - 1, 0) }
                    .buttonStyle(.borderedProminent)
                Spacer()
                Button("下一页") { currentPage = min(currentPage + 1, max(totalPageCount - 1, 0)) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .glassCard()
        .padding(.horizontal, 14)
    }

    private var currentPageText: String {
        guard !pages.isEmpty else { return "" }
        return pages[min(currentPage, pages.count - 1)]
    }

    private func repaginate() {
        if isPdf {
            let count = max(book.totalPages, 1)
            pages = Array(repeating: "", count: count)
            chapters = []
            pdfPageCount = count
            return
        }

        pages = ReaderPaginator.paginate(
            text: book.cachedContent,
            fontSize: fontSize,
            lineSpacing: lineSpacing,
            horizontalPadding: horizontalPadding
        )
        if pages.isEmpty { pages = ["当前书籍暂无可显示内容"] }
        chapters = ReaderChapterExtractor.extract(from: book.cachedContent, pages: pages)
        store.updatePaginationCache(bookID: book.id, pages: pages, chapters: chapters)
        currentPage = min(currentPage, max(pages.count - 1, 0))
    }

    private func toggleSpeech() {
        if speechService.isSpeaking {
            speechService.stop()
        } else {
            speechService.speak(currentPageText)
        }
    }

    private func persistReadingSession() {
        let duration = max(Int(Date().timeIntervalSince(sessionStart)), 1)
        let pagesRead = max(currentPage - book.currentPage, 0)
        store.updateReadingProgress(
            bookID: book.id,
            currentPage: currentPage,
            totalPages: totalPageCount,
            pagesRead: pagesRead,
            durationSeconds: duration
        )
    }
}

struct ReaderTapZonesOverlay: View {
    let onPrev: () -> Void
    let onToggleControls: () -> Void
    let onNext: () -> Void

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onPrev)
                    .frame(width: geometry.size.width * 0.3)

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onToggleControls)
                    .frame(width: geometry.size.width * 0.4)

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onNext)
                    .frame(width: geometry.size.width * 0.3)
            }
        }
    }
}

struct BookSourceView: View {
    @Environment(ReaderAppStore.self) private var store
    @State private var sourceName = ""
    @State private var sourceURL = ""

    var body: some View {
        NavigationStack {
            List {
                Section("新增书源") {
                    TextField("书源名称", text: $sourceName)
                    TextField("书源地址", text: $sourceURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("添加") {
                        let name = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let url = sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty, !url.isEmpty else { return }
                        store.addSource(name: name, url: url)
                        sourceName = ""
                        sourceURL = ""
                    }
                }

                Section("已配置书源") {
                    if store.sources.isEmpty {
                        Text("暂无书源")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(store.sources) { source in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(source.sourceName)
                                    .font(.headline)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { source.enabled },
                                    set: { store.toggleSource(id: source.id, enabled: $0) }
                                ))
                                .labelsHidden()
                            }
                            Text(source.sourceURL)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            store.deleteSource(id: store.sources[index].id)
                        }
                    }
                }
            }
            .navigationTitle("书源管理")
        }
    }
}

struct BookmarkSheet: View {
    @Environment(ReaderAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let bookID: Int64
    @Binding var currentPage: Int

    @State private var bookmarks: [BookmarkRecord] = []

    var body: some View {
        NavigationStack {
            List {
                Button("添加当前页书签") { addBookmark() }

                ForEach(bookmarks) { bookmark in
                    Button {
                        currentPage = bookmark.pageIndex
                        dismiss()
                    } label: {
                        VStack(alignment: .leading) {
                            Text("第 \(bookmark.pageIndex + 1) 页")
                            Text(Date(timeIntervalSince1970: TimeInterval(bookmark.createdAt)).formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("书签")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear(perform: reload)
        }
        .presentationDetents([.medium, .large])
    }

    private func reload() {
        bookmarks = store.fetchBookmarks(bookID: bookID)
    }

    private func addBookmark() {
        store.addBookmark(bookID: bookID, pageIndex: currentPage, chapterTitle: "第 \(currentPage + 1) 页")
        reload()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            store.deleteBookmark(id: bookmarks[index].id)
        }
        reload()
    }
}

struct NoteSheet: View {
    @Environment(ReaderAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let bookID: Int64
    let currentPage: Int

    @State private var noteText = ""
    @State private var notes: [NoteRecord] = []

    var body: some View {
        NavigationStack {
            List {
                Section("新建笔记") {
                    TextEditor(text: $noteText)
                        .frame(minHeight: 120)
                    Button("保存") { saveNote() }
                }

                Section("全部笔记") {
                    ForEach(notes) { note in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("第 \(note.pageIndex + 1) 页")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(note.content)
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
            .navigationTitle("笔记")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear(perform: reload)
        }
        .presentationDetents([.medium, .large])
    }

    private func reload() {
        notes = store.fetchNotes(bookID: bookID)
    }

    private func saveNote() {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.addNote(bookID: bookID, pageIndex: currentPage, content: trimmed)
        noteText = ""
        reload()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            store.deleteNote(id: notes[index].id)
        }
        reload()
    }
}

struct TocSheet: View {
    @Environment(\.dismiss) private var dismiss
    let chapters: [ReaderChapter]
    @Binding var currentPage: Int

    var body: some View {
        NavigationStack {
            List(chapters) { chapter in
                Button {
                    currentPage = chapter.startPage
                    dismiss()
                } label: {
                    HStack {
                        Text(chapter.title)
                            .lineLimit(1)
                        Spacer()
                        Text("P\(chapter.startPage + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("目录")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct SearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    let pages: [String]
    @Binding var currentPage: Int

    @State private var keyword = ""

    private var matches: [Int] {
        let key = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return [] }
        return pages.enumerated()
            .filter { $0.element.localizedCaseInsensitiveContains(key) }
            .map { $0.offset }
            .prefix(200)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("关键词") {
                    TextField("输入要搜索的内容", text: $keyword)
                }

                Section("结果") {
                    if matches.isEmpty {
                        Text(keyword.isEmpty ? "请输入关键词" : "未找到匹配项")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(matches, id: \.self) { page in
                        Button {
                            currentPage = page
                            dismiss()
                        } label: {
                            HStack {
                                Text("第 \(page + 1) 页")
                                Spacer()
                                Text(snippet(for: page))
                                    .lineLimit(1)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("书内搜索")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func snippet(for page: Int) -> String {
        let prefix = String(pages[page].replacingOccurrences(of: "\n", with: " ").prefix(40))
        return prefix + "..."
    }
}

struct StatsView: View {
    let stats: [ReadingStatRecord]

    private var totalDuration: Int { stats.reduce(0) { $0 + $1.durationSeconds } }
    private var totalPages: Int { stats.reduce(0) { $0 + $1.pagesRead } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    StatCard(title: "累计阅读时长", value: formatDuration(totalDuration), icon: "clock")
                    StatCard(title: "累计阅读页数", value: "\(totalPages) 页", icon: "book.pages")
                    StatCard(title: "阅读会话次数", value: "\(stats.count)", icon: "waveform.path.ecg")
                }
                .padding(16)
            }
            .navigationTitle("阅读统计")
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hour = seconds / 3600
        let minute = (seconds % 3600) / 60
        return "\(hour) 小时 \(minute) 分钟"
    }
}

struct SettingsView: View {
    @Environment(ReaderAppStore.self) private var store

    @AppStorage(ReaderSettingsKey.fontSize) private var fontSize = 22.0
    @AppStorage(ReaderSettingsKey.lineSpacing) private var lineSpacing = 8.0
    @AppStorage(ReaderSettingsKey.horizontalPadding) private var horizontalPadding = 20.0
    @AppStorage(ReaderSettingsKey.readingTheme) private var themeRaw = ReaderTheme.ocean.rawValue
    @AppStorage(ReaderSettingsKey.ttsRate) private var ttsRate = 0.46
    @AppStorage(ReaderSettingsKey.ttsPitch) private var ttsPitch = 1.0
    @AppStorage(ReaderSettingsKey.ttsVolume) private var ttsVolume = 1.0

    @AppStorage("sync.webdav.endpoint") private var syncEndpoint = ""
    @AppStorage("sync.webdav.username") private var syncUsername = ""
    @AppStorage("sync.webdav.password") private var syncPassword = ""
    @AppStorage("sync.webdav.path") private var syncPath = "xxread"

    var body: some View {
        NavigationStack {
            Form {
                Section("阅读排版") {
                    VStack(alignment: .leading) {
                        Text("字体大小：\(Int(fontSize))")
                        Slider(value: $fontSize, in: 16...34, step: 1)
                    }

                    VStack(alignment: .leading) {
                        Text("行间距：\(Int(lineSpacing))")
                        Slider(value: $lineSpacing, in: 2...16, step: 1)
                    }

                    VStack(alignment: .leading) {
                        Text("左右边距：\(Int(horizontalPadding))")
                        Slider(value: $horizontalPadding, in: 12...40, step: 1)
                    }
                }

                Section("阅读主题") {
                    Picker("主题", selection: $themeRaw) {
                        ForEach(ReaderTheme.allCases, id: \.rawValue) { theme in
                            Text(theme.title).tag(theme.rawValue)
                        }
                    }
                }

                Section("TTS 朗读") {
                    VStack(alignment: .leading) {
                        Text("语速：\(String(format: "%.2f", ttsRate))")
                        Slider(value: $ttsRate, in: 0.35...0.60, step: 0.01)
                    }

                    VStack(alignment: .leading) {
                        Text("音调：\(String(format: "%.2f", ttsPitch))")
                        Slider(value: $ttsPitch, in: 0.7...1.3, step: 0.01)
                    }

                    VStack(alignment: .leading) {
                        Text("音量：\(String(format: "%.2f", ttsVolume))")
                        Slider(value: $ttsVolume, in: 0.1...1.0, step: 0.01)
                    }
                }

                Section("WebDAV 同步") {
                    TextField("WebDAV 地址", text: $syncEndpoint)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("用户名", text: $syncUsername)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("密码", text: $syncPassword)
                    TextField("远程目录", text: $syncPath)
                        .textInputAutocapitalization(.never)

                    Button {
                        Task {
                            await store.runWebDavSync(
                                config: WebDavConfig(
                                    endpoint: syncEndpoint,
                                    username: syncUsername,
                                    password: syncPassword,
                                    remotePath: syncPath
                                )
                            )
                        }
                    } label: {
                        if store.isSyncing {
                            ProgressView()
                        } else {
                            Text("立即同步")
                        }
                    }
                    .disabled(store.isSyncing)

                    if let status = store.syncStatusMessage {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("关于") {
                    Label("SQLite 兼容 Flutter 主数据库表", systemImage: "cylinder")
                    Label("纯 SwiftUI + 官方框架优先", systemImage: "swift")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppGlassTheme.gradient(for: ReaderTheme(rawValue: themeRaw) ?? .ocean))
            .navigationTitle("设置")
        }
    }
}

struct EmptyLibraryView: View {
    @Binding var showingImporter: Bool

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 40))
                .foregroundStyle(.cyan)

            Text("还没有书籍")
                .font(.title3.weight(.semibold))

            Text("支持导入 TXT / PDF / EPUB")
                .foregroundStyle(.secondary)

            Button("立即导入") {
                showingImporter = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(22)
        .glassCard(cornerRadius: 26)
        .padding(.top, 90)
    }
}

struct BookCard: View {
    let book: BookRecord

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.12))
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundStyle(.cyan)
            }
            .frame(width: 58, height: 74)

            VStack(alignment: .leading, spacing: 6) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\(book.format.uppercased()) · 进度 \(progressPercent)%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .glassCard(cornerRadius: 24)
    }

    private var iconName: String {
        switch book.format.lowercased() {
        case BookFormat.pdf.rawValue: return "doc.richtext"
        case BookFormat.epub.rawValue: return "book.closed"
        default: return "doc.text"
        }
    }

    private var progressPercent: Int {
        guard book.totalPages > 0 else { return 0 }
        return Int((Double(book.currentPage + 1) / Double(book.totalPages)) * 100)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.cyan)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.weight(.semibold))
            }
            Spacer()
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }
}

struct EpubQuickLookView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return url as NSURL
        }
    }
}

struct NativePDFReaderView: UIViewRepresentable {
    let url: URL
    @Binding var currentPage: Int
    @Binding var totalPages: Int

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        if let document = PDFDocument(url: url) {
            view.document = document
            totalPages = max(document.pageCount, 1)
            if let page = document.page(at: min(currentPage, document.pageCount - 1)) {
                view.go(to: page)
            }
        }

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: Notification.Name.PDFViewPageChanged,
            object: view
        )
        context.coordinator.pageBinding = $currentPage
        context.coordinator.totalBinding = $totalPages
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        guard let document = uiView.document else { return }
        context.coordinator.pageBinding = $currentPage
        context.coordinator.totalBinding = $totalPages
        totalPages = max(document.pageCount, 1)

        let targetIndex = min(max(currentPage, 0), document.pageCount - 1)
        if let current = uiView.currentPage {
            let currentIndex = document.index(for: current)
            if currentIndex != targetIndex, let page = document.page(at: targetIndex) {
                uiView.go(to: page)
            }
        } else if let page = document.page(at: targetIndex) {
            uiView.go(to: page)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    static func dismantleUIView(_ uiView: PDFView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }

    final class Coordinator: NSObject {
        var pageBinding: Binding<Int> = .constant(0)
        var totalBinding: Binding<Int> = .constant(1)

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let document = pdfView.document,
                  let page = pdfView.currentPage else { return }
            pageBinding.wrappedValue = document.index(for: page)
            totalBinding.wrappedValue = max(document.pageCount, 1)
        }
    }
}

#Preview {
    ContentView()
        .environment(ReaderAppStore())
}
