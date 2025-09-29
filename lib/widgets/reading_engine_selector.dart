import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/reading_router_service.dart';
import '../services/reading_engine_coordinator.dart';

/// 阅读引擎选择器
///
/// 提供用户选择不同阅读引擎的界面
class ReadingEngineSelector extends StatelessWidget {
  final Book book;

  const ReadingEngineSelector({
    Key? key,
    required this.book,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '选择阅读模式',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),

            // 沉浸式阅读器（新）
            _buildEngineOption(
              context,
              icon: Icons.auto_stories,
              title: '沉浸式阅读器',
              subtitle: '全新体验，90%屏幕利用率，三种翻页模式，TTS朗读',
              isRecommended: true,
              onTap: () =>
                  _openWithEngine(context, ReadingEngineType.immersive),
            ),

            const SizedBox(height: 12),

            // 高级阅读器
            _buildEngineOption(
              context,
              icon: Icons.book,
              title: '高级阅读器',
              subtitle: '精确分页，高性能渲染，适合长篇阅读',
              onTap: () => _openWithEngine(context, ReadingEngineType.advanced),
            ),

            const SizedBox(height: 12),

            // WebView阅读器
            _buildEngineOption(
              context,
              icon: Icons.web,
              title: 'WebView阅读器',
              subtitle: '基于anx-reader，适合复杂排版的书籍',
              onTap: () => _openWithEngine(context, ReadingEngineType.webView),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isRecommended = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isRecommended
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                : Theme.of(context).dividerColor,
            width: isRecommended ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isRecommended
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isRecommended
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isRecommended
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isRecommended
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '推荐',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  void _openWithEngine(BuildContext context, ReadingEngineType engine) {
    Navigator.of(context).pop(); // 关闭选择器
    ReadingRouterService.openBook(context, book, preferEngine: engine);
  }
}

/// 显示阅读引擎选择对话框
void showReadingEngineSelector(BuildContext context, Book book) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: ReadingEngineSelector(book: book),
    ),
  );
}

