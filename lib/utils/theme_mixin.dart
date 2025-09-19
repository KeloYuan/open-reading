import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';

/// 主题助手 Mixin，为组件提供主题访问能力
mixin ThemeMixin<T extends StatefulWidget> on State<T> {
  /// 获取当前主题的强调色
  Color getAccentColor(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    return themeNotifier.currentAppTheme.lightColorScheme.primary;
  }

  /// 获取当前主题的文本颜色
  Color getTextColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.white.withValues(alpha:0.9)
        : Colors.black.withValues(alpha:0.8);
  }

  /// 获取当前主题的背景色
  Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  /// 获取当前主题的卡片颜色
  Color getCardColor(BuildContext context) {
    return Theme.of(context).cardColor;
  }

  /// 判断是否为深色模式
  bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// 获取ThemeNotifier实例
  ThemeNotifier getThemeNotifier(BuildContext context) {
    return Provider.of<ThemeNotifier>(context, listen: false);
  }
}

/// 主题监听Mixin，确保Widget能立即响应主题变化
mixin ThemeListenerMixin<T extends StatefulWidget> on State<T> {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateThemeState();
  }

  void _updateThemeState() {
    final brightness = Theme.of(context).brightness;
    final newIsDarkMode = brightness == Brightness.dark;

    if (_isDarkMode != newIsDarkMode) {
      _isDarkMode = newIsDarkMode;
      onThemeChanged(newIsDarkMode);
    }
  }

  /// 主题变化时的回调，子类可以重写此方法
  void onThemeChanged(bool isDarkMode) {
    // 默认实现，子类可以重写
  }

  /// 获取ThemeNotifier实例
  ThemeNotifier get themeNotifier =>
      Provider.of<ThemeNotifier>(context, listen: false);

  /// 监听ThemeNotifier的方法
  ThemeNotifier watchTheme() => Provider.of<ThemeNotifier>(context);
}

/// 用于无状态Widget的主题帮助类
class ThemeHelper {
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static ThemeNotifier getThemeNotifier(
    BuildContext context, {
    bool listen = true,
  }) {
    return Provider.of<ThemeNotifier>(context, listen: listen);
  }

  static void toggleTheme(BuildContext context, bool isDarkMode) {
    final themeNotifier = getThemeNotifier(context, listen: false);
    themeNotifier.toggleTheme(isDarkMode);
  }
}
