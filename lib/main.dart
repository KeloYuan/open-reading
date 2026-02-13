import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'l10n/app_localizations.dart';
import 'pages/home_shell_page.dart';
import 'pages/user_agreement_page.dart';
import 'services/books/book_services.dart';
import 'services/core/core_services.dart';
import 'services/reading/reading_services.dart';
import 'utils/app_themes.dart';
import 'services/tts_service.dart';
import 'package:path_provider/path_provider.dart';
import 'utils/glass_config.dart';
import 'utils/localization_extension.dart';
import 'utils/font_catalog_helper.dart';

void main() async {
  // 确保可以在 runApp 前安全调用 SystemChrome
  WidgetsFlutterBinding.ensureInitialized();

  // 🚀 启用120Hz高刷新率支持
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    // 检查并启用设备的最高刷新率
    SystemChrome.setApplicationSwitcherDescription(
      const ApplicationSwitcherDescription(
        label: '小元读书',
        primaryColor: 0xFF1976D2,
      ),
    );
  }

  // 在桌面平台上初始化 sqflite_common_ffi
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 设置基础系统UI样式 - 透明背景
  // 注意：不在这里设置SystemUiMode，让各页面根据需要自行控制
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // iOS: 状态栏图标为深色(适合白色背景)
      statusBarBrightness: Brightness.light, // iOS: 状态栏背景为浅色
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  runApp(
    ProviderScope(
      child: provider.MultiProvider(
        providers: [
          provider.ChangeNotifierProvider(create: (_) => ThemeNotifier()),
          provider.ChangeNotifierProvider(create: (_) => AppSettingsNotifier()),
          provider.ChangeNotifierProvider(create: (_) => TtsService()),
          provider.ChangeNotifierProvider(create: (_) => ShareService()),
        ],
        child: const XxReadApp(),
      ),
    ),
  );
}

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isInitialized = false;
  AppTheme _currentAppTheme = AppThemes.blueTheme; // 默认蓝色主题
  Color? _customAccentColor; // 存储自定义强调色
  Color? _globalAccentColor; // 全局强调色（与应用主题分离）

  ThemeMode get themeMode => _themeMode;
  bool get isInitialized => _isInitialized;
  AppTheme get currentAppTheme => _currentAppTheme;
  Color? get customAccentColor => _customAccentColor;
  Color? get globalAccentColor => _globalAccentColor;

  ThemeNotifier() {
    _loadTheme();
  }

  void _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool('isDarkMode');
    final appThemeName = prefs.getString('appTheme') ?? 'blue';
    final enableAnimations = prefs.getBool('enableAnimations') ?? true;
    final customColorValue = prefs.getInt('customAccentColor');
    final globalAccentColorValue = prefs.getInt('globalAccentColor');

    // 根据动画设置降低毛玻璃成本（提升流畅度）
    GlassEffectConfig.applyPerformanceMode(reduceEffects: !enableAnimations);

    if (isDarkMode == null) {
      // 首次启动，使用系统主题
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    }

    // 加载全局强调色
    if (globalAccentColorValue != null) {
      _globalAccentColor = Color(globalAccentColorValue);
      AppThemes.setGlobalAccentColor(_globalAccentColor);
    }

    // 加载应用主题
    if (appThemeName == 'custom' && customColorValue != null) {
      // 加载自定义主题
      _customAccentColor = Color(customColorValue);
      _currentAppTheme = AppThemes.createCustomTheme(_customAccentColor!);
      debugPrint('🎨 加载自定义主题: ${_customAccentColor.toString()}');
    } else {
      _customAccentColor = null;
      _currentAppTheme = AppThemes.getThemeByName(appThemeName);
      debugPrint('🎨 加载预设主题: ${_currentAppTheme.displayName}');
    }

    _isInitialized = true;
    notifyListeners();

    // 不在这里更新系统UI，让各页面自行控制
    // 避免与阅读页面的全屏模式冲突
  }

  void toggleTheme(bool isDarkMode) async {
    final newThemeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == newThemeMode) return; // 避免重复设置

    _themeMode = newThemeMode;

    // 立即通知监听器更新UI
    notifyListeners();

    // 不在这里更新系统栏样式，让各页面自行控制
    // 避免与阅读页面的全屏模式冲突

    // 异步保存设置
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }

  // 切换应用主题
  void setAppTheme(AppTheme theme) async {
    if (_currentAppTheme.name == theme.name) return; // 避免重复设置

    debugPrint('🎨 切换应用主题到: ${theme.displayName}');
    _currentAppTheme = theme;
    _customAccentColor = null; // 清除自定义强调色

    // 立即通知监听器更新UI
    notifyListeners();

    // 异步保存设置
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('appTheme', theme.name);
    await prefs.remove('customAccentColor'); // 移除自定义颜色设置
    debugPrint('🎨 主题已保存: ${theme.name}');
  }

  // 设置自定义强调色
  void setCustomAccentColor(Color color) async {
    debugPrint('🎨 设置自定义强调色: ${color.toString()}');

    // 清除可能冲突的全局强调色
    _globalAccentColor = null;
    AppThemes.setGlobalAccentColor(null);
    debugPrint('🎨 已清除全局强调色，避免冲突');

    _customAccentColor = color;
    final customTheme = AppThemes.createCustomTheme(color);

    _currentAppTheme = customTheme;
    debugPrint('🎨 当前主题已更新为: ${_currentAppTheme.displayName}');
    debugPrint(
      '🎨 自定义主题主色调: ${customTheme.lightColorScheme.primary.toString()}',
    );

    // 立即通知监听器更新UI
    notifyListeners();

    // 异步保存设置
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('appTheme', 'custom');
    await prefs.setInt('customAccentColor', color.toARGB32());
    await prefs.remove('globalAccentColor'); // 清除全局强调色设置
    debugPrint('🎨 自定义颜色已保存: ${color.toARGB32()}');
  }

  // 设置全局强调色（与应用主题分离）
  void setGlobalAccentColor(Color? color) async {
    if (_globalAccentColor == color) return; // 避免重复设置

    debugPrint('🎨 设置全局强调色: ${color?.toString() ?? "null (跟随主题)"}');
    _globalAccentColor = color;
    AppThemes.setGlobalAccentColor(color);

    // 立即通知监听器更新UI
    notifyListeners();

    // 异步保存设置
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (color != null) {
      await prefs.setInt('globalAccentColor', color.toARGB32());
    } else {
      await prefs.remove('globalAccentColor');
    }
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    // 不在这里更新系统UI，让各页面自行控制
    // 避免与阅读页面的全屏模式冲突

    // 保存设置
    _saveThemeMode(mode);
  }

  void _saveThemeMode(ThemeMode mode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.system) {
      await prefs.remove('isDarkMode');
    } else {
      await prefs.setBool('isDarkMode', mode == ThemeMode.dark);
    }
  }
}

class XxReadApp extends StatefulWidget {
  const XxReadApp({super.key});

  @override
  State<XxReadApp> createState() => _XxReadAppState();
}

class _XxReadAppState extends State<XxReadApp> {
  bool? _hasAcceptedAgreement;
  bool _isBootstrapped = false;
  String? _bootstrapError;

  @override
  void initState() {
    super.initState();
    _bootstrapServices();
    _checkAgreementStatus();
  }

  Future<void> _bootstrapServices() async {
    setState(() {
      _isBootstrapped = false;
      _bootstrapError = null;
    });

    // 🗄️ 初始化数据管理器
    debugPrint('🚀 开始初始化应用数据管理系统');
    try {
      await DataManager().initialize();
      debugPrint('✅ 数据管理系统初始化成功');
    } catch (e) {
      debugPrint('❌ 数据管理系统初始化失败: $e');
      if (mounted) {
        setState(() => _bootstrapError = '数据系统初始化失败');
      }
      return;
    }

    // 初始化阅读引擎协调器
    try {
      await ReadingEngineCoordinator().ensureInitialized();
      debugPrint('✅ 阅读引擎协调器已初始化');
    } catch (e) {
      debugPrint('❌ 阅读引擎协调器初始化失败: $e');
      if (mounted) {
        setState(() => _bootstrapError = '阅读引擎初始化失败');
      }
      return;
    }

    // 🖼️ 初始化图片管理器
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      await BookImageManager().initialize(appDocDir.path);
      debugPrint('✅ 图片管理器已初始化');
    } catch (e) {
      debugPrint('❌ 图片管理器初始化失败: $e');
      if (mounted) {
        setState(() => _bootstrapError = '图片管理器初始化失败');
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _isBootstrapped = true;
      _bootstrapError = null;
    });
  }

  /// 检查用户是否已同意协议
  Future<void> _checkAgreementStatus() async {
    final hasAccepted = await UserAgreementService.hasUserAcceptedAgreement();
    if (!mounted) return;
    setState(() {
      _hasAcceptedAgreement = hasAccepted;
    });
    debugPrint('📋 协议状态检查: ${hasAccepted ? "已同意" : "未同意"}');
  }

  /// 处理用户同意协议
  void _onAgreementAccepted() {
    setState(() {
      _hasAcceptedAgreement = true;
    });
    debugPrint('✅ 用户协议已同意，进入主应用');
  }

  /// 处理用户拒绝协议
  void _onAgreementRejected() {
    // 退出应用
    debugPrint('❌ 用户拒绝协议，退出应用');
    // 这里可以调用 SystemNavigator.pop() 或其他退出逻辑
    // SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return provider.Consumer2<ThemeNotifier, AppSettingsNotifier>(
      builder: (context, themeNotifier, appSettings, child) {
        // 不在这里更新系统UI，让各页面自行控制
        // 避免与阅读页面的全屏模式冲突

        return MaterialApp(
          onGenerateTitle: (context) => context.l10n.appTitle,
          debugShowCheckedModeBanner: false,
          // 🚀 启用高性能渲染，支持120Hz高刷新率
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            physics: const BouncingScrollPhysics(),
          ),
          theme: _buildLightTheme(
            themeNotifier.currentAppTheme,
            appSettings.appFontFamily,
          ),
          darkTheme: _buildDarkTheme(
            themeNotifier.currentAppTheme,
            appSettings.appFontFamily,
          ),
          themeMode: themeNotifier.themeMode,
          locale: appSettings.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => _buildHome(context),
          ),
          // 移除 builder 中的系统UI更新，让各页面自行控制
          // 避免与阅读页面的全屏模式冲突
        );
      },
    );
  }

  // 已移除未使用的 _getEffectiveThemeMode 方法

  /// 根据协议状态决定显示哪个页面
  Widget _buildHome(BuildContext context) {
    if (_bootstrapError != null) {
      return _buildBootstrapErrorPage(context);
    }

    // 如果还在初始化，显示加载页面
    if (!_isBootstrapped) {
      return _buildLoadingPage(context);
    }

    // 如果还在检查协议状态，显示加载页面
    if (_hasAcceptedAgreement == null) {
      return _buildLoadingPage(context);
    }

    // 如果未同意协议，显示协议页面
    if (!_hasAcceptedAgreement!) {
      return UserAgreementPage(
        onAgreed: _onAgreementAccepted,
        onDisagreed: _onAgreementRejected,
      );
    }

    // 已同意协议，显示主页面
    return const HomeShellPage();
  }

  Widget _buildBootstrapErrorPage(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.initializationFailed,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _bootstrapError ?? context.l10n.unknownError,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _bootstrapServices,
                child: Text(context.l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建加载页面
  Widget _buildLoadingPage(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.appTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 40),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ThemeData _buildLightTheme(AppTheme appTheme, String? appFontFamily) {
    ColorScheme colorScheme = appTheme.lightColorScheme;
    debugPrint('🎨 构建浅色主题 - 基础主题: ${appTheme.displayName}');
    debugPrint('🎨 基础主色调: ${colorScheme.primary.toString()}');

    // 如果有全局强调色，应用到color scheme
    final globalAccent = AppThemes.getGlobalAccentColor();
    if (globalAccent != null) {
      debugPrint('🎨 应用全局强调色 (浅色主题): ${globalAccent.toString()}');
      colorScheme = AppThemes.getColorSchemeWithAccent(
        colorScheme,
        globalAccent,
      );
      debugPrint('🎨 新的主要颜色: ${colorScheme.primary.toString()}');
    } else {
      debugPrint('🎨 没有全局强调色，使用主题默认色');
    }

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      fontFamily: appFontFamily,
      fontFamilyFallback: FontCatalog.appFallbacks(appFontFamily),
      // fontFamily: GoogleFonts.notoSansSc().fontFamily, // 中文字体支持
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: false,
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme(AppTheme appTheme, String? appFontFamily) {
    ColorScheme colorScheme = appTheme.darkColorScheme;

    // 如果有全局强调色，应用到color scheme
    final globalAccent = AppThemes.getGlobalAccentColor();
    if (globalAccent != null) {
      debugPrint('🎨 应用全局强调色 (深色主题): ${globalAccent.toString()}');
      colorScheme = AppThemes.getColorSchemeWithAccent(
        colorScheme,
        globalAccent,
      );
      debugPrint('🎨 新的主要颜色: ${colorScheme.primary.toString()}');
    }

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      fontFamily: appFontFamily,
      fontFamilyFallback: FontCatalog.appFallbacks(appFontFamily),
      // fontFamily: GoogleFonts.notoSansSc().fontFamily, // 中文字体支持
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: Colors.transparent,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: false,
        ),
      ),
    );
  }
}
