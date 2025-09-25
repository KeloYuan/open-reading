import 'package:flutter/material.dart';
import '../models/book.dart';
import '../pages/enhanced_webview_reading_page.dart';
import '../pages/reading_page_enhanced.dart';
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
      default:
        page = EnhancedWebViewReadingPage(book: book);
    }

    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }
}
