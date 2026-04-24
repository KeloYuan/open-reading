// 文件说明：Web 阅读资源准备服务，把不同格式转换成 Web 阅读器可加载的源文件。
// 技术要点：服务层、Archive ZIP、Path、JSON、文件系统。

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'package:xxread/models/book.dart';
import 'package:xxread/reader_core/parser/docx_parser.dart';
import 'package:xxread/reader_core/parser/fb2_parser.dart';
import 'package:xxread/reader_core/parser/mobi_parser.dart';
import 'package:xxread/reader_core/parser/parser_models.dart';
import 'package:xxread/reader_core/parser/rtf_parser.dart';
import 'package:xxread/reader_core/parser/txt_parser.dart';

class WebReaderSource {
  final String filePath;
  final bool synthesized;

  const WebReaderSource({
    required this.filePath,
    this.synthesized = false,
  });
}

class WebReaderSourceService {
  static const Set<String> _syntheticEpubFormats = <String>{
    'txt',
    'rtf',
    'docx',
    'mobi',
    'azw',
    'azw3',
    'fb2',
  };

  Future<WebReaderSource> resolve(Book book) async {
    final format = book.format.toLowerCase();
    if (!_syntheticEpubFormats.contains(format) && format != 'epub') {
      // 这里的 epub 直接加载，其他不支持转化的暂且抛错或尝试原生加载
      return WebReaderSource(filePath: book.filePath);
    }
    
    if (format == 'epub') {
      return WebReaderSource(filePath: book.filePath);
    }

    final generatedFile = await _buildSyntheticEpub(book, format);
    return WebReaderSource(
      filePath: generatedFile.path,
      synthesized: true,
    );
  }

  Future<File> _buildSyntheticEpub(Book book, String format) async {
    final parser = _pickParser(format);
    final stat = await File(book.filePath).stat();
    final cacheDir = Directory(
      p.join(Directory.systemTemp.path, 'xxread_web_reader'),
    );
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final bookKey = book.id?.toString() ?? _safeFileSegment(book.title);
    final fingerprint =
        '${stat.modified.millisecondsSinceEpoch}_${stat.size}_$format';
    final targetPath = p.join(
      cacheDir.path,
      'book_${bookKey}_$fingerprint.epub',
    );
    final targetFile = File(targetPath);
    if (await targetFile.exists()) {
      return targetFile;
    }

    await _cleanupOutdatedSyntheticFiles(cacheDir, bookKey);

    final parsed = await parser.parse(
      bookId: (book.id ?? 0).toString(),
      title: book.title,
      author: book.author,
      filePath: book.filePath,
      encodingOverride: book.textEncoding,
    );
    if (parsed.chapters.isEmpty) {
      throw const FormatException('未提取到可供 Web 阅读的章节内容。');
    }

    final archive = Archive();
    final mimetypeBytes = ascii.encode('application/epub+zip');
    archive.addFile(ArchiveFile.noCompress(
        'mimetype', mimetypeBytes.length, mimetypeBytes));
    archive.addFile(
      ArchiveFile.string(
        'META-INF/container.xml',
        _containerXml,
      ),
    );
    archive.addFile(
      ArchiveFile.string(
        'OEBPS/styles/book.css',
        _bookCss,
      ),
    );
    archive.addFile(
      ArchiveFile.string(
        'OEBPS/nav.xhtml',
        _buildNavDocument(parsed),
      ),
    );
    archive.addFile(
      ArchiveFile.string(
        'OEBPS/toc.ncx',
        _buildNcxDocument(book, parsed),
      ),
    );

    for (var index = 0; index < parsed.chapters.length; index++) {
      archive.addFile(
        ArchiveFile.string(
          _chapterFileName(index),
          _buildChapterDocument(parsed, index),
        ),
      );
    }

    archive.addFile(
      ArchiveFile.string(
        'OEBPS/content.opf',
        _buildPackageDocument(book, parsed),
      ),
    );

    final bytes = ZipEncoder().encode(archive) ?? const <int>[];
    await targetFile.writeAsBytes(bytes, flush: true);
    return targetFile;
  }

  Future<void> _cleanupOutdatedSyntheticFiles(
    Directory cacheDir,
    String bookKey,
  ) async {
    await for (final entity in cacheDir.list()) {
      if (entity is! File) {
        continue;
      }
      final name = p.basename(entity.path);
      if (!name.startsWith('book_${bookKey}_') || !name.endsWith('.epub')) {
        continue;
      }
      try {
        await entity.delete();
      } catch (_) {
        // Ignore stale cache cleanup failures.
      }
    }
  }

  dynamic _pickParser(String format) {
    switch (format) {
      case 'rtf':
        return RtfParser();
      case 'docx':
        return DocxParser();
      case 'mobi':
      case 'azw':
      case 'azw3':
        return MobiParser();
      case 'fb2':
        return Fb2Parser();
      case 'txt':
      default:
        return TxtParser();
    }
  }

  String _buildPackageDocument(Book book, ParsedBook parsed) {
    final manifestItems = <String>[
      '<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>',
      '<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>',
      '<item id="style" href="styles/book.css" media-type="text/css"/>',
      for (var index = 0; index < parsed.chapters.length; index++)
        '<item id="chap_${index + 1}" href="chapters/chapter_${(index + 1).toString().padLeft(4, '0')}.xhtml" media-type="application/xhtml+xml"/>',
    ].join('\n    ');

    final spineItems = <String>[
      for (var index = 0; index < parsed.chapters.length; index++)
        '<itemref idref="chap_${index + 1}"/>',
    ].join('\n    ');

    return '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="BookId">xxread-${_escapeXml((book.id ?? 0).toString())}</dc:identifier>
    <dc:title>${_escapeXml(book.title)}</dc:title>
    <dc:creator>${_escapeXml(book.author)}</dc:creator>
    <dc:language>zh-CN</dc:language>
    <meta property="dcterms:modified">${DateTime.now().toUtc().toIso8601String().replaceFirst(RegExp(r'\.\d{3}Z$'), 'Z')}</meta>
  </metadata>
  <manifest>
    $manifestItems
  </manifest>
  <spine toc="ncx">
    $spineItems
  </spine>
</package>
''';
  }

  String _buildNavDocument(ParsedBook parsed) {
    final navItems = <String>[
      for (var index = 0; index < parsed.chapters.length; index++)
        '<li><a href="chapters/chapter_${(index + 1).toString().padLeft(4, '0')}.xhtml">${_escapeXml(_chapterTitle(parsed, index))}</a></li>',
    ].join('\n        ');

    return '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="zh-CN">
  <head>
    <meta charset="utf-8"/>
    <title>目录</title>
  </head>
  <body>
    <nav epub:type="toc" id="toc" xmlns:epub="http://www.idpf.org/2007/ops">
      <h1>目录</h1>
      <ol>
        $navItems
      </ol>
    </nav>
  </body>
</html>
''';
  }

  String _buildNcxDocument(Book book, ParsedBook parsed) {
    final navPoints = <String>[
      for (var index = 0; index < parsed.chapters.length; index++)
        '''<navPoint id="navPoint-${index + 1}" playOrder="${index + 1}">
      <navLabel><text>${_escapeXml(_chapterTitle(parsed, index))}</text></navLabel>
      <content src="chapters/chapter_${(index + 1).toString().padLeft(4, '0')}.xhtml"/>
    </navPoint>''',
    ].join('\n    ');

    return '''<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="xxread-${_escapeXml((book.id ?? 0).toString())}"/>
    <meta name="dtb:depth" content="1"/>
    <meta name="dtb:totalPageCount" content="0"/>
    <meta name="dtb:maxPageNumber" content="0"/>
  </head>
  <docTitle><text>${_escapeXml(book.title)}</text></docTitle>
  <navMap>
    $navPoints
  </navMap>
</ncx>
''';
  }

  String _buildChapterDocument(ParsedBook parsed, int index) {
    final chapter = parsed.chapters[index];
    final title = _chapterTitle(parsed, index);
    final body = _formatPlainTextBody(chapter.chapter.content);
    return '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="zh-CN">
  <head>
    <meta charset="utf-8"/>
    <title>${_escapeXml(title)}</title>
    <link rel="stylesheet" type="text/css" href="../styles/book.css"/>
  </head>
  <body>
    <section class="chapter">
      <h1>${_escapeXml(title)}</h1>
      $body
    </section>
  </body>
</html>
''';
  }

  String _formatPlainTextBody(String text) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) {
      return '<p></p>';
    }

    final paragraphs = normalized
        .split(RegExp(r'\n\s*\n+'))
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .map((segment) =>
            '<p>${_escapeXml(segment).replaceAll('\n', '<br/>')}</p>')
        .join('\n      ');
    return paragraphs.isEmpty ? '<p></p>' : paragraphs;
  }

  String _chapterTitle(ParsedBook parsed, int index) {
    final raw = parsed.chapters[index].chapter.title.trim();
    if (raw.isNotEmpty) {
      return raw;
    }
    return '第 ${index + 1} 章';
  }

  String _chapterFileName(int index) {
    return 'OEBPS/chapters/chapter_${(index + 1).toString().padLeft(4, '0')}.xhtml';
  }

  String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _safeFileSegment(String value) {
    return value
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '')
        .toLowerCase();
  }

  static const String _containerXml = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
''';

  static const String _bookCss = '''
html, body {
  margin: 0;
  padding: 0;
}

body {
  font-family: serif;
}

.chapter {
  padding: 0;
}

h1 {
  margin: 0 0 1.4em;
  font-size: 1.35em;
  font-weight: 700;
  line-height: 1.35;
}

p {
  margin: 0 0 1em;
  line-height: 1.7;
  white-space: normal;
}
''';
}
