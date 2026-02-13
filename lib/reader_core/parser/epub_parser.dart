import 'dart:io';
import 'dart:typed_data';

import 'package:epubx/epubx.dart';

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
    final parsedChapters = <ParsedChapter>[];
    final toc = <TocItem>[];

    int chapterOrder = 0;
    int anchor = 0;

    Future<void> walk(EpubChapter chapter, int level) async {
      final chapterTitle = (chapter.Title ?? '').trim().isEmpty
          ? 'Chapter ${chapterOrder + 1}'
          : chapter.Title!.trim();
      final html = chapter.HtmlContent ?? '';
      final flowDoc = html.trim().isEmpty
          ? FlowDoc(
              blocks: [
                ParagraphBlock(
                  id: 'p-$chapterOrder-0',
                  inlines: const [TextInline('')],
                ),
              ],
            )
          : _converter.convert(html);

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
      final htmlFiles = epubBook.Content?.Html?.values.toList() ?? const [];
      for (final htmlFile in htmlFiles) {
        final html = htmlFile.Content ?? '';
        final flowDoc = _converter.convert(html);
        final plain = flowDoc.toPlainText();
        final chapterId = '$bookId-epub-$chapterOrder';
        final chapterTitle =
            htmlFile.FileName?.split('/').last ?? 'Chapter ${chapterOrder + 1}';
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
            level: 0,
            anchorOffset: anchor,
          ),
        );
        anchor += plain.length;
        chapterOrder += 1;
      }
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

  String _normalizeResourceKey(String key) {
    var value = key.trim().replaceAll('\\', '/');
    while (value.startsWith('./')) {
      value = value.substring(2);
    }
    while (value.startsWith('/')) {
      value = value.substring(1);
    }
    return value;
  }
}
