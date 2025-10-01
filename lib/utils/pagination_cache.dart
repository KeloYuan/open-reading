import 'dart:convert';
import 'package:flutter/material.dart';

/// 分页缓存管理器 - 多级缓存系统提升分页性能
class PaginationCache {
  static final PaginationCache _instance = PaginationCache._internal();
  factory PaginationCache() => _instance;
  PaginationCache._internal();

  // 分页结果缓存 - 基于内容哈希+设置指纹
  final Map<String, List<String>> _paginationCache = {};

  // 文本度量缓存 - 缓存字符宽度、行高计算
  final Map<String, TextMetrics> _metricsCache = {};

  // 布局缓存 - 缓存文本布局测量结果
  final Map<String, LayoutMeasurement> _layoutCache = {};

  // TextPainter池 - 复用TextPainter实例
  final List<TextPainter> _painterPool = [];
  static const int _maxPoolSize = 5;

  /// 生成设置指纹 - 用于缓存键
  String generateSettingsFingerprint({
    required double fontSize,
    required double lineSpacing,
    required double letterSpacing,
    required String fontFamily,
    required double horizontalPadding,
    required Size screenSize,
  }) {
    final settingsMap = {
      'fontSize': fontSize,
      'lineSpacing': lineSpacing,
      'letterSpacing': letterSpacing,
      'fontFamily': fontFamily,
      'horizontalPadding': horizontalPadding,
      'screenWidth': screenSize.width,
      'screenHeight': screenSize.height,
    };
    final settingsJson = jsonEncode(settingsMap);
    return _simpleHash(settingsJson);
  }

  /// 生成内容哈希
  String generateContentHash(String content) {
    if (content.length <= 1000) {
      // 短内容直接哈希
      return _simpleHash(content);
    } else {
      // 长内容采样哈希 - 性能优化
      final sample = content.substring(0, 500) +
                    content.substring(content.length ~/ 2 - 250, content.length ~/ 2 + 250) +
                    content.substring(content.length - 500);
      final sampleWithLength = '${content.length}:$sample';
      return _simpleHash(sampleWithLength);
    }
  }

  /// 简单哈希算法 - 用于生成缓存键
  String _simpleHash(String input) {
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = ((hash << 5) - hash + input.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// 获取缓存的分页结果
  List<String>? getCachedPagination({
    required String contentHash,
    required String settingsFingerprint,
  }) {
    final cacheKey = '${contentHash}_$settingsFingerprint';
    return _paginationCache[cacheKey];
  }

  /// 缓存分页结果
  void cachePagination({
    required String contentHash,
    required String settingsFingerprint,
    required List<String> pages,
  }) {
    final cacheKey = '${contentHash}_$settingsFingerprint';
    _paginationCache[cacheKey] = List.from(pages);

    // 限制缓存大小，避免内存泄漏
    if (_paginationCache.length > 20) {
      final oldestKey = _paginationCache.keys.first;
      _paginationCache.remove(oldestKey);
    }
  }

  /// 获取缓存的文本度量
  TextMetrics? getCachedMetrics(String metricsKey) {
    return _metricsCache[metricsKey];
  }

  /// 缓存文本度量
  void cacheMetrics(String metricsKey, TextMetrics metrics) {
    _metricsCache[metricsKey] = metrics;

    // 限制缓存大小
    if (_metricsCache.length > 50) {
      final oldestKey = _metricsCache.keys.first;
      _metricsCache.remove(oldestKey);
    }
  }

  /// 获取TextPainter实例（从池中获取或新建）
  TextPainter getTextPainter() {
    if (_painterPool.isNotEmpty) {
      return _painterPool.removeLast();
    }
    return TextPainter(textDirection: TextDirection.ltr);
  }

  /// 归还TextPainter到池中
  void returnTextPainter(TextPainter painter) {
    if (_painterPool.length < _maxPoolSize) {
      // 清理painter状态
      painter.text = null;
      _painterPool.add(painter);
    } else {
      // 池已满，销毁实例
      painter.dispose();
    }
  }

  /// 获取缓存的布局测量
  LayoutMeasurement? getCachedLayout(String layoutKey) {
    return _layoutCache[layoutKey];
  }

  /// 缓存布局测量结果
  void cacheLayout(String layoutKey, LayoutMeasurement measurement) {
    _layoutCache[layoutKey] = measurement;

    // 限制缓存大小
    if (_layoutCache.length > 100) {
      final oldestKey = _layoutCache.keys.first;
      _layoutCache.remove(oldestKey);
    }
  }

  /// 清理所有缓存
  void clearAllCaches() {
    _paginationCache.clear();
    _metricsCache.clear();
    _layoutCache.clear();

    // 清理TextPainter池
    for (final painter in _painterPool) {
      painter.dispose();
    }
    _painterPool.clear();
  }

  /// 获取缓存统计信息
  CacheStats getCacheStats() {
    return CacheStats(
      paginationCacheSize: _paginationCache.length,
      metricsCacheSize: _metricsCache.length,
      layoutCacheSize: _layoutCache.length,
      painterPoolSize: _painterPool.length,
    );
  }
}

/// 文本度量数据结构
class TextMetrics {
  final double avgCharWidth;
  final double avgLineHeight;
  final int charsPerLine;

  TextMetrics({
    required this.avgCharWidth,
    required this.avgLineHeight,
    required this.charsPerLine,
  });
}

/// 布局测量数据结构
class LayoutMeasurement {
  final double textWidth;
  final double textHeight;
  final int characterCount;

  LayoutMeasurement({
    required this.textWidth,
    required this.textHeight,
    required this.characterCount,
  });
}

/// 缓存统计信息
class CacheStats {
  final int paginationCacheSize;
  final int metricsCacheSize;
  final int layoutCacheSize;
  final int painterPoolSize;

  CacheStats({
    required this.paginationCacheSize,
    required this.metricsCacheSize,
    required this.layoutCacheSize,
    required this.painterPoolSize,
  });

  @override
  String toString() {
    return 'CacheStats(pagination: $paginationCacheSize, metrics: $metricsCacheSize, layout: $layoutCacheSize, pool: $painterPoolSize)';
  }
}