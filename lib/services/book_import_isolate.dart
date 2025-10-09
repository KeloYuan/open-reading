import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:gbk_codec/gbk_codec.dart';

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

    // 智能检测编码（支持 GB2312/GBK/UTF-8）
    String content = _detectAndDecodeText(bytesToAnalyze);

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
          // 使用智能编码检测
          String content = _detectAndDecodeText(bytesToAnalyze);
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

/// 智能检测并解码文本（支持 GB2312/GBK/UTF-8）
///
/// 在 isolate 中使用的简化版编码检测
/// 参数 [bytes] 要解码的字节数组
/// 返回解码后的文本内容
String _detectAndDecodeText(Uint8List bytes) {
  debugPrint('🔍 [Isolate] 开始编码检测，文件大小: ${bytes.length} 字节');

  // 1. 检测 BOM
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    debugPrint('✅ [Isolate] UTF-8 BOM');
    return utf8.decode(bytes.sublist(3));
  }

  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    debugPrint('✅ [Isolate] UTF-16 LE BOM');
    return _decodeUtf16LE(bytes.sublist(2));
  }

  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    debugPrint('✅ [Isolate] UTF-16 BE BOM');
    return _decodeUtf16BE(bytes.sublist(2));
  }

  // 2. 尝试 UTF-8 严格模式
  debugPrint('📊 [Isolate] 步骤1: UTF-8 严格模式...');
  try {
    final content = utf8.decode(bytes, allowMalformed: false);
    if (_isValidUtf8Content(content)) {
      debugPrint('✅ [Isolate] UTF-8 解码成功 (${content.length} 字符)');
      return content;
    }
    debugPrint('⚠️ [Isolate] UTF-8 内容验证失败');
  } catch (e) {
    debugPrint('⚠️ [Isolate] UTF-8 严格模式失败');
  }

  // 3. 检测 GBK 特征
  debugPrint('📊 [Isolate] 步骤2: GBK 特征检测...');
  final gbkScore = _calculateGbkScore(bytes);
  debugPrint('   GBK 评分: ${gbkScore.toStringAsFixed(2)}');

  if (gbkScore > 0.3) {
    try {
      final content = gbk.decode(bytes);
      if (content.isNotEmpty && _isValidGbkContent(content)) {
        debugPrint('✅ [Isolate] GBK 解码成功 (${content.length} 字符)');
        return content;
      }
      debugPrint('⚠️ [Isolate] GBK 内容验证失败');
    } catch (e) {
      debugPrint('❌ [Isolate] GBK 解码失败: $e');
    }
  }

  // 4. UTF-8 宽松模式
  debugPrint('📊 [Isolate] 步骤3: UTF-8 宽松模式...');
  try {
    final content = utf8.decode(bytes, allowMalformed: true);
    if (content.isNotEmpty && !_hasExcessiveReplacementChars(content)) {
      debugPrint('✅ [Isolate] UTF-8 宽松模式成功 (${content.length} 字符)');
      return content;
    }
    debugPrint('⚠️ [Isolate] UTF-8 宽松模式替换字符过多');
  } catch (e) {
    debugPrint('❌ [Isolate] UTF-8 宽松模式失败: $e');
  }

  // 5. 强制 GBK
  debugPrint('📊 [Isolate] 步骤4: 强制 GBK...');
  try {
    final content = gbk.decode(bytes);
    if (content.isNotEmpty) {
      debugPrint('⚠️ [Isolate] 强制 GBK (${content.length} 字符)');
      return content;
    }
  } catch (e) {
    debugPrint('❌ [Isolate] 强制 GBK 失败: $e');
  }

  // 6. 最终降级
  debugPrint('⚠️ [Isolate] 最终降级：UTF-8 宽松');
  return utf8.decode(bytes, allowMalformed: true);
}

/// UTF-16 LE 解码
String _decodeUtf16LE(Uint8List bytes) {
  final buffer = StringBuffer();
  for (int i = 0; i < bytes.length - 1; i += 2) {
    final codeUnit = bytes[i] | (bytes[i + 1] << 8);
    buffer.writeCharCode(codeUnit);
  }
  return buffer.toString();
}

/// UTF-16 BE 解码
String _decodeUtf16BE(Uint8List bytes) {
  final buffer = StringBuffer();
  for (int i = 0; i < bytes.length - 1; i += 2) {
    final codeUnit = (bytes[i] << 8) | bytes[i + 1];
    buffer.writeCharCode(codeUnit);
  }
  return buffer.toString();
}

/// 计算 GBK 特征评分
double _calculateGbkScore(Uint8List bytes) {
  if (bytes.length < 100) return 0.0;

  int gbkPairCount = 0;
  int totalPairs = 0;
  int validPairs = 0;

  final checkLength = math.min(bytes.length, 2000);

  for (int i = 0; i < checkLength - 1; i++) {
    final byte1 = bytes[i];

    if (byte1 >= 0x81 && byte1 <= 0xFE) {
      totalPairs++;
      final byte2 = bytes[i + 1];

      if (byte2 >= 0x40 && byte2 <= 0xFE && byte2 != 0x7F) {
        gbkPairCount++;

        // GB2312 常用汉字区域
        if (byte1 >= 0xB0 && byte1 <= 0xF7 && byte2 >= 0xA1 && byte2 <= 0xFE) {
          validPairs++;
        }

        i++;
      }
    }
  }

  if (totalPairs == 0) return 0.0;

  final matchRatio = gbkPairCount / totalPairs;
  final validRatio = validPairs > 0 ? validPairs / gbkPairCount : 0.0;

  return matchRatio * 0.7 + validRatio * 0.3;
}

/// 验证 UTF-8 内容
bool _isValidUtf8Content(String content) {
  if (content.isEmpty) return false;

  final replacementCount = content.codeUnits.where((c) => c == 0xFFFD).length;
  if (replacementCount > content.length * 0.01) return false;

  final controlCount = content.codeUnits.where((c) {
    return c < 32 && c != 9 && c != 10 && c != 13;
  }).length;

  return controlCount < content.length * 0.05;
}

/// 验证 GBK 内容
bool _isValidGbkContent(String content) {
  if (content.isEmpty) return false;

  final replacementCount = content.codeUnits.where((c) => c == 0xFFFD).length;
  if (replacementCount > content.length * 0.05) return false;

  final chineseCount = RegExp(r'[\u4e00-\u9fff]').allMatches(content).length;
  if (chineseCount > 0) return true;

  final printableCount = content.codeUnits.where((c) {
    return (c >= 32 && c <= 126) || c == 9 || c == 10 || c == 13;
  }).length;

  return printableCount > content.length * 0.8;
}

/// 检查是否有过多替换字符
bool _hasExcessiveReplacementChars(String content) {
  final replacementCount = content.codeUnits.where((c) => c == 0xFFFD).length;
  return replacementCount > content.length * 0.1;
}
