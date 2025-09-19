import 'package:flutter/material.dart';

import '../models/book.dart';
import 'webview_reading_page.dart';

/// WebView阅读引导页面
/// 直接启动WebView阅读引擎
class ReadingModeSelector extends StatefulWidget {
  final Book book;
  final int? initialChapterIndex;
  final double? initialProgress;

  const ReadingModeSelector({
    super.key,
    required this.book,
    this.initialChapterIndex,
    this.initialProgress,
  });

  @override
  State<ReadingModeSelector> createState() => _ReadingModeSelectorState();
}

class _ReadingModeSelectorState extends State<ReadingModeSelector> {
  @override
  void initState() {
    super.initState();
    // 直接启动WebView阅读模式
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startWebViewReading();
    });
  }

  void _startWebViewReading() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewReadingPage(
          book: widget.book,
          initialChapterIndex: widget.initialChapterIndex,
          initialProgress: widget.initialProgress,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '正在启动WebView阅读器...',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.book.title,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
