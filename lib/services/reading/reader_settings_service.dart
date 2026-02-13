import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/providers/reader_providers.dart';

/// 阅读器设置持久化服务
/// 使用SharedPreferences保存和加载用户的阅读设置
class ReaderSettingsService {
  static const String _keyFontSize = 'reader_font_size';
  static const String _keyLineHeight = 'reader_line_height';
  static const String _keyLetterSpacing = 'reader_letter_spacing';
  static const String _keyFirstLineIndent = 'reader_first_line_indent';
  static const String _keyHorizontalMargin = 'reader_horizontal_margin';
  static const String _keyTheme = 'reader_theme';
  static const String _keyPaginationMode = 'reader_pagination_mode';
  static const String _keyShowPageIndicator = 'reader_show_page_indicator';
  static const String _keyEnableTextSelection = 'reader_enable_text_selection';
  static const String _keyParagraphSpacing = 'reader_paragraph_spacing';
  static const String _keyFontFamily = 'reader_font_family';

  /// 保存设置到SharedPreferences
  static Future<void> saveSettings(ReaderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();

    await Future.wait([
      prefs.setDouble(_keyFontSize, settings.fontSize),
      prefs.setDouble(_keyLineHeight, settings.lineSpacing),
      prefs.setDouble(_keyLetterSpacing, settings.letterSpacing),
      prefs.setDouble(_keyFirstLineIndent, settings.firstLineIndent),
      prefs.setDouble(_keyHorizontalMargin, settings.horizontalMargin),
      prefs.setString(_keyTheme, settings.theme.name),
      prefs.setString(_keyPaginationMode, settings.paginationMode.name),
      prefs.setBool(_keyShowPageIndicator, settings.showPageIndicator),
      prefs.setBool(_keyEnableTextSelection, settings.enableTextSelection),
      prefs.setInt(_keyParagraphSpacing, settings.paragraphSpacing),
      if (settings.fontFamily != null && settings.fontFamily!.isNotEmpty)
        prefs.setString(_keyFontFamily, settings.fontFamily!)
      else
        prefs.remove(_keyFontFamily),
    ]);
  }

  /// 从SharedPreferences加载设置
  static Future<ReaderSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // 加载各项设置，如果不存在则使用默认值
    final fontSize = prefs.getDouble(_keyFontSize) ?? 18.0;
    final lineSpacing = prefs.getDouble(_keyLineHeight) ?? 1.8;
    final letterSpacing = prefs.getDouble(_keyLetterSpacing) ?? 0.2;
    final firstLineIndent = prefs.getDouble(_keyFirstLineIndent) ?? 2.0;
    final horizontalMargin = prefs.getDouble(_keyHorizontalMargin) ?? 20.0;
    final showPageIndicator = prefs.getBool(_keyShowPageIndicator) ?? true;
    final enableTextSelection = prefs.getBool(_keyEnableTextSelection) ?? true;
    final paragraphSpacing = prefs.getInt(_keyParagraphSpacing) ?? 0;
    final storedFontFamily = prefs.getString(_keyFontFamily);
    final fontFamily = (storedFontFamily == null ||
            storedFontFamily.isEmpty ||
            storedFontFamily == 'system')
        ? null
        : storedFontFamily;

    // 解析枚举类型
    final themeStr = prefs.getString(_keyTheme);
    final theme = themeStr != null
        ? ReadingTheme.values.firstWhere(
            (e) => e.name == themeStr,
            orElse: () => ReadingTheme.day,
          )
        : ReadingTheme.day;

    final paginationModeStr = prefs.getString(_keyPaginationMode);
    final paginationMode = paginationModeStr != null
        ? PaginationMode.values.firstWhere(
            (e) => e.name == paginationModeStr,
            orElse: () => PaginationMode.slide,
          )
        : PaginationMode.slide;

    return ReaderSettings(
      fontSize: fontSize,
      lineSpacing: lineSpacing,
      letterSpacing: letterSpacing,
      firstLineIndent: firstLineIndent,
      horizontalMargin: horizontalMargin,
      theme: theme,
      paginationMode: paginationMode,
      showPageIndicator: showPageIndicator,
      enableTextSelection: enableTextSelection,
      paragraphSpacing: paragraphSpacing,
      fontFamily: fontFamily,
    );
  }

  /// 清除所有设置（恢复默认）
  static Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await Future.wait([
      prefs.remove(_keyFontSize),
      prefs.remove(_keyLineHeight),
      prefs.remove(_keyLetterSpacing),
      prefs.remove(_keyFirstLineIndent),
      prefs.remove(_keyHorizontalMargin),
      prefs.remove(_keyTheme),
      prefs.remove(_keyPaginationMode),
      prefs.remove(_keyShowPageIndicator),
      prefs.remove(_keyEnableTextSelection),
      prefs.remove(_keyParagraphSpacing),
      prefs.remove(_keyFontFamily),
    ]);
  }
}
