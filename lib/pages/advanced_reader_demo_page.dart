import 'dart:async';
import 'package:flutter/material.dart';

import '../services/flutter_advanced_paginator.dart';
import '../widgets/flutter_advanced_reader_widget.dart';

/// 高级阅读器演示页面
/// 展示基于anx-reader原理的精确分页效果
class AdvancedReaderDemoPage extends StatefulWidget {
  const AdvancedReaderDemoPage({super.key});

  @override
  State<AdvancedReaderDemoPage> createState() => _AdvancedReaderDemoPageState();
}

class _AdvancedReaderDemoPageState extends State<AdvancedReaderDemoPage>
    with TickerProviderStateMixin {
  // --- 核心控制器 ---
  final FlutterAdvancedReaderController _readerController =
      FlutterAdvancedReaderController();

  // --- 阅读设置 ---
  late ReadingTheme _currentTheme;
  double _fontSize = 16.0;
  double _lineHeight = 1.6;
  final double _letterSpacing = 0.0;
  final String _fontFamily = 'System';

  // --- UI状态 ---
  bool _showControlBar = false;
  bool _showSettings = false;
  bool _showSearch = false;
  bool _showInfo = false;

  // --- 阅读数据 ---
  ReadingInfo? _currentReadingInfo;
  List<TextSearchResult> _searchResults = [];
  int _currentSearchIndex = -1;

  // --- 控制器和动画 ---
  late AnimationController _controlBarAnimationController;
  late Animation<double> _controlBarAnimation;
  final TextEditingController _searchController = TextEditingController();
  Timer? _hideControlBarTimer;

  // --- 演示文本 ---
  static const String _demoText = '''
第一章 高级分页器的原理

在现代电子书阅读器的开发中，文本分页是一个至关重要的技术挑战。传统的简单分页方法往往会导致文字被截断、排版不美观等问题。本章将深入探讨基于anx-reader原理的高级分页技术。

anx-reader采用了一种创新的分页算法，该算法结合了以下几个核心技术：

1. 基于DOM Range的精确文本定位
2. 二分查找算法优化断点选择
3. 智能的文本边界检测
4. 多层次的位置记录系统

首先，让我们了解DOM Range技术。DOM Range是浏览器提供的一个强大API，它可以精确地选择文档中的任意文本片段。通过使用Range，我们可以准确知道每个字符在页面中的确切位置，从而实现像素级的精确分页。

二分查找算法在这里发挥了关键作用。当我们需要确定一页能容纳多少文本时，我们不能简单地按字符数截断，而是需要找到最佳的断点。二分查找帮助我们快速找到既不会溢出页面，又能最大化利用空间的断点位置。

第二章 智能断点检测

在实际的分页过程中，简单地在任意位置断开文本会导致阅读体验的严重下降。想象一下，如果一个单词被从中间截断，或者一个句子被不合理地分割，读者的阅读流畅性将受到很大影响。

因此，高级分页器实现了智能的断点检测机制。该机制按照以下优先级寻找最佳断点：

第一优先级：段落分隔符
段落之间的分隔是最自然的断点。当我们检测到连续的换行符时，这通常表示一个段落的结束和另一个段落的开始。在这种位置进行分页，不会破坏文本的逻辑结构。

第二优先级：句子结束标点
句号、感叹号、问号等标点符号标志着一个完整思想的结束。在这些位置分页，虽然可能会在段落中间断开，但至少保证了语意的完整性。

第三优先级：逗号和分号
这些标点虽然不代表句子的结束，但它们标志着语意的暂停。在必要时，可以选择这些位置作为断点。

第四优先级：空格字符
作为最后的选择，我们可以在单词之间的空格处断开，确保不会把单词从中间截断。

第三章 文本完整性保证

anx-reader的一个核心优势是能够完全保证文字的完整性，不会出现文字丢失的问题。这主要得益于以下几个技术特性：

基于字符级的精确分页：
与传统的基于像素或行数的分页方法不同，anx-reader采用基于字符级的精确分页。系统会精确记录每个字符的位置，确保所有文字都能被准确地分配到相应的页面中。

渐进式内容加载：
系统采用渐进式的内容加载策略。当用户翻页时，系统不是简单地跳转到下一个预定义的页面，而是根据当前的阅读位置，精确计算下一页应该从哪里开始。

多重位置记录：
为了确保位置的准确性，系统同时使用多种位置记录方法：CFI（Canonical Fragment Identifier）记录精确位置、Range记录可见文本范围、百分比记录相对进度、页码记录当前页面。这种多重保障机制确保了即使在某个记录方法出现问题时，系统仍能准确恢复阅读位置。

第四章 响应式布局适配

现代阅读器需要适配各种不同的设备和屏幕尺寸。anx-reader的分页算法考虑了这一需求，实现了完全响应式的布局适配。

设备类型识别：
系统首先会识别当前设备的类型（手机、平板、桌面等），并根据设备特性调整分页参数。不同设备有不同的最佳阅读体验配置。

动态列数调整：
在较大的屏幕上，系统可以自动启用多列布局，类似于传统书籍的双页显示。列数会根据屏幕宽度和用户设置动态调整。

字体和间距优化：
系统会根据屏幕密度和尺寸，自动调整字体大小、行间距、字符间距等参数，确保在任何设备上都能获得最佳的阅读体验。

第五章 性能优化策略

高级分页算法的计算复杂度相对较高，因此性能优化是一个重要的考虑因素。anx-reader采用了多种优化策略：

懒加载分页：
系统不会一次性对整本书进行分页，而是采用懒加载的策略。只有当用户接近某个章节时，系统才会对该章节进行分页处理。

分页结果缓存：
一旦某个章节完成分页，结果会被缓存起来。当用户再次访问该章节时，可以直接使用缓存的结果，避免重复计算。

后台预计算：
系统会在后台预先计算用户可能访问的下一个章节，确保翻页时的流畅性。

内存管理：
为了避免内存占用过大，系统会智能地管理分页缓存，自动清理长时间未访问的章节缓存。

第六章 用户体验优化

除了技术层面的优化，anx-reader还在用户体验方面做了大量工作：

平滑翻页动画：
系统提供了多种翻页动画效果，包括滑动、淡入淡出、翻书效果等，用户可以根据个人喜好选择。

智能预加载：
系统会智能预测用户的阅读行为，提前加载下一页的内容，确保翻页时的即时响应。

个性化设置：
用户可以自定义字体、字号、行距、页边距、背景色等多项参数，创造专属的阅读环境。

阅读进度同步：
系统支持多设备间的阅读进度同步，用户可以在不同设备间无缝切换阅读。

第七章 未来发展方向

随着技术的不断进步，电子书阅读器的分页技术还有很大的发展空间：

人工智能辅助：
未来的分页器可能会集成人工智能技术，根据用户的阅读习惯和内容特性，自动优化分页策略。

虚拟现实支持：
随着VR技术的发展，分页器需要适配三维空间的阅读体验，这将是一个全新的挑战。

语音交互：
语音控制的翻页功能将成为未来阅读器的标准配置，这要求分页器与语音识别系统深度集成。

无障碍访问：
为视觉障碍用户提供更好的分页体验，包括屏幕阅读器优化、高对比度模式等。

结语

高级分页技术是现代电子书阅读器的核心竞争力之一。通过采用anx-reader的技术原理，我们能够为用户提供更加流畅、准确、个性化的阅读体验。随着技术的不断发展，相信未来的电子书阅读器将能够提供更加智能和人性化的服务。

这就是高级分页器的完整技术解析。希望通过这个演示，您能够理解anx-reader分页技术的核心原理和优势。
''';

  @override
  void initState() {
    super.initState();
    _initializeTheme();
    _initializeAnimations();
  }

  @override
  void dispose() {
    _controlBarAnimationController.dispose();
    _searchController.dispose();
    _hideControlBarTimer?.cancel();
    super.dispose();
  }

  void _initializeTheme() {
    _currentTheme = ReadingThemes.dayTheme;
  }

  void _initializeAnimations() {
    _controlBarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _controlBarAnimation = CurvedAnimation(
      parent: _controlBarAnimationController,
      curve: Curves.easeInOut,
    );
  }

  // --- UI控制方法 ---

  void _toggleControlBar() {
    setState(() {
      _showControlBar = !_showControlBar;
    });

    if (_showControlBar) {
      _controlBarAnimationController.forward();
      _resetHideControlBarTimer();
    } else {
      _controlBarAnimationController.reverse();
      _hideControlBarTimer?.cancel();
    }
  }

  void _hideControlBar() {
    setState(() {
      _showControlBar = false;
      _showSettings = false;
      _showSearch = false;
      _showInfo = false;
    });
    _controlBarAnimationController.reverse();
    _hideControlBarTimer?.cancel();
  }

  void _resetHideControlBarTimer() {
    _hideControlBarTimer?.cancel();
    _hideControlBarTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _showControlBar) {
        _hideControlBar();
      }
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: _currentTheme.controlBarColor,
      ),
    );
  }

  // --- 搜索功能 ---

  void _performSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _currentSearchIndex = -1;
      });
      return;
    }

    final results = _readerController.searchText(query.trim());
    setState(() {
      _searchResults = results;
      _currentSearchIndex = results.isNotEmpty ? 0 : -1;
    });

    if (results.isNotEmpty) {
      _readerController.goToPage(results[0].pageIndex + 1);
      _showMessage('找到 ${results.length} 个结果');
    } else {
      _showMessage('未找到匹配内容');
    }
  }

  void _goToNextSearchResult() {
    if (_searchResults.isEmpty) return;

    setState(() {
      _currentSearchIndex = (_currentSearchIndex + 1) % _searchResults.length;
    });

    final result = _searchResults[_currentSearchIndex];
    _readerController.goToPage(result.pageIndex + 1);
  }

  void _goToPrevSearchResult() {
    if (_searchResults.isEmpty) return;

    setState(() {
      _currentSearchIndex =
          (_currentSearchIndex - 1 + _searchResults.length) %
          _searchResults.length;
    });

    final result = _searchResults[_currentSearchIndex];
    _readerController.goToPage(result.pageIndex + 1);
  }

  // --- 主题和设置 ---

  void _updateTheme(ReadingTheme theme) {
    setState(() {
      _currentTheme = theme;
    });
  }

  void _updateFontSize(double size) {
    setState(() {
      _fontSize = size;
    });
  }

  void _updateLineHeight(double height) {
    setState(() {
      _lineHeight = height;
    });
  }

  TextStyle get _textStyle => TextStyle(
    fontSize: _fontSize,
    height: _lineHeight,
    letterSpacing: _letterSpacing,
    color: _currentTheme.textColor,
    fontFamily: _fontFamily == 'System' ? null : _fontFamily,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentTheme.backgroundColor,
      body: Stack(
        children: [
          // 主要阅读区域
          _buildReaderWidget(),

          // 控制栏
          if (_showControlBar) _buildControlBar(),

          // 设置面板
          if (_showSettings) _buildSettingsPanel(),

          // 搜索面板
          if (_showSearch) _buildSearchPanel(),

          // 信息面板
          if (_showInfo) _buildInfoPanel(),
        ],
      ),
    );
  }

  Widget _buildReaderWidget() {
    return GestureDetector(
      onTap: _toggleControlBar,
      child: ControlledFlutterAdvancedReaderWidget(
        text: _demoText,
        textStyle: _textStyle,
        backgroundColor: _currentTheme.backgroundColor,
        padding: const EdgeInsets.all(20),
        preserveWordBoundaries: true,
        controller: _readerController,
        onPageChanged: (currentPage, totalPages) {
          _currentReadingInfo = ReadingInfo(
            currentPage: currentPage,
            totalPages: totalPages,
            progress: currentPage / totalPages,
            chapterTitle: null,
            chapterIndex: null,
          );
        },
        onReachStart: () => _showMessage('已到达开始'),
        onReachEnd: () => _showMessage('已到达结尾'),
        onMiddleClick: _toggleControlBar,
        onTextSelected: (text) {
          _showMessage(
            '选中文本: ${text.substring(0, text.length > 20 ? 20 : text.length)}...',
          );
        },
      ),
    );
  }

  Widget _buildControlBar() {
    return AnimatedBuilder(
      animation: _controlBarAnimation,
      builder: (context, child) {
        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Transform.translate(
            offset: Offset(0, (1 - _controlBarAnimation.value) * 100),
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: _currentTheme.controlBarColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 进度条
                  if (_currentReadingInfo != null) _buildProgressBar(),

                  // 控制按钮
                  _buildControlButtons(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressBar() {
    final readingInfo = _currentReadingInfo!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${readingInfo.currentPage}/${readingInfo.totalPages}',
                style: TextStyle(
                  fontSize: 12,
                  color: _currentTheme.controlBarTextColor,
                ),
              ),
              Text(
                '${(readingInfo.progress * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: _currentTheme.controlBarTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _currentTheme.sliderActiveColor,
              inactiveTrackColor: _currentTheme.sliderInactiveColor,
              thumbColor: _currentTheme.sliderActiveColor,
              overlayColor: _currentTheme.sliderActiveColor.withValues(
                alpha: 0.2,
              ),
            ),
            child: Slider(
              value: readingInfo.progress,
              onChanged: (value) {
                _readerController.goToProgress(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: Icons.info_outline,
            label: '信息',
            onPressed: () {
              setState(() {
                _showInfo = !_showInfo;
                _showSettings = false;
                _showSearch = false;
              });
            },
          ),
          _buildControlButton(
            icon: Icons.search,
            label: '搜索',
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                _showInfo = false;
                _showSettings = false;
              });
            },
          ),
          _buildControlButton(
            icon: Icons.settings,
            label: '设置',
            onPressed: () {
              setState(() {
                _showSettings = !_showSettings;
                _showInfo = false;
                _showSearch = false;
              });
            },
          ),
          _buildControlButton(
            icon: Icons.keyboard_arrow_left,
            label: '上一页',
            onPressed: () {
              _readerController.prevPage();
            },
          ),
          _buildControlButton(
            icon: Icons.keyboard_arrow_right,
            label: '下一页',
            onPressed: () {
              _readerController.nextPage();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _currentTheme.iconColor, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: _currentTheme.controlBarTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return Positioned(
      bottom: 200,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _currentTheme.controlBarColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '阅读设置',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _currentTheme.controlBarTextColor,
              ),
            ),
            const SizedBox(height: 16),

            // 字体大小
            _buildSettingSlider(
              label: '字体大小',
              value: _fontSize,
              min: 12.0,
              max: 24.0,
              divisions: 12,
              onChanged: _updateFontSize,
            ),

            // 行间距
            _buildSettingSlider(
              label: '行间距',
              value: _lineHeight,
              min: 1.0,
              max: 2.5,
              divisions: 15,
              onChanged: _updateLineHeight,
            ),

            // 主题选择
            _buildThemeSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: _currentTheme.controlBarTextColor,
              ),
            ),
            Text(
              value.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 14,
                color: _currentTheme.controlBarTextColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _currentTheme.sliderActiveColor,
            inactiveTrackColor: _currentTheme.sliderInactiveColor,
            thumbColor: _currentTheme.sliderActiveColor,
            overlayColor: _currentTheme.sliderActiveColor.withValues(
              alpha: 0.2,
            ),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildThemeSelector() {
    final themes = [
      ReadingThemes.dayTheme,
      ReadingThemes.nightTheme,
      ReadingThemes.greenTheme,
      ReadingThemes.brownTheme,
      ReadingThemes.sepiaTheme,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '阅读主题',
          style: TextStyle(
            fontSize: 14,
            color: _currentTheme.controlBarTextColor,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: themes.map((theme) {
            final isSelected = theme.name == _currentTheme.name;
            return GestureDetector(
              onTap: () => _updateTheme(theme),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? _currentTheme.sliderActiveColor
                        : Colors.grey.withValues(alpha: 0.3),
                    width: isSelected ? 3 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    '文',
                    style: TextStyle(color: theme.textColor, fontSize: 12),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSearchPanel() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _currentTheme.controlBarColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: _currentTheme.controlBarTextColor),
                    decoration: InputDecoration(
                      hintText: '搜索内容...',
                      hintStyle: TextStyle(
                        color: _currentTheme.controlBarTextColor.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _currentTheme.sliderInactiveColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _currentTheme.sliderActiveColor,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: _performSearch,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _performSearch(_searchController.text),
                  icon: Icon(Icons.search, color: _currentTheme.iconColor),
                ),
              ],
            ),
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_currentSearchIndex + 1}/${_searchResults.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _currentTheme.controlBarTextColor,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _goToPrevSearchResult,
                        icon: Icon(
                          Icons.keyboard_arrow_up,
                          color: _currentTheme.iconColor,
                        ),
                      ),
                      IconButton(
                        onPressed: _goToNextSearchResult,
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: _currentTheme.iconColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _currentTheme.controlBarColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '高级分页器演示',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _currentTheme.controlBarTextColor,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('技术原理', 'anx-reader精确分页算法'),
            _buildInfoRow('分页方式', '基于文本边界的智能分页'),
            _buildInfoRow('断点检测', '段落→句子→逗号→空格'),
            _buildInfoRow('文字保证', '100%文字完整性，无丢失'),
            _buildInfoRow('响应式', '自适应屏幕尺寸和设备类型'),
            if (_currentReadingInfo != null) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              _buildInfoRow(
                '当前页',
                '${_currentReadingInfo!.currentPage}/${_currentReadingInfo!.totalPages}',
              ),
              _buildInfoRow(
                '阅读进度',
                '${(_currentReadingInfo!.progress * 100).toStringAsFixed(1)}%',
              ),
              _buildInfoRow('字体大小', '${_fontSize.toStringAsFixed(0)}px'),
              _buildInfoRow('行间距', '${_lineHeight.toStringAsFixed(1)}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: _currentTheme.controlBarTextColor.withValues(alpha: 0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: _currentTheme.controlBarTextColor,
            ),
          ),
        ],
      ),
    );
  }
}

// --- 阅读主题定义 ---

class ReadingTheme {
  final String name;
  final String displayName;
  final Color backgroundColor;
  final Color textColor;
  final Color controlBarColor;
  final Color controlBarTextColor;
  final Color iconColor;
  final Color sliderActiveColor;
  final Color sliderInactiveColor;

  const ReadingTheme({
    required this.name,
    required this.displayName,
    required this.backgroundColor,
    required this.textColor,
    required this.controlBarColor,
    required this.controlBarTextColor,
    required this.iconColor,
    required this.sliderActiveColor,
    required this.sliderInactiveColor,
  });
}

class ReadingThemes {
  static const ReadingTheme dayTheme = ReadingTheme(
    name: 'day',
    displayName: '白天',
    backgroundColor: Color(0xFFFFFBF0),
    textColor: Color(0xFF2C2C2C),
    controlBarColor: Color(0xFFF5F5F5),
    controlBarTextColor: Color(0xFF333333),
    iconColor: Color(0xFF666666),
    sliderActiveColor: Color(0xFF4CAF50),
    sliderInactiveColor: Color(0xFFE0E0E0),
  );

  static const ReadingTheme nightTheme = ReadingTheme(
    name: 'night',
    displayName: '夜间',
    backgroundColor: Color(0xFF121212),
    textColor: Color(0xFFE8E8E8),
    controlBarColor: Color(0xFF1E1E1E),
    controlBarTextColor: Color(0xFFE0E0E0),
    iconColor: Color(0xFFB0B0B0),
    sliderActiveColor: Color(0xFF81C784),
    sliderInactiveColor: Color(0xFF424242),
  );

  static const ReadingTheme greenTheme = ReadingTheme(
    name: 'green',
    displayName: '护眼绿',
    backgroundColor: Color(0xFFE8F5E8),
    textColor: Color(0xFF2E4A2E),
    controlBarColor: Color(0xFFDCE9DC),
    controlBarTextColor: Color(0xFF1B3A1B),
    iconColor: Color(0xFF4A6E4A),
    sliderActiveColor: Color(0xFF66BB6A),
    sliderInactiveColor: Color(0xFFC8E6C9),
  );

  static const ReadingTheme brownTheme = ReadingTheme(
    name: 'brown',
    displayName: '牛皮纸',
    backgroundColor: Color(0xFFF4F1E8),
    textColor: Color(0xFF8B4513),
    controlBarColor: Color(0xFFE8E2D6),
    controlBarTextColor: Color(0xFF654321),
    iconColor: Color(0xFFA0522D),
    sliderActiveColor: Color(0xFFD2B48C),
    sliderInactiveColor: Color(0xFFF5DEB3),
  );

  static const ReadingTheme sepiaTheme = ReadingTheme(
    name: 'sepia',
    displayName: '古典',
    backgroundColor: Color(0xFFFDF6E3),
    textColor: Color(0xFF5D4E37),
    controlBarColor: Color(0xFFEEE5D0),
    controlBarTextColor: Color(0xFF4A3E28),
    iconColor: Color(0xFF8B7355),
    sliderActiveColor: Color(0xFFCD853F),
    sliderInactiveColor: Color(0xFFF5DEB3),
  );
}
