import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xxread/services/book_dao.dart';
import 'package:epubx/epubx.dart';
import 'package:pdfx/pdfx.dart';
import 'dart:convert';

import '../models/book.dart';
import '../models/chapter.dart';
import 'enhanced_txt_import_service.dart';

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
  final _enhancedTxtService = EnhancedTxtImportService();

  Future<Book?> importBook() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'txt',
          'epub',
          'pdf',
          'mobi',
          'azw',
          'azw3',
          'fb2',
          'rtf',
          'doc',
          'docx',
          'cbz',
          'cbr',
        ],
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
          coverImagePath = await _saveCoverImage(
            metadata.coverImage!,
            pickedFile.name,
          );
        }

        // 5. Create Book object with enhanced metadata
        final book = Book(
          title: metadata.title,
          author: metadata.author,
          filePath: newFilePath,
          format: pickedFile.extension?.toUpperCase() ?? 'UNKNOWN',
          totalPages: metadata.estimatedPages,
          coverImagePath: coverImagePath,
        );

        // 6. Insert metadata into the database
        final bookId = await _bookDao.insertBook(book);
        debugPrint('Enhanced book metadata inserted with ID: $bookId');
        debugPrint('Title: ${metadata.title}');
        debugPrint('Author: ${metadata.author}');
        debugPrint('Pages: ${metadata.estimatedPages}');
        debugPrint('Language: ${metadata.language ?? 'Unknown'}');
        debugPrint('Publisher: ${metadata.publisher ?? 'Unknown'}');

        return book.copyWith(id: bookId);
      }
    } catch (e) {
      debugPrint('Enhanced import process failed: $e');
      rethrow;
    }
    return null;
  }

  /// Extract enhanced metadata from different file formats
  Future<EnhancedBookMetadata> _extractEnhancedMetadata(
    PlatformFile pickedFile,
  ) async {
    final extension = pickedFile.extension?.toLowerCase();
    final bytes = pickedFile.bytes!;

    switch (extension) {
      case 'epub':
        return await _extractEpubMetadata(bytes, pickedFile.name);
      case 'pdf':
        return await _extractPdfMetadata(bytes, pickedFile.name);
      case 'txt':
        return await _extractTxtMetadata(bytes, pickedFile.name);
      case 'mobi':
      case 'azw':
      case 'azw3':
        return await _extractMobiMetadata(bytes, pickedFile.name);
      case 'fb2':
        return await _extractFb2Metadata(bytes, pickedFile.name);
      case 'cbz':
      case 'cbr':
        return await _extractComicMetadata(bytes, pickedFile.name);
      case 'rtf':
        return await _extractRtfMetadata(bytes, pickedFile.name);
      default:
        return _extractBasicMetadata(bytes, pickedFile.name);
    }
  }

  /// Extract comprehensive EPUB metadata
  Future<EnhancedBookMetadata> _extractEpubMetadata(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final epubBook = await EpubReader.readBook(bytes);

      // Extract cover image with enhanced logic
      Uint8List? coverImage;
      try {
        coverImage = await _extractEpubCover(epubBook);
      } catch (e) {
        debugPrint('Cover image extraction failed: $e');
      }

      // Extract all available metadata
      final title = epubBook.Title?.isNotEmpty == true
          ? epubBook.Title!
          : fileName.replaceAll(RegExp(r'\.(epub)$'), '');
      final author =
          epubBook.Author?.isNotEmpty == true ? epubBook.Author! : 'Unknown';

      // Try to extract description from available fields
      String? description;
      // EPUB standard doesn't have a direct Description property, so try alternative methods
      final allContent = await _getAllEpubContent(epubBook);
      if (allContent.isNotEmpty && allContent.length > 200) {
        // Take first 500 characters as description
        description =
            allContent.substring(0, allContent.length.clamp(0, 500)).trim();
        if (description.length >= 500) {
          description = '${description.substring(0, 497)}...';
        }
      }

      // Extract language - simple approach since Language property may not exist
      String? language;
      if (epubBook.Schema?.Package?.Metadata?.Languages?.isNotEmpty == true) {
        language = epubBook.Schema!.Package!.Metadata!.Languages!.first;
      }

      // Extract publisher - Publishers may be a list of strings
      String? publisher;
      if (epubBook.Schema?.Package?.Metadata?.Publishers?.isNotEmpty == true) {
        publisher = epubBook.Schema!.Package!.Metadata!.Publishers!.first;
      }

      // Extract publication date
      String? publishDate;
      if (epubBook.Schema?.Package?.Metadata?.Dates?.isNotEmpty == true) {
        publishDate = epubBook.Schema!.Package!.Metadata!.Dates!.first.Date;
      }

      // Extract ISBN
      String? isbn;
      if (epubBook.Schema?.Package?.Metadata?.Identifiers?.isNotEmpty == true) {
        for (final identifier
            in epubBook.Schema!.Package!.Metadata!.Identifiers!) {
          if (identifier.Scheme?.toLowerCase().contains('isbn') == true) {
            isbn = identifier.Identifier;
            break;
          }
        }
      }

      // Extract subject tags - Subjects is likely a list of strings
      List<String>? tags;
      if (epubBook.Schema?.Package?.Metadata?.Subjects?.isNotEmpty == true) {
        tags = epubBook.Schema!.Package!.Metadata!.Subjects!
            .where((subject) => subject.isNotEmpty)
            .toList();
      }

      // Estimate pages based on content length
      final estimatedPages = (allContent.length / 1500).ceil().clamp(1, 9999);

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
  Future<EnhancedBookMetadata> _extractPdfMetadata(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final pdfDocument = await PdfDocument.openData(bytes);
      final pageCount = pdfDocument.pagesCount;

      // Extract basic metadata - PDF metadata is often limited
      final title = fileName.replaceAll(RegExp(r'\.(pdf)$'), '');

      // 提取PDF封面
      Uint8List? coverImage;
      try {
        coverImage = await _extractPdfCover(bytes);
      } catch (e) {
        debugPrint('PDF cover extraction failed: $e');
      }

      await pdfDocument.close();

      return EnhancedBookMetadata(
        title: title,
        author: 'Unknown',
        estimatedPages: pageCount,
        coverImage: coverImage,
        additionalInfo: {'format': 'PDF', 'actualPageCount': pageCount},
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

  /// 使用增强服务提取TXT元数据
  Future<EnhancedBookMetadata> _extractTxtMetadata(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      // 使用增强的TXT导入服务
      final content = _enhancedTxtService.detectTextEncoding(bytes);
      final txtMetadata = _enhancedTxtService.extractTxtMetadata(
        content,
        fileName,
      );

      debugPrint('增强TXT元数据提取完成:');
      debugPrint('标题: ${txtMetadata.title}');
      debugPrint('作者: ${txtMetadata.author}');
      debugPrint('语言: ${txtMetadata.language ?? '未知'}');
      debugPrint('预估页数: ${txtMetadata.estimatedPages}');
      if (txtMetadata.description != null) {
        debugPrint(
          '简介: ${txtMetadata.description!.substring(0, txtMetadata.description!.length.clamp(0, 100))}...',
        );
      }

      return EnhancedBookMetadata(
        title: txtMetadata.title,
        author: txtMetadata.author,
        description: txtMetadata.description,
        estimatedPages: txtMetadata.estimatedPages,
        language: txtMetadata.language,
        additionalInfo: txtMetadata.additionalInfo,
      );
    } catch (e) {
      debugPrint('增强TXT元数据提取失败，回退到基础提取: $e');
      return _extractBasicMetadata(bytes, fileName);
    }
  }

  /// Extract FictionBook 2 (FB2) metadata
  Future<EnhancedBookMetadata> _extractFb2Metadata(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      debugPrint('FB2 metadata extraction - using basic XML parsing');

      // 直接使用 XML 解析
      return await _extractFb2MetadataXml(bytes, fileName);
    } catch (e) {
      debugPrint('FB2 metadata extraction failed: $e');
      return _extractBasicMetadata(bytes, fileName);
    }
  }

  /// 传统 FB2 XML 解析（WebView 解析失败时的回退方案）
  Future<EnhancedBookMetadata> _extractFb2MetadataXml(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final xmlContent = utf8.decode(bytes);

      // Parse FB2 XML structure
      String title = fileName.replaceAll(RegExp(r'\.(fb2)$'), '');
      String author = 'Unknown';
      String? description;
      String? language;
      List<String>? tags;
      Uint8List? coverImage;

      // Extract title
      final titleMatch = RegExp(
        r'<book-title[^>]*>(.*?)</book-title>',
        dotAll: true,
      ).firstMatch(xmlContent);
      if (titleMatch != null) {
        title = _stripXmlTags(titleMatch.group(1) ?? '').trim();
      }

      // Extract author (enhanced)
      final authorMatch = RegExp(
        r'<author[^>]*>.*?<first-name[^>]*>(.*?)</first-name>.*?<last-name[^>]*>(.*?)</last-name>.*?</author>',
        dotAll: true,
      ).firstMatch(xmlContent);
      if (authorMatch != null) {
        final firstName = _stripXmlTags(authorMatch.group(1) ?? '').trim();
        final lastName = _stripXmlTags(authorMatch.group(2) ?? '').trim();
        author = '$firstName $lastName'.trim();
      } else {
        // 尝试简单作者匹配
        final simpleAuthorMatch = RegExp(
          r'<author[^>]*>(.*?)</author>',
          dotAll: true,
        ).firstMatch(xmlContent);
        if (simpleAuthorMatch != null) {
          author = _stripXmlTags(simpleAuthorMatch.group(1) ?? '').trim();
        }
      }

      // Extract description (enhanced)
      final descMatch = RegExp(
        r'<annotation[^>]*>(.*?)</annotation>',
        dotAll: true,
      ).firstMatch(xmlContent);
      if (descMatch != null) {
        description = _stripXmlTags(descMatch.group(1) ?? '').trim();
        // 限制描述长度
        if (description.length > 500) {
          description = '${description.substring(0, 497)}...';
        }
      }

      // Extract language
      final langMatch = RegExp(
        r'<lang[^>]*>(.*?)</lang>',
      ).firstMatch(xmlContent);
      if (langMatch != null) {
        language = langMatch.group(1)?.trim();
      }

      // Extract genres as tags
      final genreMatches = RegExp(
        r'<genre[^>]*>(.*?)</genre>',
      ).allMatches(xmlContent);
      if (genreMatches.isNotEmpty) {
        tags = genreMatches
            .map((match) => match.group(1)?.trim() ?? '')
            .where((tag) => tag.isNotEmpty)
            .toList();
      }

      // Try to extract cover image from FB2
      coverImage = await _extractFb2Cover(xmlContent);

      final textContent = _stripXmlTags(xmlContent);
      final estimatedPages = (textContent.length / 1500).ceil().clamp(1, 9999);

      return EnhancedBookMetadata(
        title: title,
        author: author,
        description: description,
        language: language,
        coverImage: coverImage,
        estimatedPages: estimatedPages,
        tags: tags,
        additionalInfo: {
          'format': 'FB2',
          'characterCount': textContent.length,
          'parsedByXml': true,
        },
      );
    } catch (e) {
      debugPrint('FB2 XML metadata extraction failed: $e');
      return _extractBasicMetadata(bytes, fileName);
    }
  }

  /// 从 FB2 文件提取封面图片
  Future<Uint8List?> _extractFb2Cover(String xmlContent) async {
    try {
      // FB2 格式中的封面通常在 <binary> 标签中
      final binaryPattern = RegExp(
        r'<binary[^>]*id\s*=\s*["\x27]([^"\x27]*cover[^"\x27]*)["\x27][^>]*>(.*?)</binary>',
        dotAll: true,
        caseSensitive: false,
      );
      final binaryMatch = binaryPattern.firstMatch(xmlContent);

      if (binaryMatch != null) {
        final base64Content = binaryMatch.group(2)?.trim() ?? '';
        if (base64Content.isNotEmpty) {
          try {
            // 清理base64字符串（移除换行和空格）
            final cleanBase64 = base64Content.replaceAll(RegExp(r'\s+'), '');
            return base64.decode(cleanBase64);
          } catch (e) {
            debugPrint('FB2 封面base64解码失败: $e');
          }
        }
      }

      // 尝试查找其他可能的图片
      final allBinaryMatches = RegExp(
        r"<binary[^>]*>(.*?)</binary>",
        dotAll: true,
      ).allMatches(xmlContent);

      for (final match in allBinaryMatches) {
        final base64Content = match.group(1)?.trim() ?? '';
        if (base64Content.isNotEmpty && base64Content.length > 100) {
          try {
            final cleanBase64 = base64Content.replaceAll(RegExp(r'\s+'), '');
            final imageBytes = base64.decode(cleanBase64);
            if (_isValidImageFormat(imageBytes)) {
              return imageBytes;
            }
          } catch (e) {
            continue; // 尝试下一个
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('FB2 封面提取失败: $e');
      return null;
    }
  }

  /// Extract MOBI/AZW3 metadata using WebView parsing
  Future<EnhancedBookMetadata> _extractMobiMetadata(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      debugPrint('MOBI/AZW3 metadata extraction - using WebView parsing');

      // MOBI/AZW3 基础解析（不依赖 WebView）
      debugPrint('Using basic parsing for MOBI/AZW3');

      // 估算页数（MOBI格式基于内容长度）
      final estimatedPages = (bytes.length / 3000).ceil().clamp(50, 1000);

      return EnhancedBookMetadata(
        title: fileName.replaceAll(RegExp(r'\.(mobi|azw|azw3)$'), ''),
        author: '未知作者',
        description: null,
        language: null,
        publisher: null,
        publishDate: null,
        isbn: null,
        coverImage: null,
        estimatedPages: estimatedPages,
        tags: null,
        additionalInfo: {
          'format': 'MOBI/AZW',
          'fileSize': bytes.length,
        },
      );
    } catch (e) {
      debugPrint('MOBI/AZW3 metadata extraction failed: $e');
      // 回退到基础解析
      return _extractBasicMobiMetadata(bytes, fileName);
    }
  }

  /// 基础 MOBI 元数据提取（WebView 解析失败时的回退方案）
  EnhancedBookMetadata _extractBasicMobiMetadata(
    Uint8List bytes,
    String fileName,
  ) {
    final title = fileName.replaceAll(RegExp(r'\.(mobi|azw|azw3)$'), '');
    final estimatedPages = (bytes.length / 3000).ceil().clamp(50, 1000);

    return EnhancedBookMetadata(
      title: title,
      author: 'Unknown',
      estimatedPages: estimatedPages,
      additionalInfo: {
        'format': fileName.split('.').last.toUpperCase(),
        'fileSize': bytes.length,
        'note': 'Basic extraction - WebView parsing failed',
      },
    );
  }

  /// Extract Comic Book (CBZ/CBR) metadata
  Future<EnhancedBookMetadata> _extractComicMetadata(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      // CBZ files are ZIP archives containing images
      // CBR files are RAR archives containing images
      final extension = fileName.split('.').last.toLowerCase();
      final title = fileName.replaceAll(RegExp(r'\.(cbz|cbr)$'), '');

      // For comic books, we can extract some basic info
      String author = 'Unknown';

      // Try to extract info from filename patterns
      final seriesMatch = RegExp(r'^(.+?)\s*#?\d+').firstMatch(title);
      if (seriesMatch != null) {
        author = 'Series: ${seriesMatch.group(1)}';
      }

      // Estimate pages based on typical comic book length
      final estimatedPages =
          extension == 'cbz' ? 25 : 30; // Comics typically 20-40 pages

      return EnhancedBookMetadata(
        title: title,
        author: author,
        description: 'Comic book in ${extension.toUpperCase()} format',
        estimatedPages: estimatedPages,
        additionalInfo: {
          'format': extension.toUpperCase(),
          'mediaType': 'comic',
          'isArchive': true,
          'note': 'Comic book archive - contains image files',
        },
      );
    } catch (e) {
      debugPrint('Comic metadata extraction failed: $e');
      return _extractBasicMetadata(bytes, fileName);
    }
  }

  /// Extract RTF metadata
  Future<EnhancedBookMetadata> _extractRtfMetadata(
    Uint8List bytes,
    String fileName,
  ) async {
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
        additionalInfo: {'format': 'RTF', 'characterCount': plainText.length},
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
      additionalInfo: {'format': extension, 'fileSize': fileSize},
    );
  }

  /// Save cover image to disk
  Future<String?> _saveCoverImage(
    Uint8List imageBytes,
    String bookFileName,
  ) async {
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

  /// 从TXT文件解析章节信息
  Future<List<Chapter>> extractTxtChapters(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('TXT文件不存在: $filePath');
        return [];
      }

      final bytes = await file.readAsBytes();

      // 使用增强的TXT导入服务检测编码和分析章节
      final content = _enhancedTxtService.detectTextEncoding(bytes);
      final chapters = _enhancedTxtService.analyzeChapterStructure(content);

      debugPrint('TXT章节分析完成，共提取到 ${chapters.length} 个章节');
      for (final chapter in chapters) {
        debugPrint('章节: ${chapter.title} (层级: ${chapter.level})');
      }

      return chapters;
    } catch (e) {
      debugPrint('TXT章节解析失败: $e');
      return [];
    }
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
      if (epubChapter.SubChapters != null &&
          epubChapter.SubChapters!.isNotEmpty) {
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
    return tocPatterns.any(
      (pattern) =>
          lowerTitle == pattern.toLowerCase() ||
          lowerTitle.startsWith(pattern.toLowerCase()),
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
    final headerRegex = RegExp(
      r'<h[1-6][^>]*>(.*?)<\/h[1-6]>',
      caseSensitive: false,
    );
    final match = headerRegex.firstMatch(html);

    if (match != null) {
      return _stripHtml(match.group(1) ?? '').trim();
    }

    // 尝试提取title标签
    final titleRegex = RegExp(
      r'<title[^>]*>(.*?)<\/title>',
      caseSensitive: false,
    );
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

  /// 智能构建章节层级结构
  List<Chapter> _buildSmartChapterHierarchy(List<Chapter> chapters) {
    // 实现章节层级化逻辑
    // 这里可以根据章节标题的模式来判断层级关系
    return chapters;
  }

  /// 根据分页结果更新章节页码 - 增强版
  Future<List<Chapter>> updateChapterPages(
    List<Chapter> chapters,
    String bookContent,
    List<String> pages,
  ) async {
    if (chapters.isEmpty || pages.isEmpty) return chapters;

    List<Chapter> updatedChapters = [];

    for (int i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      int startPage = 0;

      // 方法1: 精确匹配章节标题
      for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
        final pageContent = pages[pageIndex];

        if (_isChapterStartPage(pageContent, chapter.title)) {
          startPage = pageIndex;
          break;
        }
      }

      // 方法2: 如果没有找到，使用内容文件名匹配（适用于EPUB）
      if (startPage == 0 && chapter.contentFileName != null) {
        startPage = _findPageByContentFileName(pages, chapter.contentFileName!);
      }

      // 方法3: 如果还没找到，使用顺序估算
      if (startPage == 0 && i > 0) {
        final prevChapter = updatedChapters[i - 1];
        final avgPagesPerChapter = pages.length ~/ chapters.length;
        startPage = (prevChapter.startPage + avgPagesPerChapter).clamp(
          0,
          pages.length - 1,
        );
      }

      // 方法4: 确保章节页码递增
      if (i > 0 && startPage <= updatedChapters[i - 1].startPage) {
        startPage = updatedChapters[i - 1].startPage + 1;
      }

      updatedChapters.add(chapter.copyWith(startPage: startPage));
    }

    return updatedChapters;
  }

  /// 通过内容文件名查找页面
  int _findPageByContentFileName(List<String> pages, String contentFileName) {
    // 这里可以根据实际的分页逻辑来实现
    // 暂时返回简单的估算
    return 0;
  }

  /// 检查页面是否包含章节开始 - 增强版
  bool _isChapterStartPage(String pageContent, String chapterTitle) {
    final normalizedPageContent = pageContent.toLowerCase().trim();
    final normalizedChapterTitle = chapterTitle.toLowerCase().trim();

    // 移除特殊字符进行比较
    final cleanPageContent = normalizedPageContent.replaceAll(
      RegExp(r'[^\w\s\u4e00-\u9fff]'),
      ' ',
    );
    final cleanChapterTitle = normalizedChapterTitle.replaceAll(
      RegExp(r'[^\w\s\u4e00-\u9fff]'),
      ' ',
    );

    // 策略1: 直接匹配
    if (cleanPageContent.contains(cleanChapterTitle)) {
      return true;
    }

    // 策略2: 分词匹配 - 至少匹配70%的关键词
    final titleWords = cleanChapterTitle
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 1)
        .toList();

    if (titleWords.isNotEmpty) {
      int matchedWords = 0;
      for (final word in titleWords) {
        if (cleanPageContent.contains(word)) {
          matchedWords++;
        }
      }

      if (matchedWords / titleWords.length >= 0.7) {
        return true;
      }
    }

    // 策略3: 模糊匹配 - 处理数字章节
    if (RegExp(r'第?\s*\d+\s*[章节]').hasMatch(cleanChapterTitle)) {
      final chapterNum = RegExp(r'\d+').stringMatch(cleanChapterTitle);
      if (chapterNum != null) {
        final patterns = [
          '第$chapterNum章',
          '第$chapterNum节',
          'chapter $chapterNum',
          '$chapterNum.',
        ];

        for (final pattern in patterns) {
          if (cleanPageContent.contains(pattern)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// 增强的EPUB封面提取
  Future<Uint8List?> _extractEpubCover(EpubBook epubBook) async {
    try {
      // 方法1: 直接从CoverImage属性获取
      if (epubBook.CoverImage != null) {
        // 如果CoverImage是Uint8List类型
        if (epubBook.CoverImage is Uint8List) {
          return epubBook.CoverImage as Uint8List;
        }
        // 如果有其他类型，尝试转换
      }

      // 方法2: 从Content.Images中查找封面
      if (epubBook.Content?.Images != null &&
          epubBook.Content!.Images!.isNotEmpty) {
        // 优先查找名称包含"cover"的图片
        for (final entry in epubBook.Content!.Images!.entries) {
          final fileName = entry.key.toLowerCase();
          if (fileName.contains('cover') || fileName.contains('front')) {
            final imageFile = entry.value;
            if (imageFile.Content != null && imageFile.Content!.isNotEmpty) {
              final imageBytes = Uint8List.fromList(imageFile.Content!);
              if (_isValidImageFormat(imageBytes)) {
                return imageBytes;
              }
            }
          }
        }

        // 如果没找到，返回第一个有效的图片
        for (final entry in epubBook.Content!.Images!.entries) {
          final imageFile = entry.value;
          if (imageFile.Content != null && imageFile.Content!.isNotEmpty) {
            final imageBytes = Uint8List.fromList(imageFile.Content!);
            if (_isValidImageFormat(imageBytes)) {
              return imageBytes;
            }
          }
        }
      }

      // 方法3: 从manifest中查找封面引用
      if (epubBook.Schema?.Package?.Manifest?.Items != null) {
        for (final item in epubBook.Schema!.Package!.Manifest!.Items!) {
          // 查找cover相关的item
          if (item.Id?.toLowerCase().contains('cover') == true ||
              item.Href?.toLowerCase().contains('cover') == true ||
              item.Properties?.contains('cover-image') == true) {
            // 尝试从Images中获取对应的内容
            if (epubBook.Content?.Images != null && item.Href != null) {
              final imageFile = epubBook.Content!.Images![item.Href!];
              if (imageFile?.Content != null &&
                  imageFile!.Content!.isNotEmpty) {
                final imageBytes = Uint8List.fromList(imageFile.Content!);
                if (_isValidImageFormat(imageBytes)) {
                  return imageBytes;
                }
              }
            }
          }
        }
      }

      debugPrint('No cover image found in EPUB');
      return null;
    } catch (e) {
      debugPrint('Error extracting EPUB cover: $e');
      return null;
    }
  }

  /// 验证图片格式
  bool _isValidImageFormat(Uint8List bytes) {
    if (bytes.length < 10) return false;

    // 检查文件头
    final header = bytes.take(10).toList();

    // JPEG: FF D8 FF
    if (header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF) {
      return true;
    }

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (header[0] == 0x89 &&
        header[1] == 0x50 &&
        header[2] == 0x4E &&
        header[3] == 0x47) {
      return true;
    }

    // GIF: 47 49 46 38
    if (header[0] == 0x47 &&
        header[1] == 0x49 &&
        header[2] == 0x46 &&
        header[3] == 0x38) {
      return true;
    }

    // WebP: 52 49 46 46 ... 57 45 42 50
    if (header[0] == 0x52 &&
        header[1] == 0x49 &&
        header[2] == 0x46 &&
        header[3] == 0x46 &&
        bytes.length > 12 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }

    return false;
  }

  /// 创建临时文件用于 WebView 解析
  Future<File> _createTempFile(Uint8List bytes, String fileName) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempFileName = '${timestamp}_$fileName';
    final tempFile = File('${tempDir.path}/$tempFileName');

    await tempFile.writeAsBytes(bytes);
    debugPrint('创建临时文件: ${tempFile.path}');

    return tempFile;
  }

  /// 增强的PDF封面提取
  Future<Uint8List?> _extractPdfCover(Uint8List bytes) async {
    try {
      final pdfDocument = await PdfDocument.openData(bytes);

      // 获取第一页作为封面
      if (pdfDocument.pagesCount > 0) {
        final page = await pdfDocument.getPage(1);
        final pageImage = await page.render(
          width: 300, // 封面宽度
          height: 400, // 封面高度
        );

        await page.close();
        await pdfDocument.close();

        if (pageImage?.bytes != null && pageImage!.bytes.isNotEmpty) {
          return pageImage.bytes;
        }
      }

      await pdfDocument.close();
      return null;
    } catch (e) {
      debugPrint('Error extracting PDF cover: $e');
      return null;
    }
  }
}
