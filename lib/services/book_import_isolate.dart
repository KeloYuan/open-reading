import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Isolate工作参数
class HashCalculationParams {
  final String filePath;
  final int chunkSize;

  HashCalculationParams({
    required this.filePath,
    this.chunkSize = 1024 * 1024, // 1MB chunks
  });
}

/// 文件哈希计算结果
class HashCalculationResult {
  final String hash;
  final int fileSize;

  HashCalculationResult({
    required this.hash,
    required this.fileSize,
  });
}

/// 元数据提取参数
class MetadataExtractionParams {
  final Uint8List bytes;
  final String fileName;
  final String extension;

  MetadataExtractionParams({
    required this.bytes,
    required this.fileName,
    required this.extension,
  });
}

/// 简化的元数据结果（用于isolate传输）
class SimpleMetadata {
  final String title;
  final String author;
  final int estimatedPages;
  final String? description;
  final String? language;

  SimpleMetadata({
    required this.title,
    required this.author,
    required this.estimatedPages,
    this.description,
    this.language,
  });
}

/// 在isolate中分块计算文件哈希
///
/// 参数 [params] 包含文件路径和分块大小
/// 返回包含哈希值和文件大小的结果
Future<HashCalculationResult> calculateFileHashInIsolate(
  HashCalculationParams params,
) async {
  final file = File(params.filePath);
  if (!await file.exists()) {
    throw Exception('File does not exist: ${params.filePath}');
  }

  final fileSize = await file.length();

  // 使用流式计算hash以支持大文件
  final hash = await md5.bind(file.openRead()).first;

  return HashCalculationResult(
    hash: hash.toString(),
    fileSize: fileSize,
  );
}

/// 在isolate中提取TXT元数据
///
/// 参数 [params] 包含文件字节数据、文件名和扩展名
/// 返回简化的元数据对象
Future<SimpleMetadata> extractTxtMetadataInIsolate(
  MetadataExtractionParams params,
) async {
  try {
    // 只读取文件的前100KB用于元数据提取
    final maxBytesForMetadata = 100 * 1024; // 100KB
    final bytesToAnalyze = params.bytes.length > maxBytesForMetadata
        ? params.bytes.sublist(0, maxBytesForMetadata)
        : params.bytes;

    // 尝试检测编码
    String content;
    try {
      content = utf8.decode(bytesToAnalyze, allowMalformed: true);
    } catch (e) {
      // 如果UTF-8失败，尝试GBK（简化处理）
      content = latin1.decode(bytesToAnalyze);
    }

    // 提取标题（从前几行）
    final lines = content
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(20)
        .toList();

    String title = params.fileName
        .replaceAll(RegExp(r'\.(txt)$', caseSensitive: false), '');
    if (lines.isNotEmpty) {
      // 查找合适的标题行
      for (var line in lines) {
        if (line.length >= 2 && line.length <= 50 && !line.contains('http')) {
          title = line.substring(0, line.length.clamp(0, 50));
          break;
        }
      }
    }

    // 估算页数（基于文件大小，避免完全解析）
    final estimatedPages = (params.bytes.length / 1500).ceil().clamp(1, 9999);

    // 提取描述（前200字符）
    String? description;
    if (content.length > 100) {
      description = content.substring(0, content.length.clamp(0, 200)).trim();
    }

    return SimpleMetadata(
      title: title,
      author: 'Unknown',
      estimatedPages: estimatedPages,
      description: description,
      language: 'zh',
    );
  } catch (e) {
    debugPrint('TXT元数据提取失败: $e');
    // 返回基础元数据
    return SimpleMetadata(
      title: params.fileName
          .replaceAll(RegExp(r'\.(txt)$', caseSensitive: false), ''),
      author: 'Unknown',
      estimatedPages: (params.bytes.length / 10000).ceil().clamp(1, 9999),
    );
  }
}

/// 在isolate中提取MOBI元数据
///
/// 参数 [params] 包含文件字节数据、文件名和扩展名
/// 返回简化的元数据对象
Future<SimpleMetadata> extractMobiMetadataInIsolate(
  MetadataExtractionParams params,
) async {
  try {
    String title = params.fileName.replaceAll(
      RegExp(r'\.(mobi|azw|azw3)$', caseSensitive: false),
      '',
    );

    int estimatedPages = 100;

    // 只读取文件头部和部分内容
    if (params.bytes.length >= 68) {
      final identifier = String.fromCharCodes(params.bytes.sublist(60, 68));

      if (identifier.contains('BOOKMOBI') || identifier.contains('TEXTREAD')) {
        // 只分析文件的前500KB
        final maxBytesForAnalysis = 500 * 1024;
        final bytesToAnalyze = params.bytes.length > maxBytesForAnalysis
            ? params.bytes.sublist(0, maxBytesForAnalysis)
            : params.bytes;

        try {
          String content = utf8.decode(bytesToAnalyze, allowMalformed: true);
          content = content.replaceAll(RegExp(r'<[^>]*>'), ' ');
          content = content.replaceAll(RegExp(r'\s+'), ' ').trim();

          // 提取标题
          final lines = content.split(' ').take(100).toList();
          for (var line in lines) {
            final trimmed = line.trim();
            if (trimmed.isNotEmpty &&
                trimmed.length > 3 &&
                trimmed.length < 100) {
              title = trimmed;
              break;
            }
          }
        } catch (e) {
          debugPrint('MOBI内容分析失败: $e');
        }
      }
    }

    // 基于文件大小估算页数
    estimatedPages = (params.bytes.length / 3000).ceil().clamp(50, 1000);

    return SimpleMetadata(
      title: title,
      author: 'Unknown',
      estimatedPages: estimatedPages,
    );
  } catch (e) {
    debugPrint('MOBI元数据提取失败: $e');
    return SimpleMetadata(
      title: params.fileName.replaceAll(
        RegExp(r'\.(mobi|azw|azw3)$', caseSensitive: false),
        '',
      ),
      author: 'Unknown',
      estimatedPages: (params.bytes.length / 3000).ceil().clamp(50, 1000),
    );
  }
}
