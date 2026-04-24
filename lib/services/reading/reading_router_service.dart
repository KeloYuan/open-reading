// 文件说明：阅读路由服务，按书籍格式打开当前主阅读页面。
// 技术要点：服务层、文件系统、Flutter。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/pages/foliate_reader_page.dart';
import 'package:xxread/services/books/book_dao.dart';
import 'package:xxread/services/books/book_storage_repair_service.dart';
import 'package:xxread/services/core/app_state_service.dart';
import 'package:xxread/services/library/library_event_bus_service.dart';
import 'package:xxread/services/reading/web_reader_source_service.dart';
import 'package:xxread/utils/system_ui_helper.dart';
import 'package:xxread/widgets/side_toast.dart';

/// 阅读器路由服务（统一走 WebView 阅读线路）
class ReadingRouterService {
  static const Set<String> _supportedFormats = <String>{
    'txt',
    'epub',
    'mobi',
    'azw',
    'azw3',
    'fb2',
    'rtf',
    'docx',
    'pdf',
  };

  /// 打开书籍（使用阅读内核页面）
  static Future<void> openBook(BuildContext context, Book book) async {
    final repairedBook =
        await BookStorageRepairService().repairSingleBookIfNeeded(book);

    final file = File(repairedBook.filePath);
    if (!await file.exists()) {
      if (context.mounted) {
        showSideToast(context, '书籍文件不存在，可能已被移动或删除。请重新导入或从 WebDAV 恢复。');
      }
      debugPrint('❌ 打开失败，书籍文件不存在: ${repairedBook.filePath}');
      return;
    }

    if (!context.mounted) {
      return;
    }

    await _navigateToReader(context, repairedBook);
  }

  static Future<void> _navigateToReader(BuildContext context, Book book) async {
    final format = book.format.toLowerCase();
    if (!_supportedFormats.contains(format)) {
      if (context.mounted) {
        showSideToast(
          context,
          '暂不支持 ${book.format.toUpperCase()}，当前支持 TXT / EPUB / MOBI / AZW / AZW3 / FB2 / RTF / DOCX / PDF。',
        );
      }
      return;
    }

    if (!context.mounted) {
      return;
    }
    await _openFoliateReaderPage(context, book);
  }

  static Future<void> _openFoliateReaderPage(
    BuildContext context,
    Book book,
  ) async {
    final hostBrightness = Theme.of(context).brightness;
    WebReaderSource source;
    try {
      source = await WebReaderSourceService().resolve(book);
    } catch (e) {
      debugPrint('❌ WebView 阅读资源准备失败: $e');
      if (context.mounted) {
        showSideToast(
          context,
          'WebView 阅读资源准备失败：$e',
          icon: Icons.error_outline_rounded,
        );
      }
      return;
    }

    final page = FoliateReaderPage(
      book: book,
      sourceFilePath: source.filePath,
    );

    await _recordRecentReading(book);
    if (!context.mounted) return;

    await Navigator.push(
      context,
      _buildReaderOpenRoute(page: page),
    );

    _restoreHostSystemUI(hostBrightness);
    await _recordRecentReadingFromDatabase(book.id);
    LibraryEventBus().notifyLibraryChanged();
  }

  static Route<void> _buildReaderOpenRoute({required Widget page}) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final scale = Tween<double>(begin: 0.985, end: 1.0).animate(curve);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: scale,
            child: child,
          ),
        );
      },
    );
  }

  static void _restoreHostSystemUI(Brightness hostBrightness) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiHelper.overlayStyleForBrightness(hostBrightness),
    );
  }

  static Future<void> _recordRecentReading(Book book) async {
    final bookId = book.id;
    if (bookId == null) return;
    try {
      final appState = AppStateService();
      if (!appState.isInitialized) {
        await appState.initialize();
      }
      await appState.setCurrentBook(bookId, book.title, book.currentPage);
    } catch (e) {
      debugPrint('⚠️ 更新最近阅读失败: $e');
    }
  }

  static Future<void> _recordRecentReadingFromDatabase(int? bookId) async {
    if (bookId == null) return;
    try {
      final latest = await BookDao().getBookById(bookId);
      if (latest == null) return;
      final appState = AppStateService();
      if (!appState.isInitialized) {
        await appState.initialize();
      }
      await appState.setCurrentBook(bookId, latest.title, latest.currentPage);
    } catch (e) {
      debugPrint('⚠️ 回写最近阅读失败: $e');
    }
  }
}
