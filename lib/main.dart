import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// import 'package:google_fonts/google_fonts.dart';

import 'pages/home_page_responsive.dart';
import 'utils/app_themes.dart';
import 'services/tts_service.dart';
import 'services/share_service.dart';

void main() {
  // 确保可以在 runApp 前安全调用 SystemChrome
  WidgetsFlutterBinding.ensureInitialized();

  // 在桌面平台上初始化 sqflite_common_ffi
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 强制启用边到边沉浸式模式
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // 设置系统UI样式 - 完全透明沉浸式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // 强制设置沉浸式导航栏
  if (!kIsWeb && Platform.isAndroid) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => TtsService()),
        ChangeNotifierProvider(create: (_) => ShareService()),
      ],
      child: const XxReadApp(),
    ),
  );
}

// 使用Flutter内置的调试日志
void debugLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

// 动态更新系统栏样式的函数 - 强制沉浸式
void _updateSystemUIOverlay(bool isDarkMode) {
  // 确保在UI线程中执行
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // 首先重新启用边到边模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // 设置统一的系统UI样式
    final systemStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDarkMode
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    );

    // 立即应用样式
    SystemChrome.setSystemUIOverlayStyle(systemStyle);

    // Android特殊处理 - 确保导航栏设置生效
    if (!kIsWeb && Platform.isAndroid) {
      Future.delayed(const Duration(milliseconds: 50), () {
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: isDarkMode
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarContrastEnforced: false,
          ),
        );
      });
    }
  });
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
    final customColorValue = prefs.getInt('customAccentColor');
    final globalAccentColorValue = prefs.getInt('globalAccentColor');

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
    } else {
      _customAccentColor = null;
      _currentAppTheme = AppThemes.getThemeByName(appThemeName);
    }

    _isInitialized = true;
    notifyListeners();

    // 加载主题后立即更新系统UI
    _updateSystemUIOverlayForCurrentTheme();
  }

  void toggleTheme(bool isDarkMode) async {
    final newThemeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == newThemeMode) return; // 避免重复设置

    _themeMode = newThemeMode;

    // 立即通知监听器更新UI
    notifyListeners();

    // 立即更新系统栏样式
    _updateSystemUIOverlay(isDarkMode);

    // 异步保存设置
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }

  // 切换应用主题
  void setAppTheme(AppTheme theme) async {
    if (_currentAppTheme.name == theme.name) return; // 避免重复设置

    _currentAppTheme = theme;
    _customAccentColor = null; // 清除自定义强调色

    // 立即通知监听器更新UI
    notifyListeners();

    // 异步保存设置
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('appTheme', theme.name);
    await prefs.remove('customAccentColor'); // 移除自定义颜色设置
  }

  // 设置自定义强调色
  void setCustomAccentColor(Color color) async {
    _customAccentColor = color;
    final customTheme = AppThemes.createCustomTheme(color);

    _currentAppTheme = customTheme;

    // 立即通知监听器更新UI
    notifyListeners();

    // 异步保存设置
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('appTheme', 'custom');
    await prefs.setInt('customAccentColor', color.toARGB32());
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

    // 立即更新系统UI
    _updateSystemUIOverlayForCurrentTheme();

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

  void _updateSystemUIOverlayForCurrentTheme() {
    final isDarkMode = _themeMode == ThemeMode.dark;
    _updateSystemUIOverlay(isDarkMode);
  }
}

class XxReadApp extends StatelessWidget {
  const XxReadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        // 获取当前实际的主题模式
        final effectiveThemeMode = _getEffectiveThemeMode(
          context,
          themeNotifier,
        );
        final isDarkMode = effectiveThemeMode == ThemeMode.dark;

        // 只有在初始化完成后才更新系统UI
        if (themeNotifier.isInitialized) {
          // 立即同步系统UI样式
          _updateSystemUIOverlay(isDarkMode);
        }

        return MaterialApp(
          title: '小元读书',
          debugShowCheckedModeBanner: false,
          theme: _buildLightTheme(themeNotifier.currentAppTheme),
          darkTheme: _buildDarkTheme(themeNotifier.currentAppTheme),
          themeMode: themeNotifier.themeMode,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('zh')],
          home: const HomePageResponsive(),
          builder: (context, child) {
            // 确保在每次构建时都同步系统UI
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final currentIsDarkMode =
                  Theme.of(context).brightness == Brightness.dark;
              _updateSystemUIOverlay(currentIsDarkMode);
            });
            return child!;
          },
        );
      },
    );
  }

  ThemeMode _getEffectiveThemeMode(
    BuildContext context,
    ThemeNotifier notifier,
  ) {
    if (notifier.themeMode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light;
    }
    return notifier.themeMode;
  }

  ThemeData _buildLightTheme(AppTheme appTheme) {
    ColorScheme colorScheme = appTheme.lightColorScheme;

    // 如果有全局强调色，应用到color scheme
    final globalAccent = AppThemes.getGlobalAccentColor();
    if (globalAccent != null) {
      debugPrint('🎨 应用全局强调色 (浅色主题): ${globalAccent.toString()}');
      colorScheme = AppThemes.getColorSchemeWithAccent(
        colorScheme,
        globalAccent,
      );
      debugPrint('🎨 新的主要颜色: ${colorScheme.primary.toString()}');
    }

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      // fontFamily: GoogleFonts.notoSansSc().fontFamily, // 中文字体支持
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme(AppTheme appTheme) {
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
      // fontFamily: GoogleFonts.notoSansSc().fontFamily, // 中文字体支持
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
    );
  }
}
