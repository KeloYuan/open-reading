import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:epubx/epubx.dart';
import 'package:pdfx/pdfx.dart';
import 'package:path/path.dart' as path;
import '../models/book.dart';
import '../pages/reader_page.dart';
import 'book_dao.dart';
import 'enhanced_txt_import_service.dart';
import 'text_preprocessor.dart'; // 🔧 导入文本预处理器
import 'epub_image_extractor.dart';
import 'book_image_map_service.dart';
import '../widgets/side_toast.dart';
// import 'debug_image_files.dart'; // 已删除

class TxtDecodeRequest {
  final Uint8List bytes;
  final String? encodingOverride;

  TxtDecodeRequest({
    required this.bytes,
    this.encodingOverride,
  });
}

String decodeAndPreprocessTxtInIsolate(TxtDecodeRequest request) {
  final txtService = EnhancedTxtImportService();
  String content = txtService.decodeWithOverride(
    request.bytes,
    encodingOverride: request.encodingOverride,
  );
  final normalized = EnhancedTxtImportService.normalizeEncoding(
    request.encodingOverride,
  );
  if (normalized == 'auto' && _looksGarbled(content)) {
    for (final candidate in ['gbk', 'utf16le', 'utf16be']) {
      final fallback = txtService.decodeWithOverride(
        request.bytes,
        encodingOverride: candidate,
      );
      if (!_looksGarbled(fallback)) {
        content = fallback;
        break;
      }
    }
  }

  final preprocessor = TextPreprocessor();
  content = preprocessor.process(
    content,
    indentSize: 2,
    indentDialogue: true,
    compressEmptyLines: true,
    paragraphSpacing: 0,
  );

  return content;
}

bool _looksGarbled(String text) {
  final value = text.trim();
  if (value.isEmpty) {
    return true;
  }

  int total = 0;
  int cjk = 0;
  int asciiLetters = 0;
  int digits = 0;
  int latinExtended = 0;
  int otherNonAscii = 0;
  int replacement = 0;

  for (final rune in value.runes) {
    if (rune <= 0x20) {
      continue;
    }
    total++;
    if (rune == 0xfffd) {
      replacement++;
      continue;
    }
    if ((rune >= 0x4e00 && rune <= 0x9fff) ||
        (rune >= 0x3400 && rune <= 0x4dbf) ||
        (rune >= 0xf900 && rune <= 0xfaff)) {
      cjk++;
      continue;
    }
    if ((rune >= 0x41 && rune <= 0x5a) ||
        (rune >= 0x61 && rune <= 0x7a)) {
      asciiLetters++;
      continue;
    }
    if (rune >= 0x30 && rune <= 0x39) {
      digits++;
      continue;
    }
    if (rune >= 0x00c0 && rune <= 0x024f) {
      latinExtended++;
      continue;
    }
    if (rune > 0x7e) {
      otherNonAscii++;
    }
  }

  if (total == 0 || replacement > 0) {
    return true;
  }

  final asciiRatio = (asciiLetters + digits) / total;
  final cjkRatio = cjk / total;
  final nonAsciiRatio = (latinExtended + otherNonAscii) / total;

  if (cjkRatio >= 0.2) {
    return false;
  }
  if (asciiRatio >= 0.6) {
    return false;
  }
  return nonAsciiRatio >= 0.3;
}

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

  /// 导航到沉浸式阅读器（带流畅加载动画）
  static Future<void> _navigateToReader(
    BuildContext context,
    Book book,
  ) async {
    String? bookContent = book.cachedContent;

    // 调试：检查缓存内容
    if (bookContent != null && bookContent.isNotEmpty) {
      final lengthMB = bookContent.length / (1024 * 1024);
      debugPrint('📖 检测到缓存内容: ${lengthMB.toStringAsFixed(2)} MB');
      debugPrint('   字符数: ${bookContent.length}');
      // ⚠️ 强制禁用缓存，始终从文件重新加载
      debugPrint('   ⚠️ 为确保加载完整内容，忽略缓存，从文件重新加载');
      bookContent = null;
    }

    // 如果有缓存内容，直接打开
    if (bookContent != null && bookContent.isNotEmpty) {
      debugPrint('📖 使用缓存内容打开书籍');
      _openReaderPage(context, book, bookContent);
      return;
    }

    final format = book.format.toLowerCase();
    if (format == 'txt') {
      var previewContent = await _loadTxtPreviewContent(
        book,
        maxBytes: 128 * 1024,
      );
      if (previewContent.trim().isEmpty) {
        previewContent = '正在加载全书...';
      }
      _openReaderPage(
        context,
        book,
        previewContent,
        fullContentLoader: () => _loadFullTxtContent(book),
      );
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
    await Future.delayed(const Duration(milliseconds: 16));

    try {
      // 在后台异步加载书籍内容（一次性全部加载）
      bookContent = await _loadBookContent(book, book.id ?? 0);

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
        showSideToast(context, '加载失败: $e');
      }
    }
  }

  /// 打开阅读页面
  static void _openReaderPage(
    BuildContext context,
    Book book,
    String content, {
    Future<String> Function()? fullContentLoader,
  }) {
    final page = ReaderPage(
      bookContent: content,
      bookTitle: book.title,
      initialPageIndex: book.currentPage,
      bookId: book.id,
      fullContentLoader: fullContentLoader,
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
  static Future<String> _loadBookContent(Book book, int bookId) async {
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

      String content;

      final format = book.format.toLowerCase();
      if (format == 'txt') {
        content = await _loadFullTxtContent(book);
      } else if (format == 'epub') {
        content = await _parseEpubContent(file, bookId);
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

  static Future<String> _loadFullTxtContent(Book book) async {
    final file = File(book.filePath);
    final fileSize = await file.length();
    final fileSizeMB = fileSize / (1024 * 1024);
    debugPrint('📖 一次性加载TXT文件 (${fileSizeMB.toStringAsFixed(2)} MB)');

    final bytes = await file.readAsBytes();
    final txtService = EnhancedTxtImportService();
    final normalized = EnhancedTxtImportService.normalizeEncoding(
      book.textEncoding,
    );
    final isAuto = normalized == 'auto';
    final detectedEncoding = txtService.detectEncoding(
      bytes,
      encodingOverride: book.textEncoding,
    );
    if (bytes.length > 512 * 1024) {
      debugPrint('🧵 大文本解码与预处理改为isolate执行');
      if (isAuto) {
        await _persistTxtEncoding(book, detectedEncoding);
      }
      return await compute(
        decodeAndPreprocessTxtInIsolate,
        TxtDecodeRequest(
          bytes: bytes,
          encodingOverride: detectedEncoding,
        ),
      );
    }

    final decodeResult = txtService.decodeWithResult(
      bytes,
      encodingOverride: book.textEncoding,
    );
    String content = decodeResult.content;
    String resolvedEncoding = isAuto ? decodeResult.encoding : normalized;
    if (isAuto && _looksGarbled(content)) {
      for (final candidate in ['gbk', 'utf16le', 'utf16be']) {
        final fallback = txtService.decodeWithOverride(
          bytes,
          encodingOverride: candidate,
        );
        if (!_looksGarbled(fallback)) {
          content = fallback;
          resolvedEncoding = candidate;
          break;
        }
      }
    }
    if (isAuto) {
      await _persistTxtEncoding(book, resolvedEncoding);
    }
    final preprocessor = TextPreprocessor();
    content = preprocessor.process(
      content,
      indentSize: 2,
      indentDialogue: true,
      compressEmptyLines: true,
      paragraphSpacing: 0,
    );
    debugPrint('✅ 成功加载TXT文件，长度: ${content.length} 字符');
    return content;
  }

  static Future<String> _loadTxtPreviewContent(
    Book book, {
    int maxBytes = 128 * 1024,
  }) async {
    try {
      final file = File(book.filePath);
      if (!await file.exists()) {
        return '';
      }

      final builder = BytesBuilder();
      await for (final chunk in file.openRead(0, maxBytes)) {
        builder.add(chunk);
      }
      var bytes = builder.takeBytes();
      if (bytes.isEmpty) return '';

      final txtService = EnhancedTxtImportService();
      final normalized = EnhancedTxtImportService.normalizeEncoding(
        book.textEncoding,
      );
      final isAuto = normalized == 'auto';
      final effectiveEncoding = isAuto
          ? txtService.detectEncoding(
              bytes,
              encodingOverride: book.textEncoding,
            )
          : normalized;

      bytes = _trimBytesForEncoding(bytes, effectiveEncoding);
      if (bytes.isEmpty) return '';

      var content = txtService.decodeWithOverride(
        bytes,
        encodingOverride: effectiveEncoding,
      );
      if (isAuto && _looksGarbled(content)) {
        for (final candidate in ['gbk', 'utf16le', 'utf16be']) {
          final fallback = txtService.decodeWithOverride(
            bytes,
            encodingOverride: candidate,
          );
          if (!_looksGarbled(fallback)) {
            content = fallback;
            break;
          }
        }
      }
      return content;
    } catch (e) {
      debugPrint('❌ TXT预览加载失败: $e');
      return '';
    }
  }

  static Uint8List _trimBytesForEncoding(
    Uint8List bytes,
    String? encodingOverride,
  ) {
    final normalized = EnhancedTxtImportService.normalizeEncoding(
      encodingOverride,
    );
    if ((normalized == 'utf16le' || normalized == 'utf16be') &&
        bytes.length.isOdd) {
      return bytes.sublist(0, bytes.length - 1);
    }
    return bytes;
  }

  static Future<void> _persistTxtEncoding(
    Book book,
    String encoding,
  ) async {
    if (book.id == null) {
      return;
    }
    final normalized = EnhancedTxtImportService.normalizeEncoding(encoding);
    if (normalized == 'auto') {
      return;
    }
    final current = EnhancedTxtImportService.normalizeEncoding(
      book.textEncoding,
    );
    if (current == normalized) {
      return;
    }
    try {
      await BookDao().updateBookTextEncoding(book.id!, normalized);
      debugPrint('✅ 更新TXT编码: ${book.title} -> $normalized');
    } catch (e) {
      debugPrint('❌ 更新TXT编码失败: $e');
    }
  }

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
                  fileSizeMB != null && fileSizeMB > 50
                      ? '正在加载大文件，请耐心等待...'
                      : fileSizeMB != null && fileSizeMB > 30
                          ? '正在加载大文件，请稍候...'
                          : fileSizeMB != null && fileSizeMB > 15
                              ? '正在加载，请稍候...'
                              : '正在打开书籍...',
                  style: TextStyle(
                    fontSize: 14,
                    color: fileSizeMB != null && fileSizeMB > 50
                        ? Colors.orange[800]
                        : fileSizeMB != null && fileSizeMB > 30
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
  static Future<String> _parseEpubContent(File file, int bookId) async {
    try {
      // 读取 EPUB 文件
      final bytes = await file.readAsBytes();
      final epubBook = await EpubReader.readBook(bytes);

      debugPrint('📚 EPUB 书籍信息:');
      debugPrint('   标题: ${epubBook.Title}');
      debugPrint('   作者: ${epubBook.Author}');
      debugPrint('   章节数: ${epubBook.Chapters?.length ?? 0}');

      // 🖼️ 加载或提取图片映射
      final imageMapService = BookImageMapService();
      final bookIdStr = bookId.toString();
      Map<String, String> imagePathMap = {};

      try {
        // 先尝试从数据库加载
        debugPrint('🖼️ 尝试从数据库加载图片映射...');
        debugPrint('   BookId: $bookId, BookIdStr: $bookIdStr');
        imagePathMap = await imageMapService.loadImageMap(bookId);

        if (imagePathMap.isNotEmpty) {
          debugPrint('✅ 从数据库加载图片映射: ${imagePathMap.length} 张');
        } else {
          // 如果数据库没有，重新提取并保存
          debugPrint('🖼️ 数据库无映射，开始提取EPUB图片...');
          final imageExtractor = EpubImageExtractor();
          imagePathMap = await imageExtractor.extractImagesFromEpubBook(
            epubBook,
            bookIdStr,
          );

          if (imagePathMap.isNotEmpty) {
            debugPrint('✅ 图片提取完成: ${imagePathMap.length} 张');
            // 保存到数据库
            await imageMapService.saveImageMap(bookId, imagePathMap);
            debugPrint('✅ 图片映射已保存到数据库');
          } else {
            debugPrint('⚠️ 未提取到任何图片');
          }
        }

        // 调试：打印所有映射
        debugPrint('📊 图片映射详情 (共${imagePathMap.length}张):');
        for (var entry in imagePathMap.entries) {
          debugPrint('   ${entry.key} -> ${entry.value}');
        }

        // 🔍 调试功能已删除
        // debugPrint('🔍 开始检查实际图片文件...');
        // await DebugImageFiles.listAllImageFiles();
        // if (imagePathMap.isNotEmpty) {
        //   final firstImage = imagePathMap.values.first;
        //   await DebugImageFiles.checkImageFileExists(firstImage);
        // }
      } catch (e, stackTrace) {
        debugPrint('⚠️ 图片处理失败: $e');
        debugPrint('   堆栈: $stackTrace');
      }

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
          await _extractChapterContent(
              chapter, buffer, 0, imagePathMap, bookIdStr);
        }
      } else {
        // 如果没有章节结构，尝试直接读取 HTML 内容
        debugPrint('⚠️ 未找到章节结构，尝试读取原始内容');
        if (epubBook.Content?.Html != null) {
          for (var htmlFile in epubBook.Content!.Html!.values) {
            final htmlContent = htmlFile.Content ?? '';
            final plainText =
                _stripHtmlTags(htmlContent, imagePathMap, bookIdStr);
            if (plainText.trim().isNotEmpty) {
              buffer.writeln(plainText);
              buffer.writeln('\n');
            }
          }
        }
      }

      var content = buffer.toString();

      // 🖼️ 最后再做一次全局路径替换（以防有遗漏）
      if (imagePathMap.isNotEmpty) {
        content = _replaceImagePaths(content, imagePathMap, bookIdStr);
      }

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
    Map<String, String> imagePathMap,
    String bookId,
  ) async {
    // 添加章节标题
    if (chapter.Title?.isNotEmpty == true) {
      final indent = '  ' * level;
      buffer.writeln('$indent${chapter.Title}\n');
    }

    // 提取章节 HTML 内容并转换为纯文本
    if (chapter.HtmlContent?.isNotEmpty == true) {
      final plainText =
          _stripHtmlTags(chapter.HtmlContent!, imagePathMap, bookId);
      if (plainText.trim().isNotEmpty) {
        buffer.writeln(plainText);
        buffer.writeln('\n');
      }
    }

    // 递归处理子章节
    if (chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty) {
      for (var subChapter in chapter.SubChapters!) {
        await _extractChapterContent(
            subChapter, buffer, level + 1, imagePathMap, bookId);
      }
    }
  }

  /// 替换图片路径为缓存路径
  static String _replaceImagePaths(
    String content,
    Map<String, String> imagePathMap,
    String bookId,
  ) {
    if (imagePathMap.isEmpty) return content;

    return content.replaceAllMapped(
      RegExp(r'''<img src=["']([^"']+)["']/?>''', caseSensitive: false),
      (match) {
        final originalSrc = match.group(1);
        if (originalSrc == null) return match.group(0)!;

        // 提取文件名
        final fileName = path.basename(Uri.decodeFull(originalSrc));
        final imageKey = '${bookId}_$fileName';

        // 查找对应的缓存路径
        if (imagePathMap.containsKey(imageKey)) {
          final cachePath = imagePathMap[imageKey]!;
          return '<img src="$cachePath"/>';
        }

        // 如果没找到，保持原样
        return match.group(0)!;
      },
    );
  }

  /// 移除 HTML 标签，保留纯文本和图片标签
  static String _stripHtmlTags(
    String html, [
    Map<String, String>? imagePathMap,
    String? bookId,
  ]) {
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

    // 🖼️ 保留图片标签（用于图片混排支持）
    // 将图片标签规范化为统一格式：<img src="path"/>
    text = text.replaceAllMapped(
      RegExp(r'''<img[^>]+src=["']([^"']+)["'][^>]*>''', caseSensitive: false),
      (match) {
        final src = match.group(1);
        if (src != null && src.isNotEmpty) {
          // 规范化为统一格式，方便分页器解析
          return '<img src="$src"/>';
        }
        return ''; // 无效的图片标签，删除
      },
    );

    // 移除所有其他 HTML 标签（但保留 img 标签）
    text = text.replaceAllMapped(
      RegExp(r'<(?!img\s)([^>]+)>'),
      (match) => '',
    );

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
