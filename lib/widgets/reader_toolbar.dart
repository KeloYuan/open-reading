import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reader_providers.dart';

/// 工具栏位置枚举
enum ToolbarPosition {
  top, // 顶部工具栏
  bottom, // 底部工具栏
}

/// 阅读器工具栏
///
/// 提供阅读设置的交互控制：
/// - 顶部工具栏：返回按钮、书籍标题、目录按钮
/// - 底部工具栏：主题切换、字体设置、排版设置、TTS控制
class ReaderToolbar extends StatefulWidget {
  /// 工具栏位置
  final ToolbarPosition position;

  /// 用户交互回调（用于重置自动隐藏计时器）
  final VoidCallback? onInteraction;

  const ReaderToolbar({
    Key? key,
    required this.position,
    this.onInteraction,
  }) : super(key: key);

  @override
  State<ReaderToolbar> createState() => _ReaderToolbarState();
}

class _ReaderToolbarState extends State<ReaderToolbar> {
  bool _showAdvancedSettings = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ReaderSettingsNotifier>(
      builder: (context, settingsNotifier, child) {
        final settings = settingsNotifier.state;

        return Container(
          decoration: _buildToolbarDecoration(settings),
          child: SafeArea(
            top: widget.position == ToolbarPosition.top,
            bottom: widget.position == ToolbarPosition.bottom,
            child: widget.position == ToolbarPosition.top
                ? _buildTopToolbar(settings)
                : _buildBottomToolbar(settings),
          ),
        );
      },
    );
  }

  /// 构建工具栏装饰
  BoxDecoration _buildToolbarDecoration(ReaderSettings settings) {
    return BoxDecoration(
      color: _getToolbarBackgroundColor(settings),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 8,
          offset: widget.position == ToolbarPosition.top
              ? const Offset(0, 2)
              : const Offset(0, -2),
        ),
      ],
    );
  }

  /// 获取工具栏背景色
  Color _getToolbarBackgroundColor(ReaderSettings settings) {
    switch (settings.theme) {
      case ReadingTheme.day:
        return const Color(0xFFF8F8F8);
      case ReadingTheme.night:
        return const Color(0xFF2A2A2A);
      case ReadingTheme.eyeCare:
        return const Color(0xFFF0F2E8);
      case ReadingTheme.warmPaper:
        return const Color(0xFFFFF8DC);
      case ReadingTheme.coolGray:
        return const Color(0xFFE8E8E8);
      case ReadingTheme.sepia:
        return const Color(0xFFF5E6D3);
      case ReadingTheme.pureBlack:
        return const Color(0xFF000000);
      case ReadingTheme.blueLight:
        return const Color(0xFFE8F4F8);
    }
  }

  /// 构建顶部工具栏
  Widget _buildTopToolbar(ReaderSettings settings) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 返回按钮
          _buildIconButton(
            icon: Icons.arrow_back,
            onPressed: () => Navigator.of(context).pop(),
            settings: settings,
          ),

          const SizedBox(width: 16),

          // 书籍标题
          Expanded(
            child: Text(
              '阅读中...', // 这里可以传入实际的书籍标题
              style: settings.textStyle.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: 16),

          // 目录按钮
          _buildIconButton(
            icon: Icons.list,
            onPressed: _showTableOfContents,
            settings: settings,
          ),

          const SizedBox(width: 8),

          // 更多选项按钮
          _buildIconButton(
            icon: Icons.more_vert,
            onPressed: _showMoreOptions,
            settings: settings,
          ),
        ],
      ),
    );
  }

  /// 构建底部工具栏
  Widget _buildBottomToolbar(ReaderSettings settings) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 高级设置面板
        if (_showAdvancedSettings) _buildAdvancedSettingsPanel(settings),

        // 主工具栏
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 亮度/主题切换
              _buildThemeToggle(settings),

              // 字体大小调节
              _buildFontSizeControls(settings),

              // 高级设置切换
              _buildAdvancedToggle(settings),

              // TTS控制
              _buildTtsControls(),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建高级设置面板
  Widget _buildAdvancedSettingsPanel(ReaderSettings settings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getToolbarBackgroundColor(settings),
        border: Border(
          bottom: BorderSide(
            color: settings.textStyle.color?.withValues(alpha: 0.1) ??
                Colors.grey.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 行间距调节
          _buildLineHeightSlider(settings),

          const SizedBox(height: 16),

          // 字间距调节
          _buildLetterSpacingSlider(settings),

          const SizedBox(height: 16),

          // 翻页模式选择
          _buildPaginationModeSelector(settings),
        ],
      ),
    );
  }

  /// 构建主题切换按钮
  Widget _buildThemeToggle(ReaderSettings settings) {
    return GestureDetector(
      onTap: () {
        _onInteraction();
        _cycleTheme();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: settings.textStyle.color?.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getThemeIcon(settings.theme),
              size: 20,
              color: settings.textStyle.color?.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 4),
            Text(
              _getThemeName(settings.theme),
              style: settings.textStyle.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建字体大小控制
  Widget _buildFontSizeControls(ReaderSettings settings) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIconButton(
          icon: Icons.text_decrease,
          onPressed: () {
            _onInteraction();
            _decreaseFontSize();
          },
          settings: settings,
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: settings.textStyle.color?.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${settings.fontSize.toInt()}',
            style: settings.textStyle.copyWith(fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        _buildIconButton(
          icon: Icons.text_increase,
          onPressed: () {
            _onInteraction();
            _increaseFontSize();
          },
          settings: settings,
        ),
      ],
    );
  }

  /// 构建高级设置切换
  Widget _buildAdvancedToggle(ReaderSettings settings) {
    return GestureDetector(
      onTap: () {
        _onInteraction();
        setState(() {
          _showAdvancedSettings = !_showAdvancedSettings;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _showAdvancedSettings
              ? settings.textStyle.color?.withValues(alpha: 0.2)
              : settings.textStyle.color?.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _showAdvancedSettings ? Icons.tune : Icons.settings,
          size: 20,
          color: settings.textStyle.color?.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  /// 构建TTS控制
  Widget _buildTtsControls() {
    return Consumer<ReaderTtsNotifier>(
      builder: (context, ttsNotifier, child) {
        final ttsState = ttsNotifier.state;

        return GestureDetector(
          onTap: () {
            _onInteraction();
            _toggleTts();
          },
          child: Consumer<ReaderSettingsNotifier>(
            builder: (context, settingsNotifier, child) {
              final settings = settingsNotifier.state;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ttsState.isPlaying
                      ? settings.textStyle.color?.withValues(alpha: 0.2)
                      : settings.textStyle.color?.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  ttsState.isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 20,
                  color: settings.textStyle.color?.withValues(alpha: 0.8),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// 构建行间距滑块
  Widget _buildLineHeightSlider(ReaderSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '行间距',
          style: settings.textStyle
              .copyWith(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Slider(
          value: settings.lineSpacing,
          min: 1.0,
          max: 3.0,
          divisions: 20,
          label: settings.lineSpacing.toStringAsFixed(1),
          onChanged: (value) {
            _onInteraction();
            context.read<ReaderSettingsNotifier>().updateLineSpacing(value);
          },
        ),
      ],
    );
  }

  /// 构建字间距滑块
  Widget _buildLetterSpacingSlider(ReaderSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '字间距',
          style: settings.textStyle
              .copyWith(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Slider(
          value: settings.letterSpacing,
          min: -1.0,
          max: 2.0,
          divisions: 30,
          label: settings.letterSpacing.toStringAsFixed(1),
          onChanged: (value) {
            _onInteraction();
            context.read<ReaderSettingsNotifier>().updateLetterSpacing(value);
          },
        ),
      ],
    );
  }

  /// 构建翻页模式选择器
  Widget _buildPaginationModeSelector(ReaderSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '翻页模式',
          style: settings.textStyle
              .copyWith(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: PaginationMode.values.map((mode) {
            final isSelected = settings.paginationMode == mode;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  _onInteraction();
                  context
                      .read<ReaderSettingsNotifier>()
                      .switchPaginationMode(mode);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? settings.textStyle.color?.withValues(alpha: 0.2)
                        : settings.textStyle.color?.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getPaginationModeName(mode),
                    style: settings.textStyle.copyWith(fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 构建图标按钮
  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required ReaderSettings settings,
  }) {
    return GestureDetector(
      onTap: () {
        _onInteraction();
        onPressed();
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: settings.textStyle.color?.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 20,
          color: settings.textStyle.color?.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  /// 交互回调
  void _onInteraction() {
    widget.onInteraction?.call();
  }

  /// 循环切换主题
  void _cycleTheme() {
    final settings = context.read<ReaderSettingsNotifier>().state;
    ReadingTheme nextTheme;

    switch (settings.theme) {
      case ReadingTheme.day:
        nextTheme = ReadingTheme.night;
        break;
      case ReadingTheme.night:
        nextTheme = ReadingTheme.eyeCare;
        break;
      case ReadingTheme.eyeCare:
        nextTheme = ReadingTheme.warmPaper;
        break;
      case ReadingTheme.warmPaper:
        nextTheme = ReadingTheme.coolGray;
        break;
      case ReadingTheme.coolGray:
        nextTheme = ReadingTheme.sepia;
        break;
      case ReadingTheme.sepia:
        nextTheme = ReadingTheme.pureBlack;
        break;
      case ReadingTheme.pureBlack:
        nextTheme = ReadingTheme.blueLight;
        break;
      case ReadingTheme.blueLight:
        nextTheme = ReadingTheme.day;
        break;
    }

    context.read<ReaderSettingsNotifier>().switchTheme(nextTheme);
  }

  /// 增加字体大小
  void _increaseFontSize() {
    final currentSize = context.read<ReaderSettingsNotifier>().state.fontSize;
    context.read<ReaderSettingsNotifier>().updateFontSize(currentSize + 1);
  }

  /// 减少字体大小
  void _decreaseFontSize() {
    final currentSize = context.read<ReaderSettingsNotifier>().state.fontSize;
    context.read<ReaderSettingsNotifier>().updateFontSize(currentSize - 1);
  }

  /// 切换TTS
  void _toggleTts() {
    final ttsState = context.read<ReaderTtsNotifier>().state;
    final ttsNotifier = context.read<ReaderTtsNotifier>();

    if (ttsState.isPlaying) {
      ttsNotifier.pause();
    } else {
      final currentPageContent =
          context.read<ReaderPaginationNotifier>().state.currentPageContent;
      ttsNotifier.play(text: currentPageContent);
    }
  }

  /// 显示目录
  void _showTableOfContents() {
    // TODO: 实现目录显示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('目录功能待实现')),
    );
  }

  /// 显示更多选项
  void _showMoreOptions() {
    // TODO: 实现更多选项
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('更多选项待实现')),
    );
  }

  /// 获取主题图标
  IconData _getThemeIcon(ReadingTheme theme) {
    switch (theme) {
      case ReadingTheme.day:
        return Icons.wb_sunny;
      case ReadingTheme.night:
        return Icons.nights_stay;
      case ReadingTheme.eyeCare:
        return Icons.eco;
      case ReadingTheme.warmPaper:
        return Icons.wb_incandescent;
      case ReadingTheme.coolGray:
        return Icons.ac_unit;
      case ReadingTheme.sepia:
        return Icons.auto_stories;
      case ReadingTheme.pureBlack:
        return Icons.brightness_2;
      case ReadingTheme.blueLight:
        return Icons.water_drop;
    }
  }

  /// 获取主题名称
  String _getThemeName(ReadingTheme theme) {
    switch (theme) {
      case ReadingTheme.day:
        return '白天';
      case ReadingTheme.night:
        return '夜间';
      case ReadingTheme.eyeCare:
        return '护眼';
      case ReadingTheme.warmPaper:
        return '暖黄';
      case ReadingTheme.coolGray:
        return '冷灰';
      case ReadingTheme.sepia:
        return '棕褐';
      case ReadingTheme.pureBlack:
        return '纯黑';
      case ReadingTheme.blueLight:
        return '蓝光';
    }
  }

  /// 获取翻页模式名称
  String _getPaginationModeName(PaginationMode mode) {
    switch (mode) {
      case PaginationMode.slide:
        return '滑动';
      case PaginationMode.scroll:
        return '滚动';
      case PaginationMode.simulation:
        return '仿真';
    }
  }
}
