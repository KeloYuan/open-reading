import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/pages/reader_kernel_page.dart';
import 'package:xxread/services/books/book_storage_repair_service.dart';
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

    await _navigateToReader(context, repairedBook);
  }

  static Future<void> _navigateToReader(
    BuildContext context,
    Book book,
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

    _openReaderKernelPage(context, book);
  }

  static void _openReaderKernelPage(
    BuildContext context,
    Book book,
  ) {
    final hostBrightness = Theme.of(context).brightness;
    final page = ReaderKernelPage(book: book);

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
    ).then((_) => _restoreHostSystemUI(hostBrightness));
  }

  static void _restoreHostSystemUI(Brightness hostBrightness) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiHelper.overlayStyleForBrightness(hostBrightness),
    );
  }
}
