import 'package:flutter/material.dart';

import 'package:xxread/models/book_source.dart';
import 'package:xxread/services/books/online_book_source_service.dart';
import 'package:xxread/widgets/side_toast.dart';

class OnlineBookSearchPage extends StatefulWidget {
  const OnlineBookSearchPage({
    super.key,
    required this.source,
    this.initialKeyword = '',
  });

  final BookSource source;
  final String initialKeyword;

  @override
  State<OnlineBookSearchPage> createState() => _OnlineBookSearchPageState();
}

class _OnlineBookSearchPageState extends State<OnlineBookSearchPage> {
  final _service = OnlineBookSourceService.instance();
  late final TextEditingController _keywordController;

  List<OnlineBookItem> _results = const <OnlineBookItem>[];
  bool _isLoading = false;
  bool _hasSearched = false;
  int _page = 1;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _keywordController = TextEditingController(text: widget.initialKeyword);
    if (widget.initialKeyword.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _search(resetPage: true);
      });
    }
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _search({required bool resetPage}) async {
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
      final list = await _service.searchBooks(
        source: widget.source,
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OnlineChapterListPage(
          source: widget.source,
          book: book,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.source.bookSourceName),
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
                  onPressed: _isLoading ? null : () => _search(resetPage: true),
                  child: const Text('搜索'),
                ),
              ],
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
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
  });

  final BookSource source;
  final OnlineBookItem book;

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

  void _openReader(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OnlineReaderPage(
          source: widget.source,
          book: widget.book,
          chapters: _chapters,
          initialIndex: index,
        ),
      ),
    );
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
                          onTap: () => _openReader(index),
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
