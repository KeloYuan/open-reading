import 'dart:io';
import 'dart:typed_data';

import 'package:epubx/epubx.dart';
import 'package:html/parser.dart' as html_parser;

import '../data/reader_models.dart';
import '../document/flow_doc.dart';
import '../document/html_to_flow_doc.dart';
import 'parser_models.dart';

class EpubParser implements BookParser {
  final HtmlToFlowDocConverter _converter = HtmlToFlowDocConverter();

  @override
  Future<ParsedBook> parse({
    required String bookId,
    required String title,
    required String author,
    required String filePath,
    String? encodingOverride,
  }) async {
    final bytes = await File(filePath).readAsBytes();
    final epubBook = await EpubReader.readBook(bytes);

    final resolvedTitle =
        (epubBook.Title ?? '').trim().isEmpty ? title : epubBook.Title!.trim();
    final resolvedAuthor = (epubBook.Author ?? '').trim().isEmpty
        ? author
        : epubBook.Author!.trim();

    final resources = _extractResources(epubBook);
    final coverResourcePath = _resolveCoverResourcePath(epubBook, resources);
    final parsedChapters = <ParsedChapter>[];
    final toc = <TocItem>[];

    int chapterOrder = 0;
    int anchor = 0;

    Future<void> appendChapter({
      required String chapterTitle,
      required String html,
      required int level,
      String? contentFileName,
    }) async {
      final stylesheetText = _resolveChapterStylesheetText(
        epubBook,
        html: html,
        contentFileName: contentFileName,
      );
      final flowDoc = html.trim().isEmpty
          ? const FlowDoc(blocks: [])
          : _converter.convert(
              html,
              stylesheetText: stylesheetText,
            );

      final plain = flowDoc.toPlainText();
      final chapterId = '$bookId-epub-$chapterOrder';
      final model = Chapter(
        id: chapterId,
        bookId: bookId,
        title: chapterTitle,
        order: chapterOrder,
        content: plain,
      );

      parsedChapters.add(
        ParsedChapter(
          chapter: model,
          flowDoc: flowDoc,
          htmlContent: html,
          resources: resources,
        ),
      );

      toc.add(
        TocItem(
          chapterId: chapterId,
          title: chapterTitle,
          level: level,
          anchorOffset: anchor,
        ),
      );
      anchor += plain.length;
      chapterOrder += 1;
    }

    Future<void> walk(EpubChapter chapter, int level) async {
      final chapterTitle = (chapter.Title ?? '').trim().isEmpty
          ? 'Chapter ${chapterOrder + 1}'
          : chapter.Title!.trim();
      final html = _resolveChapterHtml(epubBook, chapter);

      await appendChapter(
        chapterTitle: chapterTitle,
        html: html,
        level: level,
        contentFileName: chapter.ContentFileName,
      );

      final children = chapter.SubChapters ?? const <EpubChapter>[];
      for (final child in children) {
        await walk(child, level + 1);
      }
    }

    if (epubBook.Chapters != null && epubBook.Chapters!.isNotEmpty) {
      for (final chapter in epubBook.Chapters!) {
        await walk(chapter, 0);
      }
    } else {
      final htmlFiles = _orderedHtmlFiles(epubBook);
      for (final htmlFile in htmlFiles) {
        final html = htmlFile.Content ?? '';
        final chapterTitle =
            htmlFile.FileName?.split('/').last ?? 'Chapter ${chapterOrder + 1}';
        await appendChapter(
          chapterTitle: chapterTitle,
          html: html,
          level: 0,
          contentFileName: htmlFile.FileName,
        );
      }
    }

    final allEmpty = parsedChapters.isNotEmpty &&
        parsedChapters
            .every((chapter) => !_hasRenderableContent(chapter.flowDoc));
    if (allEmpty) {
      final htmlFiles = _orderedHtmlFiles(epubBook);
      if (htmlFiles.isNotEmpty) {
        parsedChapters.clear();
        toc.clear();
        chapterOrder = 0;
        anchor = 0;
        for (final htmlFile in htmlFiles) {
          final html = htmlFile.Content ?? '';
          final chapterTitle = htmlFile.FileName?.split('/').last ??
              'Chapter ${chapterOrder + 1}';
          await appendChapter(
            chapterTitle: chapterTitle,
            html: html,
            level: 0,
            contentFileName: htmlFile.FileName,
          );
        }
      }
    }

    if (coverResourcePath != null &&
        !_firstChapterIsCover(parsedChapters, coverResourcePath)) {
      final coverChapter = Chapter(
        id: '$bookId-epub-cover',
        bookId: bookId,
        title: '封面',
        order: -1,
        content: '',
      );
      parsedChapters.insert(
        0,
        ParsedChapter(
          chapter: coverChapter,
          flowDoc: _buildCoverFlowDoc(coverResourcePath),
          resources: resources,
        ),
      );
      toc.insert(
        0,
        TocItem(
          chapterId: coverChapter.id,
          title: coverChapter.title,
          level: 0,
          anchorOffset: 0,
        ),
      );
    }

    if (parsedChapters.isEmpty && coverResourcePath != null) {
      final coverChapter = Chapter(
        id: '$bookId-epub-cover',
        bookId: bookId,
        title: '封面',
        order: -1,
        content: '',
      );
      parsedChapters.add(
        ParsedChapter(
          chapter: coverChapter,
          flowDoc: _buildCoverFlowDoc(coverResourcePath),
          resources: resources,
        ),
      );
      toc.add(
        TocItem(
          chapterId: coverChapter.id,
          title: '封面',
          level: 0,
          anchorOffset: 0,
        ),
      );
    }

    _trimLeadingEmptyChapters(parsedChapters, toc);
    _rebuildChapterOrderAndAnchors(parsedChapters, toc);

    if (parsedChapters.isEmpty && coverResourcePath != null) {
      final coverChapter = Chapter(
        id: '$bookId-epub-cover',
        bookId: bookId,
        title: '封面',
        order: 0,
        content: '',
      );
      parsedChapters.add(
        ParsedChapter(
          chapter: coverChapter,
          flowDoc: _buildCoverFlowDoc(coverResourcePath),
          resources: resources,
        ),
      );
      toc.add(
        TocItem(
          chapterId: coverChapter.id,
          title: coverChapter.title,
          level: 0,
          anchorOffset: 0,
        ),
      );
    }

    if (parsedChapters.isEmpty) {
      throw const FormatException('EPUB 解析失败：未提取到章节');
    }

    return ParsedBook(
      book: Book(
        id: bookId,
        title: resolvedTitle,
        author: resolvedAuthor,
        filePath: filePath,
        format: 'epub',
      ),
      toc: toc,
      chapters: parsedChapters,
    );
  }

  String _resolveChapterHtml(EpubBook epubBook, EpubChapter chapter) {
    final direct = chapter.HtmlContent ?? '';
    if (direct.trim().isNotEmpty) {
      return direct;
    }

    final contentFileName = chapter.ContentFileName;
    final file = _findHtmlFileByPath(epubBook.Content?.Html, contentFileName);
    final fallback = file?.Content ?? '';
    if (fallback.trim().isNotEmpty) {
      return fallback;
    }
    return direct;
  }

  List<EpubTextContentFile> _orderedHtmlFiles(EpubBook epubBook) {
    final htmlMap = epubBook.Content?.Html;
    if (htmlMap == null || htmlMap.isEmpty) {
      return const <EpubTextContentFile>[];
    }

    final ordered = <EpubTextContentFile>[];
    final seen = <String>{};
    final manifestById = <String, EpubManifestItem>{
      for (final item in epubBook.Schema?.Package?.Manifest?.Items ??
          const <EpubManifestItem>[])
        if ((item.Id ?? '').trim().isNotEmpty) item.Id!.trim(): item,
    };

    void addFile(EpubTextContentFile? file, {String? keyHint}) {
      if (file == null) {
        return;
      }
      final dedupeKey =
          _normalizeResourceKey(file.FileName ?? keyHint ?? '').toLowerCase();
      if (dedupeKey.isNotEmpty && !seen.add(dedupeKey)) {
        return;
      }
      ordered.add(file);
    }

    for (final spineItem in epubBook.Schema?.Package?.Spine?.Items ??
        const <EpubSpineItemRef>[]) {
      final idRef = spineItem.IdRef?.trim();
      if (idRef == null || idRef.isEmpty) {
        continue;
      }
      final manifestItem = manifestById[idRef];
      final file = _findHtmlFileByPath(htmlMap, manifestItem?.Href);
      addFile(file, keyHint: manifestItem?.Href);
    }

    for (final entry in htmlMap.entries) {
      addFile(entry.value, keyHint: entry.key);
    }
    return ordered;
  }

  EpubTextContentFile? _findHtmlFileByPath(
    Map<String, EpubTextContentFile>? htmlFiles,
    String? rawPath,
  ) {
    if (htmlFiles == null || htmlFiles.isEmpty || rawPath == null) {
      return null;
    }
    final trimmed = rawPath.trim();
    final normalized = _normalizeResourceKey(trimmed);
    if (trimmed.isNotEmpty && htmlFiles.containsKey(trimmed)) {
      return htmlFiles[trimmed];
    }
    if (normalized.isNotEmpty && htmlFiles.containsKey(normalized)) {
      return htmlFiles[normalized];
    }
    final decoded = _safeUriDecodeFull(normalized);
    if (decoded.isNotEmpty && htmlFiles.containsKey(decoded)) {
      return htmlFiles[decoded];
    }

    final normalizedLower = normalized.toLowerCase();
    final baseName = normalized.split('/').last.toLowerCase();
    for (final entry in htmlFiles.entries) {
      final key = _normalizeResourceKey(entry.key);
      final keyLower = key.toLowerCase();
      if (keyLower == normalizedLower ||
          keyLower.endsWith('/$normalizedLower') ||
          normalizedLower.endsWith('/$keyLower') ||
          (baseName.isNotEmpty &&
              key.split('/').last.toLowerCase() == baseName)) {
        return entry.value;
      }
    }
    return null;
  }

  String? _resolveChapterStylesheetText(
    EpubBook epubBook, {
    required String html,
    String? contentFileName,
  }) {
    final cssFiles = epubBook.Content?.Css;
    if (cssFiles == null || cssFiles.isEmpty) {
      return null;
    }

    final htmlDir = _extractDirectory(contentFileName);
    final resolvedCssTexts = <String>[];
    final seen = <String>{};

    final document = html_parser.parse(html);
    final links = document.querySelectorAll('link[rel]');
    for (final link in links) {
      final rel = (link.attributes['rel'] ?? '').toLowerCase();
      if (!rel.contains('stylesheet')) {
        continue;
      }
      final href = (link.attributes['href'] ?? '').trim();
      if (href.isEmpty) {
        continue;
      }
      final resolvedPath = _resolveRelativePath(baseDir: htmlDir, path: href);
      final css = _findCssFileByPath(cssFiles, resolvedPath);
      final key =
          css?.FileName == null ? null : _normalizeResourceKey(css!.FileName!);
      if (css?.Content != null && key != null && seen.add(key)) {
        resolvedCssTexts.add(css!.Content!);
      }
    }

    if (resolvedCssTexts.isEmpty) {
      for (final file in cssFiles.values) {
        final fileName = file.FileName;
        if (fileName == null || file.Content == null) {
          continue;
        }
        final key = _normalizeResourceKey(fileName);
        if (seen.add(key)) {
          resolvedCssTexts.add(file.Content!);
        }
      }
    }

    if (resolvedCssTexts.isEmpty) {
      return null;
    }
    return resolvedCssTexts.join('\n');
  }

  EpubTextContentFile? _findCssFileByPath(
    Map<String, EpubTextContentFile> cssFiles,
    String rawPath,
  ) {
    final normalized = _normalizeResourceKey(rawPath);
    if (normalized.isEmpty) {
      return null;
    }
    if (cssFiles.containsKey(rawPath)) {
      return cssFiles[rawPath];
    }
    if (cssFiles.containsKey(normalized)) {
      return cssFiles[normalized];
    }
    final decoded = _safeUriDecodeFull(normalized);
    if (cssFiles.containsKey(decoded)) {
      return cssFiles[decoded];
    }

    final normalizedLower = normalized.toLowerCase();
    final baseName = normalized.split('/').last.toLowerCase();
    for (final entry in cssFiles.entries) {
      final key = _normalizeResourceKey(entry.key);
      final keyLower = key.toLowerCase();
      if (keyLower == normalizedLower ||
          keyLower.endsWith('/$normalizedLower') ||
          normalizedLower.endsWith('/$keyLower') ||
          (baseName.isNotEmpty &&
              key.split('/').last.toLowerCase() == baseName)) {
        return entry.value;
      }
    }
    return null;
  }

  String _extractDirectory(String? path) {
    if (path == null || path.trim().isEmpty) {
      return '';
    }
    final normalized = _normalizeResourceKey(path);
    final index = normalized.lastIndexOf('/');
    if (index <= 0) {
      return '';
    }
    return normalized.substring(0, index);
  }

  String _resolveRelativePath({
    required String baseDir,
    required String path,
  }) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return _normalizeResourceKey(trimmed);
    }

    final normalizedPath = _normalizeResourceKey(path);
    if (normalizedPath.isEmpty) {
      return '';
    }
    if (!normalizedPath.startsWith('../') && !normalizedPath.startsWith('./')) {
      if (baseDir.isEmpty) {
        return normalizedPath;
      }
      return _normalizeResourceKey('$baseDir/$normalizedPath');
    }
    return _normalizeResourceKey('$baseDir/$normalizedPath');
  }

  bool _firstChapterIsCover(
    List<ParsedChapter> parsedChapters,
    String coverResourcePath,
  ) {
    if (parsedChapters.isEmpty) {
      return false;
    }
    final firstBlocks = parsedChapters.first.flowDoc.blocks;
    if (firstBlocks.length != 1 || firstBlocks.first is! ImageBlock) {
      return false;
    }
    final firstImage = firstBlocks.first as ImageBlock;
    return _normalizeResourceKey(firstImage.src).toLowerCase() ==
        _normalizeResourceKey(coverResourcePath).toLowerCase();
  }

  void _trimLeadingEmptyChapters(
    List<ParsedChapter> parsedChapters,
    List<TocItem> toc,
  ) {
    while (parsedChapters.length > 1 &&
        !_hasRenderableContent(parsedChapters.first.flowDoc)) {
      final removedChapterId = parsedChapters.removeAt(0).chapter.id;
      toc.removeWhere((item) => item.chapterId == removedChapterId);
    }
  }

  void _rebuildChapterOrderAndAnchors(
    List<ParsedChapter> parsedChapters,
    List<TocItem> toc,
  ) {
    if (parsedChapters.isEmpty) {
      toc.clear();
      return;
    }

    final tocByChapterId = <String, TocItem>{};
    for (final item in toc) {
      tocByChapterId.putIfAbsent(item.chapterId, () => item);
    }

    final rebuiltToc = <TocItem>[];
    var anchor = 0;
    for (var i = 0; i < parsedChapters.length; i++) {
      final original = parsedChapters[i];
      final chapter = Chapter(
        id: original.chapter.id,
        bookId: original.chapter.bookId,
        title: original.chapter.title,
        order: i,
        content: original.chapter.content,
      );
      parsedChapters[i] = ParsedChapter(
        chapter: chapter,
        flowDoc: original.flowDoc,
        htmlContent: original.htmlContent,
        resources: original.resources,
      );

      final previousToc = tocByChapterId[chapter.id];
      rebuiltToc.add(
        TocItem(
          chapterId: chapter.id,
          title: previousToc?.title ?? chapter.title,
          level: previousToc?.level ?? 0,
          anchorOffset: anchor,
        ),
      );
      anchor += chapter.content.length;
    }

    toc
      ..clear()
      ..addAll(rebuiltToc);
  }

  bool _hasRenderableContent(FlowDoc flowDoc) {
    for (final block in flowDoc.blocks) {
      if (block is ImageBlock) {
        return true;
      }
      if (block is ParagraphBlock && block.plainText.trim().isNotEmpty) {
        return true;
      }
      if (block is HeadingBlock && block.plainText.trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  FlowDoc _buildCoverFlowDoc(String coverSrc) {
    return FlowDoc(
      blocks: [
        ImageBlock(
          id: 'cover-1',
          src: coverSrc,
          alt: '封面',
        ),
      ],
    );
  }

  Map<String, Uint8List> _extractResources(EpubBook book) {
    final map = <String, Uint8List>{};
    final images = book.Content?.Images?.values.toList() ?? [];
    for (final image in images) {
      final key = image.FileName;
      final value = image.Content;
      if (key != null && key.isNotEmpty && value != null) {
        final bytes = value is Uint8List ? value : Uint8List.fromList(value);
        map[key] = bytes;
        final normalized = _normalizeResourceKey(key);
        if (normalized != key) {
          map[normalized] = bytes;
        }
        final fileName = normalized.split('/').last;
        if (fileName.isNotEmpty) {
          map[fileName] = bytes;
        }
      }
    }
    return map;
  }

  String? _resolveCoverResourcePath(
    EpubBook book,
    Map<String, Uint8List> resources,
  ) {
    if (resources.isEmpty) {
      return null;
    }

    final metaItems = book.Schema?.Package?.Metadata?.MetaItems ?? const [];
    final manifestItems =
        book.Schema?.Package?.Manifest?.Items ?? const <EpubManifestItem>[];

    String? coverId;
    for (final metaItem in metaItems) {
      final name = (metaItem.Name ?? '').toString().toLowerCase();
      final content = (metaItem.Content ?? '').toString().trim();
      if (name == 'cover' && content.isNotEmpty) {
        coverId = content.toLowerCase();
        break;
      }
    }
    if (coverId != null) {
      EpubManifestItem? manifestItem;
      for (final item in manifestItems) {
        if ((item.Id ?? '').toLowerCase() == coverId) {
          manifestItem = item;
          break;
        }
      }
      final coverPath = _lookupResourceKey(resources, manifestItem?.Href);
      if (coverPath != null) {
        return coverPath;
      }
    }

    for (final item in manifestItems) {
      final properties = (item.Properties ?? '').toLowerCase();
      final id = (item.Id ?? '').toLowerCase();
      final href = (item.Href ?? '').toLowerCase();
      final likelyCover = properties.contains('cover-image') ||
          id.contains('cover') ||
          id.contains('front') ||
          href.contains('cover') ||
          href.contains('front');
      if (!likelyCover) {
        continue;
      }
      final coverPath = _lookupResourceKey(resources, item.Href);
      if (coverPath != null) {
        return coverPath;
      }
    }

    final guideItems =
        book.Schema?.Package?.Guide?.Items ?? const <EpubGuideReference>[];
    for (final guideRef in guideItems) {
      final type = (guideRef.Type ?? '').toLowerCase();
      if (!type.contains('cover')) {
        continue;
      }
      final coverPath = _lookupResourceKey(resources, guideRef.Href);
      if (coverPath != null) {
        return coverPath;
      }
    }

    for (final key in resources.keys) {
      final normalized = _normalizeResourceKey(key).toLowerCase();
      if (normalized.contains('cover') || normalized.contains('front')) {
        return key;
      }
    }
    if (resources.length == 1) {
      return resources.keys.first;
    }
    return null;
  }

  String? _lookupResourceKey(
      Map<String, Uint8List> resources, String? rawPath) {
    if (rawPath == null || rawPath.trim().isEmpty) {
      return null;
    }

    final normalized = _normalizeResourceKey(rawPath);
    final decoded = _safeUriDecodeFull(normalized);
    final baseName = normalized.split('/').last;

    final candidates = <String>{
      rawPath.trim(),
      normalized,
      decoded,
      baseName,
    }.where((candidate) => candidate.isNotEmpty);

    for (final candidate in candidates) {
      if (resources.containsKey(candidate)) {
        return candidate;
      }
    }

    final normalizedLower = normalized.toLowerCase();
    final baseNameLower = baseName.toLowerCase();
    for (final entry in resources.entries) {
      final key = _normalizeResourceKey(entry.key);
      final keyLower = key.toLowerCase();
      if (keyLower == normalizedLower ||
          keyLower.endsWith('/$normalizedLower') ||
          normalizedLower.endsWith('/$keyLower') ||
          (baseNameLower.isNotEmpty &&
              key.split('/').last.toLowerCase() == baseNameLower)) {
        return entry.key;
      }
    }
    return null;
  }

  String _normalizeResourceKey(String key) {
    var value = key.trim().replaceAll('\\', '/');
    if (value.contains('#')) {
      value = value.split('#').first;
    }
    value = _safeUriDecodeFull(value);
    while (value.startsWith('./')) {
      value = value.substring(2);
    }
    while (value.startsWith('/')) {
      value = value.substring(1);
    }
    return value;
  }

  String _safeUriDecodeFull(String value) {
    try {
      return Uri.decodeFull(value);
    } catch (_) {
      return value;
    }
  }
}
