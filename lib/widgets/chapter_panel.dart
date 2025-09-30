import 'package:flutter/material.dart';
import '../models/chapter.dart';

class ChapterPanel extends StatelessWidget {
  final List<Chapter> chapters;
  final Function(Chapter) onChapterTap;

  const ChapterPanel({
    super.key,
    required this.chapters,
    required this.onChapterTap,
  });

  @override
  Widget build(BuildContext context) {
    if (chapters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无章节信息',
              style:
                  (Theme.of(context).textTheme.titleMedium ??
                          Theme.of(context).textTheme.bodyLarge ??
                          const TextStyle())
                      .copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
            ),
            const SizedBox(height: 8),
            Text(
              '正在解析书籍结构...',
              style: const TextStyle().copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    // 智能分析章节结构
    final structuredChapters = _analyzeChapterStructure(chapters);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: structuredChapters.length,
      itemBuilder: (context, index) {
        final chapterData = structuredChapters[index];
        final chapter = chapterData['chapter'] as Chapter;
        final isMainChapter = chapterData['isMainChapter'] as bool;
        final isSubChapter = chapterData['isSubChapter'] as bool;
        final chapterNumber = chapterData['chapterNumber'] as String?;

        return _buildChapterItem(
          context,
          chapter,
          index,
          isMainChapter: isMainChapter,
          isSubChapter: isSubChapter,
          chapterNumber: chapterNumber,
        );
      },
    );
  }

  // 智能分析章节结构
  List<Map<String, dynamic>> _analyzeChapterStructure(List<Chapter> chapters) {
    final List<Map<String, dynamic>> structured = [];
    int mainChapterCount = 0;

    for (int i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      bool isMainChapter = chapter.isMainChapter;
      bool isSubChapter = false;
      String? chapterNumber;

      // 智能判断主章节
      if (isMainChapter || chapter.isPossibleTableOfContents) {
        mainChapterCount++;
        chapterNumber = mainChapterCount.toString();
      } else {
        // 检查是否为子章节
        isSubChapter =
            chapter.level > 0 ||
            (i > 0 && chapters[i - 1].isMainChapter) ||
            chapter.title.contains(RegExp(r'[0-9]+\.[0-9]+'));
      }

      structured.add({
        'chapter': chapter,
        'isMainChapter': isMainChapter,
        'isSubChapter': isSubChapter,
        'chapterNumber': chapterNumber,
      });
    }

    return structured;
  }

  // 构建章节项目
  Widget _buildChapterItem(
    BuildContext context,
    Chapter chapter,
    int index, {
    bool isMainChapter = false,
    bool isSubChapter = false,
    String? chapterNumber,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 根据章节类型设置样式
    Color? backgroundColor;
    EdgeInsets padding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    );
    TextStyle? titleStyle = theme.textTheme.bodyLarge;
    TextStyle? subtitleStyle = theme.textTheme.bodySmall;
    IconData iconData = Icons.article_outlined;
    Color? iconColor = colorScheme.onSurface.withOpacity(0.6);

    if (isMainChapter) {
      backgroundColor = colorScheme.primaryContainer.withOpacity(0.3);
      titleStyle =
          (theme.textTheme.titleMedium ??
                  theme.textTheme.bodyLarge ??
                  const TextStyle())
              .copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              );
      iconData = Icons.auto_stories;
      iconColor = colorScheme.primary;
      padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
    } else if (isSubChapter) {
      padding = const EdgeInsets.only(left: 32, right: 16, top: 8, bottom: 8);
      titleStyle =
          (theme.textTheme.bodyMedium ??
                  theme.textTheme.bodyLarge ??
                  const TextStyle())
              .copyWith(color: colorScheme.onSurface.withOpacity(0.8));
      iconData = Icons.subdirectory_arrow_right;
      iconColor = colorScheme.secondary;
    }

    // 特殊章节处理
    if (chapter.isPreface) {
      iconData = Icons.notes;
      iconColor = colorScheme.tertiary;
    } else if (chapter.isEpilogue) {
      iconData = Icons.bookmark_border;
      iconColor = colorScheme.tertiary;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onChapterTap(chapter),
          child: Padding(
            padding: padding,
            child: Row(
              children: [
                // 章节图标
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    iconData,
                    size: isMainChapter ? 20 : 16,
                    color: iconColor,
                  ),
                ),

                const SizedBox(width: 12),

                // 章节内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 章节标题
                      Text(
                        chapter.title,
                        style: titleStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // 章节副标题
                      if (chapterNumber != null || chapter.level > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          chapterNumber != null
                              ? '第 $chapterNumber 章'
                              : chapter.level > 0
                              ? '层级 ${chapter.level}'
                              : '',
                          style: subtitleStyle?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // 导航箭头
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: colorScheme.onSurface.withOpacity(0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
