import 'package:flutter/material.dart';
import '../services/reading_theme_manager.dart';
import '../services/page_animation_manager.dart';

/// 增强的阅读设置对话框
/// 集成主题、动画、字体等所有阅读相关设置
class EnhancedReadingSettingsDialog extends StatefulWidget {
  final ReadingTheme currentTheme;
  final Function(ReadingTheme) onThemeChanged;
  final double fontSize;
  final Function(double) onFontSizeChanged;
  final double lineHeight;
  final Function(double) onLineHeightChanged;
  final double letterSpacing;
  final Function(double) onLetterSpacingChanged;
  final String fontFamily;
  final Function(String) onFontFamilyChanged;
  final PageAnimationType currentAnimationType;
  final Function(PageAnimationType) onAnimationTypeChanged;

  const EnhancedReadingSettingsDialog({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
    required this.fontSize,
    required this.onFontSizeChanged,
    required this.lineHeight,
    required this.onLineHeightChanged,
    required this.letterSpacing,
    required this.onLetterSpacingChanged,
    required this.fontFamily,
    required this.onFontFamilyChanged,
    required this.currentAnimationType,
    required this.onAnimationTypeChanged,
  });

  @override
  State<EnhancedReadingSettingsDialog> createState() => _EnhancedReadingSettingsDialogState();
}

class _EnhancedReadingSettingsDialogState extends State<EnhancedReadingSettingsDialog>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late ReadingTheme _currentTheme;
  late double _fontSize;
  late double _lineHeight;
  late double _letterSpacing;
  late String _fontFamily;
  late PageAnimationType _animationType;

  final List<String> _fontFamilies = [
    'System',
    'Serif',
    'Sans-serif',
    'Monospace',
    'Cursive',
    'Fantasy',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentTheme = widget.currentTheme;
    _fontSize = widget.fontSize;
    _lineHeight = widget.lineHeight;
    _letterSpacing = widget.letterSpacing;
    _fontFamily = widget.fontFamily;
    _animationType = widget.currentAnimationType;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ReadingThemeManager.createDialogTheme(_currentTheme),
      child: Container(
        width: double.infinity, // 左右贴着屏幕边缘
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: _currentTheme.controlBarColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            _buildDragHandle(),
            _buildHeader(),
            _buildTabBar(),
            Expanded(child: _buildTabBarView()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: _currentTheme.controlBarTextColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.tune,
            color: _currentTheme.controlBarTextColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            '阅读设置',
            style: TextStyle(
              color: _currentTheme.controlBarTextColor,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.close,
              color: _currentTheme.controlBarTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _currentTheme.backgroundColor.withValues(alpha:0.3),
        borderRadius: BorderRadius.circular(25),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: _currentTheme.controlBarTextColor,
        unselectedLabelColor: _currentTheme.controlBarTextColor.withValues(alpha:0.6),
        indicator: BoxDecoration(
          color: _currentTheme.sliderActiveColor,
          borderRadius: BorderRadius.circular(25),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: const [
          Tab(text: '主题'),
          Tab(text: '字体'),
          Tab(text: '动画'),
          Tab(text: '其他'),
        ],
      ),
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildThemeTab(),
        _buildFontTab(),
        _buildAnimationTab(),
        _buildOtherTab(),
      ],
    );
  }

  Widget _buildThemeTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '选择阅读主题',
            style: TextStyle(
              color: _currentTheme.controlBarTextColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: ReadingThemes.allThemes.length,
              itemBuilder: (context, index) {
                final theme = ReadingThemes.allThemes[index];
                final isSelected = theme.name == _currentTheme.name;

                return ReadingThemeManager.createThemePreviewCard(
                  theme: theme,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _currentTheme = theme;
                    });
                    widget.onThemeChanged(theme);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ReadingThemeManager.createSettingItem(
            title: '字体大小',
            subtitle: '${_fontSize.toInt()}sp',
            theme: _currentTheme,
            trailing: ReadingThemeManager.createThemedSlider(
              value: _fontSize,
              min: 12.0,
              max: 30.0,
              divisions: 18,
              theme: _currentTheme,
              onChanged: (value) {
                setState(() {
                  _fontSize = value;
                });
                widget.onFontSizeChanged(value);
              },
            ),
          ),
          const SizedBox(height: 12),
          ReadingThemeManager.createSettingItem(
            title: '行高',
            subtitle: '${_lineHeight.toStringAsFixed(1)}倍',
            theme: _currentTheme,
            trailing: ReadingThemeManager.createThemedSlider(
              value: _lineHeight,
              min: 1.0,
              max: 3.0,
              divisions: 20,
              theme: _currentTheme,
              onChanged: (value) {
                setState(() {
                  _lineHeight = value;
                });
                widget.onLineHeightChanged(value);
              },
            ),
          ),
          const SizedBox(height: 12),
          ReadingThemeManager.createSettingItem(
            title: '字符间距',
            subtitle: '${_letterSpacing.toStringAsFixed(1)}px',
            theme: _currentTheme,
            trailing: ReadingThemeManager.createThemedSlider(
              value: _letterSpacing,
              min: -1.0,
              max: 3.0,
              divisions: 40,
              theme: _currentTheme,
              onChanged: (value) {
                setState(() {
                  _letterSpacing = value;
                });
                widget.onLetterSpacingChanged(value);
              },
            ),
          ),
          const SizedBox(height: 12),
          ReadingThemeManager.createSettingItem(
            title: '字体类型',
            subtitle: _fontFamily,
            theme: _currentTheme,
            trailing: DropdownButton<String>(
              value: _fontFamily,
              dropdownColor: _currentTheme.controlBarColor,
              style: TextStyle(color: _currentTheme.controlBarTextColor),
              underline: Container(),
              items: _fontFamilies.map((font) {
                return DropdownMenuItem<String>(
                  value: font,
                  child: Text(font),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _fontFamily = value;
                  });
                  widget.onFontFamilyChanged(value);
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _currentTheme.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _currentTheme.sliderInactiveColor,
                width: 1,
              ),
            ),
            child: Text(
              '这是一段示例文字，用来预览当前的字体设置效果。The quick brown fox jumps over the lazy dog.',
              style: TextStyle(
                fontSize: _fontSize,
                height: _lineHeight,
                letterSpacing: _letterSpacing,
                color: _currentTheme.textColor,
                fontFamily: _fontFamily == 'System' ? null : _fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimationTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '翻页动画效果',
            style: TextStyle(
              color: _currentTheme.controlBarTextColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: PageAnimationType.values.length,
              itemBuilder: (context, index) {
                final animationType = PageAnimationType.values[index];
                final isSelected = animationType == _animationType;
                final performanceNote = PageAnimationManager.getPerformanceNotes()[animationType] ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _currentTheme.sliderActiveColor.withValues(alpha:0.2)
                        : _currentTheme.backgroundColor.withValues(alpha:0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? _currentTheme.sliderActiveColor
                          : _currentTheme.sliderInactiveColor,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      _getAnimationIcon(animationType),
                      color: isSelected
                          ? _currentTheme.sliderActiveColor
                          : _currentTheme.controlBarTextColor,
                    ),
                    title: Text(
                      animationType.displayName,
                      style: TextStyle(
                        color: _currentTheme.controlBarTextColor,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          animationType.description,
                          style: TextStyle(
                            color: _currentTheme.controlBarTextColor.withValues(alpha:0.7),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          performanceNote,
                          style: TextStyle(
                            color: _currentTheme.sliderActiveColor,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: _currentTheme.sliderActiveColor,
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _animationType = animationType;
                      });
                      widget.onAnimationTypeChanged(animationType);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ReadingThemeManager.createSettingItem(
            title: '沉浸式阅读',
            subtitle: '隐藏状态栏和导航栏',
            theme: _currentTheme,
            trailing: ReadingThemeManager.createThemedSwitch(
              value: true,
              onChanged: (value) {
                // TODO: 实现沉浸式模式切换
              },
              theme: _currentTheme,
            ),
          ),
          const SizedBox(height: 8),
          ReadingThemeManager.createSettingItem(
            title: '音量键翻页',
            subtitle: '使用音量键控制翻页',
            theme: _currentTheme,
            trailing: ReadingThemeManager.createThemedSwitch(
              value: true,
              onChanged: (value) {
                // TODO: 实现音量键翻页设置
              },
              theme: _currentTheme,
            ),
          ),
          const SizedBox(height: 8),
          ReadingThemeManager.createSettingItem(
            title: '屏幕常亮',
            subtitle: '阅读时保持屏幕不息屏',
            theme: _currentTheme,
            trailing: ReadingThemeManager.createThemedSwitch(
              value: false,
              onChanged: (value) {
                // TODO: 实现屏幕常亮设置
              },
              theme: _currentTheme,
            ),
          ),
          const SizedBox(height: 8),
          ReadingThemeManager.createSettingItem(
            title: '自动保存进度',
            subtitle: '定时保存阅读进度',
            theme: _currentTheme,
            trailing: ReadingThemeManager.createThemedSwitch(
              value: true,
              onChanged: (value) {
                // TODO: 实现自动保存设置
              },
              theme: _currentTheme,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _currentTheme.backgroundColor.withValues(alpha:0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _currentTheme.sliderActiveColor.withValues(alpha:0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: _currentTheme.sliderActiveColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '设置会自动保存，无需手动确认',
                    style: TextStyle(
                      color: _currentTheme.controlBarTextColor.withValues(alpha:0.8),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentTheme.sliderActiveColor,
                foregroundColor: _currentTheme.backgroundColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '完成',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getAnimationIcon(PageAnimationType type) {
    switch (type) {
      case PageAnimationType.cover:
        return Icons.layers;
      case PageAnimationType.slide:
        return Icons.swipe;
      case PageAnimationType.simulation:
        return Icons.flip_to_front;
      case PageAnimationType.scroll:
        return Icons.vertical_align_top;
      case PageAnimationType.none:
        return Icons.block;
    }
  }
}