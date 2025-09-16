import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';

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
