import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:xxread/models/book_source.dart';
import 'package:xxread/services/books/book_source_dao.dart';
import 'package:xxread/utils/fast_gbk_decoder.dart';

String normalizeBookSourceImportUrl(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('导入链接不能为空');
  }

  final decodedInput = _decodeRepeatedly(trimmed);
  final uri = Uri.tryParse(decodedInput);
  if (uri == null) {
    throw FormatException('无法识别导入链接: $trimmed');
  }

  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'http' || scheme == 'https') {
    return decodedInput;
  }

  if (scheme != 'legado') {
    throw const FormatException('仅支持 http/https 或 Legado 一键导入链接');
  }

  final pathSegments = uri.pathSegments.map((segment) => segment.toLowerCase());
  final isBookSourceImport =
      uri.host.toLowerCase() == 'import' && pathSegments.contains('booksource');
  if (!isBookSourceImport) {
    throw const FormatException('当前仅支持书源导入链接');
  }

  final src = uri.queryParameters['src']?.trim() ?? '';
  if (src.isEmpty) {
    throw const FormatException('导入链接缺少 src 参数');
  }

  final resolved = _decodeRepeatedly(src);
  final resolvedUri = Uri.tryParse(resolved);
  if (resolvedUri == null ||
      !(resolvedUri.scheme == 'http' || resolvedUri.scheme == 'https')) {
    throw FormatException('导入链接中的 src 无效: $resolved');
  }
  return resolved;
}

String decodeBookSourceImportPayload(
  List<int> bytes, {
  Map<String, String>? responseHeaders,
}) {
  if (bytes.isEmpty) return '';

  var effectiveBytes = Uint8List.fromList(bytes);
  if (effectiveBytes.length >= 3 &&
      effectiveBytes[0] == 0xEF &&
      effectiveBytes[1] == 0xBB &&
      effectiveBytes[2] == 0xBF) {
    effectiveBytes = Uint8List.sublistView(effectiveBytes, 3);
  }

  final explicitCharset = _extractCharset(responseHeaders);
  if (_isGbkCharset(explicitCharset)) {
    return sanitizeBookSourceImportPayload(
      decodeGbkFast(effectiveBytes, lenient: true),
    );
  }

  try {
    return sanitizeBookSourceImportPayload(utf8.decode(effectiveBytes));
  } catch (_) {
    if (_isGbkCharset(explicitCharset) || isLikelyValidGbkByteStream(effectiveBytes)) {
      return sanitizeBookSourceImportPayload(
        decodeGbkFast(effectiveBytes, lenient: true),
      );
    }
    return sanitizeBookSourceImportPayload(
      utf8.decode(effectiveBytes, allowMalformed: true),
    );
  }
}

String sanitizeBookSourceImportPayload(String rawText) {
  final normalized = _stripBom(rawText).trim();
  if (normalized.isEmpty) return '';

  if (_isValidJsonDocument(normalized)) {
    return normalized;
  }

  final preMatch = RegExp(
    r'<pre[^>]*>([\s\S]*?)</pre>',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (preMatch != null) {
    final candidate = _stripBom(preMatch.group(1) ?? '').trim();
    if (_isValidJsonDocument(candidate)) {
      return candidate;
    }
  }

  final listCandidate = _extractJsonCandidate(normalized, '[', ']');
  if (listCandidate != null) {
    return listCandidate;
  }

  final objectCandidate = _extractJsonCandidate(normalized, '{', '}');
  if (objectCandidate != null) {
    return objectCandidate;
  }

  return normalized;
}

String _decodeRepeatedly(String value) {
  var current = value.trim();
  for (var i = 0; i < 3; i++) {
    final decoded = Uri.decodeFull(current);
    if (decoded == current) {
      break;
    }
    current = decoded;
  }
  return current;
}

String? _extractJsonCandidate(String input, String startToken, String endToken) {
  final start = input.indexOf(startToken);
  final end = input.lastIndexOf(endToken);
  if (start < 0 || end <= start) {
    return null;
  }

  final candidate = input.substring(start, end + 1).trim();
  if (_isValidJsonDocument(candidate)) {
    return candidate;
  }
  return null;
}

bool _isValidJsonDocument(String text) {
  if (text.isEmpty) return false;
  final trimmed = text.trim();
  if (!(trimmed.startsWith('[') || trimmed.startsWith('{'))) {
    return false;
  }
  try {
    jsonDecode(trimmed);
    return true;
  } catch (_) {
    return false;
  }
}

String _stripBom(String value) {
  if (value.startsWith('\uFEFF')) {
    return value.substring(1);
  }
  return value;
}

String _extractCharset(Map<String, String>? headers) {
  if (headers == null || headers.isEmpty) return '';
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() != 'content-type') continue;
    final match = RegExp(
      r'charset\s*=\s*("?)([^;"\s]+)\1',
      caseSensitive: false,
    ).firstMatch(entry.value);
    if (match != null) {
      return match.group(2)?.trim().toLowerCase() ?? '';
    }
  }
  return '';
}

bool _isGbkCharset(String charset) {
  final normalized = charset.trim().toLowerCase();
  return normalized == 'gbk' ||
      normalized == 'gb2312' ||
      normalized == 'gb18030';
}

/// 书源业务服务
/// 提供书源管理、搜索、导入导出等功能
class BookSourceService {
  static BookSourceService? _instance;
  factory BookSourceService({http.Client? httpClient}) {
    if (httpClient != null) {
      return BookSourceService._internal(httpClient);
    }
    return _instance ??= BookSourceService._internal(http.Client());
  }
  BookSourceService._internal(this._httpClient);

  final http.Client _httpClient;

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
      final jsonData = jsonDecode(sanitizeBookSourceImportPayload(jsonString));
      final List<BookSource> sources = [];
      final List<String> errors = [];
      final Set<String> importedIds = <String>{};

      void parseAndCollect(dynamic rawEntry, String prefix) {
        if (rawEntry is! Map) {
          errors.add('$prefix 不是有效对象');
          return;
        }

        final normalizedEntry = rawEntry.map(
          (key, value) => MapEntry(key.toString(), value),
        );

        try {
          final parsed = BookSource.fromJson(normalizedEntry);
          final normalizedUrl = parsed.bookSourceUrl.trim();
          if (normalizedUrl.isEmpty) {
            errors.add('$prefix 缺少 bookSourceUrl');
            return;
          }

          final uri = Uri.tryParse(normalizedUrl);
          if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
            errors.add('$prefix bookSourceUrl 无效: $normalizedUrl');
            return;
          }

          final normalizedId =
              parsed.id.trim().isEmpty ? normalizedUrl : parsed.id.trim();
          if (importedIds.contains(normalizedId)) {
            errors.add('$prefix 与前面条目重复，已跳过: $normalizedId');
            return;
          }

          importedIds.add(normalizedId);
          sources.add(
            parsed.copyWith(
              id: normalizedId,
              bookSourceUrl: normalizedUrl,
              bookSourceName: parsed.bookSourceName.trim().isEmpty
                  ? uri.host
                  : parsed.bookSourceName.trim(),
            ),
          );
        } catch (e) {
          errors.add('$prefix 解析失败: $e');
        }
      }

      if (jsonData is List) {
        // 批量导入
        for (int i = 0; i < jsonData.length; i++) {
          parseAndCollect(jsonData[i], '第${i + 1}个书源');
        }
      } else if (jsonData is Map) {
        // 单个导入
        parseAndCollect(jsonData, '书源');
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
      final resolvedUrl = normalizeBookSourceImportUrl(url);
      final response = await _httpClient.get(
        Uri.parse(resolvedUrl),
        headers: {
          'User-Agent': 'XXRead/1.0',
          'Accept': 'application/json, text/plain',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonString = decodeBookSourceImportPayload(
          response.bodyBytes,
          responseHeaders: response.headers,
        );
        return await importFromJson(jsonString);
      } else {
        return ImportResult(
          success: 0,
          total: 0,
          errors: ['HTTP错误: ${response.statusCode}'],
        );
      }
    } on FormatException catch (e) {
      return ImportResult(success: 0, total: 0, errors: [e.message]);
    } catch (e) {
      return ImportResult(success: 0, total: 0, errors: ['网络错误: $e']);
    }
  }

  /// 从文件导入书源
  Future<ImportResult> importFromFile(File file) async {
    try {
      if (!await file.exists()) {
        return const ImportResult(
          success: 0,
          total: 0,
          errors: ['文件不存在'],
        );
      }

      final content = decodeBookSourceImportPayload(await file.readAsBytes());
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
        return const TestResult(
          success: false,
          message: '书源URL不能为空',
          responseTime: 0,
        );
      }

      final stopwatch = Stopwatch()..start();

      final response = await _httpClient.get(
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
