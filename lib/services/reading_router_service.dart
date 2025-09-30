import 'dart:io';
import 'package:flutter/material.dart';
import '../models/book.dart';
import '../pages/enhanced_webview_reading_page.dart';
import '../pages/reading_page_enhanced.dart';
import '../pages/reader_page.dart';
import '../services/reading_engine_coordinator.dart';

/// 阅读器路由服务
///
/// 通过 [ReadingEngineCoordinator] 选择并打开合适的阅读引擎页面。
class ReadingRouterService {
  /// 根据协调器策略打开书籍。
  ///
  /// [preferEngine] 可用于强制使用指定引擎，若为空则遵循策略选择。
  static Future<void> openBook(
    BuildContext context,
    Book book, {
    ReadingEngineType? preferEngine,
  }) async {
    final coordinator = ReadingEngineCoordinator();
    await coordinator.ensureInitialized();

    final engine = preferEngine ?? await coordinator.selectOptimalEngine(book);
    await _navigateToEngine(context, book, engine);
  }

  /// 导航到指定的阅读引擎
  static Future<void> _navigateToEngine(
    BuildContext context,
    Book book,
    ReadingEngineType engine,
  ) async {
    Widget page;

    switch (engine) {
      case ReadingEngineType.advanced:
        page = ReadingPageEnhanced(book: book);
        break;
      case ReadingEngineType.webView:
        page = EnhancedWebViewReadingPage(book: book);
        break;
      case ReadingEngineType.immersive:
      default:
        // 使用新的沉浸式阅读器
        String bookContent = book.cachedContent ?? '';

        // 如果缓存内容为空，尝试从文件加载
        if (bookContent.isEmpty) {
          debugPrint('📖 沉浸式阅读器：缓存内容为空，从文件加载...');
          try {
            final file = File(book.filePath);
            if (await file.exists()) {
              if (book.format.toLowerCase() == 'txt') {
                bookContent = await file.readAsString();
                debugPrint('✅ 成功加载TXT文件，长度: ${bookContent.length}');
              } else {
                debugPrint('⚠️ 非TXT格式，需要使用其他阅读器');
                bookContent = '此格式暂不支持沉浸式阅读器\n\n请选择"高级阅读器"或"WebView阅读器"';
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

        page = ReaderPage(
          bookContent: bookContent,
          bookTitle: book.title,
          initialPageIndex: book.currentPage,
        );
    }

    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }
}
