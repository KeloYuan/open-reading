import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xxread/services/book_dao.dart';
import 'package:epubx/epubx.dart';
import 'package:pdfx/pdfx.dart';
import 'dart:typed_data';
import 'dart:convert';

import '../models/book.dart';
import '../models/chapter.dart';

class EnhancedBookMetadata {
  final String title;
  final String author;
  final String? description;
  final String? language;
  final String? publisher;
  final String? publishDate;
  final String? isbn;
  final Uint8List? coverImage;
  final int estimatedPages;
  final List<String>? tags;
  final Map<String, dynamic>? additionalInfo;

  EnhancedBookMetadata({
    required this.title,
    required this.author,
    this.description,
    this.language,
    this.publisher,
    this.publishDate,
    this.isbn,
    this.coverImage,
    required this.estimatedPages,
    this.tags,
    this.additionalInfo,
  });
}

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

        // 3. Extract enhanced metadata based on format
        final metadata = await _extractEnhancedMetadata(pickedFile);
        
        // 4. Save cover image if available
        String? coverImagePath;
        if (metadata.coverImage != null) {
          coverImagePath = await _saveCoverImage(metadata.coverImage!, pickedFile.name);
        }
        
        // 5. Create Book object with enhanced metadata
        final book = Book(
          title: metadata.title,
          author: metadata.author,
          filePath: newFilePath,
          format: pickedFile.extension?.toUpperCase() ?? 'UNKNOWN',
          totalPages: metadata.estimatedPages,
          coverImagePath: coverImagePath,
          description: metadata.description,
          language: metadata.language,
          publisher: metadata.publisher,
          publishDate: metadata.publishDate,
          isbn: metadata.isbn,
          tags: metadata.tags?.join(','),
        );

        // 6. Insert metadata into the database
        final bookId = await _bookDao.insertBook(book);
        debugPrint('Book metadata inserted with ID: $bookId, estimated pages: ${metadata.estimatedPages}');

        return book.copyWith(id: bookId);
      }
    } catch (e) {
      debugPrint('Import process failed: $e');
      rethrow;
    }
    return null;
  }

  /// Extract enhanced metadata from different file formats
  Future<EnhancedBookMetadata> _extractEnhancedMetadata(PlatformFile pickedFile) async {
    final extension = pickedFile.extension?.toLowerCase();
    final bytes = pickedFile.bytes!;
    
    switch (extension) {
      case 'epub':
        return await _extractEpubMetadata(bytes, pickedFile.name);
      case 'pdf':
        return await _extractPdfMetadata(bytes, pickedFile.name);
      case 'txt':
        return await _extractTxtMetadata(bytes, pickedFile.name);
      case 'fb2':
        return await _extractFb2Metadata(bytes, pickedFile.name);
      case 'rtf':
        return await _extractRtfMetadata(bytes, pickedFile.name);
      default:
        return _extractBasicMetadata(bytes, pickedFile.name);
    }
  }

  /// Extract comprehensive EPUB metadata
  Future<EnhancedBookMetadata> _extractEpubMetadata(Uint8List bytes, String fileName) async {
    try {
      final epubBook = await EpubReader.readBook(bytes);
      
      // Extract cover image
      Uint8List? coverImage;
      if (epubBook.CoverImage != null) {
        coverImage = epubBook.CoverImage;
      }
      
      // Extract all available metadata
      final title = epubBook.Title?.isNotEmpty == true ? epubBook.Title! : 
          fileName.replaceAll(RegExp(r'\.(epub)$'), '');
      final author = epubBook.Author?.isNotEmpty == true ? epubBook.Author! : 'Unknown';
      final description = epubBook.Description;
      final language = epubBook.Language;
      final publisher = epubBook.Schema?.Package?.Metadata?.Publishers?.isNotEmpty == true
          ? epubBook.Schema!.Package!.Metadata!.Publishers!.first.Publisher
          : null;
      
      // Extract publication date
      String? publishDate;
      if (epubBook.Schema?.Package?.Metadata?.Dates?.isNotEmpty == true) {
        publishDate = epubBook.Schema!.Package!.Metadata!.Dates!.first.Date;
      }
      
      // Extract ISBN
      String? isbn;
      if (epubBook.Schema?.Package?.Metadata?.Identifiers?.isNotEmpty == true) {
        for (final identifier in epubBook.Schema!.Package!.Metadata!.Identifiers!) {
          if (identifier.Scheme?.toLowerCase().contains('isbn') == true) {
            isbn = identifier.Identifier;
            break;
          }
        }
      }
      
      // Extract subject tags
      List<String>? tags;
      if (epubBook.Schema?.Package?.Metadata?.Subjects?.isNotEmpty == true) {
        tags = epubBook.Schema!.Package!.Metadata!.Subjects!
            .map((subject) => subject.Subject)
            .where((tag) => tag.isNotEmpty)
            .toList();
      }
      
      // Estimate pages based on content length
      final content = await _getAllEpubContent(epubBook);
      final estimatedPages = (content.length / 1500).ceil().clamp(1, 9999);
      
      return EnhancedBookMetadata(
        title: title,
        author: author,
        description: description,
        language: language,
        publisher: publisher,
        publishDate: publishDate,
        isbn: isbn,
        coverImage: coverImage,
        estimatedPages: estimatedPages,
        tags: tags,
        additionalInfo: {
          'format': 'EPUB',
          'hasImages': epubBook.Content?.Images?.isNotEmpty == true,
          'chapterCount': epubBook.Chapters?.length ?? 0,
        },
      );
    } catch (e) {
      debugPrint('EPUB metadata extraction failed: $e');
      return _extractBasicMetadata(bytes, fileName);
    }
  }

  /// Extract PDF metadata
  Future<EnhancedBookMetadata> _extractPdfMetadata(Uint8List bytes, String fileName) async {
    try {
      final pdfDocument = await PdfDocument.openData(bytes);
      final pageCount = pdfDocument.pagesCount;
      
      // Extract basic metadata - PDF metadata is often limited
      final title = fileName.replaceAll(RegExp(r'\.(pdf)$'), '');
      
      await pdfDocument.close();
      
      return EnhancedBookMetadata(
        title: title,
        author: 'Unknown',
        estimatedPages: pageCount,
        additionalInfo: {
          'format': 'PDF',
          'actualPageCount': pageCount,
        },
      );
    } catch (e) {
      debugPrint('PDF metadata extraction failed: $e');
      final fileSize = bytes.length;
      final estimatedPages = (fileSize / 50000).ceil().clamp(1, 9999);
      
      return EnhancedBookMetadata(
        title: fileName.replaceAll(RegExp(r'\.(pdf)$'), ''),
        author: 'Unknown',
        estimatedPages: estimatedPages,
      );
    }
  }

  /// Extract TXT metadata with smart content analysis
  Future<EnhancedBookMetadata> _extractTxtMetadata(Uint8List bytes, String fileName) async {
    try {
      final content = utf8.decode(bytes);
      final lines = content.split('\n');
      
      // Try to extract title and author from first few lines
      String title = fileName.replaceAll(RegExp(r'\.(txt)$'), '');
      String author = 'Unknown';
      String? description;
      
      // Smart parsing for common TXT book formats
      if (lines.isNotEmpty) {
        // First line might be title
        final firstLine = lines[0].trim();
        if (firstLine.isNotEmpty && firstLine.length < 100) {
          title = firstLine;
        }
        
        // Look for author in first few lines
        for (int i = 1; i < lines.length.clamp(0, 10); i++) {
          final line = lines[i].trim().toLowerCase();
          if (line.contains('author:') || line.contains('by ') || line.contains('作者：')) {
            author = lines[i].trim()
                .replaceAll(RegExp(r'(author:|by |作者：)', caseSensitive: false), '')
                .trim();
            break;
          }
        }
        
        // Extract description from first paragraph
        for (int i = 2; i < lines.length.clamp(0, 20); i++) {
          final line = lines[i].trim();
          if (line.isNotEmpty && line.length > 50 && line.length < 500) {
            description = line;
            break;
          }
        }
      }
      
      final estimatedPages = (content.length / 1500).ceil().clamp(1, 9999);
      
      return EnhancedBookMetadata(
        title: title,
        author: author,
        description: description,
        estimatedPages: estimatedPages,
        language: _detectLanguage(content),
        additionalInfo: {
          'format': 'TXT',
          'characterCount': content.length,
          'lineCount': lines.length,
        },
      );
    } catch (e) {
      debugPrint('TXT metadata extraction failed: $e');
      return _extractBasicMetadata(bytes, fileName);
    }
  }

  /// Extract FictionBook 2 (FB2) metadata
  Future<EnhancedBookMetadata> _extractFb2Metadata(Uint8List bytes, String fileName) async {
    try {
      final xmlContent = utf8.decode(bytes);
      
      // Parse FB2 XML structure
      String title = fileName.replaceAll(RegExp(r'\.(fb2)$'), '');
      String author = 'Unknown';
      String? description;
      String? language;
      List<String>? tags;
      
      // Extract title
      final titleMatch = RegExp(r'<book-title[^>]*>(.*?)</book-title>', dotAll: true).firstMatch(xmlContent);
      if (titleMatch != null) {
        title = _stripXmlTags(titleMatch.group(1) ?? '').trim();
      }
      
      // Extract author
      final authorMatch = RegExp(r'<author[^>]*>.*?<first-name[^>]*>(.*?)</first-name>.*?<last-name[^>]*>(.*?)</last-name>.*?</author>', dotAll: true).firstMatch(xmlContent);
      if (authorMatch != null) {
        final firstName = _stripXmlTags(authorMatch.group(1) ?? '').trim();
        final lastName = _stripXmlTags(authorMatch.group(2) ?? '').trim();
        author = '$firstName $lastName'.trim();
      }
      
      // Extract description
      final descMatch = RegExp(r'<annotation[^>]*>(.*?)</annotation>', dotAll: true).firstMatch(xmlContent);
      if (descMatch != null) {
        description = _stripXmlTags(descMatch.group(1) ?? '').trim();
      }
      
      // Extract language
      final langMatch = RegExp(r'<lang[^>]*>(.*?)</lang>').firstMatch(xmlContent);
      if (langMatch != null) {
        language = langMatch.group(1)?.trim();
      }
      
      // Extract genres as tags
      final genreMatches = RegExp(r'<genre[^>]*>(.*?)</genre>').allMatches(xmlContent);
      if (genreMatches.isNotEmpty) {
        tags = genreMatches.map((match) => match.group(1)?.trim() ?? '').where((tag) => tag.isNotEmpty).toList();
      }
      
      final textContent = _stripXmlTags(xmlContent);
      final estimatedPages = (textContent.length / 1500).ceil().clamp(1, 9999);
      
      return EnhancedBookMetadata(
        title: title,
        author: author,
        description: description,
        language: language,
        estimatedPages: estimatedPages,
        tags: tags,
        additionalInfo: {
          'format': 'FB2',
          'characterCount': textContent.length,
        },
      );
    } catch (e) {
      debugPrint('FB2 metadata extraction failed: $e');
      return _extractBasicMetadata(bytes, fileName);
    }
  }

  /// Extract RTF metadata
  Future<EnhancedBookMetadata> _extractRtfMetadata(Uint8List bytes, String fileName) async {
    try {
      final content = utf8.decode(bytes);
      
      // RTF files contain control codes, extract plain text
      String title = fileName.replaceAll(RegExp(r'\.(rtf)$'), '');
      String author = 'Unknown';
      
      // Extract title from RTF info if available
      final titleMatch = RegExp(r'\\title\s+([^}]+)').firstMatch(content);
      if (titleMatch != null) {
        title = titleMatch.group(1)?.trim() ?? title;
      }
      
      // Extract author from RTF info
      final authorMatch = RegExp(r'\\author\s+([^}]+)').firstMatch(content);
      if (authorMatch != null) {
        author = authorMatch.group(1)?.trim() ?? author;
      }
      
      // Strip RTF control codes to get plain text
      final plainText = content
          .replaceAll(RegExp(r'\\[a-z]+\d*\s*'), ' ')
          .replaceAll(RegExp(r'[{}]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      
      final estimatedPages = (plainText.length / 1500).ceil().clamp(1, 9999);
      
      return EnhancedBookMetadata(
        title: title,
        author: author,
        estimatedPages: estimatedPages,
        additionalInfo: {
          'format': 'RTF',
          'characterCount': plainText.length,
        },
      );
    } catch (e) {
      debugPrint('RTF metadata extraction failed: $e');
      return _extractBasicMetadata(bytes, fileName);
    }
  }

  /// Basic metadata extraction fallback
  EnhancedBookMetadata _extractBasicMetadata(Uint8List bytes, String fileName) {
    final fileSize = bytes.length;
    final estimatedPages = (fileSize / 10000).ceil().clamp(1, 9999);
    final extension = fileName.split('.').last.toUpperCase();
    
    return EnhancedBookMetadata(
      title: fileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
      author: 'Unknown',
      estimatedPages: estimatedPages,
      additionalInfo: {
        'format': extension,
        'fileSize': fileSize,
      },
    );
  }

  /// Detect content language (basic implementation)
  String? _detectLanguage(String content) {
    // Simple language detection based on character patterns
    final chineseCount = RegExp(r'[\u4e00-\u9fff]').allMatches(content).length;
    final englishCount = RegExp(r'[a-zA-Z]').allMatches(content).length;
    final totalChars = content.length;
    
    if (chineseCount > totalChars * 0.3) {
      return 'zh';
    } else if (englishCount > totalChars * 0.5) {
      return 'en';
    }
    
    return null;
  }

  /// Save cover image to disk
  Future<String?> _saveCoverImage(Uint8List imageBytes, String bookFileName) async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory(join(documentsDir.path, 'covers'));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }
      
      final bookName = bookFileName.replaceAll(RegExp(r'\.[^.]+$'), '');
      final coverPath = join(coversDir.path, '${bookName}_cover.jpg');
      final coverFile = File(coverPath);
      
      await coverFile.writeAsBytes(imageBytes);
      debugPrint('Cover image saved to: $coverPath');
      
      return coverPath;
    } catch (e) {
      debugPrint('Failed to save cover image: $e');
      return null;
    }
  }
              
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
