// 文件说明：EpubPlayer 组件——封装 Foliate WebView、JS Bridge 和阅读状态。
// 技术要点：InAppWebView、JS Bridge、EpubPlayerContract、OverlayEntry。

import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:xxread/models/book.dart' as legacy;
import 'package:xxread/models/book_note.dart';
import 'package:xxread/models/bookmark.dart';
import 'package:xxread/services/books/book_note_dao.dart';
import 'package:xxread/services/books/bookmark_dao.dart';
import 'package:xxread/widgets/context_menu/context_menu.dart';

class EpubPlayer extends StatefulWidget {
  final legacy.Book book;
  final String? sourceFilePath;
  final String? serverUrl;
  final String? initialCfi;
  final double initialProgress;
  final Map<String, dynamic> foliateConfig;
  final VoidCallback? onRelocated;
  final ValueChanged<bool>? onBookmarkChanged;
  final ValueChanged<double>? onClick;
  final VoidCallback? onLoadEnd;
  final VoidCallback? onPullUp;
  final ValueChanged<String>? onExternalLink;

  const EpubPlayer({
    super.key,
    required this.book,
    this.sourceFilePath,
    this.serverUrl,
    this.initialCfi,
    this.initialProgress = 0.0,
    required this.foliateConfig,
    this.onRelocated,
    this.onBookmarkChanged,
    this.onClick,
    this.onLoadEnd,
    this.onPullUp,
    this.onExternalLink,
  });

  @override
  State<EpubPlayer> createState() => EpubPlayerState();
}

class EpubPlayerState extends State<EpubPlayer> implements EpubPlayerContract {
  InAppWebViewController? _webController;
  bool _readerReady = false;

  // 阅读状态
  String _cfi = '';
  double _percentage = 0.0;
  String _chapterTitle = '';
  int _chapterCurrentPage = 0;
  int _chapterTotalPages = 0;
  int _bookCurrentPage = 1;
  int _bookTotalPages = 1;
  List<dynamic> _toc = [];

  // 书签状态
  bool _bookmarkExists = false;
  String? _bookmarkCfi;

  // 导航历史
  bool _canGoBack = false;
  bool _canGoForward = false;

  // 搜索状态
  double _searchProgress = 0.0;
  List<SearchResult> _searchResults = [];
  bool _searchActive = false;

  // Overlay
  @override
  OverlayEntry? contextMenuEntry;

  // 选择锁定（笔记编辑时防止选中区域被清除）
  bool _selectionClearLocked = false;
  bool _selectionClearPending = false;

  final _bookNoteDao = BookNoteDao();
  final _bookmarkDao = BookmarkDao();

  bool get _isPdfFormat => widget.book.format.toLowerCase() == 'pdf';

  // EpubPlayerContract 实现
  @override
  String get chapterTitle => _chapterTitle;

  @override
  int? get bookId => widget.book.id;

  bool get bookmarkExists => _bookmarkExists;

  String? get bookmarkCfi => _bookmarkCfi;

  String get cfi => _cfi;

  double get percentage => _percentage;

  int get chapterCurrentPage => _chapterCurrentPage;

  int get chapterTotalPages => _chapterTotalPages;

  int get bookCurrentPage => _bookCurrentPage;

  int get bookTotalPages => _bookTotalPages;

  List<dynamic> get toc => _toc;

  bool get canGoBack => _canGoBack;

  bool get canGoForward => _canGoForward;

  bool get searchActive => _searchActive;

  double get searchProgress => _searchProgress;

  List<SearchResult> get searchResults => _searchResults;

  bool get readerReady => _readerReady;

  // WebView 控制方法
  void prevPage() => _callMethod('prevPage');

  void nextPage() => _callMethod('nextPage');

  void goToHref(String href) => _callMethod('goToHref', href);

  void goToCfi(String cfi) => _callMethod('goToCfi', cfi);

  void goToPercent(double val) => _callMethod('goToPercent', val);

  void changeStyle(Map<String, dynamic> style) => _callMethod('changeStyle', style);

  void addBookmarkHere() => _callMethod('addBookmarkHere');

  @override
  void addAnnotation(BookNote bookNote) {
    if (_isPdfFormat) return; // PDF canvas 不支持 SVG overlay
    final noteContent =
        bookNote.content.replaceAll('\n', ' ').replaceAll("'", "\\'");
    _callMethod('addAnnotation', {
      'id': bookNote.id,
      'type': bookNote.type,
      'value': bookNote.cfi,
      'color': '#${bookNote.color}',
      'note': noteContent,
    });
  }

  @override
  void removeAnnotation(String cfi) => _callMethod('removeAnnotation', cfi);

  @override
  void clearWebViewSelection() => _callMethod('clearSelection');

  @override
  void setSelectionClearLocked(bool locked) {
    _selectionClearLocked = locked;
    if (!locked && _selectionClearPending) {
      _selectionClearPending = false;
      removeOverlay();
    }
  }

  void search(String text) {
    final sanitized = text.trim();
    if (sanitized.isEmpty) {
      clearSearch();
      return;
    }
    setState(() {
      _searchActive = true;
      _searchProgress = 0.0;
      _searchResults = [];
    });
    _callMethod('search', [sanitized, {
      'scope': 'book',
      'matchCase': false,
      'matchDiacritics': false,
      'matchWholeWords': false,
    }]);
  }

  void clearSearch() {
    _callMethod('clearSearch');
    setState(() {
      _searchActive = false;
      _searchProgress = 0.0;
      _searchResults = [];
    });
  }

  void backHistory() => _callMethod('back');

  void forwardHistory() => _callMethod('forward');

  void refreshToc() => _callMethod('refreshToc');

  Future<String?> theChapterContent() async {
    return await _webController?.evaluateJavascript(
        source: 'theChapterContent()');
  }

  @override
  void removeOverlay() {
    _selectionClearLocked = false;
    _selectionClearPending = false;
    if (contextMenuEntry == null || contextMenuEntry?.mounted == false) return;
    contextMenuEntry?.remove();
    contextMenuEntry = null;
  }

  Future<void> renderAnnotations() async {
    final bookId = widget.book.id;
    if (bookId == null) {
      _callMethod('renderAnnotations', const <Map<String, dynamic>>[]);
      return;
    }

    final bookmarks = await _bookmarkDao.getBookmarksForBook(bookId);
    final notes = await _bookNoteDao.selectBookNotesByBookId(bookId);
    final annotations = <Map<String, dynamic>>[
      for (final bookmark in bookmarks)
        if ((bookmark.cfi ?? '').trim().isNotEmpty)
          {
            'id': bookmark.id,
            'value': bookmark.cfi,
            'type': 'bookmark',
            'color': '#215a8f',
            'note': bookmark.note,
          },
      for (final note in notes)
        if (note.cfi.trim().isNotEmpty)
          {
            'id': note.id,
            'value': note.cfi,
            'type': note.type,
            'color': '#${note.color}',
            'note': note.content,
          },
    ];
    _callMethod('renderAnnotations', annotations);
  }

  // JS Bridge 注册
  void _registerHandlers(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'onLoadEnd',
      callback: (args) {
        if (mounted) setState(() => _readerReady = true);
        widget.onLoadEnd?.call();
        return null;
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onRelocated',
      callback: (args) {
        if (args.isEmpty || args.first is! Map) return null;
        final payload = Map<String, dynamic>.from(args.first as Map);
        final bookmark = payload['bookmark'];
        final bookmarkMap =
            bookmark is Map ? Map<String, dynamic>.from(bookmark) : null;

        setState(() {
          _chapterTitle = payload['chapterTitle']?.toString() ?? '';
          _chapterCurrentPage =
              (payload['chapterCurrentPage'] as num?)?.toInt() ?? 0;
          _chapterTotalPages =
              (payload['chapterTotalPages'] as num?)?.toInt() ?? 0;
          _bookCurrentPage =
              (payload['bookCurrentPage'] as num?)?.toInt() ?? 1;
          _bookTotalPages =
              (payload['bookTotalPages'] as num?)?.toInt() ?? 1;
          _cfi = payload['cfi']?.toString() ?? '';
          _percentage =
              (payload['percentage'] as num?)?.toDouble() ?? 0.0;
          _bookmarkExists = bookmarkMap?['exists'] == true;
          _bookmarkCfi = bookmarkMap?['cfi']?.toString();
        });
        widget.onRelocated?.call();
        return null;
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onSetToc',
      callback: (args) {
        if (args.isNotEmpty) {
          setState(() => _toc = List<dynamic>.from(args.first as List));
        }
        return null;
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onClick',
      callback: (args) {
        if (args.isEmpty || args.first is! Map) return null;
        final payload = Map<String, dynamic>.from(args.first as Map);
        final x = (payload['x'] as num?)?.toDouble() ?? 0.5;
        widget.onClick?.call(x);
        return null;
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'renderAnnotations',
      callback: (args) async {
        await renderAnnotations();
        return null;
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'handleBookmark',
      callback: (args) async {
        if (args.isEmpty || args.first is! Map) return null;
        final payload = Map<String, dynamic>.from(args.first as Map);
        final detailRaw = payload['detail'];
        if (detailRaw is! Map) return null;
        final detail = Map<String, dynamic>.from(detailRaw);
        final remove = payload['remove'] == true;
        final cfi = detail['cfi']?.toString().trim() ?? '';
        if (cfi.isEmpty) return null;

        final bookId = widget.book.id;
        if (bookId == null) return null;

        if (remove) {
          await _bookmarkDao.deleteBookmarkByCfi(bookId, cfi);
          if (mounted) {
            setState(() {
              _bookmarkExists = false;
              _bookmarkCfi = null;
            });
          }
        } else {
          final existing = await _bookmarkDao.getBookmarkByCfi(bookId, cfi);
          if (existing == null) {
            final snippet = detail['content']?.toString().trim() ?? '';
            await _bookmarkDao.insertBookmark(Bookmark(
              bookId: bookId,
              pageNumber: _chapterCurrentPage,
              note: snippet,
              cfi: cfi,
            ));
          }
          if (mounted) {
            setState(() {
              _bookmarkExists = true;
              _bookmarkCfi = cfi;
            });
          }
        }
        widget.onBookmarkChanged?.call(_bookmarkExists);
        await renderAnnotations();
        return null;
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onExternalLink',
      callback: (args) {
        String? link;
        final raw = args.isNotEmpty ? args.first : null;
        if (raw is String) {
          link = raw.trim();
        } else if (raw is Map) {
          link = raw['href']?.toString().trim();
        }
        if (link != null && link.isNotEmpty) {
          widget.onExternalLink?.call(link);
        }
        return null;
      },
    );

    // 文本选中
    controller.addJavaScriptHandler(
      handlerName: 'onSelectionEnd',
      callback: (args) {
        removeOverlay();
        if (args.isEmpty || args.first is! Map) return null;
        final payload = Map<String, dynamic>.from(args.first as Map);
        final cfi = payload['cfi']?.toString().trim() ?? '';
        final text = payload['text']?.toString().trim() ?? '';
        if (cfi.isEmpty || text.isEmpty) return null;

        final pos = payload['pos'];
        if (pos is! Map) return null;
        final left = (pos['left'] as num?)?.toDouble() ?? 0;
        final top = (pos['top'] as num?)?.toDouble() ?? 0;
        final right = (pos['right'] as num?)?.toDouble() ?? 0;
        final bottom = (pos['bottom'] as num?)?.toDouble() ?? 0;
        final footnote = payload['footnote'] == true;

        showContextMenu(
          context: context,
          player: this,
          left: left,
          top: top,
          right: right,
          bottom: bottom,
          content: text,
          cfi: cfi,
          footnote: footnote,
        );
        return null;
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onSelectionCleared',
      callback: (args) {
        if (_selectionClearLocked) {
          _selectionClearPending = true;
          return null;
        }
        removeOverlay();
        return null;
      },
    );

    // 注释点击
    controller.addJavaScriptHandler(
      handlerName: 'onAnnotationClick',
      callback: (args) {
        removeOverlay();
        if (args.isEmpty || args.first is! Map) return null;
        final payload = Map<String, dynamic>.from(args.first as Map);
        final annotation = payload['annotation'];
        if (annotation is! Map) return null;
        final annoMap = Map<String, dynamic>.from(annotation);
        if (annoMap['type'] == 'bookmark') return null;

        final id = annoMap['id'] as int?;
        final cfi = annoMap['value']?.toString() ?? '';
        final note = annoMap['note']?.toString() ?? '';

        final pos = payload['pos'];
        if (pos is! Map) return null;
        final left = (pos['left'] as num?)?.toDouble() ?? 0;
        final top = (pos['top'] as num?)?.toDouble() ?? 0;
        final right = (pos['right'] as num?)?.toDouble() ?? 0;
        final bottom = (pos['bottom'] as num?)?.toDouble() ?? 0;

        showContextMenu(
          context: context,
          player: this,
          left: left,
          top: top,
          right: right,
          bottom: bottom,
          content: note,
          cfi: cfi,
          id: id,
          footnote: false,
        );
        return null;
      },
    );

    // 搜索
    controller.addJavaScriptHandler(
      handlerName: 'onSearch',
      callback: (args) {
        if (args.isEmpty || args.first is! Map) return null;
        final payload = Map<String, dynamic>.from(args.first as Map);
        if (!mounted) return null;
        if (payload['process'] != null) {
          final progress = (payload['process'] as num).toDouble();
          setState(() {
            _searchProgress = progress;
            if (progress >= 1.0) _searchActive = false;
          });
        } else {
          setState(() {
            _searchResults.add(SearchResult.fromJson(payload));
          });
        }
        return null;
      },
    );

    // 图片点击
    controller.addJavaScriptHandler(
      handlerName: 'onImageClick',
      callback: (args) {
        if (args.isEmpty || args.first is! String) return null;
        final base64 = args.first as String;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _ImageViewerPage(imageData: base64),
          ),
        );
        return null;
      },
    );

    // 脚注关闭
    controller.addJavaScriptHandler(
      handlerName: 'onFootnoteClose',
      callback: (args) {
        removeOverlay();
        return null;
      },
    );

    // 导航历史
    controller.addJavaScriptHandler(
      handlerName: 'onPushState',
      callback: (args) {
        if (args.isEmpty || args.first is! Map) return null;
        final state = Map<String, dynamic>.from(args.first as Map);
        if (!mounted) return null;
        setState(() {
          _canGoBack = state['canGoBack'] == true;
          _canGoForward = state['canGoForward'] == true;
        });
        return null;
      },
    );

    // 上拉手势
    controller.addJavaScriptHandler(
      handlerName: 'onPullUp',
      callback: (args) {
        widget.onPullUp?.call();
        return null;
      },
    );
  }

  void _callMethod(String method, [dynamic argument]) {
    final controller = _webController;
    if (controller == null) return;
    final source = argument == null
        ? 'window.$method && window.$method();'
        : 'window.$method && window.$method(${jsonEncode(argument)});';
    controller.evaluateJavascript(source: source);
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialFile: 'assets/foliate-js/app.html',
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: true,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
        allowFileAccess: true,
        supportZoom: false,
        useHybridComposition: true,
      ),
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source:
              'window.__XXREAD_CONFIG__ = ${jsonEncode(widget.foliateConfig)};',
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      ]),
      onWebViewCreated: (controller) {
        _webController = controller;
        if (defaultTargetPlatform == TargetPlatform.android) {
          InAppWebViewController.setWebContentsDebuggingEnabled(true);
        }
        _registerHandlers(controller);
      },
    );
  }
}

class SearchResult {
  final String cfi;
  final String text;
  final String? contextText;

  const SearchResult({
    required this.cfi,
    required this.text,
    this.contextText,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      cfi: json['cfi']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      contextText: json['contextText']?.toString(),
    );
  }
}

class _ImageViewerPage extends StatelessWidget {
  final String imageData;

  const _ImageViewerPage({required this.imageData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('图片查看'),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageData,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
            ),
          ),
        ),
      ),
    );
  }
}
