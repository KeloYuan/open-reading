import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xxread/services/book_dao.dart';
import 'package:epubx/epubx.dart';
import 'package:pdfx/pdfx.dart';

import '../models/book.dart';
import '../models/chapter.dart';

class BookImportService {
  final _bookDao = BookDao();

  Future<Book?> importBook() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'epub', 'pdf', 'mobi', 'azw', 'azw3', 'fb2', 'rtf', 'doc', 'docx'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;
        
        // 1. Get application documents directory
        final documentsDir = await getApplicationDocumentsDirectory();
        final booksDir = Directory(join(documentsDir.path, 'books'));
        if (!await booksDir.exists()) {
          await booksDir.create(recursive: true);
        }

        // 2. Save the file to disk
        final newFilePath = join(booksDir.path, pickedFile.name);
        final file = File(newFilePath);
        await file.writeAsBytes(pickedFile.bytes!);

        debugPrint('Book file saved to: $newFilePath');

        // 3. Get book metadata
        String title = pickedFile.name.replaceAll(RegExp(r'\.(txt|epub|pdf|mobi|azw|azw3|fb2|rtf|doc|docx)$'), '');
        String author = 'Unknown';
        int estimatedPages = 1;
        
        // Try to get more detailed information from the file
        try {
          final extension = pickedFile.extension?.toLowerCase();
          switch (extension) {
            case 'epub':
              final epubBook = await EpubReader.readBook(pickedFile.bytes!);
              title = epubBook.Title ?? title;
              author = epubBook.Author ?? author;
              
              // Estimate pages based on content length
              final content = await _getAllEpubContent(epubBook);
              final contentLength = content.length;
              estimatedPages = (contentLength / 1500).ceil().clamp(1, 9999); // Approx. 1500 chars per page
              break;
              
            case 'txt':
            case 'rtf':
              final content = String.fromCharCodes(pickedFile.bytes!);
              estimatedPages = (content.length / 1500).ceil().clamp(1, 9999);
              break;
              
            case 'pdf':
              // For PDF files, use PDFx to get accurate page count
              try {
                final pdfDocument = await PdfDocument.openData(pickedFile.bytes!);
                estimatedPages = pdfDocument.pagesCount;
                await pdfDocument.close();
              } catch (e) {
                debugPrint('Could not parse PDF: $e');
                // Fallback to file size estimation
                final fileSize = pickedFile.bytes!.length;
                estimatedPages = (fileSize / 50000).ceil().clamp(1, 9999); // Approx 50KB per page
              }
              break;
              
            case 'mobi':
            case 'azw':
            case 'azw3':
              // Amazon formats - basic estimation
              final fileSize = pickedFile.bytes!.length;
              estimatedPages = (fileSize / 5000).ceil().clamp(1, 9999); // Approx 5KB per page (more compressed)
              break;
              
            case 'fb2':
              // FictionBook format - XML based
              try {
                final content = String.fromCharCodes(pickedFile.bytes!);
                final textContent = _stripXmlTags(content);
                estimatedPages = (textContent.length / 1500).ceil().clamp(1, 9999);
              } catch (e) {
                final fileSize = pickedFile.bytes!.length;
                estimatedPages = (fileSize / 8000).ceil().clamp(1, 9999);
              }
              break;
              
            case 'doc':
            case 'docx':
              // Microsoft Word formats - basic estimation
              final fileSize = pickedFile.bytes!.length;
              estimatedPages = (fileSize / 30000).ceil().clamp(1, 9999); // Approx 30KB per page
              break;
              
            default:
              final fileSize = pickedFile.bytes!.length;
              estimatedPages = (fileSize / 10000).ceil().clamp(1, 9999); // Default estimation
          }
        } catch (e) {
          debugPrint('Could not get detailed info: $e');
        }
        
        // 4. Create Book object
        final book = Book(
          title: title,
          author: author,
          filePath: newFilePath,
          format: pickedFile.extension?.toUpperCase() ?? 'UNKNOWN',
          totalPages: estimatedPages,
        );

        // 5. Insert metadata into the database
        final bookId = await _bookDao.insertBook(book);
        debugPrint('Book metadata inserted with ID: $bookId, estimated pages: $estimatedPages');

        return book.copyWith(id: bookId);
      }
    } catch (e) {
      debugPrint('Import process failed: $e');
      rethrow;
    }
    return null;
  }

  // Recursively get all EPUB chapter content
  Future<String> _getAllEpubContent(EpubBook book) async {
    final buffer = StringBuffer();
    // Using book.Content is often more reliable for getting all text content
    if (book.Content != null) {
      // Iterate over all HTML files
      final htmlFiles = book.Content!.Html;
      if (htmlFiles != null) {
        for (var entry in htmlFiles.entries) {
          final htmlContent = entry.value.Content;
          if (htmlContent != null && htmlContent.isNotEmpty) {
            buffer.writeln(_stripHtml(htmlContent));
          }
        }
      }
    }
    return buffer.toString();
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _stripXmlTags(String xml) {
    return xml
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'&[a-zA-Z0-9#]+;'), ' ') // Remove XML entities
        .trim();
  }

  /// 从EPUB文件解析章节信息
  Future<List<Chapter>> extractEpubChapters(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('EPUB文件不存在: $filePath');
        return [];
      }

      final bytes = await file.readAsBytes();
      final epubBook = await EpubReader.readBook(bytes);

      List<Chapter> chapters = [];

      // 方法1: 从章节列表提取（最可靠）
      if (epubBook.Chapters != null && epubBook.Chapters!.isNotEmpty) {
        chapters.addAll(_parseEpubChapters(epubBook.Chapters!, 0));
      }

      // 方法2: 如果章节为空，从Spine提取
      if (chapters.isEmpty && epubBook.Schema?.Package?.Spine?.Items != null) {
        chapters.addAll(_parseSpineItems(epubBook));
      }

      // 方法3: 最后的备用方案 - 从内容文件提取
      if (chapters.isEmpty) {
        chapters.addAll(_generateChaptersFromContent(epubBook));
      }

      // 方法4: 智能层级分析 - 对平级章节进行层级化处理
      if (chapters.isNotEmpty) {
        chapters = _buildSmartChapterHierarchy(chapters);
      }

      debugPrint('提取到 ${chapters.length} 个章节');
      return chapters;
    } catch (e) {
      debugPrint('EPUB章节解析失败: $e');
      return [];
    }
  }


  /// 从Spine项目解析章节
  List<Chapter> _parseSpineItems(EpubBook epubBook) {
    List<Chapter> chapters = [];

    if (epubBook.Schema?.Package?.Spine?.Items == null) {
      return chapters;
    }

    final spineItems = epubBook.Schema!.Package!.Spine!.Items!;

    for (int i = 0; i < spineItems.length; i++) {
      final spineItem = spineItems[i];
      final manifest = epubBook.Schema!.Package!.Manifest;

      if (manifest?.Items != null) {
        try {
          final manifestItem = manifest!.Items!.firstWhere(
            (item) => item.Id == spineItem.IdRef,
          );

          String title = 'Chapter ${i + 1}';

          // 尝试从文件名推断标题
          if (manifestItem.Href != null && manifestItem.Href!.isNotEmpty) {
            final fileName = manifestItem.Href!.split('/').last;
            final nameWithoutExt = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
            if (nameWithoutExt.isNotEmpty) {
              title = _cleanTitle(nameWithoutExt);
            }
          }

          final chapter = Chapter(
            title: title,
            startPage: 0,
            level: 0,
            contentFileName: manifestItem.Href,
          );

          chapters.add(chapter);
        } catch (e) {
          debugPrint('解析清单项失败: $e');
        }
      }
    }

    return chapters;
  }

  /// 从EPUB章节对象解析章节 - 支持层级结构
  List<Chapter> _parseEpubChapters(List<EpubChapter> epubChapters, int level) {
    List<Chapter> chapters = [];

    for (int i = 0; i < epubChapters.length; i++) {
      final epubChapter = epubChapters[i];

      // 递归解析子章节
      List<Chapter> subChapters = [];
      if (epubChapter.SubChapters != null && epubChapter.SubChapters!.isNotEmpty) {
        subChapters = _parseEpubChapters(epubChapter.SubChapters!, level + 1);
      }

      final chapterTitle = _cleanTitle(epubChapter.Title ?? 'Chapter ${i + 1}');
      final chapter = Chapter(
        title: chapterTitle,
        startPage: 0,
        level: level,
        contentFileName: epubChapter.ContentFileName,
        anchor: epubChapter.Anchor,
        subChapters: subChapters, // 添加子章节
        isTableOfContents: _isTableOfContents(chapterTitle),
      );

      chapters.add(chapter);
    }

    return chapters;
  }

  /// 检查是否是目录章节的智能识别
  bool _isTableOfContents(String title) {
    final lowerTitle = title.toLowerCase().trim();
    final tocPatterns = [
      '目录',
      '目　录',
      'contents',
      'table of contents',
      '索引',
      'index',
      '章节目录',
      '目次',
    ];

    // 精确匹配或开头匹配
    return tocPatterns.any((pattern) =>
      lowerTitle == pattern.toLowerCase() ||
      lowerTitle.startsWith(pattern.toLowerCase())
    );
  }

  /// 从内容生成章节（备用方案）
  List<Chapter> _generateChaptersFromContent(EpubBook epubBook) {
    List<Chapter> chapters = [];

    if (epubBook.Content?.Html != null) {
      int chapterIndex = 1;

      for (final entry in epubBook.Content!.Html!.entries) {
        final fileName = entry.key;
        final content = entry.value.Content ?? '';

        // 尝试从内容中提取标题
        String title = _extractTitleFromHtml(content);
        if (title.isEmpty) {
          title = 'Chapter $chapterIndex';
        }

        final chapter = Chapter(
          title: _cleanTitle(title),
          startPage: 0,
          level: 0,
          contentFileName: fileName,
        );

        chapters.add(chapter);
        chapterIndex++;
      }
    }

    return chapters;
  }

  /// 从HTML内容提取标题
  String _extractTitleFromHtml(String html) {
    // 尝试提取h1-h6标签的内容作为标题
    final headerRegex = RegExp(r'<h[1-6][^>]*>(.*?)<\/h[1-6]>', caseSensitive: false);
    final match = headerRegex.firstMatch(html);

    if (match != null) {
      return _stripHtml(match.group(1) ?? '').trim();
    }

    // 尝试提取title标签
    final titleRegex = RegExp(r'<title[^>]*>(.*?)<\/title>', caseSensitive: false);
    final titleMatch = titleRegex.firstMatch(html);

    if (titleMatch != null) {
      return _stripHtml(titleMatch.group(1) ?? '').trim();
    }

    return '';
  }

  /// 清理标题文本
  String _cleanTitle(String title) {
    return title
        .replaceAll(RegExp(r'[^\w\s\u4e00-\u9fff]+'), '') // 保留字母、数字、空格和中文字符
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }


  /// 根据分页结果更新章节页码
  Future<List<Chapter>> updateChapterPages(
    List<Chapter> chapters,
    String bookContent,
    List<String> pages,
  ) async {
    if (chapters.isEmpty || pages.isEmpty) return chapters;

    List<Chapter> updatedChapters = [];

    for (final chapter in chapters) {
      // 尝试在分页内容中找到章节开始位置
      int startPage = 0;

      // 搜索章节标题在哪一页
      for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
        final pageContent = pages[pageIndex];

        // 使用多种匹配策略
        if (_isChapterStartPage(pageContent, chapter.title)) {
          startPage = pageIndex;
          break;
        }
      }

      updatedChapters.add(chapter.copyWith(startPage: startPage));
    }

    return updatedChapters;
  }

  /// 判断是否是章节开始页
  bool _isChapterStartPage(String pageContent, String chapterTitle) {
    final normalizedPageContent = pageContent.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final normalizedChapterTitle = chapterTitle.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    // 策略1: 直接匹配标题
    if (normalizedPageContent.contains(normalizedChapterTitle)) {
      return true;
    }

    // 策略2: 匹配标题的前几个关键词
    final titleWords = normalizedChapterTitle.split(' ').where((w) => w.length > 2).toList();
    if (titleWords.isNotEmpty) {
      int matchedWords = 0;
      for (final word in titleWords) {
        if (normalizedPageContent.contains(word)) {
          matchedWords++;
        }
      }

      // 如果匹配了50%以上的关键词，认为是匹配的
      if (matchedWords / titleWords.length >= 0.5) {
        return true;
      }
    }

    return false;
  }

  /// 智能构建章节层级结构
  List<Chapter> _buildSmartChapterHierarchy(List<Chapter> flatChapters) {
    if (flatChapters.isEmpty) return flatChapters;

    List<Chapter> hierarchicalChapters = [];
    Chapter? currentMainChapter;
    List<Chapter> subChapters = [];

    for (final chapter in flatChapters) {
      // 判断是否是主要章节
      if (_isMainChapterByTitle(chapter.title)) {
        // 如果有当前主章节，先保存它和它的子章节
        if (currentMainChapter != null) {
          hierarchicalChapters.add(currentMainChapter.copyWith(
            subChapters: List.from(subChapters),
          ));
          subChapters.clear();
        }

        // 设置新的主章节
        currentMainChapter = chapter.copyWith(level: 0);
      } else {
        // 如果有主章节，作为子章节；否则作为独立章节
        if (currentMainChapter != null) {
          subChapters.add(chapter.copyWith(level: 1));
        } else {
          hierarchicalChapters.add(chapter.copyWith(level: 0));
        }
      }
    }

    // 处理最后一个主章节
    if (currentMainChapter != null) {
      hierarchicalChapters.add(currentMainChapter.copyWith(
        subChapters: List.from(subChapters),
      ));
    }

    return hierarchicalChapters;
  }

  /// 通过标题判断是否是主要章节
  bool _isMainChapterByTitle(String title) {
    final patterns = [
      RegExp(r'^第[一二三四五六七八九十\d]+章', caseSensitive: false),
      RegExp(r'^Chapter\s+\d+', caseSensitive: false),
      RegExp(r'^\d+\.?\s+'), // "1. ", "1 ", "1."
      RegExp(r'^[一二三四五六七八九十]+、'),
      RegExp(r'^[IVXLCDM]+\.?\s+', caseSensitive: false), // 罗马数字
      RegExp(r'^第[一二三四五六七八九十\d]+部分', caseSensitive: false),
      RegExp(r'^Part\s+\d+', caseSensitive: false),
    ];

    return patterns.any((pattern) => pattern.hasMatch(title.trim()));
  }
}
