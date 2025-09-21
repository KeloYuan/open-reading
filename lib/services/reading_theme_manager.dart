import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 阅读主题管理器
/// 统一管理阅读器的所有主题元素，包括控制栏、菜单、对话框等
class ReadingThemeManager {
  static const String _themePreferenceKey = 'readingTheme';

  /// 获取当前阅读主题
  static Future<ReadingTheme> getCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString(_themePreferenceKey) ?? 'day';
    return ReadingThemes.getThemeByName(themeName);
  }

  /// 设置阅读主题
  static Future<void> setTheme(ReadingTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePreferenceKey, theme.name);
  }

  /// 创建统一的对话框主题
  static ThemeData createDialogTheme(ReadingTheme readingTheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: readingTheme.sliderActiveColor,
        brightness: _getBrightness(readingTheme),
        surface: readingTheme.controlBarColor,
        onSurface: readingTheme.controlBarTextColor,
        primary: readingTheme.sliderActiveColor,
        onPrimary: readingTheme.backgroundColor,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: readingTheme.controlBarColor,
        titleTextStyle: TextStyle(
          color: readingTheme.controlBarTextColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: readingTheme.controlBarTextColor.withValues(alpha: 0.8),
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: readingTheme.controlBarColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: readingTheme.sliderActiveColor,
        inactiveTrackColor: readingTheme.sliderInactiveColor,
        thumbColor: readingTheme.sliderActiveColor,
        overlayColor: readingTheme.sliderActiveColor.withValues(alpha: 0.2),
      ),
    );
  }

  /// 创建统一的控制栏样式
  static BoxDecoration createControlBarDecoration(ReadingTheme theme) {
    return BoxDecoration(
      color: theme.controlBarColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      boxShadow: [
        BoxShadow(
          color: theme.textColor.withValues(alpha: 0.1),
          blurRadius: 10,
          offset: const Offset(0, -2),
        ),
      ],
    );
  }

  /// 创建统一的顶部栏样式
  static BoxDecoration createTopBarDecoration(ReadingTheme theme) {
    return BoxDecoration(
      color: theme.controlBarColor,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      boxShadow: [
        BoxShadow(
          color: theme.textColor.withValues(alpha: 0.1),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// 创建统一的菜单项样式
  static ButtonStyle createMenuButtonStyle(ReadingTheme theme) {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.transparent,
      foregroundColor: theme.controlBarTextColor,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ).copyWith(
      overlayColor: WidgetStateProperty.all(
        theme.sliderActiveColor.withValues(alpha: 0.1),
      ),
    );
  }

  /// 创建统一的工具栏按钮样式
  static Widget createToolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ReadingTheme theme,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: isActive
            ? BoxDecoration(
                color: theme.sliderActiveColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive
                  ? theme.sliderActiveColor
                  : theme.controlBarTextColor,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? theme.sliderActiveColor
                    : theme.controlBarTextColor,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 创建统一的设置项样式
  static Widget createSettingItem({
    required String title,
    String? subtitle,
    required Widget trailing,
    required ReadingTheme theme,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            color: theme.controlBarTextColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  color: theme.controlBarTextColor.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              )
            : null,
        trailing: trailing,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// 创建统一的滑块样式
  static Widget createThemedSlider({
    required double value,
    required ValueChanged<double> onChanged,
    required ReadingTheme theme,
    double min = 0.0,
    double max = 1.0,
    int? divisions,
    String? label,
  }) {
    return SliderTheme(
      data: SliderThemeData(
        activeTrackColor: theme.sliderActiveColor,
        inactiveTrackColor: theme.sliderInactiveColor,
        thumbColor: theme.sliderActiveColor,
        overlayColor: theme.sliderActiveColor.withValues(alpha: 0.2),
        valueIndicatorColor: theme.sliderActiveColor,
        valueIndicatorTextStyle: TextStyle(
          color: theme.backgroundColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        trackHeight: 4.0,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
      ),
      child: Slider(
        value: value,
        onChanged: onChanged,
        min: min,
        max: max,
        divisions: divisions,
        label: label,
      ),
    );
  }

  /// 创建统一的开关样式
  static Widget createThemedSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
    required ReadingTheme theme,
  }) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: theme.sliderActiveColor,
      activeTrackColor: theme.sliderActiveColor.withValues(alpha: 0.3),
      inactiveThumbColor: theme.sliderInactiveColor,
      inactiveTrackColor: theme.sliderInactiveColor.withValues(alpha: 0.3),
    );
  }

  /// 创建统一的文本输入框样式
  static InputDecoration createTextFieldDecoration({
    required String hintText,
    required ReadingTheme theme,
    String? labelText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      suffixIcon: suffixIcon,
      labelStyle: TextStyle(color: theme.controlBarTextColor),
      hintStyle: TextStyle(
        color: theme.controlBarTextColor.withValues(alpha: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: theme.sliderInactiveColor),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: theme.sliderActiveColor),
        borderRadius: BorderRadius.circular(8),
      ),
      filled: true,
      fillColor: theme.backgroundColor.withValues(alpha: 0.5),
    );
  }

  /// 显示统一主题的对话框
  static Future<T?> showThemedDialog<T>({
    required BuildContext context,
    required ReadingTheme theme,
    required Widget child,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => Theme(data: createDialogTheme(theme), child: child),
    );
  }

  /// 显示统一主题的底部面板
  static Future<T?> showThemedBottomSheet<T>({
    required BuildContext context,
    required ReadingTheme theme,
    required Widget child,
    bool isScrollControlled = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: isScrollControlled,
      builder: (context) => Theme(
        data: createDialogTheme(theme),
        child: Container(
          decoration: createControlBarDecoration(theme),
          child: child,
        ),
      ),
    );
  }

  /// 获取主题亮度
  static Brightness _getBrightness(ReadingTheme theme) {
    // 计算背景颜色的亮度
    final luminance = theme.backgroundColor.computeLuminance();
    return luminance > 0.5 ? Brightness.light : Brightness.dark;
  }

  /// 创建主题预览卡片
  static Widget createThemePreviewCard({
    required ReadingTheme theme,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.sliderActiveColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 80,
            child: Column(
              children: [
                // 顶部栏区域
                Container(
                  height: 20,
                  color: theme.controlBarColor,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.controlBarTextColor.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 内容区域
                Expanded(
                  child: Container(
                    color: theme.backgroundColor,
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 3,
                          color: theme.textColor.withValues(alpha: 0.8),
                          margin: const EdgeInsets.only(bottom: 2),
                        ),
                        Container(
                          width: 60,
                          height: 3,
                          color: theme.textColor.withValues(alpha: 0.6),
                          margin: const EdgeInsets.only(bottom: 2),
                        ),
                        Container(
                          width: 80,
                          height: 3,
                          color: theme.textColor.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                  ),
                ),
                // 底部控制栏
                Container(
                  height: 20,
                  color: theme.controlBarColor,
                  child: Center(
                    child: Text(
                      theme.displayName,
                      style: TextStyle(
                        color: theme.controlBarTextColor,
                        fontSize: 8,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 扩展的阅读主题系统
class ReadingThemes {
  // 继承原有主题...
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

  static const ReadingTheme eyeProtectionTheme = ReadingTheme(
    name: 'eye_protection',
    displayName: '护眼',
    backgroundColor: Color(0xFFE8F5E8),
    textColor: Color(0xFF2E4A2E),
    controlBarColor: Color(0xFFDCE9DC),
    controlBarTextColor: Color(0xFF1B3A1B),
    iconColor: Color(0xFF4A6E4A),
    sliderActiveColor: Color(0xFF66BB6A),
    sliderInactiveColor: Color(0xFFC8E6C9),
  );

  static const ReadingTheme parchmentTheme = ReadingTheme(
    name: 'parchment',
    displayName: '羊皮纸',
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
    displayName: '棕褐色',
    backgroundColor: Color(0xFFFDF6E3),
    textColor: Color(0xFF5D4E37),
    controlBarColor: Color(0xFFEEE5D0),
    controlBarTextColor: Color(0xFF4A3E28),
    iconColor: Color(0xFF8B7355),
    sliderActiveColor: Color(0xFFCD853F),
    sliderInactiveColor: Color(0xFFF5DEB3),
  );

  static const List<ReadingTheme> allThemes = [
    dayTheme,
    nightTheme,
    eyeProtectionTheme,
    parchmentTheme,
    sepiaTheme,
  ];

  static ReadingTheme getThemeByName(String name) {
    return allThemes.firstWhere(
      (theme) => theme.name == name,
      orElse: () => dayTheme,
    );
  }
}

/// 阅读主题数据类
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

  ReadingTheme copyWith({
    String? name,
    String? displayName,
    Color? backgroundColor,
    Color? textColor,
    Color? controlBarColor,
    Color? controlBarTextColor,
    Color? iconColor,
    Color? sliderActiveColor,
    Color? sliderInactiveColor,
  }) {
    return ReadingTheme(
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      controlBarColor: controlBarColor ?? this.controlBarColor,
      controlBarTextColor: controlBarTextColor ?? this.controlBarTextColor,
      iconColor: iconColor ?? this.iconColor,
      sliderActiveColor: sliderActiveColor ?? this.sliderActiveColor,
      sliderInactiveColor: sliderInactiveColor ?? this.sliderInactiveColor,
    );
  }
}
