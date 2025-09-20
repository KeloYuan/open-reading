import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';
import '../pages/webview_reading_page.dart';
import '../pages/webview_reading_page_optimized.dart';
import '../pages/native_reading_page.dart';
import '../pages/reading_mode_comparison.dart';

/// 阅读器路由服务
/// 根据用户设置和书籍类型选择合适的阅读器
class ReadingRouterService {
  static const String _preferenceKey = 'defaultReadingEngine';

  /// 获取用户设置的默认阅读引擎
  static Future<String> getDefaultEngine() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_preferenceKey) ?? 'webview_optimized';
  }

  /// 设置默认阅读引擎
  static Future<void> setDefaultEngine(String engine) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferenceKey, engine);
  }

  /// 根据书籍和用户设置导航到适当的阅读器
  static Future<void> openBook(
    BuildContext context,
    Book book, {
    bool forceShowComparison = false,
  }) async {
    if (forceShowComparison) {
      // 强制显示阅读模式选择页面
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReadingModeComparison(book: book),
        ),
      );
      return;
    }

    final engine = await getDefaultEngine();
    final recommendedEngine = _getRecommendedEngine(book);

    // 如果推荐引擎与用户设置不同，可以显示提示
    if (recommendedEngine != engine) {
      await _showEngineRecommendation(context, book, engine, recommendedEngine);
      return;
    }

    // 直接使用用户设置的引擎
    await _navigateToEngine(context, book, engine);
  }

  /// 直接使用指定引擎打开书籍
  static Future<void> openBookWithEngine(
    BuildContext context,
    Book book,
    String engine,
  ) async {
    await _navigateToEngine(context, book, engine);
  }

  /// 根据书籍格式推荐合适的阅读引擎
  static String _getRecommendedEngine(Book book) {
    final extension = book.filePath.split('.').last.toLowerCase();

    switch (extension) {
      case 'txt':
        // TXT格式优先推荐原生阅读器
        return 'native';
      case 'epub':
      case 'pdf':
        // EPUB和PDF推荐WebView优化版
        return 'webview_optimized';
      default:
        return 'webview_optimized';
    }
  }

  /// 显示引擎推荐对话框
  static Future<void> _showEngineRecommendation(
    BuildContext context,
    Book book,
    String userEngine,
    String recommendedEngine,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.lightbulb_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text('阅读引擎建议'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '根据您打开的书籍格式，我们建议使用：',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _getEngineIcon(recommendedEngine),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getEngineName(recommendedEngine),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _getEngineDescription(recommendedEngine),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '您当前的默认设置是：${_getEngineName(userEngine)}',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, userEngine),
            child: const Text('使用我的设置'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'comparison'),
            child: const Text('查看所有选项'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, recommendedEngine),
            child: const Text('使用推荐引擎'),
          ),
        ],
      ),
    );

    if (result == null) return;

    if (result == 'comparison') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReadingModeComparison(book: book),
        ),
      );
    } else {
      await _navigateToEngine(context, book, result);
    }
  }

  /// 导航到指定的阅读引擎
  static Future<void> _navigateToEngine(
    BuildContext context,
    Book book,
    String engine,
  ) async {
    Widget page;

    switch (engine) {
      case 'native':
        page = NativeReadingPage(book: book);
        break;
      case 'webview_optimized':
        page = WebViewReadingPageOptimized(book: book);
        break;
      case 'webview_standard':
        page = WebViewReadingPage(book: book);
        break;
      default:
        page = WebViewReadingPageOptimized(book: book);
    }

    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  /// 获取引擎名称
  static String _getEngineName(String engine) {
    switch (engine) {
      case 'native':
        return 'Flutter原生阅读器';
      case 'webview_optimized':
        return 'WebView优化版';
      case 'webview_standard':
        return 'WebView标准版';
      default:
        return 'WebView优化版';
    }
  }

  /// 获取引擎图标
  static IconData _getEngineIcon(String engine) {
    switch (engine) {
      case 'native':
        return Icons.speed;
      case 'webview_optimized':
        return Icons.auto_fix_high;
      case 'webview_standard':
        return Icons.web;
      default:
        return Icons.auto_fix_high;
    }
  }

  /// 获取引擎描述
  static String _getEngineDescription(String engine) {
    switch (engine) {
      case 'native':
        return '最佳性能，支持TXT格式';
      case 'webview_optimized':
        return '性能优化，功能完整';
      case 'webview_standard':
        return '功能最完整，稳定可靠';
      default:
        return '性能优化，功能完整';
    }
  }

  /// 检查引擎是否支持指定格式
  static bool _isEngineCompatible(String engine, String fileExtension) {
    switch (engine) {
      case 'native':
        // 原生阅读器主要支持TXT
        return ['txt', 'text'].contains(fileExtension.toLowerCase());
      case 'webview_optimized':
      case 'webview_standard':
        // WebView支持所有格式
        return true;
      default:
        return true;
    }
  }

  /// 获取格式支持的引擎列表
  static List<String> getSupportedEngines(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    final List<String> supportedEngines = [];

    const allEngines = ['native', 'webview_optimized', 'webview_standard'];

    for (final engine in allEngines) {
      if (_isEngineCompatible(engine, extension)) {
        supportedEngines.add(engine);
      }
    }

    return supportedEngines;
  }
}
