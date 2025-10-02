import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';
import 'package:pdfx/pdfx.dart';
import '../models/book.dart';
import '../pages/reader_page.dart';
import 'background_content_loader.dart';

/// 阅读器路由服务
///
/// 直接打开沉浸式阅读器
class ReadingRouterService {
  // 后台内容加载器（全局单例）
  static BackgroundContentLoader? _contentLoader;

  /// 打开书籍（使用沉浸式阅读器）
  static Future<void> openBook(
    BuildContext context,
    Book book,
  ) async {
    await _navigateToReader(context, book);
  }

  /// 获取后台内容加载器
  static BackgroundContentLoader getContentLoader() {
    _contentLoader ??= BackgroundContentLoader();
    return _contentLoader!;
  }

  /// 导航到沉浸式阅读器（带流畅加载动画，支持渐进式加载）
  static Future<void> _navigateToReader(
    BuildContext context,
    Book book,
  ) async {
    String? bookContent = book.cachedContent;

    // 如果有缓存内容，直接打开
    if (bookContent != null && bookContent.isNotEmpty) {
      debugPrint('📖 使用缓存内容打开书籍');
      _openReaderPage(context, book, bookContent);
      return;
    }

    // 无缓存，显示加载对话框并在后台加载
    debugPrint('📖 缓存为空，显示加载动画并异步加载书籍');

    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _buildLoadingDialog(book),
    );

    try {
      // 在后台异步加载书籍内容（优化版：支持渐进式加载）
      bookContent = await _loadBookContent(book);

      // 延迟一小段时间，确保加载动画至少显示一会儿（提升体验）
      await Future.delayed(const Duration(milliseconds: 300));

      // 关闭加载对话框
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // 打开阅读页面
      if (context.mounted) {
        _openReaderPage(context, book, bookContent);
      }
    } catch (e) {
      debugPrint('❌ 加载书籍失败: $e');

      // 关闭加载对话框
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // 显示错误信息
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 打开阅读页面
  static void _openReaderPage(BuildContext context, Book book, String content) {
    final page = ReaderPage(
      bookContent: content,
      bookTitle: book.title,
      initialPageIndex: book.currentPage,
      bookId: book.id,
    );

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // 使用淡入淡出 + 缩放动画
          const begin = 0.95;
          const end = 1.0;
          final tween = Tween(begin: begin, end: end);
          final scaleAnimation = animation.drive(tween);

          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: scaleAnimation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// 加载书籍内容（支持大文件优化）
  static Future<String> _loadBookContent(Book book) async {
    debugPrint('📖 开始加载书籍：${book.title}');
    debugPrint('📖 书籍格式: ${book.format}');

    try {
      final file = File(book.filePath);
      if (!await file.exists()) {
        throw Exception('文件不存在: ${book.filePath}');
      }

      // 检查文件大小
      final fileSize = await file.length();
      final fileSizeMB = fileSize / (1024 * 1024);
      debugPrint('📊 文件大小: ${fileSizeMB.toStringAsFixed(2)} MB');

      final format = book.format.toLowerCase();
      String content;

      if (format == 'txt') {
        // TXT 文件大小检查和优化处理（使用后台加载服务）
        if (fileSizeMB > 3) {
          // 超过3MB，使用后台渐进式加载
          debugPrint('📖 大文件 (${fileSizeMB.toStringAsFixed(2)} MB)，启用后台渐进式加载');
          final loader = getContentLoader();
          final result = await loader.loadLargeFile(
            file: file,
            initialChunkMB: 2, // 首批加载2MB，更快显示
          );
          content = result.fullContent;

          // 如果有后台加载任务，添加提示
          if (result.hasRemaining) {
            content += '''

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📖 后台加载进行中...

已加载：2 MB / ${fileSizeMB.toStringAsFixed(1)} MB
剩余内容正在后台加载，您可以继续阅读
读到这里时，后面的内容将自动追加 ⏳

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
''';
          }
        } else {
          // 小文件（≤3MB）直接读取
          debugPrint('📖 小文件直接读取');
          content = await file.readAsString();
        }
        debugPrint('✅ 成功加载TXT文件，长度: ${content.length} 字符');
      } else if (format == 'epub') {
        content = await _parseEpubContent(file);
        debugPrint('✅ 成功加载EPUB文件，长度: ${content.length}');
      } else if (format == 'pdf') {
        content = await _parsePdfContent(file);
        debugPrint('✅ 成功加载PDF文件，长度: ${content.length}');
      } else if (['mobi', 'azw', 'azw3'].contains(format)) {
        content = await _parseMobiContent(file);
        debugPrint('✅ 成功加载${format.toUpperCase()}文件，长度: ${content.length}');
      } else {
        debugPrint('⚠️ 暂不支持的格式: $format');
        content = '''抱歉，暂不支持 ${book.format.toUpperCase()} 格式

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

      return content;
    } catch (e) {
      debugPrint('❌ 加载文件失败: $e');
      rethrow;
    }
  }

  /// 加载超大TXT文件（渐进式加载：先返回前N MB，后台继续加载）
  ///
  /// 策略：立即返回前N MB让用户开始阅读，同时在后台继续加载剩余内容

  /// 构建加载对话框（带文件大小提示）
  static Widget _buildLoadingDialog(Book book) {
    return FutureBuilder<int>(
      future: File(book.filePath).length(),
      builder: (context, snapshot) {
        final fileSize = snapshot.data;
        final fileSizeMB = fileSize != null ? fileSize / (1024 * 1024) : null;

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 加载动画
                const SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
                const SizedBox(height: 24),

                // 书籍标题
                Text(
                  book.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // 加载提示
                Text(
                  fileSizeMB != null && fileSizeMB > 30
                      ? '文件过大，只读取部分内容...'
                      : fileSizeMB != null && fileSizeMB > 15
                          ? '正在加载大文件，请稍候...'
                          : '正在打开书籍...',
                  style: TextStyle(
                    fontSize: 14,
                    color: fileSizeMB != null && fileSizeMB > 30
                        ? Colors.orange[700]
                        : Colors.grey[600],
                    fontWeight: fileSizeMB != null && fileSizeMB > 30
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 4),

                // 格式和大小信息
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      book.format.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (fileSizeMB != null) ...[
                      Text(
                        ' • ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                      Text(
                        '${fileSizeMB.toStringAsFixed(1)} MB',
                        style: TextStyle(
                          fontSize: 12,
                          color: fileSizeMB > 30
                              ? Colors.red[600]
                              : fileSizeMB > 15
                                  ? Colors.orange[700]
                                  : Colors.grey[500],
                          fontWeight: fileSizeMB > 15
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
    var text = html.replaceAll(
        RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true),
        '');
    text = text.replaceAll(
        RegExp(r'<script[^>]*>.*?</script>',
            caseSensitive: false, dotAll: true),
        '');

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

  /// 尝试将 MOBI 作为 PDB 格式解析（支持多种编码）
  static Future<String> _parseMobiAsPdb(List<int> bytes) async {
    try {
      // MOBI 基于 PalmDoc (PDB) 格式
      // 检查是否有 PDB 头部标识
      if (bytes.length < 78) {
        return '';
      }

      // PDB 头部：32字节名称（ASCII编码）
      final nameBytes = bytes.sublist(0, 32);
      final name = String.fromCharCodes(
        nameBytes.where((b) => b != 0 && b >= 32 && b < 127),
      ).trim();
      debugPrint('📱 MOBI 名称: $name');

      // 尝试多种编码解析内容
      String content = _decodeWithBestEncoding(bytes);

      // 查找 HTML 标签
      final htmlPattern = RegExp(r'<html[\s\S]*?</html>', caseSensitive: false);
      final match = htmlPattern.firstMatch(content);

      if (match != null) {
        final htmlContent = match.group(0)!;
        final plainText = _stripHtmlTags(htmlContent);

        if (plainText.isNotEmpty && plainText.length > 100) {
          final buffer = StringBuffer();
          if (name.isNotEmpty) {
            buffer.writeln('《$name》\n');
          }
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

  /// 使用最佳编码解码字节数组
  ///
  /// 尝试多种编码，选择最合适的
  static String _decodeWithBestEncoding(List<int> bytes) {
    // 方法1: 尝试 UTF-8 解码
    try {
      final utf8Content = utf8.decode(bytes, allowMalformed: true);
      // 检查是否包含有效的 HTML 或文本
      if (utf8Content.contains('<html') ||
          utf8Content.contains('<body') ||
          _hasValidChineseChars(utf8Content)) {
        debugPrint('✅ 使用 UTF-8 编码解码');
        return utf8Content;
      }
    } catch (e) {
      debugPrint('⚠️ UTF-8 解码失败: $e');
    }

    // 方法2: 尝试 Latin1 (CP1252) 解码
    try {
      final latin1Content = latin1.decode(bytes);
      if (latin1Content.contains('<html') || latin1Content.contains('<body')) {
        debugPrint('✅ 使用 Latin1 编码解码');
        return latin1Content;
      }
    } catch (e) {
      debugPrint('⚠️ Latin1 解码失败: $e');
    }

    // 方法3: 降级到 ASCII (只保留可打印字符)
    debugPrint('⚠️ 使用 ASCII 降级解码');
    return String.fromCharCodes(
      bytes.where((b) => b >= 32 && b < 127),
    );
  }

  /// 检查字符串中是否包含有效的中文字符
  static bool _hasValidChineseChars(String text) {
    // 检查是否包含中文字符范围 (U+4E00 到 U+9FFF)
    final chinesePattern = RegExp(r'[\u4e00-\u9fff]');
    final matches = chinesePattern.allMatches(text);
    return matches.length > 10; // 至少包含10个中文字符
  }

  /// 从 MOBI 字节流中提取原始文本（降级方案，支持多种编码）
  static String _extractRawTextFromMobi(List<int> bytes) {
    try {
      // 使用最佳编码解码
      final content = _decodeWithBestEncoding(bytes);

      // 移除二进制数据和控制字符
      final cleanText = content
          .replaceAll(RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F-\x9F]'), '')
          .replaceAll(RegExp(r'<[^>]+>'), ' ') // 移除HTML标签
          .replaceAll(RegExp(r'\s+'), ' '); // 合并多个空白

      // 查找连续的可读文本段落
      final paragraphs = <String>[];
      final lines = cleanText.split(RegExp(r'[.。!！?？\n]'));

      for (var line in lines) {
        final trimmed = line.trim();
        // 放宽条件，只要有一定长度且包含字母或中文就保留
        if (trimmed.length >= 15 &&
            (RegExp(r'[a-zA-Z\u4e00-\u9fff]').hasMatch(trimmed))) {
          paragraphs.add(trimmed);
        }
      }

      if (paragraphs.length >= 5) {
        // 至少有5段有效内容
        final buffer = StringBuffer();
        buffer.writeln('MOBI 文本内容\n');
        buffer.writeln('${'=' * 50}\n\n');

        // 只取前面的段落，避免包含太多垃圾数据
        final validParagraphs = paragraphs.take(200).toList();
        for (var para in validParagraphs) {
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
