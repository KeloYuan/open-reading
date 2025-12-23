import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

/// 优化的文件读取器
///
/// 提供高效的文件读取功能，包括：
/// - 流式读取大文件
/// - 智能缓存策略
/// - 并发读取控制
/// - 进度回调
class OptimizedFileReader {
  // 单例模式
  static final OptimizedFileReader _instance = OptimizedFileReader._internal();
  factory OptimizedFileReader() => _instance;
  OptimizedFileReader._internal();

  // 配置常量
  static const int _defaultBufferSize = 64 * 1024; // 64KB
  static const int _maxMemorySize = 10 * 1024 * 1024; // 10MB
  static const int _maxConcurrentReads = 3;
  static const Duration _readTimeout = Duration(seconds: 30);

  // 缓存管理
  final Map<String, FileCache> _fileCache = {};
  final Map<String, Completer<Uint8List>> _readingOperations = {};
  int _currentReads = 0;
  final Queue<Completer<void>> _readQueue = Queue();

  /// 读取文件内容（字符串）
  ///
  /// [filePath] 文件路径
  /// [encoding] 文本编码，默认UTF-8
  /// [bufferSize] 缓冲区大小
  /// [progressCallback] 进度回调
  Future<String> readFileAsString(
    String filePath, {
    Encoding encoding = utf8,
    int bufferSize = _defaultBufferSize,
    Function(double progress)? progressCallback,
  }) async {
    final bytes = await readFileAsBytes(
      filePath,
      bufferSize: bufferSize,
      progressCallback: progressCallback,
    );
    return encoding.decode(bytes);
  }

  /// 读取文件内容（字节数组）
  ///
  /// [filePath] 文件路径
  /// [bufferSize] 缓冲区大小
  /// [progressCallback] 进度回调
  Future<Uint8List> readFileAsBytes(
    String filePath, {
    int bufferSize = _defaultBufferSize,
    Function(double progress)? progressCallback,
  }) async {
    // 检查缓存
    final cache = _fileCache[filePath];
    if (cache != null && cache.isValid) {
      debugPrint('📦 从缓存读取文件: $filePath');
      return cache.data;
    }

    // 检查是否正在读取
    if (_readingOperations.containsKey(filePath)) {
      debugPrint('⏳ 等待文件读取完成: $filePath');
      return await _readingOperations[filePath]!.future;
    }

    // 控制并发读取
    if (_currentReads >= _maxConcurrentReads) {
      debugPrint('⏳ 等待读取槽位: $filePath');
      final completer = Completer<void>();
      _readQueue.add(completer);
      await completer.future;
    }

    _currentReads++;
    final completer = Completer<Uint8List>();
    _readingOperations[filePath] = completer;

    try {
      final file = File(filePath);
      final fileSize = await file.length();

      debugPrint('📖 开始读取文件: $filePath (${_formatFileSize(fileSize)})');

      Uint8List result;

      if (fileSize <= _maxMemorySize) {
        // 小文件直接读取
        result = await _readSmallFile(file, progressCallback);
      } else {
        // 大文件流式读取
        result = await _readLargeFile(file, bufferSize, progressCallback);
      }

      // 缓存结果
      _cacheFile(filePath, result);

      completer.complete(result);
      return result;
    } catch (e) {
      debugPrint('❌ 读取文件失败: $filePath, 错误: $e');
      completer.completeError(e);
      rethrow;
    } finally {
      _currentReads--;
      _readingOperations.remove(filePath);

      // 处理等待队列
      if (_readQueue.isNotEmpty && _currentReads < _maxConcurrentReads) {
        final nextCompleter = _readQueue.removeFirst();
        nextCompleter.complete();
      }
    }
  }

  /// 读取小文件
  Future<Uint8List> _readSmallFile(
    File file,
    Function(double progress)? progressCallback,
  ) async {
    progressCallback?.call(0.0);

    final bytes = await file.readAsBytes();

    progressCallback?.call(1.0);
    debugPrint('✅ 小文件读取完成: ${bytes.length} 字节');

    return bytes;
  }

  /// 读取大文件（流式）
  Future<Uint8List> _readLargeFile(
    File file,
    int bufferSize,
    Function(double progress)? progressCallback,
  ) async {
    final fileSize = await file.length();
    final bytesBuilder = BytesBuilder();
    int bytesRead = 0;

    progressCallback?.call(0.0);

    await for (final chunk in file.openRead()) {
      bytesBuilder.add(chunk);
      bytesRead += chunk.length;

      final progress = bytesRead / fileSize;
      progressCallback?.call(progress);

      // 内存管理：如果积累过多数据，暂停一下
      if (bytesBuilder.length > _maxMemorySize) {
        debugPrint('⚠️ 内存使用过高，暂停读取');
        await Future.delayed(Duration(milliseconds: 10));
      }
    }

    progressCallback?.call(1.0);
    final result = bytesBuilder.toBytes();

    debugPrint('✅ 大文件读取完成: ${result.length} 字节');
    return result;
  }

  /// 流式读取文件（逐行）
  ///
  /// [filePath] 文件路径
  /// [encoding] 文本编码
  /// [lineHandler] 行处理函数
  /// [progressCallback] 进度回调
  Future<void> readFileByLines(
    String filePath, {
    Encoding encoding = utf8,
    required Function(String line) lineHandler,
    Function(double progress)? progressCallback,
  }) async {
    final file = File(filePath);
    final fileSize = await file.length();
    int bytesRead = 0;

    progressCallback?.call(0.0);

    final stream =
        file.openRead().transform(utf8.decoder).transform(LineSplitter());

    await for (final line in stream) {
      await lineHandler(line);

      // 估算进度（不准确，但聊胜于无）
      bytesRead += line.length + 1; // +1 for newline
      final progress = bytesRead / fileSize;
      progressCallback?.call(progress.clamp(0.0, 1.0));
    }

    progressCallback?.call(1.0);
    debugPrint('✅ 逐行读取完成: $filePath');
  }

  /// 读取文件部分内容
  ///
  /// [filePath] 文件路径
  /// [start] 起始位置
  /// [end] 结束位置
  Future<Uint8List> readFileRange(
    String filePath,
    int start,
    int end,
  ) async {
    final file = File(filePath);
    final fileSize = await file.length();

    // 参数验证
    if (start < 0) start = 0;
    if (end > fileSize) end = fileSize;
    if (start >= end) return Uint8List(0);

    debugPrint('📖 读取文件范围: $filePath [$start-$end]');

    final randomAccessFile = await file.open();
    try {
      await randomAccessFile.setPosition(start);
      final length = end - start;
      final bytes = await randomAccessFile.read(length);
      return bytes;
    } finally {
      await randomAccessFile.close();
    }
  }

  /// 计算文件哈希值
  ///
  /// [filePath] 文件路径
  /// [algorithm] 哈希算法，默认MD5
  /// [progressCallback] 进度回调
  Future<String> calculateFileHash(
    String filePath, {
    Hash algorithm = md5,
    Function(double progress)? progressCallback,
  }) async {
    final file = File(filePath);
    final fileSize = await file.length();
    int bytesRead = 0;

    progressCallback?.call(0.0);

    final output = AccumulatorSink<Digest>();
    final input = algorithm.startChunkedConversion(output);

    await for (final chunk in file.openRead()) {
      input.add(chunk);
      bytesRead += chunk.length;

      final progress = bytesRead / fileSize;
      progressCallback?.call(progress);
    }

    input.close();
    final digest = output.events.single;

    progressCallback?.call(1.0);
    debugPrint('✅ 文件哈希计算完成: $filePath');

    return digest.toString();
  }

  /// 缓存文件
  void _cacheFile(String filePath, Uint8List data) {
    // 限制缓存大小
    if (_fileCache.length >= 10) {
      _evictOldestCache();
    }

    _fileCache[filePath] = FileCache(
      data: data,
      timestamp: DateTime.now(),
      size: data.length,
    );

    debugPrint('💾 文件已缓存: $filePath (${_formatFileSize(data.length)})');
  }

  /// 淘汰最旧的缓存
  void _evictOldestCache() {
    if (_fileCache.isEmpty) return;

    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in _fileCache.entries) {
      if (oldestTime == null || entry.value.timestamp.isBefore(oldestTime)) {
        oldestTime = entry.value.timestamp;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      final removed = _fileCache.remove(oldestKey);
      debugPrint(
          '🗑️ 淘汰缓存: $oldestKey (${_formatFileSize(removed?.size ?? 0)})');
    }
  }

  /// 清除缓存
  void clearCache() {
    final totalSize =
        _fileCache.values.map((cache) => cache.size).reduce((a, b) => a + b);

    _fileCache.clear();
    debugPrint('🗑️ 清除文件缓存，释放: ${_formatFileSize(totalSize)}');
  }

  /// 获取缓存统计
  Map<String, dynamic> getCacheStats() {
    final totalSize =
        _fileCache.values.map((cache) => cache.size).reduce((a, b) => a + b);

    return {
      'cacheCount': _fileCache.length,
      'totalSize': totalSize,
      'totalSizeMB': (totalSize / 1024 / 1024).toStringAsFixed(2),
      'currentReads': _currentReads,
      'queueLength': _readQueue.length,
    };
  }

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }
}

/// 文件缓存
class FileCache {
  final Uint8List data;
  final DateTime timestamp;
  final int size;
  static const Duration _maxAge = Duration(hours: 1);

  FileCache({
    required this.data,
    required this.timestamp,
    required this.size,
  });

  /// 检查缓存是否有效
  bool get isValid {
    return DateTime.now().difference(timestamp) < _maxAge;
  }
}

/// 文件读取器扩展
extension FileReaderExtensions on File {
  /// 优化的字符串读取
  Future<String> readAsStringOptimized({
    Encoding encoding = utf8,
    Function(double progress)? progressCallback,
  }) async {
    return await OptimizedFileReader().readFileAsString(
      path,
      encoding: encoding,
      progressCallback: progressCallback,
    );
  }

  /// 优化的字节数组读取
  Future<Uint8List> readAsBytesOptimized({
    Function(double progress)? progressCallback,
  }) async {
    return await OptimizedFileReader().readFileAsBytes(
      path,
      progressCallback: progressCallback,
    );
  }

  /// 优化的哈希计算
  Future<String> calculateHash({
    Hash algorithm = md5,
    Function(double progress)? progressCallback,
  }) async {
    return await OptimizedFileReader().calculateFileHash(
      path,
      algorithm: algorithm,
      progressCallback: progressCallback,
    );
  }
}

/// 文件操作工具类
class FileOperationUtils {
  /// 流式复制文件
  ///
  /// [sourcePath] 源文件路径
  /// [targetPath] 目标文件路径
  /// [bufferSize] 缓冲区大小
  /// [progressCallback] 进度回调
  static Future<void> copyFileStreaming(
    String sourcePath,
    String targetPath, {
    int bufferSize = OptimizedFileReader._defaultBufferSize,
    Function(double progress)? progressCallback,
  }) async {
    final sourceFile = File(sourcePath);
    final targetFile = File(targetPath);

    // 确保目标目录存在
    final targetDir = targetFile.parent;
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final fileSize = await sourceFile.length();
    int bytesCopied = 0;

    progressCallback?.call(0.0);

    final sourceStream = sourceFile.openRead();
    final targetSink = targetFile.openWrite();

    try {
      await for (final chunk in sourceStream) {
        targetSink.add(chunk);
        bytesCopied += chunk.length;

        final progress = bytesCopied / fileSize;
        progressCallback?.call(progress);
      }

      await targetSink.flush();
      progressCallback?.call(1.0);

      debugPrint('✅ 文件复制完成: $sourcePath -> $targetPath');
    } finally {
      await targetSink.close();
    }
  }

  /// 比较两个文件是否相同
  ///
  /// [path1] 文件1路径
  /// [path2] 文件2路径
  /// [compareHash] 是否比较哈希值（较慢但准确）
  static Future<bool> areFilesEqual(
    String path1,
    String path2, {
    bool compareHash = false,
  }) async {
    final file1 = File(path1);
    final file2 = File(path2);

    // 检查文件大小
    final size1 = await file1.length();
    final size2 = await file2.length();

    if (size1 != size2) return false;

    if (!compareHash) {
      // 简单比较：读取并比较内容
      final reader = OptimizedFileReader();
      final bytes1 = await reader.readFileAsBytes(path1);
      final bytes2 = await reader.readFileAsBytes(path2);
      return _bytesEqual(bytes1, bytes2);
    } else {
      // 哈希比较
      final reader = OptimizedFileReader();
      final hash1 = await reader.calculateFileHash(path1);
      final hash2 = await reader.calculateFileHash(path2);
      return hash1 == hash2;
    }
  }

  /// 比较两个字节数组是否相等
  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
