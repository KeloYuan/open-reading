import 'package:flutter/material.dart';
import '../models/text_page_data.dart';

/// 精确文本测量器
/// 高精度文本测量器
/// 提供字符级别的精确测量和分页功能
class PreciseTextMeasurer {
  /// 文本画笔缓存
  static final Map<String, TextPainter> _painterCache = {};

  /// 字符宽度缓存（按字体样式分组）
  static final Map<String, Map<String, double>> _charWidthCache = {};

  /// 最大缓存数量
  static const int _maxCacheSize = 1000;

  /// 测量单个字符的精确尺寸
  ///
  /// [char] 要测量的字符
  /// [style] 文本样式
  /// [context] 构建上下文（用于获取设备像素比等）
  ///
  /// Returns: 字符的字体度量信息
  static FontMetrics measureCharacter(
    String char,
    TextStyle style,
    BuildContext? context,
  ) {
    // 生成缓存键
    final cacheKey = _generateStyleKey(style);

    // 检查字符宽度缓存
    final charCache = _charWidthCache[cacheKey];
    if (charCache != null && charCache.containsKey(char)) {
      final width = charCache[char]!;
      // 从缓存中获取其他度量信息（简化版本）
      final fontSize = style.fontSize ?? 16.0;
      return FontMetrics(
        width: width,
        height: fontSize * (style.height ?? 1.0),
        ascent: fontSize * 0.75,
        descent: fontSize * 0.25,
        leading: 0.0,
      );
    }

    // 创建文本画笔
    final textPainter = _getOrCreateTextPainter(style);
    textPainter.text = TextSpan(text: char, style: style);

    // 布局文本
    textPainter.layout();

    // 获取精确度量
    final width = textPainter.width;
    final height = textPainter.height;

    // 获取字体度量信息
    final fontSize = style.fontSize ?? 16.0;
    final lineHeight = style.height ?? 1.0;

    // 计算基线信息（基于TextPainter的度量）
    final ascent = textPainter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final descent = height - ascent;
    final leading = (fontSize * lineHeight) - fontSize;

    // 缓存字符宽度
    _cacheCharWidth(cacheKey, char, width);

    return FontMetrics(
      width: width,
      height: height,
      ascent: ascent,
      descent: descent,
      leading: leading,
    );
  }

  /// 测量文本字符串中每个字符的宽度
  ///
  /// [text] 要测量的文本
  /// [style] 文本样式
  /// [context] 构建上下文
  ///
  /// Returns: 每个字符的宽度列表
  static List<double> measureCharacterWidths(
    String text,
    TextStyle style,
    BuildContext? context,
  ) {
    final widths = <double>[];
    final cacheKey = _generateStyleKey(style);

    // 获取或创建字符宽度缓存
    final charCache = _charWidthCache.putIfAbsent(
      cacheKey,
      () => <String, double>{},
    );

    // 批量处理未缓存的字符
    final uncachedChars = <String>[];
    final uncachedIndices = <int>[];

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (!charCache.containsKey(char)) {
        uncachedChars.add(char);
        uncachedIndices.add(i);
      }
    }

    // 批量测量未缓存的字符
    if (uncachedChars.isNotEmpty) {
      _batchMeasureChars(uncachedChars, style, cacheKey);
    }

    // 构建宽度列表
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final width = charCache[char] ?? _measureSingleChar(char, style);
      widths.add(width);

      // 确保新测量的字符也被缓存
      if (!charCache.containsKey(char)) {
        charCache[char] = width;
      }
    }

    return widths;
  }

  /// 处理Unicode组合字符和emoji
  ///
  /// [text] 输入文本
  ///
  /// Returns: 分解后的字符集群列表
  static List<String> splitTextClusters(String text) {
    final clusters = <String>[];
    final runes = text.runes.toList();

    int i = 0;
    while (i < runes.length) {
      final currentRune = runes[i];

      // 检查是否为组合字符序列的开始
      if (_isModifierBase(currentRune)) {
        String cluster = String.fromCharCode(currentRune);
        i++;

        // 收集所有修饰符字符
        while (i < runes.length && _isModifier(runes[i])) {
          cluster += String.fromCharCode(runes[i]);
          i++;
        }

        clusters.add(cluster);
      } else if (_isEmoji(currentRune)) {
        // 处理emoji序列
        String cluster = String.fromCharCode(currentRune);
        i++;

        // 检查后续的emoji修饰符和零宽连接符
        while (i < runes.length &&
            (_isEmojiModifier(runes[i]) || _isZWJ(runes[i]))) {
          cluster += String.fromCharCode(runes[i]);
          i++;

          // 如果是ZWJ，还需要包含下一个字符
          if (i < runes.length && _isZWJ(runes[i - 1])) {
            cluster += String.fromCharCode(runes[i]);
            i++;
          }
        }

        clusters.add(cluster);
      } else {
        // 普通字符
        clusters.add(String.fromCharCode(currentRune));
        i++;
      }
    }

    return clusters;
  }

  /// 计算文本在指定宽度内的换行点
  ///
  /// [text] 要计算的文本
  /// [style] 文本样式
  /// [maxWidth] 最大宽度
  /// [context] 构建上下文
  ///
  /// Returns: 换行点的字符索引列表
  static List<int> calculateLineBreaks(
    String text,
    TextStyle style,
    double maxWidth,
    BuildContext? context,
  ) {
    final breakPoints = <int>[];
    final charWidths = measureCharacterWidths(text, style, context);

    double currentWidth = 0.0;
    int lastBreakableIndex = -1;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final charWidth = charWidths[i];

      // 更新当前行宽度
      currentWidth += charWidth;

      // 检查是否为可换行位置
      if (_isBreakableChar(char)) {
        lastBreakableIndex = i;
      }

      // 检查是否超出最大宽度
      if (currentWidth > maxWidth) {
        if (lastBreakableIndex > 0 &&
            lastBreakableIndex >
                (breakPoints.isNotEmpty ? breakPoints.last : -1)) {
          // 在最后的可换行位置断行
          breakPoints.add(lastBreakableIndex + 1);

          // 重新计算剩余文本的宽度
          currentWidth = 0.0;
          for (int j = lastBreakableIndex + 1; j <= i; j++) {
            currentWidth += charWidths[j];
          }
        } else {
          // 强制在当前位置断行
          breakPoints.add(i);
          currentWidth = charWidth;
        }

        lastBreakableIndex = -1;
      }
    }

    return breakPoints;
  }

  /// 获取或创建文本画笔
  static TextPainter _getOrCreateTextPainter(TextStyle style) {
    final key = _generateStyleKey(style);

    return _painterCache.putIfAbsent(key, () {
      return TextPainter(
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.left,
      );
    });
  }

  /// 生成样式缓存键
  static String _generateStyleKey(TextStyle style) {
    return '${style.fontSize}_${style.fontFamily}_${style.fontWeight?.index}_${style.letterSpacing}_${style.height}';
  }

  /// 缓存字符宽度
  static void _cacheCharWidth(String styleKey, String char, double width) {
    final cache = _charWidthCache.putIfAbsent(
      styleKey,
      () => <String, double>{},
    );

    // 控制缓存大小
    if (cache.length >= _maxCacheSize) {
      // 移除一些旧条目（简单LRU）
      final keysToRemove = cache.keys.take(cache.length ~/ 4).toList();
      for (final key in keysToRemove) {
        cache.remove(key);
      }
    }

    cache[char] = width;
  }

  /// 批量测量字符
  static void _batchMeasureChars(
    List<String> chars,
    TextStyle style,
    String cacheKey,
  ) {
    if (chars.isEmpty) return;

    final textPainter = _getOrCreateTextPainter(style);
    final cache = _charWidthCache[cacheKey]!;

    // 为每个字符创建单独的测量
    for (final char in chars) {
      textPainter.text = TextSpan(text: char, style: style);
      textPainter.layout();
      cache[char] = textPainter.width;
    }
  }

  /// 测量单个字符（回退方法）
  static double _measureSingleChar(String char, TextStyle style) {
    final textPainter = _getOrCreateTextPainter(style);
    textPainter.text = TextSpan(text: char, style: style);
    textPainter.layout();
    return textPainter.width;
  }

  /// 检查是否为修饰符基础字符
  static bool _isModifierBase(int rune) {
    // Unicode修饰符基础字符范围（简化版本）
    return (rune >= 0x0300 && rune <= 0x036F) || // 组合变音符号
        (rune >= 0x1AB0 && rune <= 0x1AFF) || // 组合变音符号扩展
        (rune >= 0x1DC0 && rune <= 0x1DFF); // 组合变音符号补充
  }

  /// 检查是否为修饰符
  static bool _isModifier(int rune) {
    return (rune >= 0x0300 && rune <= 0x036F) || // 组合变音符号
        (rune >= 0xFE20 && rune <= 0xFE2F); // 半角和全角形式的组合符
  }

  /// 检查是否为emoji字符
  static bool _isEmoji(int rune) {
    return (rune >= 0x1F600 && rune <= 0x1F64F) || // 表情符号
        (rune >= 0x1F300 && rune <= 0x1F5FF) || // 其他符号和象形文字
        (rune >= 0x1F680 && rune <= 0x1F6FF) || // 交通和地图符号
        (rune >= 0x2600 && rune <= 0x26FF) || // 其他符号
        (rune >= 0x2700 && rune <= 0x27BF); // 装饰符号
  }

  /// 检查是否为emoji修饰符
  static bool _isEmojiModifier(int rune) {
    return (rune >= 0x1F3FB && rune <= 0x1F3FF); // Emoji肤色修饰符
  }

  /// 检查是否为零宽连接符
  static bool _isZWJ(int rune) {
    return rune == 0x200D;
  }

  /// 检查是否为可换行字符
  static bool _isBreakableChar(String char) {
    // 空格、标点符号等可换行字符
    return char == ' ' ||
        char == '\t' ||
        char == '\n' ||
        char == '，' ||
        char == '。' ||
        char == '！' ||
        char == '？' ||
        char == '；' ||
        char == '：' ||
        char == '、' ||
        RegExp(r'[.!?,:;]').hasMatch(char);
  }

  /// 清理缓存
  static void clearCache() {
    _painterCache.clear();
    _charWidthCache.clear();
  }

  /// 获取缓存统计信息
  static Map<String, dynamic> getCacheStats() {
    int totalCharsCached = 0;
    for (final cache in _charWidthCache.values) {
      totalCharsCached += cache.length;
    }

    return {
      'painterCacheSize': _painterCache.length,
      'styleCacheCount': _charWidthCache.length,
      'totalCharsCached': totalCharsCached,
      'maxCacheSize': _maxCacheSize,
    };
  }
}

/// 文本测量配置
/// 用于配置测量行为和优化选项
class TextMeasureConfig {
  /// 是否启用字符宽度缓存
  final bool enableCharWidthCache;

  /// 是否启用文本画笔缓存
  final bool enablePainterCache;

  /// 最大缓存大小
  final int maxCacheSize;

  /// 是否使用设备像素比进行精确测量
  final bool useDevicePixelRatio;

  /// 是否处理Unicode组合字符
  final bool handleComplexChars;

  const TextMeasureConfig({
    this.enableCharWidthCache = true,
    this.enablePainterCache = true,
    this.maxCacheSize = 1000,
    this.useDevicePixelRatio = false,
    this.handleComplexChars = true,
  });

  /// 默认配置
  static const TextMeasureConfig defaultConfig = TextMeasureConfig();

  /// 高性能配置（启用所有缓存和优化）
  static const TextMeasureConfig highPerformance = TextMeasureConfig(
    enableCharWidthCache: true,
    enablePainterCache: true,
    maxCacheSize: 2000,
    useDevicePixelRatio: true,
    handleComplexChars: true,
  );

  /// 低内存配置（减少缓存使用）
  static const TextMeasureConfig lowMemory = TextMeasureConfig(
    enableCharWidthCache: true,
    enablePainterCache: false,
    maxCacheSize: 500,
    useDevicePixelRatio: false,
    handleComplexChars: false,
  );
}
