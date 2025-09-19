import 'package:flutter/material.dart';

import '../models/book.dart';
import '../pages/reading_mode_selector.dart';

/// 使用示例：如何集成新的WebView阅读器
///
/// 这个示例展示了如何在你的应用中使用新的阅读模式选择器
class UsageExample extends StatelessWidget {
  const UsageExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WebView阅读器集成示例')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 示例说明
            _buildInstructions(),

            const SizedBox(height: 24),

            // 示例按钮
            _buildExampleButtons(context),

            const SizedBox(height: 24),

            // 功能特色
            _buildFeatures(),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎉 WebView阅读器已集成完成！',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '你现在拥有了基于anx-reader技术的专业阅读体验，'
            '同时完全保留了你原有的UI风格和主题系统。',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '点击下面的按钮体验不同的阅读模式：',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),

        // WebView模式示例
        ElevatedButton.icon(
          onPressed: () => _openWithWebView(context),
          icon: const Icon(Icons.web),
          label: const Text('直接使用WebView模式'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),

        const SizedBox(height: 12),

        // 原生模式示例
        ElevatedButton.icon(
          onPressed: () => _openWithNative(context),
          icon: const Icon(Icons.view_timeline),
          label: const Text('使用原生分页模式'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),

        const SizedBox(height: 12),

        // 让用户选择
        ElevatedButton.icon(
          onPressed: () => _openWithSelector(context),
          icon: const Icon(Icons.settings),
          label: const Text('让用户选择模式（推荐）'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatures() {
    const features = [
      {
        'icon': Icons.speed,
        'title': '完全保留原有UI',
        'description': '你的主题、动画、控制栏都保持不变',
      },
      {
        'icon': Icons.auto_stories,
        'title': 'anx-reader技术',
        'description': '精确分页、高亮笔记、复杂排版支持',
      },
      {
        'icon': Icons.animation,
        'title': '开书动画',
        'description': '优雅的书籍打开动画和翻页效果',
      },
      {
        'icon': Icons.highlight_alt,
        'title': '高亮笔记',
        'description': '选择文本即可添加高亮和笔记',
      },
      {
        'icon': Icons.web,
        'title': 'foliate-js引擎',
        'description': '专业的JavaScript电子书渲染引擎',
      },
      {
        'icon': Icons.battery_saver,
        'title': '阅读信息',
        'description': '时间、电池、进度信息覆盖显示',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🚀 新功能特色：',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        ...features.map(
          (feature) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    feature['icon'] as IconData,
                    color: Colors.grey.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature['title'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        feature['description'] as String,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 使用示例方法

  void _openWithWebView(BuildContext context) {
    // 创建示例书籍
    final book = _createExampleBook();

    // 直接跳转到WebView阅读页面
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ReadingModeSelector(book: book)),
    );
  }

  void _openWithNative(BuildContext context) {
    // 跳转到原生分页阅读页面
    // 注意：这里需要导入你原有的AdvancedReadingPage
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('原生模式示例 - 请在实际项目中替换为你的AdvancedReadingPage')),
    );
  }

  void _openWithSelector(BuildContext context) {
    // 创建示例书籍
    final book = _createExampleBook();

    // 跳转到模式选择器（推荐方式）
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReadingModeSelector(
          book: book,
          initialChapterIndex: 0,
          initialProgress: 0.0,
        ),
      ),
    );
  }

  Book _createExampleBook() {
    return Book(
      id: 1,
      title: '小元读书 - WebView集成示例',
      author: 'Claude AI',
      filePath: '/path/to/example.epub', // 实际使用时需要真实的书籍文件路径
      format: 'epub', // 添加必需的format字段
      // 添加其他必要的书籍属性...
    );
  }
}

/// 如何在你的主应用中集成：
/// 
/// 1. 在你的书籍列表页面或书籍详情页面中：
/// ```dart
/// // 当用户点击"开始阅读"时
/// onTap: () {
///   Navigator.push(
///     context,
///     MaterialPageRoute(
///       builder: (context) => ReadingModeSelector(
///         book: book,
///         initialChapterIndex: 0,
///         initialProgress: book.readingProgress,
///       ),
///     ),
///   );
/// }
/// ```
/// 
/// 2. 如果你想直接使用WebView模式：
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => WebViewReadingPage(
///       book: book,
///       initialChapterIndex: 0,
///       initialProgress: book.readingProgress,
///     ),
///   ),
/// );
/// ```
/// 
/// 3. 如果你想继续使用原有的分页系统：
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => AdvancedReadingPage(
///       book: book,
///       initialChapterIndex: 0,
///       initialProgress: book.readingProgress,
///     ),
///   ),
/// );
/// ```
