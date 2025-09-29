import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/book_source.dart';
import 'book_source_dao.dart';

/// 书源业务服务
/// 提供书源管理、搜索、导入导出等功能
class BookSourceService {
  static final BookSourceService _instance = BookSourceService._internal();
  factory BookSourceService() => _instance;
  BookSourceService._internal();

  /// 缓存的书源列表
  List<BookSource>? _cachedSources;

  /// 缓存的启用书源列表
  List<BookSource>? _cachedEnabledSources;

  /// 缓存过期时间（毫秒）
  static const int _cacheExpiry = 5 * 60 * 1000; // 5分钟

  /// 上次缓存更新时间
  int _lastCacheUpdate = 0;

  /// 获取所有书源
  Future<List<BookSource>> getAllSources() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final cacheExpired = (now - _lastCacheUpdate) > _cacheExpiry;

      _cachedSources ??= await BookSourceDao.getAll();

      if (_cachedEnabledSources == null || cacheExpired) {
        _cachedEnabledSources = await BookSourceDao.getEnabled();
      }

      _lastCacheUpdate = now;

      return _cachedSources ?? [];
    } catch (e) {
      debugPrint('获取书源失败: $e');
      return [];
    }
  }

  /// 获取启用的书源
  Future<List<BookSource>> getEnabledSources() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final cacheExpired = (now - _lastCacheUpdate) > _cacheExpiry;

      if (_cachedEnabledSources == null || cacheExpired) {
        _cachedEnabledSources = await BookSourceDao.getEnabled();
        _lastCacheUpdate = now;
      }

      return _cachedEnabledSources ?? [];
    } catch (e) {
      debugPrint('获取启用书源失败: $e');
      return [];
    }
  }

  /// 按类型获取书源
  Future<List<BookSource>> getSourcesByType(int type) async {
    try {
      return await BookSourceDao.getByType(type);
    } catch (e) {
      debugPrint('按类型获取书源失败: $e');
      return [];
    }
  }

  /// 按分组获取书源
  Future<List<BookSource>> getSourcesByGroup(String group) async {
    try {
      return await BookSourceDao.getByGroup(group);
    } catch (e) {
      debugPrint('按分组获取书源失败: $e');
      return [];
    }
  }

  /// 搜索书源
  Future<List<BookSource>> searchSources(String query) async {
    try {
      if (query.isEmpty) {
        return await getAllSources();
      }
      return await BookSourceDao.search(query);
    } catch (e) {
      debugPrint('搜索书源失败: $e');
      return [];
    }
  }

  /// 添加书源
  Future<bool> addSource(BookSource source) async {
    try {
      final result = await BookSourceDao.insert(source);
      if (result > 0) {
        _clearCache();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('添加书源失败: $e');
      return false;
    }
  }

  /// 批量添加书源
  Future<int> addSources(List<BookSource> sources) async {
    try {
      final result = await BookSourceDao.insertBatch(sources);
      if (result > 0) {
        _clearCache();
      }
      return result;
    } catch (e) {
      debugPrint('批量添加书源失败: $e');
      return 0;
    }
  }

  /// 更新书源
  Future<bool> updateSource(BookSource source) async {
    try {
      final result = await BookSourceDao.update(source);
      if (result > 0) {
        _clearCache();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('更新书源失败: $e');
      return false;
    }
  }

  /// 删除书源
  Future<bool> deleteSource(String id) async {
    try {
      final result = await BookSourceDao.delete(id);
      if (result > 0) {
        _clearCache();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('删除书源失败: $e');
      return false;
    }
  }

  /// 批量删除书源
  Future<int> deleteSources(List<String> ids) async {
    try {
      final result = await BookSourceDao.deleteBatch(ids);
      if (result > 0) {
        _clearCache();
      }
      return result;
    } catch (e) {
      debugPrint('批量删除书源失败: $e');
      return 0;
    }
  }

  /// 启用/禁用书源
  Future<bool> toggleSourceEnabled(String id, bool enabled) async {
    try {
      final result = await BookSourceDao.updateEnabled(id, enabled);
      if (result > 0) {
        _clearCache();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('切换书源状态失败: $e');
      return false;
    }
  }

  /// 启用/禁用书源发现功能
  Future<bool> toggleSourceExplore(String id, bool enabled) async {
    try {
      final result = await BookSourceDao.updateEnabledExplore(id, enabled);
      if (result > 0) {
        _clearCache();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('切换书源发现状态失败: $e');
      return false;
    }
  }

  /// 更新书源权重
  Future<bool> updateSourceWeight(String id, int weight) async {
    try {
      final result = await BookSourceDao.updateWeight(id, weight);
      if (result > 0) {
        _clearCache();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('更新书源权重失败: $e');
      return false;
    }
  }

  /// 获取书源统计信息
  Future<Map<String, int>> getStats() async {
    try {
      return await BookSourceDao.getStats();
    } catch (e) {
      debugPrint('获取书源统计失败: $e');
      return {};
    }
  }

  /// 获取所有分组
  Future<List<String>> getAllGroups() async {
    try {
      return await BookSourceDao.getAllGroups();
    } catch (e) {
      debugPrint('获取书源分组失败: $e');
      return [];
    }
  }

  /// 从JSON字符串导入书源
  Future<ImportResult> importFromJson(String jsonString) async {
    try {
      final jsonData = jsonDecode(jsonString);
      final List<BookSource> sources = [];
      final List<String> errors = [];

      if (jsonData is List) {
        // 批量导入
        for (int i = 0; i < jsonData.length; i++) {
          try {
            final source = BookSource.fromJson(jsonData[i]);
            sources.add(source);
          } catch (e) {
            errors.add('第${i + 1}个书源解析失败: $e');
          }
        }
      } else if (jsonData is Map<String, dynamic>) {
        // 单个导入
        try {
          final source = BookSource.fromJson(jsonData);
          sources.add(source);
        } catch (e) {
          errors.add('书源解析失败: $e');
        }
      } else {
        throw Exception('不支持的JSON格式');
      }

      if (sources.isEmpty) {
        return ImportResult(
          success: 0,
          total: 0,
          errors: errors.isEmpty ? ['没有找到有效的书源'] : errors,
        );
      }

      final successCount = await addSources(sources);

      return ImportResult(
        success: successCount,
        total: sources.length,
        errors: errors,
      );
    } catch (e) {
      return ImportResult(success: 0, total: 0, errors: ['导入失败: $e']);
    }
  }

  /// 从URL导入书源
  Future<ImportResult> importFromUrl(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'XXRead/1.0',
          'Accept': 'application/json, text/plain',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonString = utf8.decode(response.bodyBytes);
        return await importFromJson(jsonString);
      } else {
        return ImportResult(
          success: 0,
          total: 0,
          errors: ['HTTP错误: ${response.statusCode}'],
        );
      }
    } catch (e) {
      return ImportResult(success: 0, total: 0, errors: ['网络错误: $e']);
    }
  }

  /// 从文件导入书源
  Future<ImportResult> importFromFile(File file) async {
    try {
      if (!await file.exists()) {
        return ImportResult(success: 0, total: 0, errors: ['文件不存在']);
      }

      final content = await file.readAsString();
      return await importFromJson(content);
    } catch (e) {
      return ImportResult(success: 0, total: 0, errors: ['读取文件失败: $e']);
    }
  }

  /// 导出书源为JSON
  Future<String> exportToJson([List<String>? ids]) async {
    try {
      return await BookSourceDao.exportToJson(ids);
    } catch (e) {
      debugPrint('导出书源失败: $e');
      return '[]';
    }
  }

  /// 导出书源到文件
  Future<bool> exportToFile(File file, [List<String>? ids]) async {
    try {
      final jsonString = await exportToJson(ids);
      await file.writeAsString(jsonString);
      return true;
    } catch (e) {
      debugPrint('导出书源到文件失败: $e');
      return false;
    }
  }

  /// 测试书源连接
  Future<TestResult> testSource(BookSource source) async {
    try {
      if (source.bookSourceUrl.isEmpty) {
        return TestResult(
          success: false,
          message: '书源URL不能为空',
          responseTime: 0,
        );
      }

      final stopwatch = Stopwatch()..start();

      final response = await http.get(
        Uri.parse(source.bookSourceUrl),
        headers: {'User-Agent': 'XXRead/1.0', ...source.header},
      ).timeout(Duration(milliseconds: source.respondTime));

      stopwatch.stop();

      if (response.statusCode == 200) {
        return TestResult(
          success: true,
          message: '连接成功',
          responseTime: stopwatch.elapsedMilliseconds,
        );
      } else {
        return TestResult(
          success: false,
          message: 'HTTP ${response.statusCode}',
          responseTime: stopwatch.elapsedMilliseconds,
        );
      }
    } catch (e) {
      return TestResult(success: false, message: e.toString(), responseTime: 0);
    }
  }

  /// 清空所有书源
  Future<bool> deleteAllSources() async {
    try {
      final result = await BookSourceDao.deleteAll();
      if (result > 0) {
        _clearCache();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('清空书源失败: $e');
      return false;
    }
  }

  /// 验证书源规则
  ValidationResult validateSource(BookSource source) {
    final errors = <String>[];

    // 基础验证
    if (source.bookSourceName.isEmpty) {
      errors.add('书源名称不能为空');
    }

    if (source.bookSourceUrl.isEmpty) {
      errors.add('书源URL不能为空');
    } else {
      try {
        Uri.parse(source.bookSourceUrl);
      } catch (e) {
        errors.add('书源URL格式无效');
      }
    }

    // 搜索规则验证
    if (source.ruleSearch != null) {
      if (source.ruleSearch!.url.isEmpty) {
        errors.add('搜索URL不能为空');
      }
      if (source.ruleSearch!.bookList.isEmpty) {
        errors.add('书籍列表规则不能为空');
      }
      if (source.ruleSearch!.name.isEmpty) {
        errors.add('书名规则不能为空');
      }
    }

    // 发现规则验证
    if (source.enabledExplore && source.ruleExplore != null) {
      if (source.ruleExplore!.url.isEmpty) {
        errors.add('发现URL不能为空');
      }
    }

    // 目录规则验证
    if (source.ruleToc != null) {
      if (source.ruleToc!.chapterList.isEmpty) {
        errors.add('章节列表规则不能为空');
      }
      if (source.ruleToc!.chapterName.isEmpty) {
        errors.add('章节名称规则不能为空');
      }
      if (source.ruleToc!.chapterUrl.isEmpty) {
        errors.add('章节URL规则不能为空');
      }
    }

    // 正文规则验证
    if (source.ruleContent != null) {
      if (source.ruleContent!.content.isEmpty) {
        errors.add('正文规则不能为空');
      }
    }

    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }

  /// 清除缓存
  void _clearCache() {
    _cachedSources = null;
    _cachedEnabledSources = null;
    _lastCacheUpdate = 0;
  }

  /// 强制刷新缓存
  void refreshCache() {
    _clearCache();
  }
}

/// 导入结果
class ImportResult {
  /// 成功导入的数量
  final int success;

  /// 总数量
  final int total;

  /// 错误信息列表
  final List<String> errors;

  const ImportResult({
    required this.success,
    required this.total,
    required this.errors,
  });

  /// 是否完全成功
  bool get isFullSuccess => success == total && errors.isEmpty;

  /// 是否部分成功
  bool get isPartialSuccess => success > 0 && success < total;

  /// 是否完全失败
  bool get isFailure => success == 0;

  @override
  String toString() {
    return 'ImportResult{success: $success/$total, errors: ${errors.length}}';
  }
}

/// 测试结果
class TestResult {
  /// 是否成功
  final bool success;

  /// 消息
  final String message;

  /// 响应时间（毫秒）
  final int responseTime;

  const TestResult({
    required this.success,
    required this.message,
    required this.responseTime,
  });

  @override
  String toString() {
    return 'TestResult{success: $success, message: $message, time: ${responseTime}ms}';
  }
}

/// 验证结果
class ValidationResult {
  /// 是否有效
  final bool isValid;

  /// 错误信息列表
  final List<String> errors;

  const ValidationResult({required this.isValid, required this.errors});

  @override
  String toString() {
    return 'ValidationResult{valid: $isValid, errors: ${errors.length}}';
  }
}
