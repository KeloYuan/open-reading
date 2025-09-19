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

  /// 提取EPUB封面
  Future<Uint8List?> extractEpubCover(String filePath) async {
    try {
      // 暂时注释掉epub解析，因为CoverImage API存在兼容性问题
      // final bytes = await File(filePath).readAsBytes();
      // final epubBook = await EpubReader.readBook(bytes);

      // 尝试获取封面图片
      // TODO: 修复CoverImage API兼容性问题
      // final coverImage = epubBook.CoverImage;
      // if (coverImage != null) {
      //   return Uint8List.fromList(coverImage);
      // }

      debugPrint('EPUB封面提取暂不支持，等待API修复');
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
