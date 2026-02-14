import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/pages/reader_kernel_page.dart';
import 'package:xxread/services/books/book_dao.dart';
import 'package:xxread/services/books/book_storage_repair_service.dart';
import 'package:xxread/services/core/app_state_service.dart';
import 'package:xxread/services/library/library_event_bus_service.dart';
import 'package:xxread/utils/system_ui_helper.dart';
import 'package:xxread/widgets/side_toast.dart';

/// 阅读器路由服务（仅保留阅读内核入口）
class ReadingRouterService {
  static const Set<String> _supportedFormats = <String>{
    'txt',
    'epub',
    'mobi',
    'azw',
    'azw3',
  };

  /// 打开书籍（使用阅读内核页面）
  static Future<void> openBook(
    BuildContext context,
    Book book,
    {Rect? sourceRect}
  ) async {
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

    await _navigateToReader(
      context,
      repairedBook,
      sourceRect: sourceRect,
    );
  }

  static Future<void> _navigateToReader(
    BuildContext context,
    Book book,
    {Rect? sourceRect}
  ) async {
    final format = book.format.toLowerCase();
    if (!_supportedFormats.contains(format)) {
      if (context.mounted) {
        showSideToast(
          context,
          '暂不支持 ${book.format.toUpperCase()}，当前支持 TXT / EPUB / MOBI / AZW3。',
        );
      }
      return;
    }

    await _openReaderKernelPage(
      context,
      book,
      sourceRect: sourceRect,
    );
  }

  static Future<void> _openReaderKernelPage(
    BuildContext context,
    Book book,
    {Rect? sourceRect}
  ) async {
    final hostBrightness = Theme.of(context).brightness;
    final page = ReaderKernelPage(book: book);
    await _recordRecentReading(book);
    if (!context.mounted) return;

    await Navigator.push(
      context,
      sourceRect == null
          ? PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => page,
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
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
            )
          : _CardExpandPageRoute(
              page: page,
              sourceRect: sourceRect,
            ),
    );

    _restoreHostSystemUI(hostBrightness);
    await _recordRecentReadingFromDatabase(book.id);
    LibraryEventBus().notifyLibraryChanged();
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

class _CardExpandPageRoute<T> extends PageRouteBuilder<T> {
  _CardExpandPageRoute({
    required Widget page,
    required Rect sourceRect,
  }) : super(
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            final fade = CurvedAnimation(
              parent: animation,
              curve: const Interval(0.08, 1.0, curve: Curves.easeOut),
              reverseCurve: Curves.easeIn,
            );
            final targetRect = Offset.zero & MediaQuery.of(context).size;

            return AnimatedBuilder(
              animation: curved,
              child: child,
              builder: (context, routeChild) {
                final t = curved.value;
                final currentRect = Rect.lerp(sourceRect, targetRect, t)!;
                final radius = BorderRadius.lerp(
                  BorderRadius.circular(20),
                  BorderRadius.zero,
                  t,
                )!;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fromRect(
                      rect: currentRect,
                      child: Opacity(
                        opacity: 0.88 + (0.12 * fade.value),
                        child: ClipRRect(
                          borderRadius: radius,
                          child: routeChild!,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
}
