import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../utils/glass_config.dart';
import '../utils/app_themes.dart';
import '../services/webdav/webdav_sync_service.dart';
import '../widgets/webdav_config_dialog.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _enableAnimations = true;
  bool _enableAutoSave = true;
  bool _keepScreenOn = false;
  int _autoSaveInterval = 30;

  // TTS设置
  bool _enableTTS = true;
  double _ttsSpeed = 0.5;
  double _ttsVolume = 1.0;
  double _ttsPitch = 1.0;

  // 阅读设置
  bool _enablePageAnimation = true;
  bool _enableVolumeKeyTurn = true;
  String _defaultReadingEngine = 'webview_optimized'; // 默认阅读引擎

  // WebDAV设置
  final WebDavSyncService _webdavService = WebDavSyncService();

  // 其他设置
  bool _enableBatteryOptimization = true;
  bool _enableFullscreen = false;
  String _language = 'zh-CN';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _enableAnimations = prefs.getBool('enableAnimations') ?? true;
      _enableAutoSave = prefs.getBool('enableAutoSave') ?? true;
      _keepScreenOn = prefs.getBool('keepScreenOn') ?? false;
      _autoSaveInterval = prefs.getInt('autoSaveInterval') ?? 30;

      // TTS设置
      _enableTTS = prefs.getBool('enableTTS') ?? true;
      _ttsSpeed = prefs.getDouble('ttsSpeed') ?? 0.5;
      _ttsVolume = prefs.getDouble('ttsVolume') ?? 1.0;
      _ttsPitch = prefs.getDouble('ttsPitch') ?? 1.0;

      // 阅读设置
      _enablePageAnimation = prefs.getBool('enablePageAnimation') ?? true;
      _enableVolumeKeyTurn = prefs.getBool('enableVolumeKeyTurn') ?? true;
      _defaultReadingEngine =
          prefs.getString('defaultReadingEngine') ?? 'webview_optimized';

      // 其他设置
      _enableBatteryOptimization =
          prefs.getBool('enableBatteryOptimization') ?? true;
      _enableFullscreen = prefs.getBool('enableFullscreen') ?? false;
      _language = prefs.getString('language') ?? 'zh-CN';
    });

    // 初始化WebDAV服务
    await _webdavService.initialize();
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableAnimations', _enableAnimations);
    await prefs.setBool('enableAutoSave', _enableAutoSave);
    await prefs.setBool('keepScreenOn', _keepScreenOn);
    await prefs.setInt('autoSaveInterval', _autoSaveInterval);

    // TTS设置
    await prefs.setBool('enableTTS', _enableTTS);
    await prefs.setDouble('ttsSpeed', _ttsSpeed);
    await prefs.setDouble('ttsVolume', _ttsVolume);
    await prefs.setDouble('ttsPitch', _ttsPitch);

    // 阅读设置
    await prefs.setBool('enablePageAnimation', _enablePageAnimation);
    await prefs.setBool('enableVolumeKeyTurn', _enableVolumeKeyTurn);
    await prefs.setString('defaultReadingEngine', _defaultReadingEngine);

    // 其他设置
    await prefs.setBool(
      'enableBatteryOptimization',
      _enableBatteryOptimization,
    );
    await prefs.setBool('enableFullscreen', _enableFullscreen);
    await prefs.setString('language', _language);
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          '设置',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: GlassEffectConfig.createProgressiveAppBar(
          context: context,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.3, 0.7, 1.0],
            colors: [
              Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.12),
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.98),
              Theme.of(
                context,
              ).colorScheme.secondaryContainer.withValues(alpha: 0.08),
              Theme.of(
                context,
              ).colorScheme.tertiaryContainer.withValues(alpha: 0.15),
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              _buildSectionCard(
                title: '外观设置',
                icon: Icons.palette_outlined,
                children: [
                  _buildThemeToggle(themeNotifier, isDarkMode),
                  _buildAppThemeSelector(themeNotifier),
                  _buildCustomAccentColorSelector(themeNotifier),
                  _buildGlobalAccentColorSelector(themeNotifier),
                  _buildAnimationToggle(),
                ],
              ),
              const SizedBox(height: 20),
              _buildSectionCard(
                title: '阅读提示',
                icon: Icons.info_outline,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.font_download_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '字体设置已移至阅读界面',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '打开任意书籍，点击屏幕中央，在底部控制栏中点击"设置"按钮，即可调整字体大小、行间距、字符间距、页面边距等阅读设置。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.7),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSectionCard(
                title: '阅读设置',
                icon: Icons.book_outlined,
                children: [
                  _buildReadingEngineSelector(),
                  _buildSwitchSetting(
                    title: '音量键翻页',
                    subtitle: '使用音量键控制翻页',
                    value: _enableVolumeKeyTurn,
                    onChanged: (value) =>
                        setState(() => _enableVolumeKeyTurn = value),
                    icon: Icons.volume_up,
                  ),
                  _buildSwitchSetting(
                    title: '全屏阅读',
                    subtitle: '隐藏状态栏和导航栏',
                    value: _enableFullscreen,
                    onChanged: (value) =>
                        setState(() => _enableFullscreen = value),
                    icon: Icons.fullscreen,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSectionCard(
                title: 'TTS朗读',
                icon: Icons.record_voice_over,
                children: [
                  _buildSwitchSetting(
                    title: '启用朗读功能',
                    subtitle: '开启文本转语音朗读',
                    value: _enableTTS,
                    onChanged: (value) => setState(() => _enableTTS = value),
                    icon: Icons.play_circle_outline,
                  ),
                  if (_enableTTS) ...[
                    _buildSliderSetting(
                      title: '朗读速度',
                      subtitle: '调整朗读的快慢',
                      value: _ttsSpeed,
                      min: 0.1,
                      max: 2.0,
                      divisions: 19,
                      onChanged: (value) => setState(() => _ttsSpeed = value),
                      icon: Icons.speed,
                      formatter: (value) => '${(value * 100).round()}%',
                    ),
                    _buildSliderSetting(
                      title: '朗读音量',
                      subtitle: '调整朗读音量大小',
                      value: _ttsVolume,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      onChanged: (value) => setState(() => _ttsVolume = value),
                      icon: Icons.volume_up,
                      formatter: (value) => '${(value * 100).round()}%',
                    ),
                    _buildSliderSetting(
                      title: '音调高低',
                      subtitle: '调整朗读音调',
                      value: _ttsPitch,
                      min: 0.5,
                      max: 2.0,
                      divisions: 15,
                      onChanged: (value) => setState(() => _ttsPitch = value),
                      icon: Icons.graphic_eq,
                      formatter: (value) => '${(value * 100).round()}%',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              _buildSectionCard(
                title: '云端同步',
                icon: Icons.cloud_sync,
                children: [
                  _buildActionSetting(
                    title: 'WebDAV配置',
                    subtitle: _webdavService.isConfigured
                        ? '已配置 - ${_webdavService.serverUrl}'
                        : '点击配置WebDAV服务器',
                    onTap: _showWebDavConfig,
                    icon: Icons.cloud,
                    trailing: _webdavService.isConfigured
                        ? Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          )
                        : null,
                  ),
                  if (_webdavService.isConfigured)
                    _buildActionSetting(
                      title: '立即同步',
                      subtitle: '手动同步阅读数据',
                      onTap: _syncNow,
                      icon: Icons.sync,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSectionCard(
                title: '书籍管理',
                icon: Icons.library_books,
                children: [
                  _buildSwitchSetting(
                    title: '自动提取封面',
                    subtitle: '导入时自动提取书籍封面',
                    value: true, // 默认开启
                    onChanged: (value) {
                      // TODO: 实现封面提取开关逻辑
                    },
                    icon: Icons.image,
                  ),
                  _buildActionSetting(
                    title: '重新提取封面',
                    subtitle: '为现有书籍重新提取封面',
                    onTap: _refreshAllCovers,
                    icon: Icons.refresh,
                  ),
                  _buildActionSetting(
                    title: '清理封面缓存',
                    subtitle: '清理无效的封面文件',
                    onTap: _cleanCoverCache,
                    icon: Icons.cleaning_services,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSectionCard(
                title: '系统设置',
                icon: Icons.settings_outlined,
                children: [
                  _buildSwitchSetting(
                    title: '保持屏幕常亮',
                    subtitle: '阅读时防止屏幕自动关闭',
                    value: _keepScreenOn,
                    onChanged: (value) => setState(() => _keepScreenOn = value),
                    icon: Icons.stay_current_portrait,
                  ),
                  _buildSwitchSetting(
                    title: '自动保存',
                    subtitle: '自动保存阅读进度',
                    value: _enableAutoSave,
                    onChanged: (value) =>
                        setState(() => _enableAutoSave = value),
                    icon: Icons.save_outlined,
                  ),
                  _buildSwitchSetting(
                    title: '电池优化',
                    subtitle: '启用省电模式',
                    value: _enableBatteryOptimization,
                    onChanged: (value) =>
                        setState(() => _enableBatteryOptimization = value),
                    icon: Icons.battery_saver,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildAboutCard(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle(ThemeNotifier themeNotifier, bool isDarkMode) {
    return _buildSwitchSetting(
      title: '夜间模式',
      subtitle: isDarkMode ? '当前为夜间模式' : '当前为日间模式',
      value: isDarkMode,
      onChanged: (value) => themeNotifier.toggleTheme(value),
      icon: isDarkMode ? Icons.dark_mode : Icons.light_mode,
    );
  }

  Widget _buildAppThemeSelector(ThemeNotifier themeNotifier) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAppThemeModal(themeNotifier),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    AppThemes.getThemeIcon(themeNotifier.currentAppTheme.name),
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '应用主题',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '当前: ${themeNotifier.currentAppTheme.displayName}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimationToggle() {
    return _buildSwitchSetting(
      title: '动画效果',
      subtitle: '开启页面切换动画',
      value: _enableAnimations,
      onChanged: (value) => setState(() => _enableAnimations = value),
      icon: Icons.animation,
    );
  }

  void _showAppThemeModal(ThemeNotifier themeNotifier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                // 拖拽指示条
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 标题
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Icon(
                        Icons.palette,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '选择应用主题',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // 主题网格
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: AppThemes.allThemes.length,
                    itemBuilder: (context, index) {
                      final theme = AppThemes.allThemes[index];
                      final isSelected =
                          theme.name == themeNotifier.currentAppTheme.name;

                      return GestureDetector(
                        onTap: () {
                          themeNotifier.setAppTheme(theme);
                          setModalState(() {});
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? theme.lightColorScheme.primary
                                  : Theme.of(context).colorScheme.outline
                                        .withValues(alpha: 0.2),
                              width: isSelected ? 3 : 1,
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                theme.lightColorScheme.primaryContainer,
                                theme.lightColorScheme.secondaryContainer,
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.lightColorScheme.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  AppThemes.getThemeIcon(theme.name),
                                  color: theme.lightColorScheme.primary,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                theme.displayName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: theme.lightColorScheme.onSurface,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(height: 8),
                                Icon(
                                  Icons.check_circle,
                                  color: theme.lightColorScheme.primary,
                                  size: 20,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // 底部按钮
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    16,
                    24,
                    MediaQuery.of(context).padding.bottom + 16,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSwitchSetting({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            onChanged(!value);
            _saveSettings();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: (newValue) {
                    onChanged(newValue);
                    _saveSettings();
                  },
                  activeTrackColor: Theme.of(context).colorScheme.primary,
                  thumbColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAboutCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.tertiary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.tertiary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '关于应用',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      Theme.of(
                        context,
                      ).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.auto_stories,
                        color: Theme.of(context).colorScheme.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '小元读书',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'v1.0.0',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '一款简洁高效的电子书阅读应用，支持多种格式和个性化设置，助您畅享阅读时光。',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAccentColorSelector(ThemeNotifier themeNotifier) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showCustomAccentColorModal(themeNotifier),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.tertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.color_lens,
                    size: 16,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '自定义强调色',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        (themeNotifier.currentAppTheme.name == 'custom' &&
                                themeNotifier.customAccentColor != null)
                            ? '已选择自定义颜色'
                            : '点击选择强调色',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (themeNotifier.currentAppTheme.name == 'custom' &&
                    themeNotifier.customAccentColor != null)
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: themeNotifier.customAccentColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                  ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCustomAccentColorModal(ThemeNotifier themeNotifier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.5,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                // 拖拽指示条
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 标题
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Icon(
                        Icons.color_lens,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '选择自定义强调色',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // 颜色网格
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1,
                          ),
                      itemCount: AppThemes.accentColors.length,
                      itemBuilder: (context, index) {
                        final color = AppThemes.accentColors[index];
                        final isSelected =
                            themeNotifier.currentAppTheme.name == 'custom' &&
                            themeNotifier.customAccentColor?.toARGB32() ==
                                color.toARGB32();
                        debugPrint(
                          '🎨 颜色 ${color.toString()} 选中状态: $isSelected',
                        );

                        return GestureDetector(
                          onTap: () {
                            debugPrint('🎨 用户选择了颜色: ${color.toString()}');
                            themeNotifier.setCustomAccentColor(color);
                            setModalState(() {});
                            // 关闭弹窗以立即看到效果
                            Navigator.pop(context);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: isSelected
                                ? Icon(
                                    Icons.check,
                                    color: color.computeLuminance() > 0.5
                                        ? Colors.black
                                        : Colors.white,
                                    size: 20,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // 底部按钮
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    16,
                    24,
                    MediaQuery.of(context).padding.bottom + 16,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 全局强调色选择器（与应用主题分离）
  Widget _buildGlobalAccentColorSelector(ThemeNotifier themeNotifier) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showGlobalAccentColorModal(themeNotifier),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.palette,
                    size: 16,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '全局强调色',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        themeNotifier.globalAccentColor != null
                            ? AppThemes.getAccentColorName(
                                themeNotifier.globalAccentColor!,
                              )
                            : '跟随系统',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (themeNotifier.globalAccentColor != null)
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: themeNotifier.globalAccentColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                  ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // WebDAV配置对话框
  Future<void> _showWebDavConfig() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const WebDavConfigDialog(),
    );

    if (result == true) {
      setState(() {});
    }
  }

  // 立即同步
  Future<void> _syncNow() async {
    setState(() {});

    try {
      final success = await _webdavService.syncBooks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '同步成功' : '同步失败'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 构建滑块设置
  Widget _buildSliderSetting({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required Function(double) onChanged,
    required IconData icon,
    String Function(double)? formatter,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            formatter?.call(value) ?? value.toStringAsFixed(1),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                onChanged: (newValue) {
                  onChanged(newValue);
                  _saveSettings();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建操作设置
  Widget _buildActionSetting({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required IconData icon,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.tertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ] else
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGlobalAccentColorModal(ThemeNotifier themeNotifier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                // 拖拽指示条
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 标题
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Icon(
                        Icons.palette,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '全局强调色',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    '设置应用界面的全局强调色，独立于阅读主题',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // 跟随系统选项
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        themeNotifier.setGlobalAccentColor(null);
                        setModalState(() {});
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: themeNotifier.globalAccentColor == null
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.outline.withValues(alpha: 0.3),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_mode,
                              color: themeNotifier.globalAccentColor == null
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '跟随系统',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color:
                                          themeNotifier.globalAccentColor ==
                                              null
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    '使用当前应用主题的默认强调色',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (themeNotifier.globalAccentColor == null)
                              Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 颜色网格
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.2,
                          ),
                      itemCount: AppThemes.accentColors.length,
                      itemBuilder: (context, index) {
                        final color = AppThemes.accentColors[index];
                        final isSelected =
                            themeNotifier.globalAccentColor?.toARGB32() ==
                            color.toARGB32();
                        final colorName = AppThemes.getAccentColorName(color);

                        return GestureDetector(
                          onTap: () {
                            themeNotifier.setGlobalAccentColor(color);
                            setModalState(() {});
                          },
                          child: Column(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onSurface
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: isSelected
                                      ? Icon(
                                          Icons.check,
                                          color: color.computeLuminance() > 0.5
                                              ? Colors.black
                                              : Colors.white,
                                          size: 20,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                colorName,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.8),
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // 底部按钮
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    16,
                    24,
                    MediaQuery.of(context).padding.bottom + 16,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 重新提取所有书籍封面
  Future<void> _refreshAllCovers() async {
    try {
      // 显示确认对话框
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('重新提取封面'),
          content: const Text('此操作将为所有书籍重新提取封面，可能需要较长时间。确定继续吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确定'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // TODO: 实现重新提取封面的逻辑
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('封面提取功能正在开发中...')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
    }
  }

  // 清理封面缓存
  Future<void> _cleanCoverCache() async {
    try {
      // TODO: 实现清理封面缓存的逻辑
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('缓存清理功能正在开发中...')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('清理失败: $e')));
    }
  }

  // 构建阅读引擎选择器
  Widget _buildReadingEngineSelector() {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showReadingEngineModal(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    _getReadingEngineIcon(_defaultReadingEngine),
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '默认阅读引擎',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _getReadingEngineName(_defaultReadingEngine),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 获取阅读引擎名称
  String _getReadingEngineName(String engine) {
    switch (engine) {
      case 'native':
        return 'Flutter原生阅读器 (最快)';
      case 'webview_optimized':
        return 'WebView优化版 (推荐)';
      case 'webview_standard':
        return 'WebView标准版 (完整功能)';
      default:
        return 'WebView优化版';
    }
  }

  // 获取阅读引擎图标
  IconData _getReadingEngineIcon(String engine) {
    switch (engine) {
      case 'native':
        return Icons.speed;
      case 'webview_optimized':
        return Icons.auto_fix_high;
      case 'webview_standard':
        return Icons.web;
      default:
        return Icons.auto_fix_high;
    }
  }

  // 显示阅读引擎选择对话框
  void _showReadingEngineModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.65,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                // 拖拽指示条
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 标题
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_stories,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '选择阅读引擎',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    '选择适合您的阅读方式，各引擎特点不同',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // 引擎选项
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      _buildEngineOption(
                        engine: 'webview_optimized',
                        title: 'WebView优化版',
                        subtitle: '性能优化，推荐使用',
                        description: '• 批量更新机制，减少卡顿\n• 保留完整功能\n• 适合日常阅读',
                        icon: Icons.auto_fix_high,
                        color: Colors.blue,
                        isRecommended: true,
                        setModalState: setModalState,
                      ),
                      const SizedBox(height: 16),
                      _buildEngineOption(
                        engine: 'native',
                        title: 'Flutter原生阅读器',
                        subtitle: '极致性能，启动最快',
                        description: '• 零WebView开销\n• 最佳性能表现\n• 主要支持TXT格式',
                        icon: Icons.speed,
                        color: Colors.green,
                        isRecommended: false,
                        setModalState: setModalState,
                      ),
                      const SizedBox(height: 16),
                      _buildEngineOption(
                        engine: 'webview_standard',
                        title: 'WebView标准版',
                        subtitle: '完整功能，稳定可靠',
                        description: '• 功能最完整\n• 支持所有格式\n• 资源占用较高',
                        icon: Icons.web,
                        color: Colors.orange,
                        isRecommended: false,
                        setModalState: setModalState,
                      ),
                    ],
                  ),
                ),
                // 底部按钮
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    16,
                    24,
                    MediaQuery.of(context).padding.bottom + 16,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 构建引擎选项
  Widget _buildEngineOption({
    required String engine,
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color color,
    required bool isRecommended,
    required StateSetter setModalState,
  }) {
    final isSelected = _defaultReadingEngine == engine;

    return GestureDetector(
      onTap: () {
        setState(() => _defaultReadingEngine = engine);
        setModalState(() {});
        _saveSettings();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          if (isRecommended) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '推荐',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: color, size: 24),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
