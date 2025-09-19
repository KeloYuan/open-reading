import 'dart:io';
import 'dart:typed_data';
import 'package:epubx/epubx.dart';
import 'package:pdfx/pdfx.dart';
import 'package:flutter/foundation.dart';
import '../models/chapter.dart';

/// 增强的书籍处理服务
/// 提供目录分析、封面提取、元数据处理等功能
class EnhancedBookService {
  static final EnhancedBookService _instance = EnhancedBookService._internal();

  factory EnhancedBookService() {
    return _instance;
  }

  EnhancedBookService._internal();

  /// 分析EPUB书籍目录结构
  Future<List<Chapter>> analyzeEpubToc(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final epubBook = await EpubReader.readBook(bytes);

      List<Chapter> chapters = [];

      // 从基本章节信息创建目录
      if (epubBook.Chapters != null && epubBook.Chapters!.isNotEmpty) {
        for (int i = 0; i < epubBook.Chapters!.length; i++) {
          final chapter = epubBook.Chapters![i];
          chapters.add(
            Chapter(
              id: i + 1,
              title: chapter.Title ?? '第${i + 1}章',
              startPage: i,
              href: chapter.Anchor,
              order: i,
              level: 0,
            ),
          );
        }
      }

      debugPrint('成功分析EPUB目录，共${chapters.length}章');
      return chapters;
    } catch (e) {
      debugPrint('EPUB目录分析失败: $e');
      return [];
    }
  }

  /// 从HTML内容中提取标题
  String _extractTitleFromHtml(String htmlContent, int defaultIndex) {
    // 正则表达式匹配常见的标题标签
    final titlePatterns = [
      RegExp(r'<h[1-6][^>]*>([^<]*)</h[1-6]>', caseSensitive: false),
      RegExp(r'<title[^>]*>([^<]*)</title>', caseSensitive: false),
      RegExp(
        r'<p[^>]*class="[^"]*title[^"]*"[^>]*>([^<]*)</p>',
        caseSensitive: false,
      ),
      RegExp(r'第\s*[零一二三四五六七八九十百千万\d]+\s*[章节回部篇集卷]', caseSensitive: false),
    ];

    for (final pattern in titlePatterns) {
      final match = pattern.firstMatch(htmlContent);
      if (match != null) {
        String title = match.group(1) ?? match.group(0) ?? '';
        title = _cleanChapterTitle(title);
        if (title.isNotEmpty && title.length < 100) {
          return title;
        }
      }
    }

    return '第${defaultIndex}章';
  }

  /// 清理章节标题
  String _cleanChapterTitle(String title) {
    return title
        .replaceAll(RegExp(r'<[^>]*>'), '') // 移除HTML标签
        .replaceAll(RegExp(r'\s+'), ' ') // 合并空白字符
        .trim();
  }

  /// 提取EPUB封面
  Future<Uint8List?> extractEpubCover(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final epubBook = await EpubReader.readBook(bytes);

      // 尝试获取封面图片
      // TODO: 修复CoverImage API兼容性问题
      // final coverImage = epubBook.CoverImage;
      // if (coverImage != null) {
      //   return Uint8List.fromList(coverImage);
      // }

      debugPrint('未找到EPUB封面');
      return null;
    } catch (e) {
      debugPrint('EPUB封面提取失败: $e');
      return null;
    }
  }

  /// 提取PDF封面（第一页）
  Future<Uint8List?> extractPdfCover(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final pdfDocument = await PdfDocument.openData(bytes);

      // 获取第一页作为封面
      if (pdfDocument.pagesCount > 0) {
        final page = await pdfDocument.getPage(1);
        final pageImage = await page.render(
          width: 400, // 封面宽度
          height: 600, // 封面高度
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
      debugPrint('PDF封面提取失败: $e');
      return null;
    }
  }

  /// 从HTML中提取图片URL
  String? _extractImageUrlFromHtml(String htmlContent) {
    final imgPattern = RegExp(r'<img[^>]+src="([^"]+)"', caseSensitive: false);
    final match = imgPattern.firstMatch(htmlContent);
    return match?.group(1);
  }

  /// 验证图片格式
  bool _isValidImageFormat(Uint8List bytes) {
    if (bytes.length < 10) return false;

    // 检查文件头
    final header = bytes.take(10).toList();

    // JPEG: FF D8 FF
    if (header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF)
      return true;

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (header[0] == 0x89 &&
        header[1] == 0x50 &&
        header[2] == 0x4E &&
        header[3] == 0x47)
      return true;

    // GIF: 47 49 46 38
    if (header[0] == 0x47 &&
        header[1] == 0x49 &&
        header[2] == 0x46 &&
        header[3] == 0x38)
      return true;

    // WebP: 52 49 46 46 ... 57 45 42 50
    if (header[0] == 0x52 &&
        header[1] == 0x49 &&
        header[2] == 0x46 &&
        header[3] == 0x46 &&
        bytes.length > 12 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50)
      return true;

    return false;
  }

  /// 分析PDF目录结构
  Future<List<Chapter>> analyzePdfToc(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final pdfDocument = await PdfDocument.openData(bytes);

      List<Chapter> chapters = [];

      // PDF通常没有明确的目录结构，我们按页数创建简单的章节
      for (int i = 1; i <= pdfDocument.pagesCount; i++) {
        chapters.add(
          Chapter(
            id: i,
            title: '第 $i 页',
            startPage: i - 1,
            order: i - 1,
            level: 0,
          ),
        );
      }

      await pdfDocument.close();
      debugPrint('成功分析PDF目录，共${chapters.length}页');
      return chapters;
    } catch (e) {
      debugPrint('PDF目录分析失败: $e');
      return [];
    }
  }

  /// 获取书籍元数据
  Future<Map<String, String>> getBookMetadata(String filePath) async {
    final extension = filePath.split('.').last.toLowerCase();

    switch (extension) {
      case 'epub':
        return await _getEpubMetadata(filePath);
      case 'pdf':
        return await _getPdfMetadata(filePath);
      default:
        return {
          'title': _getFileNameWithoutExtension(filePath),
          'author': '未知作者',
          'language': 'zh-CN',
        };
    }
  }

  /// 获取EPUB元数据
  Future<Map<String, String>> _getEpubMetadata(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final epubBook = await EpubReader.readBook(bytes);

      return {
        'title': epubBook.Title ?? _getFileNameWithoutExtension(filePath),
        'author': epubBook.Author ?? '未知作者',
        'language': 'zh-CN',
        'publisher': '',
        'description': '',
        'identifier': '',
      };
    } catch (e) {
      debugPrint('获取EPUB元数据失败: $e');
      return {
        'title': _getFileNameWithoutExtension(filePath),
        'author': '未知作者',
        'language': 'zh-CN',
      };
    }
  }

  /// 获取PDF元数据
  Future<Map<String, String>> _getPdfMetadata(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final pdfDocument = await PdfDocument.openData(bytes);

      // PDF元数据获取较为复杂，这里返回基础信息
      final metadata = {
        'title': _getFileNameWithoutExtension(filePath),
        'author': '未知作者',
        'language': 'zh-CN',
        'pageCount': pdfDocument.pagesCount.toString(),
      };

      await pdfDocument.close();
      return metadata;
    } catch (e) {
      debugPrint('获取PDF元数据失败: $e');
      return {
        'title': _getFileNameWithoutExtension(filePath),
        'author': '未知作者',
        'language': 'zh-CN',
      };
    }
  }

  /// 获取不带扩展名的文件名
  String _getFileNameWithoutExtension(String filePath) {
    final fileName = filePath.split('/').last;
    final dotIndex = fileName.lastIndexOf('.');
    return dotIndex != -1 ? fileName.substring(0, dotIndex) : fileName;
  }
}
