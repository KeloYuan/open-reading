import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Page;

import 'ai/ai_service.dart';
import 'data/reader_models.dart';
import 'document/flow_doc.dart';
import 'paginator/flow_paginator.dart';
import 'paginator/page_plan.dart';
import 'parser/epub_parser.dart';
import 'parser/mobi_parser.dart';
import 'parser/parser_models.dart';
import 'parser/txt_parser.dart';
import 'selection/reader_selection.dart';
import 'storage/reader_storage.dart';

class ReaderKernelController extends ChangeNotifier {
  ReaderKernelController({
    ReaderStorage? storage,
    AIService? aiService,
    FlowPaginator? paginator,
  })  : _storage = storage ?? ReaderStorage(),
        _aiService = aiService ?? ReaderHttpAIService(),
        _paginator = paginator ?? FlowPaginator();

  final ReaderStorage _storage;
  final AIService _aiService;
  final FlowPaginator _paginator;

  String? _openBookId;
  String? _openTitle;
  String? _openAuthor;
  String? _openFilePath;
  String? _openFormat;

  ParsedBook? _parsedBook;
  int _chapterIndex = 0;
  int _pageIndex = 0;
  PagePlan? _pagePlan;
  int _paginationRequestId = 0;

  ReaderStyle _style = const ReaderStyle();
  PageLayout _layout = const PageLayout(
    usableWidth: 360,
    usableHeight: 640,
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    columns: 1,
    gutter: 24,
  );

  bool _loading = false;
  String? _error;
  String? _lastAiAnswer;
  List<Annotation> _annotations = const [];

  ParsedBook? get parsedBook => _parsedBook;
  int get chapterIndex => _chapterIndex;
  int get pageIndex => _pageIndex;
  PagePlan? get pagePlan => _pagePlan;
  ReaderStyle get style => _style;
  PageLayout get layout => _layout;
  bool get loading => _loading;
  String? get error => _error;
  String? get lastAiAnswer => _lastAiAnswer;
  List<Annotation> get annotations => _annotations;

  ParsedChapter? get currentParsedChapter {
    final book = _parsedBook;
    if (book == null || book.chapters.isEmpty) return null;
    return book.chapters[_chapterIndex.clamp(0, book.chapters.length - 1)];
  }

  Future<void> openBook({
    required String bookId,
    required String title,
    required String author,
    required String filePath,
    required String format,
    String? textEncoding,
  }) async {
    _openBookId = bookId;
    _openTitle = title;
    _openAuthor = author;
    _openFilePath = filePath;
    _openFormat = format;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final parser = _pickParser(format);
      final parsed = await parser.parse(
        bookId: bookId,
        title: title,
        author: author,
        filePath: filePath,
        encodingOverride: textEncoding,
      );

      _parsedBook = parsed;
      _chapterIndex = 0;
      _pageIndex = 0;
      _pagePlan = null;

      await _storage.saveBook(parsed.book);
      if (_shouldPersistChapters(parsed)) {
        await _storage
            .saveChapters(parsed.chapters.map((e) => e.chapter).toList());
      } else if (kDebugMode) {
        final totalChars = parsed.chapters.fold<int>(
          0,
          (sum, item) => sum + item.chapter.content.length,
        );
        debugPrint(
          '[ReaderController] skip persisting chapters for fast-open '
          'format=${parsed.book.format} chapters=${parsed.chapters.length} chars=$totalChars',
        );
      }

      final position = await _storage.getReadingPosition(bookId);
      if (position != null) {
        final chapter = parsed.chapters
            .indexWhere((e) => e.chapter.id == position.chapterId);
        if (chapter >= 0) {
          _chapterIndex = chapter;
        }
      }

      await _loadAnnotations();
      await paginateCurrentChapter(anchorOffset: null);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  bool _shouldPersistChapters(ParsedBook parsed) {
    final format = parsed.book.format.toLowerCase();
    if (format != 'txt') {
      return true;
    }
    final chapterCount = parsed.chapters.length;
    final totalChars = parsed.chapters.fold<int>(
      0,
      (sum, item) => sum + item.chapter.content.length,
    );

    // 大TXT首开优先速度：避免一次性大量写库导致长时间转圈。
    if (totalChars > 1200000) {
      return false;
    }
    if (chapterCount > 320) {
      return false;
    }
    return true;
  }

  Future<void> reloadWithEncoding(String? textEncoding) async {
    if (_openBookId == null ||
        _openTitle == null ||
        _openAuthor == null ||
        _openFilePath == null ||
        _openFormat == null) {
      return;
    }

    final parsed = currentParsedChapter;
    final plan = _pagePlan;
    final book = _parsedBook?.book;
    if (parsed != null &&
        plan != null &&
        plan.pages.isNotEmpty &&
        book != null) {
      final current = plan.pages[_pageIndex.clamp(0, plan.pages.length - 1)];
      await _storage.saveReadingPosition(
        bookId: book.id,
        position: ReadingPosition(
          chapterId: parsed.chapter.id,
          anchorOffset: current.startOffset,
        ),
      );
    }

    await openBook(
      bookId: _openBookId!,
      title: _openTitle!,
      author: _openAuthor!,
      filePath: _openFilePath!,
      format: _openFormat!,
      textEncoding: textEncoding,
    );
  }

  BookParser _pickParser(String format) {
    final normalized = format.toLowerCase();
    if (normalized == 'epub') {
      return EpubParser();
    }
    if (normalized == 'mobi' || normalized == 'azw' || normalized == 'azw3') {
      return MobiParser();
    }
    return TxtParser();
  }

  Future<void> updateViewport({
    required Size viewport,
    required EdgeInsets padding,
    required bool enableSpread,
  }) async {
    if (_parsedBook == null) return;

    final nextColumns = enableSpread ? 2 : 1;
    const spreadGutter = 24.0;
    final paneWidth =
        enableSpread ? ((viewport.width - spreadGutter) / 2) : viewport.width;
    final usableWidth = math.max(80.0, paneWidth - padding.horizontal);
    final usableHeight = math.max(80.0, viewport.height - padding.vertical);

    final nextLayout = _layout.copyWith(
      usableWidth: usableWidth,
      usableHeight: usableHeight,
      padding: padding,
      columns: nextColumns,
      gutter: spreadGutter,
    );

    final changed = nextLayout.cacheSignature() != _layout.cacheSignature();
    _layout = nextLayout;
    if (kDebugMode && changed) {
      debugPrint(
        '[ReaderController] viewport=${viewport.width.toStringAsFixed(1)}x${viewport.height.toStringAsFixed(1)} '
        'padding=(${padding.left.toStringAsFixed(1)},${padding.top.toStringAsFixed(1)},'
        '${padding.right.toStringAsFixed(1)},${padding.bottom.toStringAsFixed(1)}) '
        'usable=${usableWidth.toStringAsFixed(1)}x${usableHeight.toStringAsFixed(1)} '
        'columns=$nextColumns',
      );
    }

    if (changed) {
      final anchor = currentAnchorOffset;
      _loading = true;
      _error = null;
      _pagePlan = null;
      notifyListeners();
      await paginateCurrentChapter(anchorOffset: anchor);
    }
  }

  Future<void> updateStyle(ReaderStyle nextStyle) async {
    if (_parsedBook == null) return;
    if (_style.cacheSignature() == nextStyle.cacheSignature()) return;

    final anchor = currentAnchorOffset;
    _style = nextStyle;
    _loading = true;
    _error = null;
    _pagePlan = null;
    notifyListeners();

    await paginateCurrentChapter(anchorOffset: anchor);
  }

  int get currentAnchorOffset {
    final plan = _pagePlan;
    if (plan == null || plan.pages.isEmpty) return 0;
    final index = _pageIndex.clamp(0, plan.pages.length - 1);
    return plan.pages[index].startOffset;
  }

  Future<void> jumpToChapter(int chapterIndex, {int? anchorOffset}) async {
    if (_parsedBook == null) return;
    _chapterIndex = chapterIndex.clamp(0, _parsedBook!.chapters.length - 1);
    _pageIndex = 0;
    await _loadAnnotations();
    await paginateCurrentChapter(anchorOffset: anchorOffset);
  }

  Future<void> paginateCurrentChapter({int? anchorOffset}) async {
    final parsed = currentParsedChapter;
    final parsedBook = _parsedBook;
    if (parsed == null || parsedBook == null) return;
    final requestId = ++_paginationRequestId;

    final chapterId = parsed.chapter.id;
    final chapterCacheId =
        '$chapterId:${parsed.chapter.content.length}:${parsed.chapter.content.hashCode}';
    final cacheKey = FlowPaginator.buildCacheKey(
      chapterId: chapterCacheId,
      style: _style,
      layout: _layout,
    );

    final cachedMemory = FlowPaginator.getMemoryCache(cacheKey);
    if (cachedMemory != null) {
      if (requestId != _paginationRequestId) {
        if (kDebugMode) {
          debugPrint(
            '[ReaderController] ignore stale memory cache request=$requestId '
            'current=$_paginationRequestId',
          );
        }
        return;
      }
      final repaired =
          _repairPagePlanIfNeeded(cachedMemory, parsed.chapter.content);
      _applyPagePlan(repaired, anchorOffset: anchorOffset);
      return;
    }

    final cachedDisk = await _storage.getPaginationCache(cacheKey);
    if (cachedDisk != null) {
      if (requestId != _paginationRequestId) {
        if (kDebugMode) {
          debugPrint(
            '[ReaderController] ignore stale disk cache request=$requestId '
            'current=$_paginationRequestId',
          );
        }
        return;
      }
      final repaired =
          _repairPagePlanIfNeeded(cachedDisk, parsed.chapter.content);
      FlowPaginator.putMemoryCache(repaired);
      _applyPagePlan(repaired, anchorOffset: anchorOffset);
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      if (kDebugMode) {
        debugPrint(
          '[ReaderController] paginate request=$requestId chapter=${parsed.chapter.id} '
          'layout=${_layout.cacheSignature()} style=${_style.cacheSignature()}',
        );
      }
      final result = await _paginator.paginate(
        chapterId: chapterId,
        flowDoc: parsed.flowDoc,
        style: _style,
        layout: _layout,
        chapterTitle: parsed.chapter.title,
        eagerPageCount: 4,
        batchSize: 8,
        onProgress: (pages, done) {
          if (requestId != _paginationRequestId) {
            if (kDebugMode) {
              debugPrint(
                '[ReaderController] drop stale onProgress request=$requestId '
                'current=$_paginationRequestId pages=${pages.length} done=$done',
              );
            }
            return;
          }
          _pagePlan = _repairPagePlanIfNeeded(
            PagePlan(chapterId: chapterId, pages: pages, cacheKey: cacheKey),
            parsed.chapter.content,
          );
          final currentPageCount = _pagePlan?.pages.length ?? pages.length;
          if (!done && currentPageCount > 0 && _pageIndex >= currentPageCount) {
            _pageIndex = currentPageCount - 1;
          }
          notifyListeners();
        },
      );
      if (requestId != _paginationRequestId) {
        if (kDebugMode) {
          debugPrint(
            '[ReaderController] drop stale result request=$requestId '
            'current=$_paginationRequestId pages=${result.pages.length}',
          );
        }
        return;
      }

      final repairedResult =
          _repairPagePlanIfNeeded(result, parsed.chapter.content);
      _applyPagePlan(repairedResult, anchorOffset: anchorOffset);
      await _storage.savePaginationCache(
        cacheKey: cacheKey,
        bookId: parsedBook.book.id,
        chapterId: chapterId,
        plan: repairedResult,
      );
    } catch (e) {
      if (requestId != _paginationRequestId) {
        if (kDebugMode) {
          debugPrint(
            '[ReaderController] ignore stale error request=$requestId '
            'current=$_paginationRequestId error=$e',
          );
        }
        return;
      }
      _error = e.toString();
    } finally {
      if (requestId == _paginationRequestId) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  void _applyPagePlan(PagePlan plan, {int? anchorOffset}) {
    _pagePlan = plan;

    if (anchorOffset != null) {
      _pageIndex = FlowPaginator.findPageIndexByAnchor(plan, anchorOffset);
    } else if (_pageIndex >= plan.pages.length) {
      _pageIndex = math.max(0, plan.pages.length - 1);
    }
    if (kDebugMode) {
      debugPrint(
        '[ReaderController] applyPagePlan chapter=$_chapterIndex pages=${plan.pages.length} '
        'anchor=${anchorOffset ?? -1} pageIndex=$_pageIndex',
      );
    }

    notifyListeners();
  }

  Future<void> setPageIndex(int pageIndex) async {
    final parsed = currentParsedChapter;
    final book = _parsedBook?.book;
    if (parsed == null ||
        book == null ||
        _pagePlan == null ||
        _pagePlan!.pages.isEmpty) {
      return;
    }

    _pageIndex = pageIndex.clamp(0, _pagePlan!.pages.length - 1);
    if (kDebugMode) {
      final page = _pagePlan!.pages[_pageIndex];
      debugPrint(
        '[ReaderController] setPageIndex=$_pageIndex '
        'range=${page.startOffset}-${page.endOffset}',
      );
    }
    notifyListeners();

    final page = _pagePlan!.pages[_pageIndex];
    await _storage.saveReadingPosition(
      bookId: book.id,
      position: ReadingPosition(
        chapterId: parsed.chapter.id,
        anchorOffset: page.startOffset,
      ),
    );
  }

  Future<void> addHighlight(ReaderSelectionPayload payload) async {
    final parsed = currentParsedChapter;
    final book = _parsedBook?.book;
    if (parsed == null || book == null) return;

    final annotation = Annotation(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      bookId: book.id,
      chapterId: parsed.chapter.id,
      startOffset: payload.globalStart,
      endOffset: payload.globalEnd,
      color: const Color(0x66FFE082),
      createdAt: DateTime.now(),
    );
    await _storage.saveAnnotation(annotation);
    await _loadAnnotations();
    notifyListeners();
  }

  Future<void> addNote({
    required ReaderSelectionPayload payload,
    required String note,
  }) async {
    final parsed = currentParsedChapter;
    final book = _parsedBook?.book;
    if (parsed == null || book == null) return;

    final annotation = Annotation(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      bookId: book.id,
      chapterId: parsed.chapter.id,
      startOffset: payload.globalStart,
      endOffset: payload.globalEnd,
      color: const Color(0x6659B6F6),
      noteText: note,
      createdAt: DateTime.now(),
    );
    await _storage.saveAnnotation(annotation);
    await _loadAnnotations();
    notifyListeners();
  }

  Future<void> onSelection(ReaderSelectionPayload payload) async {
    if (payload.action == ReaderSelectionAction.highlight) {
      await addHighlight(payload);
      return;
    }
    if (payload.action == ReaderSelectionAction.note) {
      await addNote(payload: payload, note: payload.text);
      return;
    }
    if (payload.action == ReaderSelectionAction.askAi) {
      await askSelectionAi(
          payload.text, payload.globalStart, payload.globalEnd);
    }
  }

  Future<void> askSelectionAi(
      String text, int globalStart, int globalEnd) async {
    final parsed = currentParsedChapter;
    final book = _parsedBook?.book;
    if (parsed == null || book == null) return;

    final chapterText = parsed.chapter.content;
    final beforeStart = math.max(0, globalStart - 120);
    final afterEnd = math.min(chapterText.length, globalEnd + 120);

    final contextBefore = beforeStart < globalStart
        ? chapterText.substring(beforeStart, globalStart)
        : '';
    final contextAfter =
        globalEnd < afterEnd ? chapterText.substring(globalEnd, afterEnd) : '';

    _lastAiAnswer = await _aiService.askSelection(
      selectedText: text,
      contextBefore: contextBefore,
      contextAfter: contextAfter,
      meta: AIRequestMeta(
        bookId: book.id,
        chapterId: parsed.chapter.id,
        pageIndex: _pageIndex,
      ),
    );
    notifyListeners();
  }

  Future<void> analyzeCurrentPage() async {
    final plan = _pagePlan;
    final parsed = currentParsedChapter;
    final book = _parsedBook?.book;
    if (plan == null || parsed == null || book == null || plan.pages.isEmpty) {
      return;
    }

    final page = plan.pages[_pageIndex.clamp(0, plan.pages.length - 1)];
    final text = pageText(page);

    _lastAiAnswer = await _aiService.analyzePage(
      pageText: text,
      meta: AIRequestMeta(
        bookId: book.id,
        chapterId: parsed.chapter.id,
        pageIndex: _pageIndex,
      ),
    );
    notifyListeners();
  }

  Future<AIProviderSettings> loadAiSettings([AIProviderType? provider]) async {
    final aiService = _aiService;
    if (aiService is ConfigurableAIService) {
      return aiService.loadSettings(provider);
    }
    return AIProviderSettings.defaults(provider ?? AIProviderType.minimax);
  }

  Future<void> saveAiSettings(AIProviderSettings settings) async {
    final aiService = _aiService;
    if (aiService is! ConfigurableAIService) {
      return;
    }
    await aiService.saveSettings(settings);
  }

  Future<String> askAiChat({
    required List<AIChatMessage> history,
    required String pageText,
  }) async {
    final parsed = currentParsedChapter;
    final book = _parsedBook?.book;
    if (parsed == null || book == null) {
      throw const AIServiceException('请先打开书籍后再使用 AI');
    }

    final answer = await _aiService.chat(
      history: history,
      pageText: pageText,
      meta: AIRequestMeta(
        bookId: book.id,
        chapterId: parsed.chapter.id,
        pageIndex: _pageIndex,
      ),
    );
    _lastAiAnswer = answer;
    notifyListeners();
    return answer;
  }

  String pageText(Page page) {
    final chapter = currentParsedChapter;
    if (chapter == null) return '';

    final blockMap = <String, Block>{
      for (final b in chapter.flowDoc.blocks) b.id: b
    };
    final buffer = StringBuffer();

    for (final fragment in page.fragments) {
      if (fragment is TextFragment) {
        final block = blockMap[fragment.blockId];
        if (block is ParagraphBlock) {
          final text = block.plainText;
          if (fragment.start >= 0 &&
              fragment.end <= text.length &&
              fragment.end > fragment.start) {
            buffer.write(text.substring(fragment.start, fragment.end));
          }
        }
        if (block is HeadingBlock) {
          final text = block.plainText;
          if (fragment.start >= 0 &&
              fragment.end <= text.length &&
              fragment.end > fragment.start) {
            buffer.write(text.substring(fragment.start, fragment.end));
          }
        }
      }
      if (fragment is SpaceFragment) {
        buffer.write('\n');
      }
    }

    return buffer.toString();
  }

  PagePlan _repairPagePlanIfNeeded(PagePlan plan, String chapterText) {
    if (chapterText.trim().isEmpty) {
      return plan;
    }

    final hasMeaningfulPage = plan.pages.any(
      (p) => p.fragments.isNotEmpty || p.endOffset > p.startOffset,
    );
    if (hasMeaningfulPage) {
      return plan;
    }

    final rebuiltPages = _paginatePlainText(chapterText);

    return PagePlan(
      chapterId: plan.chapterId,
      pages: rebuiltPages,
      cacheKey: plan.cacheKey,
    );
  }

  List<Page> _paginatePlainText(String text) {
    final pages = <Page>[];
    if (text.isEmpty) {
      return const [
        Page(index: 0, startOffset: 0, endOffset: 0, fragments: []),
      ];
    }

    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: _style.textAlign,
      locale: _style.locale,
    );

    var start = 0;
    var pageIndex = 0;
    final maxLines = math.max(
      1,
      (_layout.usableHeight / (_style.fontSize * _style.lineHeight)).floor(),
    );

    while (start < text.length) {
      final remaining = text.substring(start);
      painter.text = TextSpan(text: remaining, style: _style.toTextStyle());
      painter.layout(maxWidth: _layout.usableWidth);

      int end;
      if (painter.height <= _layout.usableHeight) {
        end = text.length;
      } else {
        final lineHeight = _style.fontSize * _style.lineHeight;
        final targetDy = (maxLines * lineHeight - 0.5)
            .clamp(0.5, _layout.usableHeight - 0.5)
            .toDouble();
        final probe = painter.getPositionForOffset(
          Offset(_layout.usableWidth - 0.5, targetDy),
        );
        var localEnd = painter.getLineBoundary(probe).end;
        if (localEnd <= 0) {
          final fallback = painter.getPositionForOffset(
            Offset(_layout.usableWidth - 0.5, _layout.usableHeight - 0.5),
          );
          localEnd = math.max(1, painter.getLineBoundary(fallback).end);
        }
        if (localEnd <= 0 && start + 1 < text.length) {
          localEnd = painter.getWordBoundary(const TextPosition(offset: 1)).end;
        }
        end = (start + localEnd).clamp(start + 1, text.length).toInt();
      }

      pages.add(
        Page(
          index: pageIndex,
          startOffset: start,
          endOffset: end,
          fragments: const [],
        ),
      );
      pageIndex += 1;
      start = end;
    }

    painter.dispose();
    return pages;
  }

  Future<void> _loadAnnotations() async {
    final parsed = currentParsedChapter;
    final book = _parsedBook?.book;
    if (parsed == null || book == null) {
      _annotations = const [];
      return;
    }

    _annotations = await _storage.listAnnotations(
      bookId: book.id,
      chapterId: parsed.chapter.id,
    );
  }
}
