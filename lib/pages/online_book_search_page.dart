import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:xxread/models/book_source.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/services/books/book_services.dart';
import 'package:xxread/services/library/library_event_bus_service.dart';
import 'package:xxread/services/reading/reading_router_service.dart';
import 'package:xxread/widgets/side_toast.dart';

class OnlineBookSearchPage extends StatefulWidget {
  const OnlineBookSearchPage({
    super.key,
    this.source,
    this.aggregateEnabledSources = false,
    this.initialKeyword = '',
  });

  const OnlineBookSearchPage.aggregate({
    super.key,
    this.initialKeyword = '',
  })  : source = null,
        aggregateEnabledSources = true;

  final BookSource? source;
  final bool aggregateEnabledSources;
  final String initialKeyword;

  @override
  State<OnlineBookSearchPage> createState() => _OnlineBookSearchPageState();
}

class _OnlineBookSearchPageState extends State<OnlineBookSearchPage> {
  final _service = OnlineBookSourceService.instance();
  final _sourceService = BookSourceService();
  final _bookDao = BookDao();
  late final TextEditingController _keywordController;
  final Map<String, BookSource> _sourceById = <String, BookSource>{};
  List<BookSource> _searchSources = const <BookSource>[];

  List<OnlineBookItem> _results = const <OnlineBookItem>[];
  bool _isLoading = false;
  bool _isDownloading = false;
  bool _sourcesReady = false;
  bool _hasSearched = false;
  int _page = 1;
  String _error = '';
  String _downloadMessage = '';

  @override
  void initState() {
    super.initState();
    _keywordController = TextEditingController(text: widget.initialKeyword);
    _prepareSearchSources();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _prepareSearchSources() async {
    if (widget.aggregateEnabledSources) {
      final enabledSources = await _sourceService.getEnabledSources();
      if (!mounted) return;
      setState(() {
        _searchSources = enabledSources;
        _sourcesReady = true;
      });
      for (final source in enabledSources) {
        _sourceById[source.id] = source;
      }
    } else {
      final singleSource = widget.source;
      if (singleSource != null) {
        _searchSources = <BookSource>[singleSource];
        _sourceById[singleSource.id] = singleSource;
      }
      _sourcesReady = true;
    }

    if (widget.initialKeyword.trim().isNotEmpty && mounted) {
      _search(resetPage: true);
    }
  }

  BookSource? _resolveSource(OnlineBookItem item) {
    final matched = _sourceById[item.sourceId];
    if (matched != null) {
      return matched;
    }
    final fallback = _searchSources.where((s) => s.id == item.sourceId);
    if (fallback.isNotEmpty) {
      return fallback.first;
    }
    return widget.source;
  }

  Future<void> _search({required bool resetPage}) async {
    if (!_sourcesReady) {
      showSideToast(context, '正在加载书源，请稍候');
      return;
    }
    if (_searchSources.isEmpty) {
      showSideToast(context, '没有可用书源，请先启用书源');
      return;
    }

    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) {
      showSideToast(context, '请输入关键词');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
      _hasSearched = true;
      if (resetPage) {
        _page = 1;
      }
    });

    try {
      final pageToSearch = resetPage ? 1 : _page + 1;
      final list = widget.aggregateEnabledSources
          ? await _service.searchBooksAcrossSources(
              sources: _searchSources,
              keyword: keyword,
              page: pageToSearch,
            )
          : await _service.searchBooks(
              source: _searchSources.first,
              keyword: keyword,
              page: pageToSearch,
            );

      if (!mounted) return;
      setState(() {
        if (resetPage) {
          _results = list;
          _page = 1;
        } else {
          _results = <OnlineBookItem>[..._results, ...list];
          _page = pageToSearch;
        }
      });

      if (list.isEmpty && !resetPage) {
        showSideToast(context, '没有更多结果');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openBookChapters(OnlineBookItem book) {
    final source = _resolveSource(book);
    if (source == null) {
      showSideToast(context, '无法定位该结果对应的书源');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OnlineChapterListPage(
          source: source,
          book: book,
          onDownloadAndRead: () => _downloadAndOpen(book),
        ),
      ),
    );
  }

  String _safeFileName(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  Future<void> _downloadAndOpen(OnlineBookItem book) async {
    if (_isDownloading) {
      showSideToast(context, '已有下载任务进行中');
      return;
    }

    final source = _resolveSource(book);
    if (source == null) {
      showSideToast(context, '无法定位该结果对应的书源');
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadMessage = '正在获取目录...';
    });

    try {
      final chapters = await _service.getChapters(
        source: source,
        bookUrl: book.bookUrl,
      );
      if (chapters.isEmpty) {
        throw Exception('未获取到可下载章节');
      }

      final txtBuffer = StringBuffer();
      final htmlBuffer = StringBuffer()
        ..writeln('<!doctype html>')
        ..writeln('<html><head><meta charset="utf-8">')
        ..writeln('<title>${htmlEscape.convert(book.title)}</title>')
        ..writeln(
          '<style>body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;line-height:1.7;padding:20px;max-width:820px;margin:0 auto;}h1{font-size:24px;}h2{font-size:18px;margin-top:28px;}p{white-space:pre-wrap;}</style>',
        )
        ..writeln('</head><body>')
        ..writeln('<h1>${htmlEscape.convert(book.title)}</h1>')
        ..writeln('<p>作者：${htmlEscape.convert(book.author)}</p>')
        ..writeln('<p>来源：${htmlEscape.convert(source.bookSourceName)}</p>');

      int successCount = 0;
      for (int i = 0; i < chapters.length; i++) {
        final chapter = chapters[i];
        if (!mounted) return;
        setState(() {
          _downloadMessage = '下载正文 ${i + 1}/${chapters.length}';
        });
        try {
          final content = await _service.getChapterContent(
            source: source,
            chapter: chapter,
          );
          final chapterText = content.content.trim();
          if (chapterText.isEmpty) {
            continue;
          }
          successCount++;
          txtBuffer
            ..writeln(chapter.title)
            ..writeln()
            ..writeln(chapterText)
            ..writeln();
          htmlBuffer
            ..writeln('<h2>${htmlEscape.convert(chapter.title)}</h2>')
            ..writeln('<p>${htmlEscape.convert(chapterText)}</p>');
        } catch (_) {
          continue;
        }
      }

      htmlBuffer.writeln('</body></html>');

      if (successCount == 0 || txtBuffer.toString().trim().isEmpty) {
        throw Exception('章节内容为空或规则不兼容');
      }

      setState(() {
        _downloadMessage = '写入文件并入库...';
      });

      final docsDir = await getApplicationDocumentsDirectory();
      final importDir = Directory(p.join(docsDir.path, 'online_imports'));
      if (!await importDir.exists()) {
        await importDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final baseName = _safeFileName('${book.title}_${source.bookSourceName}');
      final txtPath = p.join(importDir.path, '${baseName}_$timestamp.txt');
      final htmlPath = p.join(importDir.path, '${baseName}_$timestamp.html');

      final txtContent = txtBuffer.toString().trim();
      await File(txtPath).writeAsString(txtContent, flush: true);
      await File(htmlPath).writeAsString(htmlBuffer.toString(), flush: true);

      final hash = md5.convert(utf8.encode(txtContent)).toString();
      final insertedId = await _bookDao.insertBook(
        Book(
          title: '${book.title} [${source.bookSourceName}]',
          author: book.author.isEmpty ? '未知' : book.author,
          filePath: txtPath,
          format: 'txt',
          contentHash: hash,
        ),
      );

      final inserted = await _bookDao.getBookById(insertedId);
      if (!mounted || inserted == null) {
        return;
      }

      LibraryEventBus().notifyLibraryChanged();
      showSideToast(context, '下载完成，已保存 TXT + HTML');
      await ReadingRouterService.openBook(context, inserted);
    } catch (e) {
      if (mounted) {
        showSideToast(context, '下载失败：$e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadMessage = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.aggregateEnabledSources
              ? '全源搜索'
              : (_searchSources.isNotEmpty
                  ? _searchSources.first.bookSourceName
                  : '书源搜索'),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : () => _search(resetPage: true),
            icon: const Icon(Icons.search),
            tooltip: '搜索',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _keywordController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(resetPage: true),
                    decoration: const InputDecoration(
                      hintText: '输入书名或作者',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: (_isLoading || _isDownloading)
                      ? null
                      : () => _search(resetPage: true),
                  child: const Text('搜索'),
                ),
              ],
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          if (_isDownloading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _downloadMessage.isEmpty ? '下载中...' : _downloadMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _buildBody(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (!_hasSearched) {
      return const Center(child: Text('输入关键词后开始搜索'));
    }
    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '搜索失败：$_error',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      );
    }
    if (_results.isEmpty && !_isLoading) {
      return const Center(child: Text('没有搜索到结果'));
    }

    return RefreshIndicator(
      onRefresh: () => _search(resetPage: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
        itemCount: _results.length + 1,
        itemBuilder: (context, index) {
          if (index == _results.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : () => _search(resetPage: false),
                icon: const Icon(Icons.expand_more),
                label: const Text('加载下一页'),
              ),
            );
          }

          final book = _results[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openBookChapters(book),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      book.author.isEmpty ? '作者未知' : '作者：${book.author}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '来源：${book.sourceName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (book.latestChapter.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '最新：${book.latestChapter}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (book.intro.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        book.intro,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _openBookChapters(book),
                          icon: const Icon(Icons.list_alt),
                          label: const Text('目录'),
                        ),
                        const SizedBox(width: 6),
                        FilledButton.icon(
                          onPressed: _isDownloading
                              ? null
                              : () => _downloadAndOpen(book),
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('下载并阅读'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class OnlineChapterListPage extends StatefulWidget {
  const OnlineChapterListPage({
    super.key,
    required this.source,
    required this.book,
    this.onDownloadAndRead,
  });

  final BookSource source;
  final OnlineBookItem book;
  final Future<void> Function()? onDownloadAndRead;

  @override
  State<OnlineChapterListPage> createState() => _OnlineChapterListPageState();
}

class _OnlineChapterListPageState extends State<OnlineChapterListPage> {
  final _service = OnlineBookSourceService.instance();

  List<OnlineChapterItem> _chapters = const <OnlineChapterItem>[];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final chapters = await _service.getChapters(
        source: widget.source,
        bookUrl: widget.book.bookUrl,
      );
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadAndRead() async {
    final callback = widget.onDownloadAndRead;
    if (callback == null) {
      showSideToast(context, '当前页面未接入下载能力');
      return;
    }
    await callback();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadChapters,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新目录',
          ),
          IconButton(
            onPressed: _isLoading ? null : _downloadAndRead,
            icon: const Icon(Icons.download_rounded),
            tooltip: '下载并阅读',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '目录加载失败：$_error',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                )
              : _chapters.isEmpty
                  ? const Center(child: Text('没有解析到章节'))
                  : ListView.separated(
                      itemCount: _chapters.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final chapter = _chapters[index];
                        return ListTile(
                          title: Text(
                            chapter.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('第 ${index + 1} 章'),
                          onTap: () => showSideToast(
                            context,
                            '为保证体验一致，请使用右上角“下载并阅读”',
                          ),
                        );
                      },
                    ),
    );
  }
}

class OnlineReaderPage extends StatefulWidget {
  const OnlineReaderPage({
    super.key,
    required this.source,
    required this.book,
    required this.chapters,
    required this.initialIndex,
  });

  final BookSource source;
  final OnlineBookItem book;
  final List<OnlineChapterItem> chapters;
  final int initialIndex;

  @override
  State<OnlineReaderPage> createState() => _OnlineReaderPageState();
}

class _OnlineReaderPageState extends State<OnlineReaderPage> {
  final _service = OnlineBookSourceService.instance();

  late int _currentIndex;
  bool _isLoading = true;
  String _content = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.chapters.length - 1);
    _loadCurrentChapter();
  }

  Future<void> _loadCurrentChapter() async {
    final chapter = widget.chapters[_currentIndex];
    setState(() {
      _isLoading = true;
      _error = '';
      _content = '';
    });

    try {
      final chapterContent = await _service.getChapterContent(
        source: widget.source,
        chapter: chapter,
      );
      if (!mounted) return;
      setState(() {
        _content = chapterContent.content;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _jumpToChapter(int nextIndex) async {
    if (nextIndex < 0 || nextIndex >= widget.chapters.length) return;
    setState(() {
      _currentIndex = nextIndex;
    });
    await _loadCurrentChapter();
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.chapters[_currentIndex];
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          chapter.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadCurrentChapter,
            icon: const Icon(Icons.refresh),
            tooltip: '重新加载',
          ),
          IconButton(
            onPressed: () => _showChapterPicker(context),
            icon: const Icon(Icons.menu_book),
            tooltip: '章节列表',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _buildContent(theme),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }
    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '正文加载失败：$_error',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      );
    }
    if (_content.trim().isEmpty) {
      return const Center(child: Text('正文为空或规则暂不兼容'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      child: SelectableText(
        _content,
        style: theme.textTheme.bodyLarge?.copyWith(
          height: 1.75,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final hasPrev = _currentIndex > 0;
    final hasNext = _currentIndex < widget.chapters.length - 1;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: (!_isLoading && hasPrev)
                    ? () => _jumpToChapter(_currentIndex - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
                label: const Text('上一章'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: (!_isLoading && hasNext)
                    ? () => _jumpToChapter(_currentIndex + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
                label: const Text('下一章'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChapterPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: ListView.builder(
            itemCount: widget.chapters.length,
            itemBuilder: (context, index) {
              final chapter = widget.chapters[index];
              return ListTile(
                selected: index == _currentIndex,
                title: Text(
                  chapter.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('第 ${index + 1} 章'),
                onTap: () => Navigator.pop(context, index),
              );
            },
          ),
        );
      },
    );

    if (selected != null && selected != _currentIndex) {
      await _jumpToChapter(selected);
    }
  }
}
