import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../utils/app_themes.dart';
import '../services/sync/webdav_sync_service.dart';
import '../services/reading_engine_coordinator.dart';
import '../services/pagination_cache_service.dart';
import '../widgets/side_toast.dart';
import '../services/book_dao.dart';
import '../widgets/webdav_config_dialog.dart';
import 'home_page_responsive.dart';

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
  // 只使用沉浸式阅读器，不需要引擎选择

  // 书源设置
  bool _enableBooksource = false;

  // WebDAV设置
  final WebDavSyncService _webdavService = WebDavSyncService();

  // 其他设置
  bool _enableBatteryOptimization = true;
  bool _enableFullscreen = false;
  String _language = 'zh-CN';

  // 开发者设置
  bool _enableDeveloperMode = false;
  bool _enableDebugLogging = false;
  bool _enablePerformanceMonitor = false;
  bool _enableMemoryStats = false;
  bool _showFPS = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    // 状态栏设置现在由_SettingsPageWrapper处理
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 状态栏设置现在由_SettingsPageWrapper处理，这里保持简洁
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
      _enableBooksource = prefs.getBool('enable_booksource') ?? false;
      _ttsSpeed = prefs.getDouble('ttsSpeed') ?? 0.5;
      _ttsVolume = prefs.getDouble('ttsVolume') ?? 1.0;
      _ttsPitch = prefs.getDouble('ttsPitch') ?? 1.0;

      // 阅读设置
      _enablePageAnimation = prefs.getBool('enablePageAnimation') ?? true;
      _enableVolumeKeyTurn = prefs.getBool('enableVolumeKeyTurn') ?? true;

      // 引擎选择相关配置已移除，只使用沉浸式阅读器

      // 其他设置
      _enableBatteryOptimization =
          prefs.getBool('enableBatteryOptimization') ?? true;
      _enableFullscreen = prefs.getBool('enableFullscreen') ?? false;
      _language = prefs.getString('language') ?? 'zh-CN';

      // 开发者设置
      _enableDeveloperMode = prefs.getBool('enableDeveloperMode') ?? false;
      _enableDebugLogging = prefs.getBool('enableDebugLogging') ?? false;
      _enablePerformanceMonitor =
          prefs.getBool('enablePerformanceMonitor') ?? false;
      _enableMemoryStats = prefs.getBool('enableMemoryStats') ?? false;
      _showFPS = prefs.getBool('showFPS') ?? false;
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
    await prefs.setBool('enable_booksource', _enableBooksource);
    await prefs.setDouble('ttsSpeed', _ttsSpeed);
    await prefs.setDouble('ttsVolume', _ttsVolume);
    await prefs.setDouble('ttsPitch', _ttsPitch);

    // 阅读设置
    await prefs.setBool('enablePageAnimation', _enablePageAnimation);
    await prefs.setBool('enableVolumeKeyTurn', _enableVolumeKeyTurn);
    // 引擎选择相关配置已移除，只使用沉浸式阅读器

    // 其他设置
    await prefs.setBool(
      'enableBatteryOptimization',
      _enableBatteryOptimization,
    );
    await prefs.setBool('enableFullscreen', _enableFullscreen);
    await prefs.setString('language', _language);

    // 开发者设置
    await prefs.setBool('enableDeveloperMode', _enableDeveloperMode);
    await prefs.setBool('enableDebugLogging', _enableDebugLogging);
    await prefs.setBool('enablePerformanceMonitor', _enablePerformanceMonitor);
    await prefs.setBool('enableMemoryStats', _enableMemoryStats);
    await prefs.setBool('showFPS', _showFPS);
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 检查是否在侧边导航栏模式下
    final navContext = NavigationContext.of(context);
    final useRailNavigation = navContext?.useRailNavigation ?? false;

    // 在侧边导航栏模式下，不显示 Scaffold 和 AppBar
    if (useRailNavigation) {
      return _buildContent(context, themeNotifier, isDarkMode);
    }

    // 手机模式：显示完整的 Scaffold + AppBar
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0, // 关闭系统AppBar，使用自绘毛玻璃顶栏
      ),
      body: _buildContent(context, themeNotifier, isDarkMode),
    );
  }

  // 提取页面内容部分，在两种模式下共用
  Widget _buildContent(BuildContext context, ThemeNotifier themeNotifier, bool isDarkMode) {
    return Container(
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
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.of(context).padding.top + 80, // 顶栏高度：状态栏 + 60
            16,
            16,
          ),
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
              ],
            ),
            const SizedBox(height: 20),
            _buildSectionCard(
              title: '书源功能',
              icon: Icons.source,
              children: [
                _buildSwitchSetting(
                  title: '启用书源功能',
                  subtitle: '开启在线书籍搜索和阅读功能',
                  value: _enableBooksource,
                  onChanged: (value) {
                    setState(() => _enableBooksource = value);
                    _saveSettings();
                    // 通知主页面刷新导航栏
                    _showRestartDialog();
                  },
                  icon: Icons.cloud_download,
                ),
                if (_enableBooksource) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.amber.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '启用书源功能后，可在导航栏中看到"书源"选项，支持在线书籍搜索和阅读。',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
                // WebDAV配置入口
                _buildActionSetting(
                  title: 'WebDAV配置',
                  subtitle: _webdavService.isConfigured
                      ? '已配置 - ${_webdavService.serverUrl}'
                      : '点击配置WebDAV服务器',
                  onTap: _showWebDavConfig,
                  icon: Icons.cloud,
                  trailing: _webdavService.isConfigured
                      ? Icon(Icons.check_circle, color: Colors.green, size: 20)
                      : null,
                ),

                // 同步功能说明
                if (_webdavService.isConfigured) ...[
                  // 同步状态和时间
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getSyncStatusIcon(_webdavService.status),
                              size: 16,
                              color: _getSyncStatusColor(_webdavService.status),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _webdavService.getStatusDescription(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _getSyncStatusColor(_webdavService.status),
                              ),
                            ),
                            const Spacer(),
                            if (_webdavService.lastSyncTime != null)
                              Text(
                                '上次: ${_formatSyncTime(_webdavService.lastSyncTime!)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 同步内容说明
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 14, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              '同步内容',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _buildSyncChip('书籍', Icons.book),
                            _buildSyncChip('书签', Icons.bookmark),
                            _buildSyncChip('笔记', Icons.note),
                            _buildSyncChip('进度', Icons.timeline),
                            _buildSyncChip('统计', Icons.bar_chart),
                            _buildSyncChip('书源', Icons.source),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 立即同步按钮
                  _buildActionSetting(
                    title: '立即同步',
                    subtitle: '手动同步所有阅读数据',
                    onTap: _syncNow,
                    icon: Icons.sync,
                  ),

                  // 书籍文件同步设置
                  _buildActionSetting(
                    title: '书籍文件同步',
                    subtitle: '选择需要上传到云端的书籍文件',
                    onTap: _showBookFileSyncDialog,
                    icon: Icons.upload_file,
                  ),
                ],
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
              title: '开发者设置',
              icon: Icons.developer_mode,
              children: [
                _buildSwitchSetting(
                  title: '开发者模式',
                  subtitle: '启用开发者功能和调试选项',
                  value: _enableDeveloperMode,
                  onChanged: (value) {
                    setState(() => _enableDeveloperMode = value);
                    _saveSettings();
                  },
                  icon: Icons.code,
                ),
                if (_enableDeveloperMode) ...[
                  _buildSwitchSetting(
                    title: '调试日志',
                    subtitle: '记录详细的应用运行日志',
                    value: _enableDebugLogging,
                    onChanged: (value) {
                      setState(() => _enableDebugLogging = value);
                      _saveSettings();
                    },
                    icon: Icons.bug_report,
                  ),
                  _buildSwitchSetting(
                    title: '性能监控',
                    subtitle: '显示阅读引擎性能指标',
                    value: _enablePerformanceMonitor,
                    onChanged: (value) {
                      setState(() => _enablePerformanceMonitor = value);
                      _saveSettings();
                    },
                    icon: Icons.analytics,
                  ),
                  _buildSwitchSetting(
                    title: '内存统计',
                    subtitle: '显示内存使用情况',
                    value: _enableMemoryStats,
                    onChanged: (value) {
                      setState(() => _enableMemoryStats = value);
                      _saveSettings();
                    },
                    icon: Icons.memory,
                  ),
                  _buildSwitchSetting(
                    title: '显示FPS',
                    subtitle: '在屏幕上显示帧率信息',
                    value: _showFPS,
                    onChanged: (value) {
                      setState(() => _showFPS = value);
                      _saveSettings();
                    },
                    icon: Icons.monitor,
                  ),
                  _buildActionSetting(
                    title: '缓存统计',
                    subtitle: '查看分页缓存使用情况',
                    onTap: _viewCacheStats,
                    icon: Icons.analytics,
                  ),
                  _buildActionSetting(
                    title: '清除所有缓存',
                    subtitle: '清除字体度量和分页缓存',
                    onTap: _clearAllCaches,
                    icon: Icons.clear_all,
                  ),
                  _buildActionSetting(
                    title: '重置引擎设置',
                    subtitle: '恢复阅读引擎到默认设置',
                    onTap: _resetEngineSettings,
                    icon: Icons.restore,
                  ),
                  const Divider(height: 32),
                  // 测试页面已删除
                  // _buildActionSetting(
                  //   title: '🧪 测试稳定分页器',
                  //   onTap: () {},
                  //   icon: Icons.science,
                  // ),
                ],
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
                  onChanged: (value) => setState(() => _enableAutoSave = value),
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
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
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
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // 主题网格
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
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
                                  : Theme.of(context)
                                      .colorScheme
                                      .outline
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
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.lightColorScheme.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  AppThemes.getThemeIcon(theme.name),
                                  color: theme.lightColorScheme.primary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                theme.displayName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: theme.lightColorScheme.onSurface,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(height: 6),
                                Icon(
                                  Icons.check_circle,
                                  color: theme.lightColorScheme.primary,
                                  size: 18,
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
                    12,
                    24,
                    MediaQuery.of(context).padding.bottom + 12,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                        '自定义主题强调色',
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
      final success = await _webdavService.manualSync();
      if (mounted) {
        showSideToast(context, success ? '同步成功' : '同步失败');
      }
    } catch (e) {
      if (mounted) {
        showSideToast(context, '同步失败: $e');
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
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            formatter?.call(value) ?? value.toStringAsFixed(1),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
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
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
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
                                      color: themeNotifier.globalAccentColor ==
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
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
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

      if (confirmed == true && mounted) {
        // TODO: 实现重新提取封面的逻辑
        showSideToast(context, '封面提取功能正在开发中...');
      }
    } catch (e) {
      if (mounted) {
        showSideToast(context, '操作失败: $e');
      }
    }
  }

  // 清理封面缓存
  Future<void> _cleanCoverCache() async {
    try {
      // TODO: 实现清理封面缓存的逻辑
      showSideToast(context, '缓存清理功能正在开发中...');
    } catch (e) {
      showSideToast(context, '清理失败: $e');
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
                    Icons.auto_stories,
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
                        '阅读引擎',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      Text(
                        '沉浸式阅读器',
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
                        engine: ReadingEngineType.immersive,
                        title: '沉浸式阅读器',
                        subtitle: '全新体验，推荐使用',
                        description:
                            '• 90%屏幕利用率\n• 三种翻页模式\n• TTS语音朗读\n• 流畅的阅读体验',
                        icon: Icons.auto_stories,
                        color: Colors.blue,
                        isRecommended: true,
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
    required ReadingEngineType engine,
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color color,
    required bool isRecommended,
    required StateSetter setModalState,
  }) {
    // 只有一个引擎，总是选中状态
    return GestureDetector(
      onTap: () {
        // 只有一个引擎，无需切换
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color,
            width: 2,
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

  void _showRestartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restart_alt, color: Colors.orange),
            SizedBox(width: 8),
            Text('需要重启应用'),
          ],
        ),
        content: const Text('书源功能的开启/关闭需要重启应用才能生效。\n\n是否现在重启应用？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 实现应用重启功能
              _showInfoSnackBar('请手动重启应用以应用设置');
            },
            child: const Text('重启'),
          ),
        ],
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    showSideToast(context, message);
  }

  /// 查看缓存统计
  void _viewCacheStats() async {
    try {
      final stats = await PaginationCacheService.getCacheStats();
      final count = stats['count'] ?? 0;
      final sizeMB = stats['totalSizeMB'] ?? '0.00';
      final oldest = stats['oldestCache'] as String?;
      final newest = stats['newestCache'] as String?;

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.analytics, color: Colors.blue),
              SizedBox(width: 8),
              Text('缓存统计'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatRow(Icons.file_copy, '缓存文件', '$count 个'),
              _buildStatRow(Icons.storage, '占用空间', '$sizeMB MB'),
              if (oldest != null)
                _buildStatRow(
                  Icons.access_time,
                  '最旧缓存',
                  _formatDateTime(oldest),
                ),
              if (newest != null)
                _buildStatRow(
                  Icons.new_releases,
                  '最新缓存',
                  _formatDateTime(newest),
                ),
              const Divider(),
              const Text(
                '提示：缓存会在30天后自动清理',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
            if (count > 0)
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await PaginationCacheService.clearExpiredCache();
                  if (!mounted) return;
                  _showInfoSnackBar('已清理过期缓存');
                },
                child: const Text('清理过期'),
              ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showInfoSnackBar('获取缓存统计失败: $e');
    }
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoString;
    }
  }

  /// 清除所有缓存（优化版：包含分页缓存）
  void _clearAllCaches() async {
    // 先获取缓存统计信息
    final stats = await PaginationCacheService.getCacheStats();
    final cacheCount = stats['count'] ?? 0;
    final cacheSizeMB = stats['totalSizeMB'] ?? '0';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.clear_all, color: Colors.orange),
            SizedBox(width: 8),
            Text('清除缓存'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('这将清除以下缓存数据：'),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.description, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text('分页缓存: $cacheCount 个文件 ($cacheSizeMB MB)'),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.font_download, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text('字体度量数据'),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '清除后首次打开书籍会重新分页，是否继续？',
              style: TextStyle(color: Colors.orange, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // 显示加载提示
                showSideToast(context, '正在清除缓存...');

                // 清除持久化分页缓存
                await PaginationCacheService.clearAllCache();

                // 清除SharedPreferences中的缓存
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('cached_font_metrics');
                await prefs.remove('cached_page_metrics');

                if (!mounted) return;

                // 显示成功消息
                _showInfoSnackBar('✅ 缓存已清除 ($cacheCount 个文件, $cacheSizeMB MB)');
              } catch (e) {
                if (!mounted) return;
                _showInfoSnackBar('清除缓存失败: $e');
              }
            },
            child: const Text('清除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 重置引擎设置
  void _resetEngineSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restore, color: Colors.red),
            SizedBox(width: 8),
            Text('重置设置'),
          ],
        ),
        content: const Text('这将重置阅读引擎到默认设置，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                // 只使用沉浸式阅读器，无需重置引擎
                _enablePerformanceMonitor = false;
                _enableDebugLogging = false;
                _enableMemoryStats = false;
                _showFPS = false;
              });
              await _saveSettings();
              _showInfoSnackBar('引擎设置已重置');
            },
            child: const Text('重置'),
          ),
        ],
      ),
    );
  }

  /// 同步状态图标
  IconData _getSyncStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return Icons.cloud_done;
      case SyncStatus.syncing:
        return Icons.sync;
      case SyncStatus.completed:
        return Icons.check_circle;
      case SyncStatus.failed:
        return Icons.error;
      case SyncStatus.noNetwork:
        return Icons.cloud_off;
      case SyncStatus.notConfigured:
        return Icons.cloud_queue;
    }
  }

  /// 同步状态颜色
  Color _getSyncStatusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return Colors.grey;
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.completed:
        return Colors.green;
      case SyncStatus.failed:
        return Colors.red;
      case SyncStatus.noNetwork:
        return Colors.orange;
      case SyncStatus.notConfigured:
        return Colors.grey;
    }
  }

  /// 格式化同步时间
  String _formatSyncTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${time.month}-${time.day}';
    }
  }

  /// 构建同步内容标签
  Widget _buildSyncChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 显示书籍文件同步选择对话框
  Future<void> _showBookFileSyncDialog() async {
    final selectedBooks = _webdavService.getBooksSelectedForSync();
    final bookDao = BookDao();
    final allBooks = await bookDao.getAllBooks();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedSet = <int>{...selectedBooks};

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.upload_file, color: Colors.blue),
                SizedBox(width: 8),
                Text('书籍文件同步'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 说明文字
                  const Text(
                    '选择需要上传到云端的书籍文件',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '书籍文件较大，建议仅选择重要书籍同步',
                            style: TextStyle(fontSize: 12, color: Colors.amber.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 全选/取消按钮
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          if (selectedSet.length == allBooks.length) {
                            selectedSet.clear();
                          } else {
                            selectedSet.addAll(allBooks.map((b) => b.id!));
                          }
                          setDialogState(() {});
                        },
                        icon: Icon(
                          selectedSet.length == allBooks.length
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 18,
                        ),
                        label: Text(
                          selectedSet.length == allBooks.length ? '取消全选' : '全选',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '已选: ${selectedSet.length}/${allBooks.length}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 书籍列表
                  SizedBox(
                    height: 300,
                    child: allBooks.isEmpty
                        ? const Center(
                            child: Text('暂无书籍'),
                          )
                        : ListView.builder(
                            itemCount: allBooks.length,
                            itemBuilder: (context, index) {
                              final book = allBooks[index];
                              final isSelected = selectedSet.contains(book.id);
                              final file = File(book.filePath);
                              final fileSize = file.existsSync()
                                  ? file.lengthSync()
                                  : 0;

                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (value) {
                                  if (value == true) {
                                    selectedSet.add(book.id!);
                                  } else {
                                    selectedSet.remove(book.id!);
                                  }
                                  setDialogState(() {});
                                },
                                title: Text(
                                  book.title,
                                  style: const TextStyle(fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      book.author,
                                      style: const TextStyle(fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (fileSize > 0)
                                      Text(
                                        _formatFileSize(fileSize),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                  ],
                                ),
                                secondary: book.coverImagePath != null &&
                                        book.coverImagePath!.isNotEmpty &&
                                        File(book.coverImagePath!).existsSync()
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.file(
                                          File(book.coverImagePath!),
                                          width: 40,
                                          height: 56,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Container(
                                        width: 40,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Icon(
                                          Icons.book,
                                          size: 20,
                                          color: Colors.grey,
                                        ),
                                      ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () async {
                  // 保存选择
                  for (final bookId in selectedSet) {
                    await _webdavService.setBookForSync(bookId, true);
                  }
                  setState(() {});
                  if (mounted) {
                    Navigator.pop(context);
                    _showInfoSnackBar('已选择 ${selectedSet.length} 本书籍进行文件同步');
                  }
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
    }
  }
}
