import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';
import '../pages/enhanced_webview_reading_page.dart';
import '../pages/reading_page_enhanced.dart';

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

  /// 根据用户设置导航到适当的阅读器
  static Future<void> openBook(BuildContext context, Book book) async {
    final engine = await getDefaultEngine();
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

  /// 导航到指定的阅读引擎
  static Future<void> _navigateToEngine(
    BuildContext context,
    Book book,
    String engine,
  ) async {
    Widget page;

    switch (engine) {
      case 'native':
        page = ReadingPageEnhanced(book: book);
        break;
      case 'webview_optimized':
      case 'webview_standard':
      default:
        page = EnhancedWebViewReadingPage(book: book);
    }

    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }
}
