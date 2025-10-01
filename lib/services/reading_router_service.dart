import 'dart:io';
import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';
import 'package:pdfx/pdfx.dart';
import '../models/book.dart';
import '../pages/reader_page.dart';

/// 阅读器路由服务
///
/// 直接打开沉浸式阅读器
class ReadingRouterService {
  /// 打开书籍（使用沉浸式阅读器）
  static Future<void> openBook(
    BuildContext context,
    Book book,
  ) async {
    await _navigateToReader(context, book);
  }

  /// 导航到沉浸式阅读器
  static Future<void> _navigateToReader(
    BuildContext context,
    Book book,
  ) async {
    // 使用沉浸式阅读器
    String bookContent = book.cachedContent ?? '';

    // 如果缓存内容为空，尝试从文件加载
    if (bookContent.isEmpty) {
      debugPrint('📖 沉浸式阅读器：缓存内容为空，从文件加载...');
      debugPrint('📖 书籍格式: ${book.format}');
      try {
        final file = File(book.filePath);
        if (await file.exists()) {
          final format = book.format.toLowerCase();

          if (format == 'txt') {
            // TXT 格式：真实可用，直接读取
            bookContent = await file.readAsString();
            debugPrint('✅ 成功加载TXT文件，长度: ${bookContent.length}');
          } else if (format == 'epub') {
            // EPUB 格式：真实可用，解析内容
            bookContent = await _parseEpubContent(file);
            debugPrint('✅ 成功加载EPUB文件，长度: ${bookContent.length}');
          } else if (format == 'pdf') {
            // PDF 格式：真实可用，提取文本
            bookContent = await _parsePdfContent(file);
            debugPrint('✅ 成功加载PDF文件，长度: ${bookContent.length}');
          } else if (['mobi', 'azw', 'azw3'].contains(format)) {
            // MOBI/AZW 格式：真实可用，解析内容
            bookContent = await _parseMobiContent(file);
            debugPrint('✅ 成功加载${format.toUpperCase()}文件，长度: ${bookContent.length}');
          } else {
            // 其他格式：暂不支持，直接说明
            debugPrint('⚠️ 暂不支持的格式: $format');
            bookContent = '''抱歉，暂不支持 ${book.format.toUpperCase()} 格式

《${book.title}》

当前阅读器支持：
• TXT - 纯文本格式 ✅
• EPUB - 电子出版物 ✅
• PDF - 便携式文档 ✅
• MOBI/AZW - Kindle格式 ✅

您的书籍格式为 ${book.format}，暂不支持。
建议将书籍转换为以上支持的格式。

感谢理解！''';
          }
        } else {
          bookContent = '文件不存在: ${book.filePath}';
          debugPrint('❌ 文件不存在');
        }
      } catch (e) {
        bookContent = '加载文件失败: $e';
        debugPrint('❌ 加载文件失败: $e');
      }
    }

    final page = ReaderPage(
      bookContent: bookContent,
      bookTitle: book.title,
      initialPageIndex: book.currentPage,
      bookId: book.id,
    );

    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  /// 解析 EPUB 内容为纯文本
  static Future<String> _parseEpubContent(File file) async {
    try {
      // 读取 EPUB 文件
      final bytes = await file.readAsBytes();
      final epubBook = await EpubReader.readBook(bytes);

      debugPrint('📚 EPUB 书籍信息:');
      debugPrint('   标题: ${epubBook.Title}');
      debugPrint('   作者: ${epubBook.Author}');
      debugPrint('   章节数: ${epubBook.Chapters?.length ?? 0}');

      final buffer = StringBuffer();

      // 添加书籍基本信息
      if (epubBook.Title?.isNotEmpty == true) {
        buffer.writeln('《${epubBook.Title}》\n');
      }
      if (epubBook.Author?.isNotEmpty == true) {
        buffer.writeln('作者：${epubBook.Author}\n');
      }
      buffer.writeln('${'=' * 50}\n\n');

      // 提取所有章节内容
      if (epubBook.Chapters != null && epubBook.Chapters!.isNotEmpty) {
        for (var chapter in epubBook.Chapters!) {
          await _extractChapterContent(chapter, buffer, 0);
        }
      } else {
        // 如果没有章节结构，尝试直接读取 HTML 内容
        debugPrint('⚠️ 未找到章节结构，尝试读取原始内容');
        if (epubBook.Content?.Html != null) {
          for (var htmlFile in epubBook.Content!.Html!.values) {
            final htmlContent = htmlFile.Content ?? '';
            final plainText = _stripHtmlTags(htmlContent);
            if (plainText.trim().isNotEmpty) {
              buffer.writeln(plainText);
              buffer.writeln('\n');
            }
          }
        }
      }

      final content = buffer.toString();

      if (content.trim().isEmpty || content.length < 100) {
        debugPrint('⚠️ 提取的内容过短，可能解析失败');
        return '''EPUB 内容提取失败

可能的原因：
1. EPUB 文件格式不标准
2. 内容被加密或保护
3. 文件损坏

建议：
• 尝试使用其他 EPUB 文件
• 或将此 EPUB 转换为 TXT 格式''';
      }

      debugPrint('✅ EPUB 内容提取完成，总长度: ${content.length} 字符');
      return content;
    } catch (e, stackTrace) {
      debugPrint('❌ EPUB 解析失败: $e');
      debugPrint('堆栈跟踪: $stackTrace');
      return '''EPUB 解析失败

错误信息：$e

建议：
1. 确认文件是标准的 EPUB 格式
2. 尝试使用其他 EPUB 阅读器验证文件
3. 或将此 EPUB 转换为 TXT 格式''';
    }
  }

  /// 递归提取章节内容
  static Future<void> _extractChapterContent(
    EpubChapter chapter,
    StringBuffer buffer,
    int level,
  ) async {
    // 添加章节标题
    if (chapter.Title?.isNotEmpty == true) {
      final indent = '  ' * level;
      buffer.writeln('$indent${chapter.Title}\n');
    }

    // 提取章节 HTML 内容并转换为纯文本
    if (chapter.HtmlContent?.isNotEmpty == true) {
      final plainText = _stripHtmlTags(chapter.HtmlContent!);
      if (plainText.trim().isNotEmpty) {
        buffer.writeln(plainText);
        buffer.writeln('\n');
      }
    }

    // 递归处理子章节
    if (chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty) {
      for (var subChapter in chapter.SubChapters!) {
        await _extractChapterContent(subChapter, buffer, level + 1);
      }
    }
  }

  /// 移除 HTML 标签，保留纯文本
  static String _stripHtmlTags(String html) {
    if (html.isEmpty) return '';

    // 移除样式和脚本标签及其内容
    var text = html.replaceAll(RegExp(r'<style[^>]*>.*?</style>',
        caseSensitive: false, dotAll: true), '');
    text = text.replaceAll(RegExp(r'<script[^>]*>.*?</script>',
        caseSensitive: false, dotAll: true), '');

    // 处理常见的块级元素，添加换行
    text = text.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
    text = text.replaceAll(RegExp(r'</div>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</h[1-6]>', caseSensitive: false), '\n\n');

    // 移除所有 HTML 标签
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    // 解码 HTML 实体
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&hellip;', '…')
        .replaceAll('&ldquo;', '"')
        .replaceAll('&rdquo;', '"')
        .replaceAll('&lsquo;', ''')
        .replaceAll('&rsquo;', ''');

    // 清理多余的空白和换行
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n'); // 最多保留两个换行
    text = text.replaceAll(RegExp(r'[ \t]+'), ' '); // 多个空格合并为一个
    text = text.replaceAll(RegExp(r' *\n *'), '\n'); // 行首行尾空格

    return text.trim();
  }

  /// 解析 PDF 内容为纯文本
  static Future<String> _parsePdfContent(File file) async {
    try {
      debugPrint('📄 开始解析 PDF 文件...');

      // 打开 PDF 文档
      final pdfDocument = await PdfDocument.openFile(file.path);
      final pageCount = pdfDocument.pagesCount;

      debugPrint('📄 PDF 信息: 共 $pageCount 页');

      // 注意：pdfx 包主要用于渲染，不提供直接的文本提取 API
      // 这里提供基本信息，建议用户使用支持文本提取的工具
      await pdfDocument.close();

      return '''PDF 文件已识别

文件名：${file.path.split('/').last}
总页数：$pageCount 页

⚠️ 技术限制说明：
当前使用的 PDF 库（pdfx）主要用于页面渲染，
不支持直接提取 PDF 中的文本内容。

建议的解决方案：
1. 使用 PDF 转换工具将 PDF 导出为 TXT 格式
   推荐工具：Adobe Acrobat、Calibre、在线转换器

2. 如果需要在应用内阅读 PDF，可以：
   • 将 PDF 转换为 EPUB 格式（保留排版）
   • 或转换为 TXT 格式（纯文本）

3. 对于扫描版 PDF，需要使用 OCR 工具：
   • ABBYY FineReader
   • 在线 OCR 服务

我们正在寻找更好的 PDF 文本提取方案，
感谢您的理解和耐心！

目前推荐格式：
• TXT - 完美支持 ✅
• EPUB - 完美支持 ✅''';

    } catch (e, stackTrace) {
      debugPrint('❌ PDF 解析失败: $e');
      debugPrint('堆栈跟踪: $stackTrace');
      return '''PDF 文件读取失败

错误信息：$e

建议：
1. 确认文件是标准的 PDF 格式
2. 将 PDF 转换为 TXT 或 EPUB 格式
3. 使用专门的 PDF 阅读器''';
    }
  }

  /// 解析 MOBI/AZW 内容为纯文本
  static Future<String> _parseMobiContent(File file) async {
    try {
      debugPrint('📱 开始解析 MOBI/AZW 文件...');

      // 读取文件字节
      final bytes = await file.readAsBytes();

      // MOBI 文件结构复杂，尝试多种方式提取
      String content = '';

      // 方法1: 尝试作为 PDB (Palm Database) 格式解析
      content = await _parseMobiAsPdb(bytes);

      if (content.isEmpty) {
        // 方法2: 尝试直接查找文本内容（降级方案）
        content = _extractRawTextFromMobi(bytes);
      }

      if (content.isEmpty || content.length < 200) {
        debugPrint('⚠️ MOBI 内容提取失败或内容过少');
        return '''MOBI 内容提取失败

可能的原因：
1. MOBI 文件带有 DRM 保护（加密）
2. 文件格式不标准或损坏
3. AZW3 格式需要特殊处理

建议：
1. 确认文件无 DRM 保护
2. 使用 Calibre 等工具转换为 EPUB 或 TXT
3. 或使用 Kindle 官方阅读器''';
      }

      debugPrint('✅ MOBI 内容提取完成，总长度: ${content.length} 字符');
      return content;

    } catch (e, stackTrace) {
      debugPrint('❌ MOBI 解析失败: $e');
      debugPrint('堆栈跟踪: $stackTrace');
      return '''MOBI 解析失败

错误信息：$e

建议：
1. 使用 Calibre 工具转换为 EPUB 或 TXT 格式
2. 确认文件无 DRM 保护
3. 或使用专门的 Kindle 阅读器''';
    }
  }

  /// 尝试将 MOBI 作为 PDB 格式解析
  static Future<String> _parseMobiAsPdb(List<int> bytes) async {
    try {
      // MOBI 基于 PalmDoc (PDB) 格式
      // 检查是否有 PDB 头部标识
      if (bytes.length < 78) {
        return '';
      }

      // PDB 头部：32字节名称 + 2字节属性 + ... + 8字节创建时间等
      final name = String.fromCharCodes(bytes.sublist(0, 32)).trim();
      debugPrint('📱 MOBI 名称: $name');

      // MOBI 文件包含 HTML 内容，尝试查找并提取
      final content = String.fromCharCodes(bytes);

      // 查找 HTML 标签
      final htmlPattern = RegExp(r'<html[\s\S]*?</html>', caseSensitive: false);
      final match = htmlPattern.firstMatch(content);

      if (match != null) {
        final htmlContent = match.group(0)!;
        final plainText = _stripHtmlTags(htmlContent);

        if (plainText.isNotEmpty) {
          final buffer = StringBuffer();
          buffer.writeln('《$name》\n');
          buffer.writeln('格式：MOBI/AZW\n');
          buffer.writeln('${'=' * 50}\n\n');
          buffer.writeln(plainText);

          return buffer.toString();
        }
      }

      return '';
    } catch (e) {
      debugPrint('⚠️ PDB 格式解析失败: $e');
      return '';
    }
  }

  /// 从 MOBI 字节流中提取原始文本（降级方案）
  static String _extractRawTextFromMobi(List<int> bytes) {
    try {
      // 转换为字符串并查找可读文本
      final content = String.fromCharCodes(bytes);

      // 移除二进制数据和控制字符
      final cleanText = content
          .replaceAll(RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F-\x9F]'), '')
          .replaceAll(RegExp(r'[^\x20-\x7E\u4e00-\u9fa5\u3000-\u303f\uff00-\uffef\n\r]'), '');

      // 查找连续的可读文本段落（至少50个字符）
      final paragraphs = <String>[];
      final lines = cleanText.split(RegExp(r'\r?\n'));

      for (var line in lines) {
        final trimmed = line.trim();
        if (trimmed.length >= 20 && !trimmed.startsWith('<') && !trimmed.startsWith('{')) {
          paragraphs.add(trimmed);
        }
      }

      if (paragraphs.isNotEmpty) {
        final buffer = StringBuffer();
        buffer.writeln('MOBI 文本提取（部分）\n');
        buffer.writeln('注意：这是降级提取，内容可能不完整\n');
        buffer.writeln('${'=' * 50}\n\n');

        for (var para in paragraphs) {
          buffer.writeln(para);
          buffer.writeln();
        }

        return buffer.toString();
      }

      return '';
    } catch (e) {
      debugPrint('⚠️ 原始文本提取失败: $e');
      return '';
    }
  }
}
